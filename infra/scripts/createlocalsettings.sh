#!/bin/bash

set -e

if [ ! -f "./local.settings.json" ]; then

    output=$(azd env get-values)

    # Initialize variables
    CosmosDBEndPoint=""
    CosmosDBName=""
    CosmosDBContainer=""

    # Parse the output to get the endpoint URLs
    while IFS= read -r line; do
        if [[ $line == COSMOS_CONNECTION__accountEndpoint=* ]]; then
            CosmosDBEndPoint=$(echo "$line" | cut -d '=' -f 2 | tr -d '"')
        elif [[ $line == COSMOS_DATABASE_NAME=* ]]; then
            CosmosDBName=$(echo "$line" | cut -d '=' -f 2 | tr -d '"')
        elif [[ $line == COSMOS_CONTAINER_NAME=* ]]; then
            CosmosDBContainer=$(echo "$line" | cut -d '=' -f 2 | tr -d '"')
        fi
    done <<< "$output"

    cat <<EOF > ./local.settings.json
{
    "IsEncrypted": false,
    "Values": {
        "AzureWebJobsStorage": "UseDevelopmentStorage=true",
        "FUNCTIONS_WORKER_RUNTIME": "python",
        "COSMOS_CONNECTION__accountEndpoint": "$CosmosDBEndPoint",
        "COSMOS_DATABASE_NAME": "$CosmosDBName",
        "COSMOS_CONTAINER_NAME": "$CosmosDBContainer"
    }
}
EOF

fi