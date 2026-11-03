#!/usr/bin/env python3
"""Create GitHub labels, milestones and issues from a backlog JSON file.

The backlog format is documented in docs/resources/templates/backlog.example.json and every
issue body follows docs/process/work-item-template.md.

Requires: Python 3.8+ (stdlib only) and an authenticated GitHub CLI (`gh auth login`)
for anything except --validate-only.

Examples:
    # Validate only (no network)
    python .harness/scripts/create_issues.py --backlog backlog.json --validate-only

    # Generate the harness feature list from the backlog (no network)
    python .harness/scripts/create_issues.py --backlog backlog.json --validate-only \
        --write-feature-list .harness/state/feature_list.json

    # Show what would be created
    python .harness/scripts/create_issues.py --repo owner/name --backlog backlog.json --dry-run

    # Create everything, save key->issue mapping and update the feature list with issue numbers
    python .harness/scripts/create_issues.py --repo owner/name --backlog backlog.json \
        --out issue-map.json --write-feature-list .harness/state/feature_list.json

After the issues, it creates (or reuses) a GitHub Project board named "Kanban board", links it
to the repo (Projects tab), adds every backlog issue (new ones in the Todo column) and adds a
Board view with one column per Status. This needs the token scope `project`
(`gh auth refresh -s project`). Use --project-title to rename it, or --no-project to skip it.

Idempotent: issues whose exact title already exists in the repo are reused, not duplicated;
the project, its items and the view are reused too, so re-running adds only what is missing.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import shutil
import subprocess
import sys
import tempfile
from typing import Any

TYPES = {"epic": "Epic", "story": "Story", "task": "Task", "bug": "Bug", "spike": "Spike"}
POINTS = {1: "xs", 2: "s", 3: "m", 5: "l", 8: "xl"}
TSHIRT = {"S": "s", "M": "m", "L": "l", "XL": "xl"}
REQUIRED = ["key", "type", "title", "milestone", "description", "acceptance_criteria",
            "checklist", "depends_on", "estimate", "how_to_test"]

DEFAULT_LABELS = [
    ("type:epic", "3e4b9e", "Large capability grouping several stories"),
    ("type:story", "0e8a16", "User-visible value"),
    ("type:task", "c5def5", "Technical unit of work"),
    ("type:bug", "d73a4a", "Defect in existing behaviour"),
    ("type:spike", "fbca04", "Time-boxed research"),
    ("priority:p0", "b60205", "Critical"),
    ("priority:p1", "d93f0b", "High"),
    ("priority:p2", "fbca04", "Normal"),
    ("priority:p3", "c2e0c6", "Low"),
    ("size:xs", "ededed", "1 point"),
    ("size:s", "d4c5f9", "2 points"),
    ("size:m", "bfd4f2", "3 points"),
    ("size:l", "5319e7", "5 points"),
    ("size:xl", "1d0f5c", "8 points"),
    ("blocked", "000000", "Waiting on a dependency"),
]


# --------------------------------------------------------------------------- validation
def validate(backlog: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    milestones = {m.get("key") for m in backlog.get("milestones", [])}
    items = backlog.get("items", [])
    if not items:
        errors.append("backlog has no items")
    keys = [i.get("key") for i in items]
    dupes = {k for k in keys if keys.count(k) > 1}
    if dupes:
        errors.append(f"duplicate keys: {sorted(dupes)}")
    by_key = {i.get("key"): i for i in items}
    titles = [i.get("title") for i in items]
    if len(titles) != len(set(titles)):
        errors.append("duplicate titles (titles must be unique for idempotency)")

    for item in items:
        k = item.get("key", "<no key>")
        for field in REQUIRED:
            if field not in item or item[field] in (None, "", []) and field != "depends_on":
                errors.append(f"{k}: missing or empty '{field}'")
        t = item.get("type")
        if t not in TYPES:
            errors.append(f"{k}: invalid type '{t}'")
        if item.get("milestone") not in milestones:
            errors.append(f"{k}: unknown milestone '{item.get('milestone')}'")
        est = item.get("estimate")
        if t == "epic":
            if est not in TSHIRT:
                errors.append(f"{k}: epic estimate must be one of {list(TSHIRT)}")
        elif est == 13:
            errors.append(f"{k}: estimate 13 means the item must be split (Definition of Ready)")
        elif est not in POINTS:
            errors.append(f"{k}: estimate must be one of {list(POINTS)} story points")
        parent = item.get("parent")
        if parent and parent not in by_key:
            errors.append(f"{k}: unknown parent '{parent}'")
        for dep in item.get("depends_on", []):
            if dep not in by_key:
                errors.append(f"{k}: depends on unknown key '{dep}'")
            if dep == k:
                errors.append(f"{k}: depends on itself")
        if t == "story" and not item.get("user_story"):
            errors.append(f"{k}: stories need 'user_story' {{as, i_want, so_that}}")
        htt = item.get("how_to_test") or {}
        if not isinstance(htt, dict) or not (htt.get("automated") or htt.get("manual")):
            errors.append(f"{k}: how_to_test needs 'automated' and/or 'manual' steps")
    refs_ok = all(d in by_key for i in items for d in i.get("depends_on", [])) and         all(not i.get("parent") or i["parent"] in by_key for i in items) and not dupes
    if refs_ok:
        try:
            topo_order(items)
        except ValueError as exc:
            errors.append(str(exc))
    return errors


def topo_order(items: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Order items so that parents and dependencies come first."""
    by_key = {i["key"]: i for i in items}
    order: list[dict[str, Any]] = []
    state: dict[str, int] = {}

    def visit(key: str, path: list[str]) -> None:
        if state.get(key) == 2:
            return
        if state.get(key) == 1:
            raise ValueError("dependency cycle: " + " -> ".join(path + [key]))
        state[key] = 1
        item = by_key[key]
        before = list(item.get("depends_on", []))
        if item.get("parent"):
            before.insert(0, item["parent"])
        for dep in before:
            visit(dep, path + [key])
        state[key] = 2
        order.append(item)

    for item in items:
        visit(item["key"], [])
    return order


