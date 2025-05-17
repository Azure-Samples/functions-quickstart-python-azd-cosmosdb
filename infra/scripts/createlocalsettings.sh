#!/bin/bash

set -e

if [ ! -f "./app/local.settings.json" ]; then

    output=$(azd env get-values)

    # Initialize variables
    CosmosDBEndPoint=""
    OpenAIEndPoint=""

    # Parse the output to get the endpoint URLs
    while IFS= read -r line; do
        if [[ $line == *"COSMOS_CONNECTION__accountEndpoint"* ]]; then
            CosmosDBEndPoint=$(echo "$line" | cut -d '=' -f 2 | tr -d '"')
        fi
        if [[ $line == *"AZURE_OPENAI_ENDPOINT"* ]]; then
            OpenAIEndPoint=$(echo "$line" | cut -d '=' -f 2 | tr -d '"')
        fi
    done <<< "$output"

    cat <<EOF > ./local.settings.json
{
    "IsEncrypted": "false",
    "Values": {
        "AzureWebJobsStorage": "UseDevelopmentStorage=true",
        "FUNCTIONS_WORKER_RUNTIME": "python",
        "COSMOS_CONNECTION__accountEndpoint": "$CosmosDBEndPoint",
        "COSMOS_DATABASE_NAME": "documents-db",
        "COSMOS_CONTAINER_NAME": "documents"
    }
}
EOF

fi