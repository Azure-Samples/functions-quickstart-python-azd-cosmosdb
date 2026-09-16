import json
import logging
import os

import azure.functions as func

app = func.FunctionApp()


@app.cosmos_db_trigger(
    arg_name="documents",
    container_name=os.environ.get("COSMOS_CONTAINER_NAME"),
    database_name=os.environ.get("COSMOS_DATABASE_NAME"),
    connection="COSMOS_CONNECTION",
    lease_container_name="leases",
    lease_container_prefix="py-latest-version",
    change_feed_mode=func.CosmosDBChangeFeedMode.LATEST_VERSION,
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


def _get_change_details(change: func.Document):
    payload = dict(change)
    current = payload.get("current")
    metadata = payload.get("metadata")
    current_document = current if isinstance(current, dict) else payload
    change_metadata = metadata if isinstance(metadata, dict) else {}

    operation_type = change_metadata.get("operationType", "unknown")
    document_id = (
        current_document.get("id")
        or change_metadata.get("id")
        or payload.get("id")
    )
    lsn = change_metadata.get("lsn") or payload.get("_lsn")
    time_to_live_expired = change_metadata.get("timeToLiveExpired", False)
    return operation_type, document_id, lsn, time_to_live_expired


@app.cosmos_db_trigger(
    arg_name="changes",
    container_name=os.environ.get("COSMOS_CONTAINER_NAME"),
    database_name=os.environ.get("COSMOS_DATABASE_NAME"),
    connection="COSMOS_CONNECTION",
    lease_container_name="leases",
    lease_container_prefix="py-full-fidelity",
    change_feed_mode=func.CosmosDBChangeFeedMode.ALL_VERSIONS_AND_DELETES,
)
def cosmos_full_fidelity_trigger(changes: func.DocumentList):
    logging.info("Python Cosmos DB full-fidelity trigger processed %d changes.", len(changes))

    for index, change in enumerate(changes):
        operation_type, document_id, lsn, time_to_live_expired = (
            _get_change_details(change)
        )
        logging.info(
            "FullFidelity change index=%d operation=%s id=%s lsn=%s",
            index,
            operation_type,
            document_id,
            lsn,
        )
        if time_to_live_expired:
            logging.info("Document %s was deleted because its TTL expired.", document_id)
        logging.info(
            "FullFidelity raw[%d]=%s",
            index,
            json.dumps(dict(change), default=str),
        )