# --------------------------------------------------------------------------- rendering
def size_label(item: dict[str, Any]) -> str:
    est = item["estimate"]
    return f"size:{TSHIRT[est]}" if item["type"] == "epic" else f"size:{POINTS[est]}"


def ref(key: str, numbers: dict[str, int]) -> str:
    return f"#{numbers[key]}" if numbers.get(key, 0) > 0 else f"`{key}`"


def render_body(item: dict[str, Any], items: list[dict[str, Any]], numbers: dict[str, int],
                milestone_titles: dict[str, str]) -> str:
    def bullets(values: list[str], checkbox: bool = False) -> str:
        prefix = "- [ ] " if checkbox else "- "
        return "\n".join(prefix + v for v in values) if values else "- none"

    lines: list[str] = ["## Description"]
    us = item.get("user_story")
    if us:
        lines.append(f"As a **{us['as']}**, I want **{us['i_want']}**, so that **{us['so_that']}**.\n")
    lines += [item["description"].strip(), ""]

    lines += ["## Acceptance criteria", bullets(item["acceptance_criteria"], True), ""]

    checklist = list(item["checklist"])
    children = [i for i in items if i.get("parent") == item["key"]]
    if children:
        checklist += [f"{ref(c['key'], numbers)} {c['title']}" for c in children]
    lines += ["## Checklist", bullets(checklist, True), ""]

    blocks = [i["key"] for i in items if item["key"] in i.get("depends_on", [])]
    deps = item.get("depends_on", [])
    lines += [
        "## Dependencies",
        "- Depends on: " + (", ".join(ref(d, numbers) for d in deps) if deps else "none"),
        "- Blocks: " + (", ".join(ref(b, numbers) for b in blocks) if blocks else "none"),
        "- External: " + ("; ".join(item.get("external_dependencies", [])) or "none"),
        "",
    ]

    est = item["estimate"]
    est_txt = f"**{est}** (T-shirt size)" if item["type"] == "epic" else f"**{est} points** ({POINTS[est].upper()})"
    lines += ["## Estimation", est_txt, ""]

    htt = item["how_to_test"]
    lines.append("## How to test")
    if htt.get("automated"):
        lines.append("**Automated**")
        lines += [f"- {s}" for s in htt["automated"]]
    if htt.get("manual"):
        lines.append("**Manual**")
        lines += [f"{n}. {s}" for n, s in enumerate(htt["manual"], 1)]
    lines.append("")

    if item.get("out_of_scope"):
        lines += ["## Out of scope", bullets(item["out_of_scope"]), ""]
    if item.get("technical_notes"):
        lines += ["## Technical notes", item["technical_notes"].strip(), ""]
    if item.get("security"):
        lines += ["## Security / access", item["security"].strip(), ""]

    footer = []
    if item.get("parent"):
        footer.append(f"Parent: {ref(item['parent'], numbers)}")
    footer.append(f"Milestone: {milestone_titles.get(item['milestone'], item['milestone'])}")
    footer.append(f"Backlog key: `{item['key']}`")
    lines += ["---", " | ".join(footer), "- [x] Meets the Definition of Ready"]
    return "\n".join(lines) + "\n"


