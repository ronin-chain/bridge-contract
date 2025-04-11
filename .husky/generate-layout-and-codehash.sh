#!/bin/sh

set -e

# Clear and recreate logs directory
rm -rf logs/storage
rm -rf logs/codehash

mkdir -p logs/storage
mkdir -p logs/codehash

# Find all .sol files in the 'out' directory
find out -type f -name '*.json' | while read -r file_in; do
  # Extract contract directory and JSON file name
  contract_dir=$(dirname "$file_in" | sed 's|out/||')
  contract_name=$(basename "$file_in")

  # Skip if folder ends with .s.sol or .t.sol and not end with .sol
  if [[ $contract_dir == *".s.sol" ]] || [[ $contract_dir == *".t.sol" ]] || [[ $contract_dir != *".sol" ]]; then
    continue
  fi

  # Skip if the file is not a valid contract
  compilation_target=$(jq -r '.metadata.settings.compilationTarget' "$file_in")
  if echo "$compilation_target" | jq -e 'keys[]' | grep -qE 'script|test|mock|dependencies|lib|libraries'; then
    continue
  fi

  # Skip if methodIdentifiers is empty
  ext_fn=$(jq -r '.methodIdentifiers' "$file_in")
  if [ -z "$ext_fn" ] || [ "$ext_fn" == "{}" ]; then
    continue
  fi

  # Skip if deployedBytecode is empty (abstract contracts)
  deployed_bytecode=$(jq -r '.deployedBytecode.object' "$file_in")
  if [ "$deployed_bytecode" == "0x" ]; then
    continue
  fi

  (
    nullified_metadata_deployed_bytecode=$(node -e "
      const deployedBytecode = process.argv[1];
      // Extract the last 2 bytes of the deployed bytecode
      const metadataLength = parseInt(deployedBytecode.slice(-4), 16);
      // Calculate the length of the metadata
      const sliceLength = deployedBytecode.length - (metadataLength * 2 + 4);
      // Create the nullified bytecode by replacing the metadata with zeros
      const nullifiedBytecode = deployedBytecode.slice(0, sliceLength) + '0'.repeat(metadataLength * 2 + 4);
      console.log(nullifiedBytecode);
  " "$deployed_bytecode")
    # Calculate codehash
    codehash=$(cast keccak256 "$nullified_metadata_deployed_bytecode" 2>/dev/null)
    echo "local: $codehash" >"logs/codehash/${contract_name%.json}.log"
  ) &
  node .husky/storage-logger.js $file_in "logs/storage/${contract_name%.json}.log" &
done

wait
