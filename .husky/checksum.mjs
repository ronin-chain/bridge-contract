// verifyContractsPretty.mjs – Optimized & prettier‑logging version (plain JS)
// ---------------------------------------------------------------
// • Consolidates async work so logs don't interleave
// • Uses cli‑table3 + chalk + log‑symbols for tidy output
// • Pure ECMAScript module, no TypeScript types
// ---------------------------------------------------------------

import fs from "fs";
import path from "path";
import { execSync } from "child_process";
import { promises as fsPromises } from "fs";
import { ethers } from "ethers";
import pLimit from "p-limit";
import chalk from "chalk";
import symbols from "log-symbols";
import Table from "cli-table3";
import * as dotenv from "dotenv";

// Node ≥18 has global fetch; for older versions uncomment:
// import fetch from "node-fetch";
// globalThis.fetch = globalThis.fetch || fetch;

dotenv.config();

/*********************************
 * CONFIG & CONSTANTS            *
 *********************************/

const config = JSON.parse(execSync("forge config --json", { encoding: "utf-8" }));

const implSlot = "0x" + (BigInt(ethers.id("eip1967.proxy.implementation")) - 1n).toString(16);

const skipChains = new Set([5, 2022]); // goerli, ronin‑devnet

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

const timed = async (label, fn) => {
	const start = Date.now();
	const result = await fn();
	const ms = Date.now() - start;
	console.log(chalk.cyan(`✔ ${label} – ${ms}ms`));
	return result;
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
			"0x" +
			dependencyChecksums
				.reduce((acc, { checksum }) => acc ^ BigInt(checksum), 0n)
				.toString(16)
				.padStart(64, "0");
		return { contractName: getContractName(metadata), aggregatedChecksum, dependencyChecksums };
	});