def issue_title(item: dict[str, Any]) -> str:
    return f"[{TYPES[item['type']]}] {item['title']}"


def labels_for(item: dict[str, Any]) -> list[str]:
    labels = [f"type:{item['type']}", f"priority:{item.get('priority', 'p2')}", size_label(item)]
    labels += [f"area:{a}" for a in item.get("area", [])]
    return labels


# --------------------------------------------------------------------------- gh helpers
GH_CANDIDATES = [
    r"C:\Program Files\GitHub CLI\gh.exe",
    r"C:\Program Files (x86)\GitHub CLI\gh.exe",
    os.path.join(os.environ.get("LOCALAPPDATA", ""), "Programs", "GitHub CLI", "gh.exe"),
    os.path.expanduser(os.path.join("~", "scoop", "shims", "gh.exe")),
    "/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh",
]


def find_gh() -> str | None:
    """Locate the GitHub CLI, also when it is installed but not on PATH (HARNESS_GH overrides)."""
    if os.environ.get("HARNESS_GH"):
        return os.environ["HARNESS_GH"]
    return shutil.which("gh") or next((c for c in GH_CANDIDATES if os.path.isfile(c)), None)


GH_INSTALL = {
    "win32": "winget install -e --id GitHub.cli   (then reopen the terminal)",
    "darwin": "brew install gh",
}


