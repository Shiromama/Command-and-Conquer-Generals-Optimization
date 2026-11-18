#!/usr/bin/env python3
"""Validate this repository's agent-facing documentation system.

Checks:
  * required files exist
  * every relative Markdown link resolves
  * docs/state.json matches the documented schema, and its `updated_at`
    equals the newest date heading in docs/log.md
  * every next_action references a real, not-Done task on the board
  * task IDs are unique and statuses are valid
  * ADR files are numbered uniquely and carry a Status line
  * issue files follow ISSUE-####-slug.md, have valid status/severity/date/task,
    are indexed, and use unique numbers
  * .opencode/continuity.md agrees with state.json (phase + date)
  * no unresolved placeholders outside templates

Usage:
    python tools/check_docs.py
    python tools/check_docs.py --self-test   # prove the validator detects breakage
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
import tempfile
from datetime import date, datetime
from pathlib import Path

TASK_STATUSES = {"Backlog", "Todo", "In Progress", "Blocked", "Done"}
MILESTONE_STATUSES = {"planned", "in-progress", "done", "blocked"}
ISSUE_STATUSES = {"Open", "Investigating", "Workaround", "Fixed", "Won't fix", "Duplicate"}
SEVERITIES = {"Critical", "High", "Medium", "Low"}
ISSUE_FILE_RE = re.compile(r"ISSUE-(\d{4})-[a-z0-9-]+\.md")
LINK_RE = re.compile(r"\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
FENCE_RE = re.compile(r"^```")
INLINE_CODE_RE = re.compile(r"`[^`\n]*`")
LOG_DATE_RE = re.compile(r"^## (\d{4}-\d{2}-\d{2})", re.MULTILINE)
TASK_ROW_RE = re.compile(r"^\|\s*(T-\d{3})\s*\|")

STATE_REQUIRED = [
    "schema_version", "project", "phase", "phase_name", "status", "updated_at",
    "canonical_entrypoint", "current_focus", "next_actions", "milestones",
    "blockers", "open_questions",
]

REQUIRED_FILES = [
    "AGENTS.md",
    "README.md",
    "docs/INDEX.md",
    "docs/project-brief.md",
    "docs/state.json",
    "docs/environment.md",
    "docs/game-inventory.md",
    "docs/architecture.md",
    "docs/roadmap.md",
    "docs/tasks/BOARD.md",
    "docs/decisions/README.md",
    "docs/issues/README.md",
    "docs/issues/TEMPLATE.md",
    "docs/research/TEMPLATE.md",
    "docs/experiments/TEMPLATE.md",
    "docs/glossary.md",
    "docs/log.md",
    ".opencode/continuity.md",
    "artifacts/README.md",
]


def strip_fenced_code(text: str) -> str:
    """Remove fenced code blocks so examples are not treated as links/placeholders."""
    out, in_fence = [], False
    for line in text.splitlines():
        if FENCE_RE.match(line.strip()):
            in_fence = not in_fence
            out.append("")
            continue
        out.append("" if in_fence else line)
    return "\n".join(out)


def markdown_files(root: Path):
    files = [root / "AGENTS.md", root / "README.md"]
    files += sorted((root / "docs").rglob("*.md"))
    return [p for p in files if p.is_file()]


def check_links(root: Path, errors: list[str], warnings: list[str]) -> int:
    count = 0
    artifacts_root = (root / "artifacts").resolve()
    for md in markdown_files(root):
        text = strip_fenced_code(md.read_text(encoding="utf-8", errors="replace"))
        for raw in LINK_RE.findall(text):
            target = raw.strip()
            if not target or target.startswith(("http://", "https://", "mailto:", "#")):
                continue
            if "{{" in target or "<" in target:
                continue
            path_part = target.split("#", 1)[0]
            if not path_part:
                continue
            resolved = (md.parent / path_part).resolve()
            count += 1
            if not resolved.exists():
                # Evidence under artifacts/ is gitignored and intentionally absent in a clean
                # checkout (and in the self-test fixture), so a missing artifact is a warning,
                # not a broken documentation link.
                try:
                    resolved.relative_to(artifacts_root)
                    is_artifact = True
                except ValueError:
                    is_artifact = False
                if is_artifact:
                    warnings.append(
                        f"artifact evidence not present locally: {md.relative_to(root)} -> {target}"
                    )
                else:
                    errors.append(
                        f"broken link: {md.relative_to(root)} -> {target}"
                    )
    return count


def load_state(root: Path, errors: list[str]) -> dict:
    path = root / "docs" / "state.json"
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001 - report any parse failure
        errors.append(f"docs/state.json is not valid JSON: {exc}")
        return {}


def check_state(root: Path, state: dict, errors: list[str]) -> None:
    if not state:
        return
    for key in STATE_REQUIRED:
        if key not in state:
            errors.append(f"docs/state.json missing key: {key}")
    if errors and any(e.startswith("docs/state.json missing") for e in errors):
        return

    if not re.fullmatch(r"P\d+", str(state.get("phase", ""))):
        errors.append(f"state.phase must look like P0..Pn, got {state.get('phase')!r}")

    raw_date = str(state.get("updated_at", ""))
    try:
        updated = datetime.strptime(raw_date, "%Y-%m-%d").date()
    except ValueError:
        errors.append(f"state.updated_at is not YYYY-MM-DD: {raw_date!r}")
        updated = None
    if updated and updated > date.today():
        errors.append(f"state.updated_at is in the future: {raw_date}")

    entry = root / str(state.get("canonical_entrypoint", ""))
    if not entry.is_file():
        errors.append(f"state.canonical_entrypoint does not exist: {state.get('canonical_entrypoint')!r}")

    # Log freshness: newest dated heading must equal state.updated_at.
    log_path = root / "docs" / "log.md"
    if log_path.is_file():
        log_dates = LOG_DATE_RE.findall(log_path.read_text(encoding="utf-8", errors="replace"))
        if not log_dates:
            errors.append("docs/log.md has no '## YYYY-MM-DD' entries")
        else:
            newest = max(log_dates)
            if raw_date != newest:
                errors.append(
                    f"state.updated_at ({raw_date}) != newest log entry ({newest})"
                )
    else:
        errors.append("docs/log.md is missing")

    actions = state.get("next_actions")
    if not isinstance(actions, list) or not actions:
        errors.append("state.next_actions must be a non-empty list")
        actions = []
    for action in actions:
        if not isinstance(action, dict) or not {"id", "title", "owner"} <= set(action):
            errors.append(f"next_action missing id/title/owner: {action!r}")
        elif not re.fullmatch(r"T-\d{3}", str(action["id"])):
            errors.append(f"next_action id is not T-###: {action['id']!r}")

    milestones = state.get("milestones")
    if not isinstance(milestones, list) or not milestones:
        errors.append("state.milestones must be a non-empty list")
        milestones = []
    for ms in milestones:
        if not isinstance(ms, dict) or not {"id", "title", "status", "doc"} <= set(ms):
            errors.append(f"milestone missing id/title/status/doc: {ms!r}")
            continue
        if ms["status"] not in MILESTONE_STATUSES:
            errors.append(f"milestone {ms['id']} has invalid status {ms['status']!r}")
        if not (root / str(ms["doc"])).is_file():
            errors.append(f"milestone {ms['id']} doc does not exist: {ms['doc']}")

    if not isinstance(state.get("open_questions"), list) or not state["open_questions"]:
        errors.append("state.open_questions must be a non-empty list")
    if not isinstance(state.get("blockers"), list):
        errors.append("state.blockers must be a list")


def check_board(root: Path, state: dict, errors: list[str]) -> dict[str, str]:
    path = root / "docs" / "tasks" / "BOARD.md"
    tasks: dict[str, str] = {}
    if not path.is_file():
        errors.append("docs/tasks/BOARD.md is missing")
        return tasks
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        m = TASK_ROW_RE.match(line)
        if not m:
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 5:
            errors.append(f"task row has too few columns: {line.strip()}")
            continue
        task_id, status = cells[0], cells[3]
        if task_id in tasks:
            errors.append(f"duplicate task id on board: {task_id}")
        tasks[task_id] = status
        if status not in TASK_STATUSES:
            errors.append(f"{task_id} has invalid status {status!r}")

    for action in state.get("next_actions", []) if isinstance(state, dict) else []:
        if isinstance(action, dict) and action.get("id") in tasks:
            if tasks[action["id"]] == "Done":
                errors.append(
                    f"state.next_actions lists {action['id']} but the board marks it Done"
                )
        elif isinstance(action, dict):
            errors.append(f"state.next_actions references unknown task {action.get('id')!r}")
    return tasks


def check_adrs(root: Path, errors: list[str]) -> int:
    folder = root / "docs" / "decisions"
    seen: dict[str, str] = {}
    count = 0
    for adr in sorted(folder.glob("ADR-*.md")):
        m = re.fullmatch(r"ADR-(\d{4})-[a-z0-9-]+\.md", adr.name)
        if not m:
            errors.append(f"ADR filename does not match ADR-####-slug.md: {adr.name}")
            continue
        count += 1
        num = m.group(1)
        if num in seen:
            errors.append(f"duplicate ADR number {num}: {seen[num]} and {adr.name}")
        seen[num] = adr.name
        text = adr.read_text(encoding="utf-8", errors="replace")
        if not re.search(r"^-\s+\*\*Status:\*\*", text, re.MULTILINE):
            errors.append(f"{adr.name} has no '- **Status:**' line")
    return count


def check_issues(root: Path, errors: list[str]) -> int:
    folder = root / "docs" / "issues"
    index_path = folder / "README.md"
    index_text = (
        index_path.read_text(encoding="utf-8", errors="replace")
        if index_path.is_file()
        else ""
    )
    seen: dict[str, str] = {}
    count = 0
    for issue in sorted(folder.glob("ISSUE-*.md")):
        m = ISSUE_FILE_RE.fullmatch(issue.name)
        if not m:
            errors.append(f"issue filename does not match ISSUE-####-slug.md: {issue.name}")
            continue
        num = m.group(1)
        count += 1
        if num in seen:
            errors.append(f"duplicate ISSUE number {num}: {seen[num]} and {issue.name}")
        seen[num] = issue.name
        text = issue.read_text(encoding="utf-8", errors="replace")

        if not re.search(rf"^# ISSUE-{num}:", text, re.MULTILINE):
            errors.append(f"{issue.name} title must start with '# ISSUE-{num}:'")

        status = re.search(r"^-\s+\*\*Status:\*\*\s*([^\n]+)$", text, re.MULTILINE)
        if not status:
            errors.append(f"{issue.name} has no '- **Status:**' line")
        elif status.group(1).strip() not in ISSUE_STATUSES:
            errors.append(f"{issue.name} has invalid status {status.group(1).strip()!r}")

        severity = re.search(r"^-\s+\*\*Severity:\*\*\s*([^\n]+)$", text, re.MULTILINE)
        if not severity:
            errors.append(f"{issue.name} has no '- **Severity:**' line")
        elif severity.group(1).strip() not in SEVERITIES:
            errors.append(
                f"{issue.name} has invalid severity {severity.group(1).strip()!r}"
            )

        if not re.search(r"^-\s+\*\*Date found:\*\*\s*\d{4}-\d{2}-\d{2}$", text, re.MULTILINE):
            errors.append(f"{issue.name} has no valid '- **Date found:** YYYY-MM-DD'")
        if not re.search(r"^-\s+\*\*Task:\*\*\s*T-\d{3}$", text, re.MULTILINE):
            errors.append(f"{issue.name} has no valid '- **Task:** T-###'")
        if "## Resolution / verification" not in text:
            errors.append(f"{issue.name} has no '## Resolution / verification' section")
        if index_text and issue.name not in index_text:
            errors.append(f"{issue.name} is not listed in docs/issues/README.md")

    return count


def check_continuity(root: Path, state: dict, errors: list[str]) -> None:
    path = root / ".opencode" / "continuity.md"
    if not path.is_file():
        errors.append(".opencode/continuity.md is missing")
        return
    text = path.read_text(encoding="utf-8", errors="replace")
    phase = re.search(r"(?im)^Phase:\s*(P\d+)", text)
    if not phase:
        errors.append("continuity.md has no 'Phase: Pn' line")
    elif state.get("phase") and phase.group(1) != state["phase"]:
        errors.append(
            f"continuity.md phase {phase.group(1)} != state.phase {state['phase']}"
        )
    updated = re.search(r"(?im)^Updated:\s*(\d{4}-\d{2}-\d{2})", text)
    if not updated:
        errors.append("continuity.md has no 'Updated: YYYY-MM-DD' line")
    elif state.get("updated_at") and updated.group(1) != state["updated_at"]:
        errors.append(
            f"continuity.md date {updated.group(1)} != state.updated_at {state['updated_at']}"
        )


def check_placeholders(root: Path, errors: list[str]) -> None:
    for md in markdown_files(root):
        if md.name == "TEMPLATE.md":
            continue
        text = strip_fenced_code(md.read_text(encoding="utf-8", errors="replace"))
        text = INLINE_CODE_RE.sub("", text)  # documented markers are not placeholders
        for marker in ("{{", "TODO:", "FIXME"):
            if marker in text:
                errors.append(
                    f"unresolved placeholder {marker!r} in {md.relative_to(root)}"
                )


def validate(root: Path) -> tuple[list[str], list[str], dict]:
    errors: list[str] = []
    warnings: list[str] = []
    for rel in REQUIRED_FILES:
        if not (root / rel).is_file():
            errors.append(f"missing required file: {rel}")

    link_count = check_links(root, errors, warnings)
    state = load_state(root, errors)
    check_state(root, state, errors)
    tasks = check_board(root, state, errors)
    adr_count = check_adrs(root, errors)
    issue_count = check_issues(root, errors)
    check_continuity(root, state, errors)
    check_placeholders(root, errors)

    try:
        updated = datetime.strptime(str(state.get("updated_at", "")), "%Y-%m-%d").date()
        if (date.today() - updated).days > 30:
            warnings.append(
                f"state.updated_at is {(date.today() - updated).days} days old; refresh it"
            )
    except ValueError:
        pass

    stats = {
        "markdown": len(markdown_files(root)),
        "links": link_count,
        "tasks": len(tasks),
        "adrs": adr_count,
        "issues": issue_count,
    }
    return errors, warnings, stats


def run_report(root: Path) -> int:
    errors, warnings, stats = validate(root)
    print(
        f"Checked {stats['markdown']} markdown files, {stats['links']} relative links, "
        f"{stats['tasks']} tasks, {stats['adrs']} ADRs, {stats['issues']} issues."
    )
    for warning in warnings:
        print(f"WARN: {warning}")
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        print(f"FAILED: {len(errors)} problem(s).")
        return 1
    print("OK: documentation system is consistent")
    return 0


def self_test() -> int:
    src = Path(__file__).resolve().parent.parent
    with tempfile.TemporaryDirectory(prefix="docs-check-") as tmp:
        dst = Path(tmp) / "repo"

        def ignore(directory: str, names: list[str]) -> set[str]:
            here = Path(directory)
            skipped = {
                n for n in names
                if n in {".git", "target", "__pycache__", "Command and Conquer Generals Zero Hour"}
                or n.endswith(".pyc")
            }
            if here == src / "artifacts":
                skipped |= {n for n in names if n != "README.md"}
            return skipped

        shutil.copytree(src, dst, ignore=ignore)

        errors, _, _ = validate(dst)
        if errors:
            print("SELF-TEST FAILED: clean fixture did not validate:")
            for error in errors:
                print(f"  {error}")
            return 1
        print("PASS: clean fixture validates")

        index = dst / "docs" / "INDEX.md"
        original = index.read_text(encoding="utf-8")
        index.write_text(original + "\n[broken](does-not-exist.md)\n", encoding="utf-8")
        errors, _, _ = validate(dst)
        if not any("does-not-exist.md" in e for e in errors):
            print("SELF-TEST FAILED: broken link was not detected")
            return 1
        print("PASS: broken link detected")

        index.write_text(original, encoding="utf-8")
        state_path = dst / "docs" / "state.json"
        state = json.loads(state_path.read_text(encoding="utf-8"))
        state["updated_at"] = "1999-01-01"
        state_path.write_text(json.dumps(state, indent=2), encoding="utf-8")
        errors, _, _ = validate(dst)
        if not any("newest log entry" in e for e in errors):
            print("SELF-TEST FAILED: stale state date was not detected")
            return 1
        print("PASS: stale state date detected")

        state["updated_at"] = json.loads(
            (src / "docs" / "state.json").read_text(encoding="utf-8")
        )["updated_at"]
        state_path.write_text(json.dumps(state, indent=2), encoding="utf-8")
        state["next_actions"] = [
            {"id": "T-999", "title": "ghost", "owner": "nobody"}
        ]
        state_path.write_text(json.dumps(state, indent=2), encoding="utf-8")
        errors, _, _ = validate(dst)
        if not any("unknown task" in e for e in errors):
            print("SELF-TEST FAILED: dangling next_action was not detected")
            return 1
        print("PASS: dangling next_action detected")

        state = json.loads((src / "docs" / "state.json").read_text(encoding="utf-8"))
        state_path.write_text(json.dumps(state, indent=2), encoding="utf-8")
        issue_dir = dst / "docs" / "issues"
        source_issue = issue_dir / "ISSUE-0001-reference-install-runtime-writes.md"
        shutil.copyfile(source_issue, issue_dir / "ISSUE-0001-duplicate.md")
        errors, _, _ = validate(dst)
        if not any("duplicate ISSUE number" in e for e in errors):
            print("SELF-TEST FAILED: duplicate issue id was not detected")
            return 1
        print("PASS: duplicate issue id detected")

    print("SELF-TEST OK: validator detects injected breakage")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parent.parent,
        help="repository root (default: parent of tools/)",
    )
    parser.add_argument("--self-test", action="store_true", help="verify the validator itself")
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    return run_report(args.root)


if __name__ == "__main__":
    sys.exit(main())
