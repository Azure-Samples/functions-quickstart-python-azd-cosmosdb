$ErrorActionPreference = "Stop"

if (-not (Test-Path ".\local.settings.json")) {

    $output = azd env get-values

    # Parse the output to get the endpoint values
    foreach ($line in $output) {
        if ($line -match '^COSMOS_CONNECTION__accountEndpoint=') {
            $CosmosDBEndPoint = ($line -split '=', 2)[1].Trim('"')
        }
        if ($line -match '^COSMOS_DATABASE_NAME=') {
            $CosmosDBName = ($line -split '=', 2)[1].Trim('"')
        }
        if ($line -match '^COSMOS_CONTAINER_NAME=') {
            $CosmosDBContainer = ($line -split '=', 2)[1].Trim('"')
        }
    }

    @{
        "IsEncrypted" = $false;
        "Values" = @{
            "AzureWebJobsStorage" = "UseDevelopmentStorage=true";
            "FUNCTIONS_WORKER_RUNTIME" = "python";
            "COSMOS_CONNECTION__accountEndpoint" = "$CosmosDBEndPoint";
            "COSMOS_DATABASE_NAME" = "$CosmosDBName";
            "COSMOS_CONTAINER_NAME" = "$CosmosDBContainer";
        }
    } | ConvertTo-Json | Out-File -FilePath ".\local.settings.json" -Encoding ascii
}