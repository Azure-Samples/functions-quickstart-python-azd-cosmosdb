import unittest
from unittest.mock import patch

import azure.functions as func

import function_app


class CosmosChangeFeedTests(unittest.TestCase):
    def test_registers_both_change_feed_modes(self):
        functions = {
            function.get_function_name(): function
            for function in function_app.app.get_functions()
        }

        latest_trigger = functions["cosmos_trigger"].get_trigger().get_dict_repr()
        full_fidelity_trigger = (
            functions["cosmos_full_fidelity_trigger"]
            .get_trigger()
            .get_dict_repr()
        )

        self.assertEqual(latest_trigger["changeFeedMode"], "LatestVersion")
        self.assertEqual(
            latest_trigger["leaseContainerPrefix"], "py-latest-version"
        )
        self.assertEqual(
            full_fidelity_trigger["changeFeedMode"], "AllVersionsAndDeletes"
        )
        self.assertEqual(
            full_fidelity_trigger["leaseContainerPrefix"], "py-full-fidelity"
        )

    @patch("function_app.logging.info")
    def test_logs_latest_version_documents(self, log_info):
        documents = func.DocumentList(
            [func.Document.from_dict({"id": "item-1", "status": "created"})]
        )

        function_app.cosmos_trigger(documents)

        log_info.assert_any_call("Documents modified: 1")
        log_info.assert_any_call("First document id: item-1")

    def test_reads_full_fidelity_envelope_details(self):
        change = func.Document.from_dict(
            {
                "current": {},
                "metadata": {
                    "operationType": "delete",
                    "id": "item-1",
                    "lsn": 42,
                    "timeToLiveExpired": True,
                },
            }
        )

        self.assertEqual(
            function_app._get_change_details(change),
            ("delete", "item-1", 42, True),
        )

    def test_reads_flat_change_details(self):
        change = func.Document.from_dict(
            {"id": "item-1", "status": "created", "_lsn": 41}
        )

        self.assertEqual(
            function_app._get_change_details(change),
            ("unknown", "item-1", 41, False),
        )

    @patch("function_app.logging.info")
    def test_logs_full_fidelity_changes(self, log_info):
        changes = func.DocumentList(
            [
                func.Document.from_dict(
                    {
                        "current": {"id": "item-1", "status": "created"},
                        "metadata": {
                            "operationType": "create",
                            "lsn": 41,
                        },
                    }
                ),
                func.Document.from_dict(
                    {
                        "current": {},
                        "metadata": {
                            "operationType": "delete",
                            "id": "item-2",
                            "lsn": 42,
                            "timeToLiveExpired": True,
                        },
                    }
                ),
            ]
        )

        function_app.cosmos_full_fidelity_trigger(changes)

        log_info.assert_any_call(
            "Python Cosmos DB full-fidelity trigger processed %d changes.", 2
        )
        log_info.assert_any_call(
            "FullFidelity change index=%d operation=%s id=%s lsn=%s",
            0,
            "create",
            "item-1",
            41,
        )
        log_info.assert_any_call(
            "FullFidelity change index=%d operation=%s id=%s lsn=%s",
            1,
            "delete",
            "item-2",
            42,
        )
        log_info.assert_any_call(
            "Document %s was deleted because its TTL expired.", "item-2"
        )


if __name__ == "__main__":
    unittest.main()