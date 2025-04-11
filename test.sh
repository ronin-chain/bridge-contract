for folder in "deployments"/*; do
    if [ -d "$folder" ]; then
        network=$(basename "$folder")
        deployed_addrs="$folder/exported_address"
        dt=$(cat $deployed_addrs)

        ## Data Format
        # MainchainBridgeManagerLogic.json@0x0ac26945032143f6196d4bb5Ae03592BfAf822FD
        # MainchainBridgeManagerProxy.json@0x2Cf3CFb17774Ce0CFa34bB3f3761904e7fc3FaDB
        # MainchainGatewayPauseEnforcer.json@0xe514d9DEB7966c8BE0ca922de8a064264eA6bcd4
        # MainchainGatewayV2Logic.json@0xa67BA5315AF4961Eb937158032AF9300C657dAcD
        # MainchainGatewayV3Logic.json@0xD6c4986bbe09f2dDb262B4611b0BA06891be605e
        # MainchainGatewayV3Proxy.json@0x64192819Ac13Ef72bF6b5AE239AC672B43a9AF08
        # MainchainGovernanceAdmin.json@0xB255D6A720BB7c39fee173cE22113397119cB930
        # MainchainRoninTrustedOrganizationProxy.json@0x7D0556D55ca1a92708681e2e231733EBd922597D
        # RoninTrustedOrganizationLogic.json@0x9Be8BB3C6ced4C0C51b1C943Dee26a593b1E6794
        # WethUnwrapper.json@0x8048b12511d9BE6e4e094089b12f54923C4E2F83

        # Filter out Logic contracts
        filtered_dt=$(echo "$dt" | grep -v "Logic.json")
        # Get deployment file name
        deployment_files=$(echo "$filtered_dt" | cut -d "@" -f 1)
        for deployment_file in $deployment_files; do
            address=$(jq -r ".address" "$folder/$deployment_file")
            impl=$(cast impl "$address" -r $network 2>/dev/null)
            if [ "$impl" == "0x0000000000000000000000000000000000000000" ]; then
                deployed_bytecode=$(cast code "$address" -r $network 2>/dev/null)
            else
                deployed_bytecode=$(cast code "$impl" -r $network 2>/dev/null)
            fi

            # Assert if deployed_bytecode is empty
            if [ "$deployed_bytecode" == "0x" ]; then
                echo "Deployed bytecode is empty for $address, $network, $deployment_file"
                # Panic error
                exit 1
            fi

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
            contract_name=$(basename "$deployment_file")
            # Remove "Proxy" from contract name if it exists
            contract_name=${contract_name/Proxy/}
            # Remove ".json" from contract name
            contract_name=${contract_name/.json/}

            code_hash_file="logs/codehash/${contract_name}.log"
            echo "Codehash file: $code_hash_file"
            # Check if the file already exists
            if [ -f "$code_hash_file" ]; then
                # Append to the existing file
                echo "$network: $codehash" >>"$code_hash_file"
            else
                echo "codehash file not found for $contract_name"
            fi
        done
    fi
done
