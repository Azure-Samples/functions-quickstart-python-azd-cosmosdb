import os
import azure.functions as func
import logging
import json

app = func.FunctionApp()


@app.cosmos_db_trigger(
    arg_name="documents",
    container_name=os.environ.get("COSMOS_CONTAINER_NAME"),
    database_name=os.environ.get("COSMOS_DATABASE_NAME"),
    connection="COSMOS_CONNECTION",
    create_lease_container_if_not_exists="true",
)
def cosmos_trigger(documents: func.DocumentList):
    logging.info("Python CosmosDB triggered.")
    logging.info(f"Documents modified: {len(documents)}")
    if documents:
        for doc in documents:
            logging.info(f"First document: {doc.to_json()}")
            logging.info(f"First document id: {doc.get('id')}")
    else:
        logging.info("No documents found.")


@app.function_name("httptrigger-cosmosdb-output")
@app.route(route="httptriggercosmosdboutput", methods=["POST"])
@app.cosmos_db_output(arg_name="doc",
                      database_name=os.environ.get("COSMOS_DATABASE_NAME"),
                      container_name=os.environ.get("COSMOS_CONTAINER_NAME"),
                      connection="COSMOS_CONNECTION")
def http_trigger_cosmosdb_output(req: func.HttpRequest, doc: func.Out[func.Document]) -> func.HttpResponse:
    """HTTP trigger with Cosmos DB output binding to insert documents."""
    logging.info('Python HTTP trigger with Cosmos DB Output Binding function processed a request.')
    
    try:
        # Parse the request body
        req_body = req.get_json()
        
        if not req_body:
            return func.HttpResponse(
                "Please pass a valid JSON object in the request body",
                status_code=400
            )
        
        # Create a new Document and set it to the output binding
        doc.set(func.Document.from_dict(req_body))
        
        # Return success response
        return func.HttpResponse(
            json.dumps(req_body),
            status_code=201,
            mimetype="application/json"
        )
        
    except ValueError as e:
        logging.error(f"JSON parsing error: {e}")
        return func.HttpResponse(
            "Invalid JSON in request body",
            status_code=400
        )
    except Exception as e:
        logging.error(f"Error processing request: {e}")
        return func.HttpResponse(
            "Internal server error",
            status_code=500
        )
