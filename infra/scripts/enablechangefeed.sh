#!/bin/bash
set -e

ApiVersion="2024-12-01-preview"
EnvironmentValues=$(azd env get-values)

while IFS= read -r line; do
    case "$line" in
        AZURE_COSMOSDB_ACCOUNT_NAME=*)
            CosmosDBResourceName=${line#*=}
            CosmosDBResourceName=${CosmosDBResourceName#\"}
            CosmosDBResourceName=${CosmosDBResourceName%\"}
            ;;
        RESOURCE_GROUP=*)
            ResourceGroup=${line#*=}
            ResourceGroup=${ResourceGroup#\"}
            ResourceGroup=${ResourceGroup%\"}
            ;;
    esac
done <<< "$EnvironmentValues"

if [[ -z $CosmosDBResourceName || -z $ResourceGroup ]]; then
    echo "Unable to resolve the Cosmos DB account and resource group from the azd environment." >&2
    exit 1
fi

ResourceId=$(az cosmosdb show \
    --resource-group "$ResourceGroup" \
    --name "$CosmosDBResourceName" \
    --query id \
    --output tsv \
    --only-show-errors)
ResourceUri="${ResourceId}?api-version=${ApiVersion}"

ChangeFeedEnabled=$(az rest \
    --method get \
    --uri "$ResourceUri" \
    --query properties.enableAllVersionsAndDeletesChangeFeed \
    --output tsv \
    --only-show-errors)

if [[ $ChangeFeedEnabled == "true" ]]; then
    echo "All Versions and Deletes change feed is already enabled."
    exit 0
fi

echo "Enabling All Versions and Deletes change feed for $CosmosDBResourceName."
az rest \
    --method patch \
    --uri "$ResourceUri" \
    --body '{"properties":{"enableAllVersionsAndDeletesChangeFeed":true}}' \
    --output none \
    --only-show-errors

az resource wait \
    --ids "$ResourceId" \
    --api-version "$ApiVersion" \
    --custom 'properties.enableAllVersionsAndDeletesChangeFeed == `true`' \
    --interval 30 \
    --timeout 3600 \
    --only-show-errors

ChangeFeedEnabled=$(az rest \
    --method get \
    --uri "$ResourceUri" \
    --query properties.enableAllVersionsAndDeletesChangeFeed \
    --output tsv \
    --only-show-errors)

if [[ $ChangeFeedEnabled != "true" ]]; then
    echo "The Cosmos DB account update completed without enabling All Versions and Deletes change feed." >&2
    exit 1
fi

echo "All Versions and Deletes change feed is enabled."