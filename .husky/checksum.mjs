import fs from "fs";
import path from "path";
import { execSync } from "child_process";
import { promises as fsPromises } from "fs";
import { ethers } from "ethers";
import pLimit from "p-limit";
import chalk from "chalk";
import * as dotenv from "dotenv";
import { exit } from "process";

dotenv.config();

/*********************************
 * CONFIG & CONSTANTS            *
 *********************************/

// Read foundry.toml config produced by `forge config --json`
const config = JSON.parse(execSync("forge config --json", { encoding: "utf-8" }));

// EIP‑1967 slots
const adminSlot = "0x" + (BigInt(ethers.id("eip1967.proxy.admin")) - 1n).toString(16);
const implSlot = "0x" + (BigInt(ethers.id("eip1967.proxy.implementation")) - 1n).toString(16);

// Skip networks
const skipChains = new Set([5, 2022]); // goerli, ronin‑devnet

// Sourcify / Etherscan endpoints
const sourcifyEndpoints = {
	2020: "https://sourcify.roninchain.com/server/",
	2021: "https://sourcify.roninchain.com/server/",
	1: "https://sourcify.dev/server/",
	11155111: "https://sourcify.dev/server/",
	5: "https://sourcify.dev/server/",
};

const sourcifyRepos = {
	2020: "https://sourcify-repo.roninchain.com/",
	2021: "https://sourcify-repo.roninchain.com/",
	1: "https://repo.sourcify.dev/",
	11155111: "https://repo.sourcify.dev/",
	5: "https://repo.sourcify.dev/",
};

const etherscanEndpoints = {
	1: "https://api.etherscan.io/api",
	5: "https://api-goerli.etherscan.io/api",
	11155111: "https://api-sepolia.etherscan.io/api",
};

/*********************************
 * HELPER UTILS                  *
 *********************************/

const interpolateEnv = (str) => str.replace(/\$\{([^}]+)}/g, (_, k) => process.env[k] || "");

const fetchJson = async (url, options = {}, allowError = false) => {
	try {
		const res = await fetch(url, options);
		if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
		return await res.json();
	} catch (err) {
		if (allowError) return null;
		throw err;
	}
};

const getContractName = (metadata) => Object.values(metadata.settings.compilationTarget)[0];

const time = async (label, fn) => {
	console.time(chalk.cyan(label));
	const res = await fn();
	console.timeEnd(chalk.cyan(label));
	return res;
};

/*********************************
 * LOCAL ARTIFACT CHECKSUMS       *
 *********************************/

const generateChecksums = (artifacts) =>
	artifacts.map(({ metadata }) => {
		const dependencyChecksums = Object.entries(metadata.sources)
			.map(([p, v]) => ({ path: p, checksum: v.keccak256 }))
			.sort((a, b) => path.basename(a.path).localeCompare(path.basename(b.path)));
		const aggregatedChecksum =
			"0x" + dependencyChecksums.reduce((acc, { checksum }) => acc ^ BigInt(checksum), 0n).toString(16);
		return {
			contractName: getContractName(metadata),
			aggregatedChecksum,
			dependencyChecksums,
		};
	});

const loadLocalChecksums = async () => {
	const filterRegex = /^(?!.*\.(?:s|t)\.sol$).*\.sol$/;
	const artifactDirs = fs
		.readdirSync(config.out, { withFileTypes: true })
		.filter((d) => d.isDirectory() && filterRegex.test(d.name))
		.map((d) => path.join(d.path, d.name));

	const artifacts = (
		await Promise.all(
			artifactDirs.map((dir) =>
				fsPromises
					.readdir(dir, { withFileTypes: true })
					.then((files) => files.filter((f) => f.name.endsWith(".json")).map((f) => path.join(dir, f.name)))
			)
		)
	).flat();

	const contents = await Promise.all(artifacts.map((p) => fsPromises.readFile(p, "utf8").then(JSON.parse)));

	const valid = contents.filter(({ metadata, methodIdentifiers, deployedBytecode }) => {
		const name = getContractName(metadata);
		return !/mock|test/i.test(name) && Object.keys(methodIdentifiers).length && deployedBytecode.object !== "0x";
	});

	return generateChecksums(valid).reduce((acc, c) => {
		acc[c.contractName] = c;
		return acc;
	}, {});
};

