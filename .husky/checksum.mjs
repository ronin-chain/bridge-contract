import fs from "fs";
import path from "path";
import { execSync } from "child_process";
import { promises as fsPromises } from "fs";
import { ethers } from "ethers";
import * as dotenv from "dotenv";

dotenv.config();

// Get foundry.toml config
const config = JSON.parse(execSync("forge config --json", { encoding: "utf-8" }));
const adminSlot = "0x" + (BigInt(ethers.id("eip1967.proxy.admin")) - 1n).toString(16);
const implSlot = "0x" + (BigInt(ethers.id("eip1967.proxy.implementation")) - 1n).toString(16);

console.log({ config });

const interpolateEnv = (str) => {
	return str.replace(/\$\{([^}]+)\}/g, (_, key) => process.env[key] || "");
};

const generateLocalChecksumsSync = async () => {
	// Get all child folders
	const filterRegex = /^(?!.*\.s\.sol$|.*\.t\.sol$).*\.sol$/;
	const childFolders = fs
		.readdirSync(config.out, { withFileTypes: true })
		.filter((dirent) => dirent.isDirectory() && filterRegex.test(dirent.name))
		.map((dirent) => path.join(dirent.path, dirent.name));

	// Get all JSON files in child folders
	const artifacts = (
		await Promise.all(
			childFolders.map(async (folder) => {
				const files = await fsPromises.readdir(folder, { withFileTypes: true });
				return files.filter((file) => file.name.endsWith(".json")).map((file) => path.join(folder, file.name));
			})
		)
	).flat();

	// Load all JSON files
	const artifactContents = await Promise.all(
		artifacts.map(async (filePath) => {
			const content = await fsPromises.readFile(filePath, "utf-8");
			return JSON.parse(content);
		})
	);

	// Filter out artifacts that are not valid (e.g., test, mock, lib, extension)
	const validArtifacts = artifactContents.filter(({ metadata, methodIdentifiers, deployedBytecode }) => {
		const { compilationTarget } = metadata.settings;
		const [, contractName] = Object.entries(compilationTarget)[0];

		const isInvalidPath = new RegExp(`^(${config.libs}|${config.test}|${config.script}|mock)`, "i").test(path);
		const isMockOrTest = /mock|test/i.test(contractName);
		const isLib = Object.keys(methodIdentifiers).length === 0;
		const isExtension = deployedBytecode.object === "0x";

		return !isInvalidPath && !isMockOrTest && !isLib && !isExtension;
	});

	// Generate checksums
	const checksums = generateChecksums(validArtifacts);

	console.dir(checksums, { depth: null });
};

const generateChecksums = (artifacts) => {
	return artifacts.map(({ metadata }) => {
		const { compilationTarget } = metadata.settings;
		const [contractPath, contractName] = Object.entries(compilationTarget)[0];

		const sources = metadata.sources;
		const dependencyChecksums = Object.entries(sources)
			.map(([k, v]) => {
				return { path: k, checksum: v.keccak256 };
			})
			.sort(({ path: a }, { path: b }) => path.basename(a).localeCompare(path.basename(b)));
		const aggregatedChecksum =
			"0x" + dependencyChecksums.reduce((acc, { checksum }) => acc ^ BigInt(checksum), 0n).toString(16);

		return { contractName, contractPath, aggregatedChecksum, dependencyChecksums };
	});
};

const batchRPCRequestsSync = async (endpoint, requests, allowError) => {
	const body = JSON.stringify(requests);

	try {
		const res = await fetch(endpoint, {
			method: "POST",
			body: body,
			headers: { "Content-Type": "application/json" },
		});

		const json = await res.json();
		const data = json.map(({ result }) => result);
		return data;
	} catch (err) {
		if (allowError) return [];
		console.error("Error:", err, endpoint, body);
		throw err;
	}
};

(async () => {
	const endpoints = Object.values(config.rpc_endpoints).map(interpolateEnv);
	const rpcs = {};

	await Promise.all(
		endpoints.map(async (endpoint) => {
			try {
				const [chainId] = await batchRPCRequestsSync(
					endpoint,
					[
						{
							jsonrpc: "2.0",
							method: "eth_chainId",
							params: [],
							id: 1,
						},
					],
					true
				);

				if (chainId) {
					rpcs[BigInt(chainId)] = endpoint;
				}
			} catch {
				// Ignore errors for individual endpoints
			}
		})
	);

	console.log("RPCs:", rpcs);

	const deploymentDir = "./deployments";
	const childFolders = fs
		.readdirSync(deploymentDir, { withFileTypes: true })
		.filter((dirent) => dirent.isDirectory())
		.map((dirent) => path.join(deploymentDir, dirent.name));

	const onchainAddrsByChainId = await Promise.all(
		childFolders.map(async (folder) => {
			const files = await fsPromises.readdir(folder, { withFileTypes: true });
			const chainId = parseInt(fs.readFileSync(path.join(folder, ".chainId"), "utf-8"));
			const jsonFiles = files.filter((file) => file.name.endsWith(".json"));
			return Promise.all(
				jsonFiles.map(async (file) => {
					const content = await fsPromises.readFile(path.join(folder, file.name), "utf-8");
					const { address } = JSON.parse(content);
					return { chainId, address };
				})
			);
		})
	);

	onchainAddrsByChainId.forEach(async (addrs) => {
		const endpoint = rpcs[addrs[0].chainId];
		if (!endpoint) {
			console.warn("No endpoint found for chainId:", addrs[0].chainId);
			return;
		}
		const aggregatedReqs = addrs.reduce((acc, { address }) => {
			acc.push({
				jsonrpc: "2.0",
				method: "eth_getStorageAt",
				params: [address, implSlot, "latest"],
				id: acc.length + 1,
			});
			return acc;
		}, []);

		console.log("Aggregated Requests:", aggregatedReqs, endpoint);
		const logics = (await batchRPCRequestsSync(endpoint, aggregatedReqs, false))
			.map((logic) => ethers.getAddress(logic.slice(-40)))
			.filter((logic) => logic !== ethers.ZeroAddress);
	});
})();
