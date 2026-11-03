"""Backlog page renderer, used by build_docs.py (not run directly).

Inputs:
    docs/backlog/backlog.json            item definitions (same format as backlog.example.json)
    .harness/state/feature_list.json     status and GitHub issue numbers (optional)

Output (written by build_docs.py):
    docs/backlog/index.md                human-friendly page (tables, dependency diagram, details)

Stdlib only. Output is deterministic (no timestamps) so build_docs.py --check is reliable.
"""
from __future__ import annotations

import json
import os
import re
from typing import Any

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BACKLOG = os.path.join(ROOT, "docs", "backlog", "backlog.json")
FEATURES = os.path.join(ROOT, ".harness", "state", "feature_list.json")
OUTPUT = os.path.join(ROOT, "docs", "backlog", "index.md")

STATUS = {
    "todo": ("⚪", "To do"),
    "in_progress": ("🔵", "In progress"),
    "in_review": ("🟣", "In review"),
    "blocked": ("🔴", "Blocked"),
    "done": ("✅", "Done"),
}
# Border colour only: the theme controls fill and text so labels stay readable in light and dark mode.
STATUS_STYLE = {
    "todo": "stroke:#9e9e9e,stroke-width:2px",
    "in_progress": "stroke:#1e88e5,stroke-width:3px",
    "in_review": "stroke:#8e24aa,stroke-width:3px",
    "blocked": "stroke:#e53935,stroke-width:3px,stroke-dasharray:5 3",
    "done": "stroke:#43a047,stroke-width:3px",
}
TYPE_LABEL = {"epic": "Epic", "story": "Story", "task": "Task", "bug": "Bug", "spike": "Spike"}

PLACEHOLDER = """# Backlog

!!! info "Not generated yet"
    The backlog is created during project bootstrap (see `BOOTSTRAP.md`).
    Its definition lives in `docs/backlog/backlog.json`; this page is generated from it with
    `python .harness/scripts/build_docs.py`.
"""


def load(path: str) -> dict[str, Any] | None:
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def node_id(key: str) -> str:
    return re.sub(r"[^A-Za-z0-9_]", "_", key)


def esc_mermaid(text: str) -> str:
    return text.replace('"', "#quot;")


def esc_cell(text: str) -> str:
    return str(text).replace("|", "\\|").replace("\n", " ")


