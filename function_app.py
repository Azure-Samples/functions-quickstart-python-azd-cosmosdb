import os
import azure.functions as func
import logging

app = func.FunctionApp()


@app.cosmos_db_trigger(
    arg_name="documents",
    container_name=os.environ.get("COSMOS_CONTAINER_NAME"),
    database_name=os.environ.get("COSMOS_DATABASE_NAME"),
    connection="COSMOS_CONNECTION",
    create_lease_container_if_not_exists="true",
)
def cosmosdb_trigger(documents: func.DocumentList):
    logging.info("Python CosmosDB triggered.")
    logging.info(f"Documents modified: {len(documents)}")
    if documents:
        for doc in documents:
            logging.info(f"Document: {doc.to_json()}")
            logging.info(f"Document id: {doc.get('id')}")
    else:
        logging.info("No documents found.")