/*********************************
 * RPC & DEPLOYMENT DISCOVERY     *
 *********************************/

const batchRpc = async (endpoint, reqs) => {
	const res = await fetch(endpoint, {
		method: "POST",
		headers: { "Content-Type": "application/json" },
		body: JSON.stringify(reqs),
	});
	const json = await res.json();
	return json.map((o) => o.result);
};

const discoverRpcs = async () => {
	const endpoints = Object.values(config.rpc_endpoints).map(interpolateEnv);
	const out = {};
	await Promise.all(
		endpoints.map(async (ep) => {
			try {
				const [cid] = await batchRpc(ep, [{ jsonrpc: "2.0", id: 1, method: "eth_chainId", params: [] }]);
				if (cid && !skipChains.has(Number(cid))) out[BigInt(cid)] = ep;
			} catch {
				/* ignore */
			}
		})
	);
	return out;
};

const loadDeploymentAddresses = async () => {
	const root = "./deployments";
	const byChain = {};
	for (const dir of fs.readdirSync(root, { withFileTypes: true })) {
		if (!dir.isDirectory()) continue;
		const cid = parseInt(fs.readFileSync(path.join(root, dir.name, ".chainId"), "utf8"));
		if (skipChains.has(cid)) continue;
		const files = await fsPromises.readdir(path.join(root, dir.name));
		byChain[cid] = files
			.filter((f) => f.endsWith(".json") && !f.endsWith("Logic.json"))
			.map((f) => JSON.parse(fs.readFileSync(path.join(root, dir.name, f), "utf8")).address)
			.map(ethers.getAddress);
	}
	return byChain;
};

const resolveImpls = async (addrByChain, rpcs) => {
	const limit = pLimit(8);
	const impls = {};
	await Promise.all(
		Object.entries(addrByChain).map(async ([cid, addrs]) => {
			const ep = rpcs[cid];
			if (!ep) return;
			const reqs = addrs.map((a, i) => ({
				id: i + 1,
				jsonrpc: "2.0",
				method: "eth_getStorageAt",
				params: [a, implSlot, "latest"],
			}));
			const res = await batchRpc(ep, reqs);
			impls[cid] = res.map((hex) => ethers.getAddress(hex.slice(-40))).filter((a) => a !== ethers.ZeroAddress);
		})
	);
	return impls;
};

/*********************************
 * SOURCIFY / ETHERSCAN HELPERS   *
 *********************************/

const getEtherscanStatus = async (cid, addr) => {
	const base = etherscanEndpoints[cid];
	if (!base) return "NA";
	const url = `${base}?module=contract&action=getsourcecode&address=${addr}&apikey=${process.env.ETHERSCAN_API_KEY}`;
	const d = await fetchJson(url, {}, true);
	return d?.status === "1" ? d.result[0] : null;
};

const getSourcifyStatus = async (cid, addr) => {
	const base = sourcifyEndpoints[cid];
	if (!base) return null;
	const v2 = await fetchJson(
		`${base}v2/contract/${cid}/${addr}?omit=matchId,deployment,proxyResolution,stdJsonOutput,stdJsonInput,sourceIds,compilation,sources,creationBytecode,runtimeBytecode,abi,userdoc,devdoc,storageLayout`,
		{},
		true
	);
	if (v2) return { metadata: v2.metadata, status: v2.match ?? v2.runtimeMatch ?? v2.creationMatch ?? "false" };
	const v1 = await fetchJson(`${base}check-all-by-addresses?addresses=${addr}&chainIds=${cid}`, {}, true);
	return Array.isArray(v1) ? { status: v1[0]?.chainIds[0]?.status } : null;
};

const importFromEtherscan = async (cid, addr) => {
	const base = sourcifyEndpoints[cid];
	const key = process.env.ETHERSCAN_API_KEY;
	if (!base || !key) return null;
	return await fetchJson(
		`${base}verify/etherscan`,
		{
			method: "POST",
			headers: { "Content-Type": "application/json" },
			body: JSON.stringify({ address: addr, chainId: String(cid), apiKey: key }),
		},
		true
	);
};