const loadLocalChecksums = async () => {
	const filterRegex = /^(?!.*\.(?:s|t)\.sol$).*\.sol$/;
	const artifactDirs = fs
		.readdirSync(config.out, { withFileTypes: true })
		.filter((d) => d.isDirectory() && filterRegex.test(d.name))
		.map((d) => path.join(d.path, d.name));

	const artifactFiles = (
		await Promise.all(
			artifactDirs.map((dir) =>
				fsPromises
					.readdir(dir, { withFileTypes: true })
					.then((files) => files.filter((f) => f.name.endsWith(".json")).map((f) => path.join(dir, f.name)))
			)
		)
	).flat();

	const contents = await Promise.all(artifactFiles.map((p) => fsPromises.readFile(p, "utf8").then(JSON.parse)));

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
				if (cid && !skipChains.has(Number(cid))) out[Number(cid)] = ep;
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
		Object.entries(addrByChain).map(async ([cidStr, addrs]) => {
			const cid = Number(cidStr);
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
	return d?.status === "1" ? !!d.result[0]?.SourceCode : null;
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
 * PRETTY LOGGING HELPERS         *
 *********************************/

const prettyBool = (ok) => {
	if (ok === "NA") return chalk.yellow("NA");
	return ok ? chalk.green(symbols.success) : chalk.red(symbols.error);
};

const printTable = (rows) => {
	const table = new Table({
		head: [
			chalk.bold("Address"),
			chalk.bold("Contract"),
			chalk.bold("Etherscan"),
			chalk.bold("Sourcify"),
			chalk.bold("Checksum"),
			chalk.bold("Notes"),
		],
		wordWrap: true,
		colWidths: [52, 44, 15, 15, 15, 40],
	});
	rows.forEach((r) => table.push([r.address, r.contract, r.etherscan, r.sourcify, r.checksum, r.notes]));
	console.log(table.toString());
};

const printChecksumDiff = (contractName, addr, localDeps, remoteDeps) => {
	// Build quick lookup maps by basename for easier side‑by‑side diff
	const localByFile = Object.fromEntries(localDeps.map((d) => [path.basename(d.path), d]));
	const remoteByFile = Object.fromEntries(remoteDeps.map((d) => [path.basename(d.path), d]));
	const allFiles = [...new Set([...Object.keys(localByFile), ...Object.keys(remoteByFile)])];

	// Helper to shorten long hashes
	const short = (cs) => (cs ? cs.slice(0, 10) + "…" + cs.slice(-8) : "—");

	const table = new Table({
		head: [chalk.bold("File"), chalk.bold("Local"), chalk.bold("Remote"), chalk.bold("Status")],
		colWidths: [38, 22, 22, 14],
		wordWrap: true,
	});

	allFiles.forEach((file) => {
		const l = localByFile[file]?.checksum;
		const r = remoteByFile[file]?.checksum;

		if (l === r) return; // identical – no diff needed

		let status;
		if (!l) status = chalk.yellow("only remote");
		else if (!r) status = chalk.yellow("only local");
		else status = chalk.red("mismatch");

		table.push([file, short(l), short(r), status]);
	});

	if (table.length) {
		console.log(chalk.yellow(`   • Checksum diff details, ${contractName} (${addr})`));
		console.log(table.toString());
	}
};

/*********************************
 * MAIN LOGIC                     *
 *********************************/

const verifyChain = async (cid, addrs, localChecksums) => {
	const limit = pLimit(2);
	const rows = [];

	await Promise.all(
		addrs.map((addr) =>
			limit(async () => {
				try {
					let [verifiedEtherscan, sour] = await Promise.all([
						getEtherscanStatus(cid, addr),
						getSourcifyStatus(cid, addr),
					]);
					let meta = sour?.metadata;
					const sourStatus = sour?.status;

					const verifiedSourcify = ["perfect", "partial", "exact_match", "match"].includes(sourStatus);

					if (!verifiedSourcify && verifiedEtherscan) await importFromEtherscan(cid, addr);
					if (!meta) meta = await fetchMetadata(cid, addr);

					if (!meta) {
						rows.push({
							address: addr,
							contract: "?",
							etherscan: prettyBool(verifiedEtherscan),
							sourcify: prettyBool(false),
							checksum: prettyBool(false),
							notes: chalk.red("No metadata found"),
						});
						return;
					}

					const contractName = getContractName(meta);
					const local = localChecksums[contractName];

					if (!local) {
						rows.push({
							address: addr,
							contract: contractName,
							etherscan: prettyBool(verifiedEtherscan),
							sourcify: prettyBool(verifiedSourcify),
							checksum: prettyBool(false),
							notes: chalk.yellow("No local artifact"),
						});
						return;
					}

					const [{ aggregatedChecksum: remoteAgg, dependencyChecksums: remoteDeps }] = generateChecksums([
						{ metadata: meta },
					]);
					const checksumMatch = local.aggregatedChecksum.toLowerCase() === remoteAgg.toLowerCase();

					rows.push({
						address: addr,
						contract: contractName,
						etherscan: prettyBool(verifiedEtherscan),
						sourcify: prettyBool(verifiedSourcify),
						checksum: prettyBool(checksumMatch),
						notes: checksumMatch ? chalk.green("Checksum full match") : chalk.red("Checksum mismatch"),
					});

					if (!checksumMatch) printChecksumDiff(contractName, addr, local.dependencyChecksums, remoteDeps);
				} catch (e) {
					rows.push({
						address: addr,
						contract: "?",
						etherscan: prettyBool(false),
						sourcify: prettyBool(false),
						checksum: prettyBool(false),
						notes: chalk.red(e.message || e.toString()),
					});
				}
			})
		)
	);

	printTable(rows);
};

const main = async () => {
	const localChecksums = await timed("Local checksums", loadLocalChecksums);
	const rpcs = await timed("RPC discovery", discoverRpcs);
	const deployed = await timed("Load deployments", loadDeploymentAddresses);
	const impls = await timed("Resolve impls", () => resolveImpls(deployed, rpcs));

	const addrByChain = {};
	for (const [cid, proxies] of Object.entries(deployed)) {
		addrByChain[cid] = [...new Set([...(proxies || []), ...(impls[cid] || [])])];
	}

	for (const [cidStr, addrs] of Object.entries(addrByChain)) {
		console.log(chalk.magenta.bold(`\n=== Chain ${cidStr} (${addrs.length} contracts) ===`));
		await verifyChain(Number(cidStr), addrs, localChecksums);
	}
};

if (import.meta.url === `file://${process.argv[1]}`) {
	main().catch((e) => {
		console.error(chalk.red(e));
		process.exit(1);
	});
}
