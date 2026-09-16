$ErrorActionPreference = "Stop"

$ApiVersion = "2024-12-01-preview"
$EnvironmentValues = azd env get-values

foreach ($line in $EnvironmentValues) {
    if ($line -match '^AZURE_COSMOSDB_ACCOUNT_NAME=') {
        $CosmosDBResourceName = ($line -split '=', 2)[1].Trim('"')
    }
    if ($line -match '^RESOURCE_GROUP=') {
        $ResourceGroup = ($line -split '=', 2)[1].Trim('"')
    }
}

if ([string]::IsNullOrWhiteSpace($CosmosDBResourceName) -or [string]::IsNullOrWhiteSpace($ResourceGroup)) {
    throw "Unable to resolve the Cosmos DB account and resource group from the azd environment."
}

$ResourceId = az cosmosdb show `
    --resource-group $ResourceGroup `
    --name $CosmosDBResourceName `
    --query id `
    --output tsv `
    --only-show-errors

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($ResourceId)) {
    throw "Unable to find Cosmos DB account $CosmosDBResourceName."
}

$ResourceUri = "${ResourceId}?api-version=$ApiVersion"
$ChangeFeedEnabled = az rest `
    --method get `
    --uri $ResourceUri `
    --query properties.enableAllVersionsAndDeletesChangeFeed `
    --output tsv `
    --only-show-errors

if ($LASTEXITCODE -ne 0) {
    throw "Unable to read the All Versions and Deletes change feed setting."
}

if ($ChangeFeedEnabled -eq "true") {
    Write-Output "All Versions and Deletes change feed is already enabled."
    exit 0
}

Write-Output "Enabling All Versions and Deletes change feed for $CosmosDBResourceName."
$RequestBody = '{"properties":{"enableAllVersionsAndDeletesChangeFeed":true}}'
az rest `
    --method patch `
    --uri $ResourceUri `
    --body $RequestBody `
    --output none `
    --only-show-errors

if ($LASTEXITCODE -ne 0) {
    throw "Failed to enable All Versions and Deletes change feed."
}

az resource wait `
    --ids $ResourceId `
    --api-version $ApiVersion `
    --custom "properties.enableAllVersionsAndDeletesChangeFeed == ``true``" `
    --interval 30 `
    --timeout 3600 `
    --only-show-errors

if ($LASTEXITCODE -ne 0) {
    throw "Timed out while waiting for the Cosmos DB account update to complete."
}

$ChangeFeedEnabled = az rest `
    --method get `
    --uri $ResourceUri `
    --query properties.enableAllVersionsAndDeletesChangeFeed `
    --output tsv `
    --only-show-errors

if ($LASTEXITCODE -ne 0 -or $ChangeFeedEnabled -ne "true") {
    throw "The Cosmos DB account update completed without enabling All Versions and Deletes change feed."
}

Write-Output "All Versions and Deletes change feed is enabled."