class Gh:
    def __init__(self, repo: str, dry_run: bool) -> None:
        self.repo = repo
        self.dry_run = dry_run
        self.bin = find_gh() or "gh"
        if not dry_run and not find_gh():
            hint = GH_INSTALL.get(sys.platform, "sudo apt install -y gh   (or https://github.com/cli/cli#installation)")
            raise SystemExit(f"GitHub CLI (gh) not found. Install it: {hint}\nThen run: gh auth login")

    def run(self, args: list[str], check: bool = True, mutate: bool = True) -> str:
        if self.dry_run and mutate:
            print("  DRY-RUN gh " + " ".join(a if " " not in a else repr(a) for a in args))
            return ""
        proc = subprocess.run([self.bin, *args], capture_output=True, text=True, encoding="utf-8")
        if check and proc.returncode != 0:
            raise RuntimeError(f"gh {' '.join(args)} failed: {proc.stderr.strip()}")
        return proc.stdout.strip() if proc.returncode == 0 else ""

    def ensure_label(self, name: str, color: str, desc: str) -> None:
        self.run(["label", "create", name, "--repo", self.repo, "--color", color,
                  "--description", desc, "--force"])

    def milestones(self) -> dict[str, int]:
        out = self.run(["api", f"repos/{self.repo}/milestones?state=all&per_page=100"], mutate=False)
        return {m["title"]: m["number"] for m in json.loads(out or "[]")}

    def ensure_milestone(self, m: dict[str, Any], existing: dict[str, int]) -> None:
        if m["title"] in existing:
            print(f"  milestone exists: {m['title']}")
            return
        args = ["api", "-X", "POST", f"repos/{self.repo}/milestones", "-f", f"title={m['title']}",
                "-f", f"description={m.get('description', '')}"]
        if m.get("due_on"):
            args += ["-f", f"due_on={m['due_on']}T23:59:59Z"]
        self.run(args)
        print(f"  milestone {'would be created' if self.dry_run else 'created'}: {m['title']}")

    def existing_issues(self) -> dict[str, int]:
        out = self.run(["issue", "list", "--repo", self.repo, "--state", "all", "--limit", "2000",
                        "--json", "number,title"], mutate=False)
        return {i["title"]: i["number"] for i in json.loads(out or "[]")}

    def create_issue(self, title: str, body: str, labels: list[str], milestone: str) -> int:
        with tempfile.NamedTemporaryFile("w", delete=False, suffix=".md", encoding="utf-8") as fh:
            fh.write(body)
            path = fh.name
        try:
            args = ["issue", "create", "--repo", self.repo, "--title", title, "--body-file", path,
                    "--milestone", milestone]
            for label in labels:
                args += ["--label", label]
            url = self.run(args)
        finally:
            os.unlink(path)
        return int(url.rstrip("/").split("/")[-1]) if url else 0

    def edit_body(self, number: int, body: str) -> None:
        with tempfile.NamedTemporaryFile("w", delete=False, suffix=".md", encoding="utf-8") as fh:
            fh.write(body)
            path = fh.name
        try:
            self.run(["issue", "edit", str(number), "--repo", self.repo, "--body-file", path])
        finally:
            os.unlink(path)

    def issue_id(self, number: int) -> str:
        return self.run(["api", f"repos/{self.repo}/issues/{number}", "--jq", ".id"], mutate=False)

    def link_blocked_by(self, number: int, blocker: int) -> bool:
        """GitHub issue dependencies API (best-effort; may not be enabled everywhere)."""
        try:
            self.run(["api", "-X", "POST", f"repos/{self.repo}/issues/{number}/dependencies/blocked_by",
                      "-F", f"issue_id={self.issue_id(blocker)}"])
            return True
        except RuntimeError as exc:
            print(f"  warn: could not add 'blocked by' #{blocker} to #{number}: {exc}")
            return False

    def link_sub_issue(self, parent: int, child: int) -> bool:
        """GitHub sub-issues API (best-effort)."""
        try:
            self.run(["api", "-X", "POST", f"repos/{self.repo}/issues/{parent}/sub_issues",
                      "-F", f"sub_issue_id={self.issue_id(child)}"])
            return True
        except RuntimeError as exc:
            print(f"  warn: could not add #{child} as sub-issue of #{parent}: {exc}")
            return False

    # ---- GitHub Projects (board linked to the repo). Needs the token scope `project`.
    def owner_info(self) -> tuple[str, str, str]:
        """Return (login, 'User'|'Organization', numeric id) of the repo owner."""
        login = self.repo.split("/")[0]
        out = self.run(["api", f"users/{login}", "--jq", '"\\(.type) \\(.id)"'], mutate=False)
        kind, _, uid = out.partition(" ")
        return login, kind or "User", uid

    def find_project(self, owner: str, title: str) -> dict[str, Any] | None:
        out = self.run(["project", "list", "--owner", owner, "--limit", "200", "--format", "json"], mutate=False)
        for p in json.loads(out or "{}").get("projects", []):
            if p.get("title") == title:
                return p
        return None

    def ensure_project(self, owner: str, title: str) -> dict[str, Any]:
        found = self.find_project(owner, title)
        if found:
            print(f"  project exists: #{found['number']} {title}")
            return found
        out = self.run(["project", "create", "--owner", owner, "--title", title, "--format", "json"])
        print(f"  project created: {title}")
        return json.loads(out)

    def project_api_bases(self, owner: str, kind: str, uid: str) -> list[str]:
        if kind == "Organization":
            return [f"orgs/{owner}"]
        return [f"users/{uid}", f"users/{owner}"] if uid else [f"users/{owner}"]

    def project_rest(self, bases: list[str], path: str, extra: list[str], mutate: bool) -> str:
        """Call a Projects REST endpoint, trying each owner path form until one works."""
        last: Exception | None = None
        for base in bases:
            try:
                return self.run(["api", "-H", "X-GitHub-Api-Version: 2026-03-10",
                                 f"{base}/projectsV2/{path}", *extra], mutate=mutate)
            except RuntimeError as exc:
                last = exc
        raise RuntimeError(str(last))

    def ensure_board_view(self, owner: str, kind: str, uid: str, number: int, name: str) -> None:
        """Add a Board view grouped by Status (columns), unless a view with that name exists."""
        node = "organization" if kind == "Organization" else "user"
        query = (f"query($login:String!,$n:Int!){{{node}(login:$login){{projectV2(number:$n)"
                 "{views(first:50){nodes{name}}}}}}")
        out = self.run(["api", "graphql", "-f", f"query={query}", "-F", f"login={owner}",
                        "-F", f"n={number}", "--jq", f".data.{node}.projectV2.views.nodes[].name"], mutate=False)
        if name in out.splitlines():
            print(f"  view exists: {name}")
            return
        bases = self.project_api_bases(owner, kind, uid)
        fields = json.loads(self.project_rest(bases, f"{number}/fields", [], mutate=False) or "[]")
        status = next((f["id"] for f in fields if f.get("name") == "Status"), None)
        body = {"name": name, "layout": "board"}
        if status is not None:
            body["vertical_group_by"] = [status]
        with tempfile.NamedTemporaryFile("w", delete=False, suffix=".json", encoding="utf-8") as fh:
            json.dump(body, fh)
            path = fh.name
        try:
            self.project_rest(bases, f"{number}/views", ["-X", "POST", "--input", path], mutate=True)
        finally:
            os.unlink(path)
        print(f"  board view created: {name} (columns = Status)")

    def status_todo(self, owner: str, number: int) -> tuple[str, str] | None:
        """Return (field id, option id) of Status = Todo, if the project has it."""
        out = self.run(["project", "field-list", str(number), "--owner", owner, "--format", "json"], mutate=False)
        for f in json.loads(out or "{}").get("fields", []):
            if f.get("name") == "Status":
                for o in f.get("options", []):
                    if o.get("name", "").lower() in ("todo", "to do"):
                        return f["id"], o["id"]
        return None

    def add_to_project(self, owner: str, number: int, issue: int) -> str:
        out = self.run(["project", "item-add", str(number), "--owner", owner, "--url",
                        f"https://github.com/{self.repo}/issues/{issue}", "--format", "json"])
        return json.loads(out).get("id", "") if out else ""

    def setup_project(self, title: str, view: str, numbers: dict[str, int], new_keys: list[str]) -> bool:
        """Create (or reuse) a project, link it to the repo, add every backlog issue and a Board view.
        Issues created in this run start in the Todo column; existing items keep their status."""
        if self.dry_run:
            owner = self.repo.split("/")[0]
            print(f"  DRY-RUN create or reuse project '{title}' (owner {owner}) and link it to {self.repo}")
            print(f"  DRY-RUN add {len(numbers)} issues; new ones get Status = Todo")
            print(f"  DRY-RUN add a '{view}' view (board layout, columns = Status)")
            return True
        try:
            owner, kind, uid = self.owner_info()
            project = self.ensure_project(owner, title)
            num, pid = int(project["number"]), project["id"]
            try:
                self.run(["project", "link", str(num), "--owner", owner, "--repo", self.repo.split("/")[1]])
                print(f"  linked to {self.repo}")
            except RuntimeError as exc:  # already linked, or not permitted
                print(f"  warn: could not link the project to {self.repo}: {exc}")
            todo = self.status_todo(owner, num)
            for key, issue in numbers.items():
                item = self.add_to_project(owner, num, issue)
                if todo and item and key in new_keys:
                    self.run(["project", "item-edit", "--id", item, "--project-id", pid,
                              "--field-id", todo[0], "--single-select-option-id", todo[1]])
            print(f"  {len(numbers)} issues in the project")
            try:
                self.ensure_board_view(owner, kind, uid, num, view)
            except RuntimeError as exc:
                print(f"  warn: could not create the '{view}' view, add it by hand (New view > Board): {exc}")
            print(f"  project URL: {project.get('url', '')}")
            return True
        except (RuntimeError, ValueError, KeyError) as exc:
            print(f"  ERROR: project NOT set up: {exc}")
            print("  If the error mentions scopes, run: gh auth refresh -s project   (then re-run this script)")
            return False


