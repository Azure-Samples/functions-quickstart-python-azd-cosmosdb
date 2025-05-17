$ErrorActionPreference = "Stop"

if (-not (Test-Path ".\local.settings.json")) {

    $output = azd env get-values

    # Parse the output to get the endpoint values
    foreach ($line in $output) {
        if ($line -match "COSMOS_CONNECTION__accountEndpoint"){
            $CosmosDBEndPoint = ($line -split "=")[1] -replace '"',''
        }
    }

    @{
        "IsEncrypted" = "false";
        "Values" = @{
            "AzureWebJobsStorage" = "UseDevelopmentStorage=true";
            "FUNCTIONS_WORKER_RUNTIME" = "python";
            "COSMOS_CONNECTION__accountEndpoint" = "$CosmosDBEndPoint";
            "COSMOS_DATABASE_NAME" = "documents-db";
            "COSMOS_CONTAINER_NAME" = "documents";
        }
    } | ConvertTo-Json | Out-File -FilePath ".\local.settings.json" -Encoding ascii
}