const fetchMetadata = async (cid, addr) => {
	const repo = sourcifyRepos[cid];
	if (!repo) return null;
	for (const kind of ["full_match", "partial_match"]) {
		const m = await fetchJson(`${repo}contracts/${kind}/${cid}/${addr}/metadata.json`, {}, true);
		if (m) return m;
	}
	return null;
};

/*********************************
 * DIFF UTIL                      *
 *********************************/

const printChecksumDiff = (localDeps, remoteDeps) => {
	const localMap = new Map(localDeps.map((d) => [d.checksum, d.path]));
	const remoteMap = new Map(remoteDeps.map((d) => [d.checksum, d.path]));
	const onlyLocal = [...localMap].filter(([c]) => !remoteMap.has(c));
	const onlyRemote = [...remoteMap].filter(([c]) => !localMap.has(c));
	if (onlyLocal.length) {
		console.log(chalk.yellow("   • Only local"));
		console.table(onlyLocal.map(([cs, p]) => ({ checksum: cs, path: p })));
	}
	if (onlyRemote.length) {
		console.log(chalk.yellow("   • Only remote"));
		console.table(onlyRemote.map(([cs, p]) => ({ checksum: cs, path: p })));
	}
};

/*********************************
 * MAIN                           *
 *********************************/

async function main() {
	const localChecksums = await time("Local checksums", loadLocalChecksums);
	const rpcs = await time("RPC discovery", discoverRpcs);
	const deployed = await time("Load deployments", loadDeploymentAddresses);
	const impls = await time("Resolve impls", () => resolveImpls(deployed, rpcs));

	// merge proxy + impl
	const addrByChain = {};
	for (const [cid, proxies] of Object.entries(deployed)) {
		addrByChain[cid] = [...new Set([...(proxies || []), ...(impls[cid] || [])])];
	}

	const limit = pLimit(4);

	for (const [cidStr, addrs] of Object.entries(addrByChain)) {
		const cid = Number(cidStr);
		console.log(chalk.magenta.bold(`\n=== Chain ${cid} ===`));

		await Promise.all(
			addrs.map((addr) =>
				limit(async () => {
					try {
						let [eth, { meta, status: sourcifyStatus }] = await Promise.all([
							getEtherscanStatus(cid, addr),
							getSourcifyStatus(cid, addr),
						]);
						const verifiedSourcify = ["perfect", "partial", "exact_match", "match"].includes(sourcifyStatus);
						const verifiedEtherscan = !!eth?.SourceCode;
						console.log(
							`Checking Verification: ${addr} | Etherscan:${
								verifiedEtherscan ? chalk.green("✔") : eth === "NA" ? chalk.yellow("⚠ NA") : chalk.red("✘")
							} | Sourcify:${verifiedSourcify ? chalk.green("✔") : chalk.red("✘")}`
						);

						if (!verifiedSourcify && verifiedEtherscan) {
							console.log(chalk.yellow("  ⚠ importing from etherscan..."));
							await importFromEtherscan(cid, addr);
						}

						if (!meta) meta = await fetchMetadata(cid, addr);
						if (!meta) {
							console.log(chalk.red("  ✘ no onchain metadata found"), addr);
							exit(1);
						}

						const local = localChecksums[getContractName(meta)];
						if (!local) {
							console.log(chalk.yellow("  ⚠ no local checksum"), `(${getContractName(meta)})`, addr);
							return;
						}

						const [{ aggregatedChecksum: remoteAgg, dependencyChecksums: remoteDeps }] = generateChecksums([
							{ metadata: meta },
						]);
						if (local.aggregatedChecksum.toLowerCase() === remoteAgg.toLowerCase()) {
							console.log(chalk.green(`  ✔ checksum match (${getContractName(meta)})`));
						} else {
							console.log(chalk.red(`  ✘ checksum mismatch (${getContractName(meta)})`, addr));
							printChecksumDiff(local.dependencyChecksums, remoteDeps);
						}
					} catch (e) {
						console.error(chalk.red("Error for"), addr, e.message);
					}
				})
			)
		);
	}
}

if (import.meta.url === `file://${process.argv[1]}`) {
	main().catch((e) => {
		console.error(e);
		process.exit(1);
	});
}