# --------------------------------------------------------------------------- feature list
def write_feature_list(path: str, backlog: dict[str, Any], numbers: dict[str, int]) -> None:
    existing: dict[str, Any] = {}
    if os.path.exists(path):
        try:
            with open(path, encoding="utf-8") as fh:
                existing = {f["key"]: f for f in json.load(fh).get("features", [])}
        except (OSError, json.JSONDecodeError, KeyError):
            existing = {}
    data = {
        "$comment": "Global state of features and milestones. status: todo | in_progress | blocked | in_review | done.",
        "schema_version": 1,
        "project": backlog.get("project", ""),
        "updated_at": dt.date.today().isoformat(),
        "milestones": [
            {"key": m["key"], "title": m["title"], "description": m.get("description", ""),
             "due_on": m.get("due_on"), "status": "todo"}
            for m in backlog.get("milestones", [])
        ],
        "features": [
            {
                "key": i["key"], "type": i["type"], "title": i["title"], "milestone": i["milestone"],
                "parent": i.get("parent"),
                "issue": numbers.get(i["key"]) or existing.get(i["key"], {}).get("issue"),
                "status": existing.get(i["key"], {}).get("status", "todo"),
                "estimate": i["estimate"], "depends_on": i.get("depends_on", []),
                "tests": i["how_to_test"].get("automated", []),
                "notes": existing.get(i["key"], {}).get("notes", ""),
            }
            for i in backlog["items"]
        ],
    }
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    print(f"feature list written: {path}")


