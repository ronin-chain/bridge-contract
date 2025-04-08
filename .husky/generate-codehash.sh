#!/bin/sh

set -e

# Clear and recreate logs directory
rm -rf logs/codehash
mkdir -p logs/codehash

# Find all .sol files in the 'out' directory
find out -type f -name '*.json' | while read -r fileIn; do
  # Extract contract directory and JSON file name
  contractDir=$(dirname "$fileIn" | sed 's|out/||')
  jsonFile=$(basename "$fileIn")

  # Skip if folder ends with .s.sol or .t.sol and not end with .sol
  if [[ $contractDir == *".s.sol" ]] || [[ $contractDir == *".t.sol" ]] || [[ $contractDir != *".sol" ]]; then
    continue
  fi

  # Skip if the file is not a valid contract
  compilationTarget=$(jq -r '.metadata.settings.compilationTarget' "$fileIn")
  if echo "$compilationTarget" | jq -e 'keys[]' | grep -qE 'script|test|mock|dependencies|lib|libraries'; then
    continue
  fi

  # Skip if methodIdentifiers is empty
  extFn=$(jq -r '.methodIdentifiers' "$fileIn")
  if [ -z "$extFn" ] || [ "$extFn" == "{}" ]; then
    continue
  fi

  # Skip if deployedBytecode is empty (abstract contracts)
  deployedBytecode=$(jq -r '.deployedBytecode.object' "$fileIn")
  if [ "$deployedBytecode" == "0x" ]; then
    continue
  fi

  # Calculate codehash and save to file
  codehash=$(cast keccak "$deployedBytecode" 2>/dev/null || echo "Error")
  if [ "$codehash" == "Error" ]; then
    echo "Error: Failed to calculate codehash for $contractDir/$jsonFile"
    continue
  fi

  fileOut="logs/codehash/${contractDir}:${jsonFile%.json}.log"
  echo "$codehash" >"$fileOut"
done
