"""Validate harness JSON state files.

Usage:
    python tests/harness/validate_json.py feature-list <path>
    python tests/harness/validate_json.py ruleset .github/rulesets/main.json .github/workflows/ci.yml

Exit code 0 when valid; prints the problems and exits 1 otherwise.
"""
from __future__ import annotations

import json
import sys

VALID_STATUS = {"todo", "in_progress", "blocked", "in_review", "done"}
VALID_TYPES = {"epic", "story", "task", "bug", "spike"}


def find_cycle(graph: dict[str, list[str]]) -> list[str] | None:
    state: dict[str, int] = {}
    stack: list[str] = []

    def visit(node: str) -> list[str] | None:
        state[node] = 1
        stack.append(node)
        for dep in graph.get(node, []):
            if state.get(dep) == 1:
                return stack[stack.index(dep):] + [dep]
            if state.get(dep) is None and dep in graph:
                found = visit(dep)
                if found:
                    return found
        stack.pop()
        state[node] = 2
        return None

    for node in graph:
        if state.get(node) is None:
            found = visit(node)
            if found:
                return found
    return None


def validate_feature_list(data: dict) -> list[str]:
    errors: list[str] = []
    for key in ("project", "milestones", "features"):
        if key not in data:
            errors.append(f"missing top-level key '{key}'")
    milestones = {m.get("key") for m in data.get("milestones", [])}
    features = data.get("features", [])
    keys = [f.get("key") for f in features]
    if len(keys) != len(set(keys)):
        errors.append("duplicate feature keys")
    keyset = set(keys)
    for f in features:
        k = f.get("key", "<no key>")
        for field in ("key", "type", "title", "status", "depends_on"):
            if field not in f:
                errors.append(f"{k}: missing '{field}'")
        if f.get("status") not in VALID_STATUS:
            errors.append(f"{k}: invalid status '{f.get('status')}'")
        if f.get("type") not in VALID_TYPES:
            errors.append(f"{k}: invalid type '{f.get('type')}'")
        if f.get("milestone") and f["milestone"] not in milestones:
            errors.append(f"{k}: unknown milestone '{f['milestone']}'")
        if f.get("parent") and f["parent"] not in keyset:
            errors.append(f"{k}: unknown parent '{f['parent']}'")
        for dep in f.get("depends_on", []):
            if dep not in keyset:
                errors.append(f"{k}: depends on unknown key '{dep}'")
    cycle = find_cycle({f.get("key"): list(f.get("depends_on", [])) for f in features})
    if cycle:
        errors.append("dependency cycle: " + " -> ".join(cycle))
    return errors


def validate_ruleset(ruleset_path: str, ci_path: str) -> list[str]:
    """The ruleset must be well-formed and every required status check must be a CI job name.

    A required check that no job produces blocks every pull request forever ("Expected").
    """
    import re

    with open(ruleset_path, encoding="utf-8") as fh:
        ruleset = json.load(fh)
    with open(ci_path, encoding="utf-8") as fh:
        jobs = set(re.findall(r"^    name:\s*(.+?)\s*$", fh.read(), re.M))
    errors = [f"missing '{k}'" for k in ("name", "target", "enforcement", "rules") if k not in ruleset]
    for rule in ruleset.get("rules", []):
        if rule.get("type") != "required_status_checks":
            continue
        for chk in rule.get("parameters", {}).get("required_status_checks", []):
            if chk.get("context") not in jobs:
                errors.append(f"required check '{chk.get('context')}' is not a job name in {ci_path} (jobs: {sorted(jobs)})")
    return errors


def main() -> int:
    if len(sys.argv) == 4 and sys.argv[1] == "ruleset":
        errors = validate_ruleset(sys.argv[2], sys.argv[3])
        for err in errors:
            print(f"  - {err}")
        return 1 if errors else 0
    if len(sys.argv) != 3 or sys.argv[1] != "feature-list":
        print(__doc__)
        return 2
    try:
        with open(sys.argv[2], encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, json.JSONDecodeError) as exc:
        print(f"cannot read {sys.argv[2]}: {exc}")
        return 1
    errors = validate_feature_list(data)
    for err in errors:
        print(f"  - {err}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
