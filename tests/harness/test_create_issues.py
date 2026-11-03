"""Unit tests for .harness/scripts/create_issues.py (stdlib only, no network).

Run: python tests/harness/test_create_issues.py   (also run by tests/harness/run.sh)
"""
import copy
import json
import os
import sys
import unittest

sys.dont_write_bytecode = True
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, ".harness", "scripts"))
import create_issues as ci  # noqa: E402

with open(os.path.join(ROOT, "docs", "resources", "templates", "backlog.example.json"), encoding="utf-8") as fh:
    EXAMPLE = json.load(fh)


def backlog(**changes):
    data = copy.deepcopy(EXAMPLE)
    for item in data["items"]:
        item.update(changes.get(item["key"], {}))
    return data


class Validate(unittest.TestCase):
    def test_example_is_valid(self):
        self.assertEqual(ci.validate(EXAMPLE), [])

    def test_missing_field(self):
        key = EXAMPLE["items"][0]["key"]
        errors = ci.validate(backlog(**{key: {"acceptance_criteria": []}}))
        self.assertTrue(any("acceptance_criteria" in e for e in errors), errors)

    def test_estimate_13_must_be_split(self):
        key = next(i["key"] for i in EXAMPLE["items"] if i["type"] != "epic")
        self.assertTrue(any("split" in e for e in ci.validate(backlog(**{key: {"estimate": 13}}))))

    def test_unknown_dependency_and_cycle(self):
        a, b = [i["key"] for i in EXAMPLE["items"] if i["type"] != "epic"][:2]
        self.assertTrue(any("unknown key" in e for e in ci.validate(backlog(**{a: {"depends_on": ["NOPE"]}}))))
        errors = ci.validate(backlog(**{a: {"depends_on": [b]}, b: {"depends_on": [a]}}))
        self.assertTrue(any("cycle" in e for e in errors), errors)


class Render(unittest.TestCase):
    def test_topo_order_puts_parents_and_dependencies_first(self):
        order = [i["key"] for i in ci.topo_order(EXAMPLE["items"])]
        for item in EXAMPLE["items"]:
            for before in item.get("depends_on", []) + ([item["parent"]] if item.get("parent") else []):
                self.assertLess(order.index(before), order.index(item["key"]))

    def test_body_has_every_section_and_the_key_footer(self):
        item = EXAMPLE["items"][-1]
        titles = {m["key"]: m["title"] for m in EXAMPLE["milestones"]}
        body = ci.render_body(item, EXAMPLE["items"], {}, titles)
        for section in ("## Description", "## Acceptance criteria", "## Checklist", "## Dependencies",
                        "## Estimation", "## How to test"):
            self.assertIn(section, body)
        self.assertEqual(ci.KEY_RE.search(body).group(1), item["key"])

    def test_labels(self):
        item = next(i for i in EXAMPLE["items"] if i["type"] == "epic")
        labels = ci.labels_for(item)
        self.assertIn("type:epic", labels)
        self.assertTrue(any(lab.startswith("size:") for lab in labels))


class MatchExisting(unittest.TestCase):
    def test_key_wins_over_title_so_renames_do_not_duplicate(self):
        issues = [{"number": 7, "title": "[Story] Old title", "body": "...\nBacklog key: `US-001`\n"},
                  {"number": 8, "title": "[Task] Legacy", "body": "no footer"}]
        by_key, by_title = ci.match_existing(issues)
        self.assertEqual(by_key["US-001"], 7)
        self.assertEqual(by_title["[Task] Legacy"], 8)
        self.assertNotIn("[Story] New title", by_title)


class StatusSync(unittest.TestCase):
    def test_column_names(self):
        self.assertEqual(ci.column_status("In Progress"), "in_progress")
        self.assertEqual(ci.column_status("To do"), "todo")
        self.assertEqual(ci.column_status("In review"), "in_review")
        self.assertIsNone(ci.column_status("Backlog"))

    def test_rules(self):
        s = ci.synced_status
        self.assertEqual(s("in_progress", "CLOSED", "In Progress"), "done")   # closed wins
        self.assertEqual(s("todo", "OPEN", "In Progress"), "in_progress")      # board wins
        self.assertEqual(s("blocked", "OPEN", "In Progress"), "blocked")       # refinement kept
        self.assertEqual(s("done", "OPEN", None), "todo")                      # reopened
        self.assertEqual(s("in_review", "OPEN", None), "in_review")            # nothing known: keep
        self.assertEqual(s("todo", None, None), "todo")                        # issue not found: keep


if __name__ == "__main__":
    unittest.main(verbosity=0)