# --------------------------------------------------------------------------- main
def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--backlog", required=True, help="path to backlog JSON")
    ap.add_argument("--repo", help="owner/name of the target GitHub repository")
    ap.add_argument("--dry-run", action="store_true", help="print gh commands without executing mutations")
    ap.add_argument("--validate-only", action="store_true", help="validate the backlog and exit (no network)")
    ap.add_argument("--out", default="issue-map.json", help="where to write the key -> issue number map")
    ap.add_argument("--write-feature-list", metavar="PATH", help="write/update a harness feature_list.json")
    ap.add_argument("--no-relationships", action="store_true", help="skip GitHub 'blocked by' and sub-issue links")
    ap.add_argument("--project-title", default="Kanban board",
                    help="GitHub Project (board) to create or reuse, linked to the repo (default: %(default)s)")
    ap.add_argument("--project-view", default="Board", help="name of the board view (default: %(default)s)")
    ap.add_argument("--no-project", action="store_true", help="do not create/update the GitHub Project")
    args = ap.parse_args()

    with open(args.backlog, encoding="utf-8") as fh:
        backlog = json.load(fh)

    errors = validate(backlog)
    if errors:
        print("Backlog is INVALID:")
        for err in errors:
            print(f"  - {err}")
        return 1
    items = backlog["items"]
    print(f"Backlog valid: {len(items)} items, {len(backlog.get('milestones', []))} milestones.")

    if args.validate_only:
        if args.write_feature_list:
            write_feature_list(args.write_feature_list, backlog, {})
        return 0
    if not args.repo:
        ap.error("--repo is required unless --validate-only")

    gh = Gh(args.repo, args.dry_run)
    milestone_titles = {m["key"]: m["title"] for m in backlog.get("milestones", [])}

    print("\n== Labels ==")
    extra = [(lab["name"], lab.get("color", "ededed"), lab.get("description", "")) for lab in backlog.get("labels", [])]
    areas = sorted({a for i in items for a in i.get("area", [])} - {lab[0][5:] for lab in extra if lab[0].startswith("area:")})
    extra += [(f"area:{a}", "0075ca", f"Area: {a}") for a in areas]
    for name, color, desc in DEFAULT_LABELS + extra:
        gh.ensure_label(name, color, desc)

    print("\n== Milestones ==")
    existing_ms = gh.milestones() if not args.dry_run else {}
    for m in backlog.get("milestones", []):
        gh.ensure_milestone(m, existing_ms)

    print("\n== Issues ==")
    existing = gh.existing_issues() if not args.dry_run else {}
    numbers: dict[str, int] = {}
    created: list[str] = []
    for n, item in enumerate(topo_order(items), 1):
        title = issue_title(item)
        if title in existing:
            numbers[item["key"]] = existing[title]
            print(f"  exists  #{existing[title]:<5} {item['key']:<10} {title}")
            continue
        body = render_body(item, items, numbers, milestone_titles)
        if args.dry_run and not created:
            print("  --- preview of the first issue body ---")
            print("  " + body.replace("\n", "\n  "))
            print("  --- end of preview ---")
        num = gh.create_issue(title, body, labels_for(item), milestone_titles[item["milestone"]])
        numbers[item["key"]] = num or -n  # negative placeholder in dry-run
        created.append(item["key"])
        label = "would create" if args.dry_run else f"created #{num}"
        print(f"  {label:<13} {item['key']:<10} {title}")

    if not args.dry_run:
        print("\n== Back-references (Blocks / child lists) ==")
        for item in items:
            has_blocks = any(item["key"] in i.get("depends_on", []) for i in items)
            has_children = any(i.get("parent") == item["key"] for i in items)
            if item["key"] in created and (has_blocks or has_children):
                gh.edit_body(numbers[item["key"]], render_body(item, items, numbers, milestone_titles))
                print(f"  updated #{numbers[item['key']]} {item['key']}")

        if not args.no_relationships:
            print("\n== GitHub relationships (best-effort) ==")
            for item in items:
                if item["key"] not in created:
                    continue
                if item.get("parent"):
                    gh.link_sub_issue(numbers[item["parent"]], numbers[item["key"]])
                for dep in item.get("depends_on", []):
                    gh.link_blocked_by(numbers[item["key"]], numbers[dep])

        with open(args.out, "w", encoding="utf-8", newline="\n") as fh:
            json.dump(numbers, fh, indent=2)
            fh.write("\n")
        print(f"\nissue map written: {args.out}")
        if args.write_feature_list:
            write_feature_list(args.write_feature_list, backlog, numbers)

    project_ok = True
    if not args.no_project:
        print("\n== GitHub Project (board) ==")
        project_ok = gh.setup_project(args.project_title, args.project_view, numbers, created)

    verb = "would be created" if args.dry_run else "created"
    print(f"\nDone. {len(created)} {verb}, {len(items) - len(created)} already existed.")
    if not project_ok:
        print("Issues are fine, but the project board was NOT set up (see the error above).")
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