def render(backlog: dict[str, Any], features: dict[str, Any] | None) -> str:
    repo = backlog.get("repository")
    status_of: dict[str, str] = {}
    issue_of: dict[str, int] = {}
    for f in (features or {}).get("features", []):
        status_of[f["key"]] = f.get("status", "todo")
        if f.get("issue"):
            issue_of[f["key"]] = f["issue"]

    items: list[dict[str, Any]] = backlog.get("items", [])
    by_key = {i["key"]: i for i in items}
    milestones = backlog.get("milestones", [])

    def status(key: str) -> str:
        return status_of.get(key, "todo")

    def issue_link(key: str) -> str:
        num = issue_of.get(key)
        if not num:
            return "—"
        return f"[#{num}](https://github.com/{repo}/issues/{num})" if repo else f"#{num}"

    def points(item: dict[str, Any]) -> int:
        return item["estimate"] if isinstance(item.get("estimate"), int) else 0

    out: list[str] = [
        "# Backlog",
        "",
        "<!-- GENERATED FILE: do not edit by hand. Source: docs/backlog/backlog.json + "
        ".harness/state/feature_list.json. Regenerate: python .harness/scripts/build_docs.py -->",
        "",
        '!!! info "For whom"',
        "    Everyone following the project. This page shows **all planned work**, its status and what depends on what.",
        "    The live discussion of each item happens in its GitHub issue.",
        "",
        "**Legend:** " + " · ".join(f"{icon} {label}" for icon, label in STATUS.values()),
        "",
        "## Progress by milestone",
        "",
        "| Milestone | Items | Done | Points done / total | Progress |",
        "|---|---:|---:|---:|---|",
    ]
    for m in milestones:
        work = [i for i in items if i["milestone"] == m["key"] and i["type"] != "epic"]
        done = [i for i in work if status(i["key"]) == "done"]
        total_pts = sum(points(i) for i in work)
        done_pts = sum(points(i) for i in done)
        pct = round(100 * done_pts / total_pts) if total_pts else 0
        bar = f'<progress value="{pct}" max="100"></progress>'
        out.append(f"| **{esc_cell(m['title'])}** | {len(work)} | {len(done)} | {done_pts} / {total_pts} | {bar} {pct}% |")
    out.append("")

    # Dependency diagram
    out += ["## Dependency map", "",
            "Arrows mean *must be done before*. Colours show status.", "", "```mermaid", "flowchart LR"]
    for m in milestones:
        members = [i for i in items if i["milestone"] == m["key"] and i["type"] != "epic"]
        if not members:
            continue
        out.append(f'  subgraph {node_id(m["key"])}["{esc_mermaid(m["title"])}"]')
        for i in members:
            icon = STATUS[status(i["key"])][0]
            out.append(f'    {node_id(i["key"])}["{icon} {i["key"]}<br/>{esc_mermaid(i["title"])}"]')
        out.append("  end")
    for i in items:
        if i["type"] == "epic":
            continue
        for dep in i.get("depends_on", []):
            if dep in by_key and by_key[dep]["type"] != "epic":
                out.append(f"  {node_id(dep)} --> {node_id(i['key'])}")
    for st, style in STATUS_STYLE.items():
        out.append(f"  classDef {st} {style}")
    for i in items:
        if i["type"] != "epic":
            out.append(f"  class {node_id(i['key'])} {status(i['key'])}")
    out += ["```", ""]

    # Tables per milestone, grouped by epic
    out += ["## Items by milestone", ""]
    for m in milestones:
        out += [f"### {m['title']}", ""]
        if m.get("description"):
            out += [m["description"], ""]
        if m.get("due_on"):
            out += [f"**Target date:** {m['due_on']}", ""]
        out += ["| | Key | Type | Title | Points | Depends on | Issue |", "|---|---|---|---|---:|---|---|"]
        ms_items = [i for i in items if i["milestone"] == m["key"]]
        epics = [i for i in ms_items if i["type"] == "epic"]
        ordered: list[dict[str, Any]] = []
        for e in epics:
            ordered.append(e)
            ordered += [i for i in ms_items if i.get("parent") == e["key"]]
        ordered += [i for i in ms_items if i not in ordered]
        for i in ordered:
            icon = STATUS[status(i["key"])][0]
            title = f"**{esc_cell(i['title'])}**" if i["type"] == "epic" else esc_cell(i["title"])
            if i.get("parent") and i["parent"] in by_key and i["type"] != "epic":
                title = "&emsp;" + title
            deps = ", ".join(i.get("depends_on", [])) or "—"
            out.append(f"| {icon} | [{i['key']}](#{i['key'].lower()}) | {TYPE_LABEL[i['type']]} | {title} | "
                       f"{i['estimate']} | {deps} | {issue_link(i['key'])} |")
        out.append("")

    # Details
    out += ["## Item details", "", "Click an item to expand it.", ""]
    for i in items:
        icon, label = STATUS[status(i["key"])]
        out += [f'<a id="{i["key"].lower()}"></a>', "",
                f'??? {"abstract" if i["type"] == "epic" else "note"} "{icon} {i["key"]} · {TYPE_LABEL[i["type"]]} · '
                f'{i["title"].replace(chr(34), chr(39))}"']
        body: list[str] = [f"**Status:** {label} · **Estimate:** {i['estimate']} · **Issue:** {issue_link(i['key'])}"]
        if i.get("parent"):
            body.append(f"**Part of:** {i['parent']} — {by_key[i['parent']]['title'] if i['parent'] in by_key else ''}")
        body.append("")
        us = i.get("user_story")
        if us:
            body += [f"*As a **{us['as']}**, I want **{us['i_want']}**, so that **{us['so_that']}**.*", ""]
        body += [i["description"].strip(), "", "**Acceptance criteria**", ""]
        body += [f"- {c}" for c in i.get("acceptance_criteria", [])]
        htt = i.get("how_to_test", {})
        if htt:
            body += ["", "**How to test**", ""]
            body += [f"- {s}" for s in htt.get("automated", []) + htt.get("manual", [])]
        if i.get("depends_on") or i.get("external_dependencies"):
            body += ["", "**Dependencies**", ""]
            body += [f"- {d} — {by_key[d]['title'] if d in by_key else ''}" for d in i.get("depends_on", [])]
            body += [f"- External: {d}" for d in i.get("external_dependencies", [])]
        if i.get("out_of_scope"):
            body += ["", "**Out of scope**", ""] + [f"- {s}" for s in i["out_of_scope"]]
        out += [("    " + line) if line else "" for line in body]
        out.append("")
    return "\n".join(out).rstrip() + "\n"


def generate() -> str:
    """Content of docs/backlog/index.md for the current backlog and status."""
    backlog = load(BACKLOG)
    return PLACEHOLDER if backlog is None else render(backlog, load(FEATURES))
