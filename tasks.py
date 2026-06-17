#!/usr/bin/env python3
"""RallyRivals task backlog tool. Single source of truth: tasks.yaml.

Usage:
  python3 tasks.py next  [--type T] [--group G] [--size S]   # 3 random unblocked TODOs
  python3 tasks.py list  [--type T] [--group G] [--size S] [--status todo|done|all]
  python3 tasks.py done <id>          # mark a task done (preserves file formatting/comments)
  python3 tasks.py validate           # check ids, labels, blockers, cycles
  python3 tasks.py render             # regenerate STATUS.md
  python3 tasks.py sync               # validate + render
"""
import argparse
import os
import random
import re
import sys

import yaml

HERE = os.path.dirname(os.path.abspath(__file__))
TASKS = os.path.join(HERE, "tasks.yaml")
STATUS = os.path.join(HERE, "STATUS.md")
SIZES = ["micro", "small", "default", "big", "huge"]
SIZE_LABEL = {"micro": "15m", "small": "30m", "default": "1h", "big": "2h", "huge": "3h+"}


def load():
    with open(TASKS) as f:
        data = yaml.safe_load(f) or {}
    data.setdefault("tasks", [])
    data.setdefault("meta", {})
    return data


def done_ids(tasks):
    return {t["id"] for t in tasks if t.get("status") == "done"}


def unblocked(t, done):
    return all(b in done for b in (t.get("blockers") or []))


def matches(t, args):
    if getattr(args, "type", None) and t.get("type") != args.type:
        return False
    if getattr(args, "group", None) and t.get("group") != args.group:
        return False
    if getattr(args, "size", None) and t.get("size") != args.size:
        return False
    return True


def fmt(t):
    size = t.get("size", "default")
    return (f"  [{t['type']}/{t.get('group', '-')}]  {size} (~{SIZE_LABEL.get(size, '?')})  "
            f"{t['id']}\n      {t['title']}")


def cmd_next(data, args):
    tasks = data["tasks"]
    done = done_ids(tasks)
    pool = [t for t in tasks if t.get("status") != "done" and unblocked(t, done) and matches(t, args)]
    if not pool:
        print("No unblocked tasks match those filters. Loosen them, or clear some blockers first.")
        return
    random.shuffle(pool)
    print(f"{len(pool)} task(s) available — here are {min(3, len(pool))}:\n")
    for t in pool[:3]:
        print(fmt(t) + "\n")


def cmd_list(data, args):
    tasks = data["tasks"]
    done = done_ids(tasks)
    want = getattr(args, "status", "todo") or "todo"
    for t in tasks:
        if want == "todo" and t.get("status") == "done":
            continue
        if want == "done" and t.get("status") != "done":
            continue
        if not matches(t, args):
            continue
        flag = "x" if t.get("status") == "done" else (" " if unblocked(t, done) else "~")
        print(f"[{flag}] {t['id']:40} {t['type']}/{t.get('group', '-')}  ({t.get('size', 'default')})")


def cmd_done(args):
    """Mark a task done via minimal text patch (preserves comments/formatting).

    Handles both one-line flow style (`- {id: x, ..., status: todo, ...}`) and block style
    (`id:` and `status:` on separate lines).
    """
    target = args.id
    with open(TASKS) as f:
        lines = f.readlines()
    id_here = re.compile(r"\bid:\s*['\"]?" + re.escape(target) + r"['\"]?(?:[\s,}]|$)")
    out, found, patched, in_block = [], False, False, False
    for line in lines:
        if not patched and id_here.search(line):  # flow style: id + status on one line
            found = True
            new = re.sub(r"(status:\s*)\w+", r"\1done", line)
            if new != line:
                patched = True
                line = new
            else:  # block style: status is on a later line
                in_block = True
        elif in_block and not patched:
            if re.match(r"\s+status:\s*\S+", line):
                line = re.sub(r"(status:\s*)\S+", r"\1done", line)
                patched = True
            elif re.match(r"\s*-\s", line):  # next task started, no status seen
                in_block = False
        out.append(line)
    if not found:
        sys.exit(f"no task with id '{target}'")
    if not patched:
        sys.exit(f"task '{target}' found but no 'status:' field to patch (add one)")
    with open(TASKS, "w") as f:
        f.writelines(out)
    print(f"marked '{target}' done. Run `python3 tasks.py sync` to refresh STATUS.md.")


def cmd_validate(data):
    tasks = data["tasks"]
    types = data["meta"].get("types", {})
    issues = []
    ids = [t.get("id") for t in tasks]
    seen = set()
    for i in ids:
        if i in seen:
            issues.append(f"duplicate id: {i}")
        seen.add(i)
    idset = set(ids)
    for t in tasks:
        tid = t.get("id", "?")
        typ, grp = t.get("type"), t.get("group")
        if typ not in types:
            issues.append(f"{tid}: unknown type '{typ}'")
        elif grp not in types[typ]:
            issues.append(f"{tid}: group '{grp}' not valid for type '{typ}'")
        if t.get("size") and t["size"] not in SIZES:
            issues.append(f"{tid}: unknown size '{t['size']}'")
        if t.get("status") not in (None, "todo", "done", "wip"):
            issues.append(f"{tid}: unknown status '{t.get('status')}'")
        for b in (t.get("blockers") or []):
            if b not in idset:
                issues.append(f"{tid}: blocker '{b}' does not exist")
    # cycle detection (DFS)
    graph = {t["id"]: [b for b in (t.get("blockers") or []) if b in idset] for t in tasks if "id" in t}
    color = {}

    def dfs(n, stack):
        color[n] = 1
        for m in graph.get(n, []):
            if color.get(m) == 1:
                issues.append("cycle: " + " -> ".join(stack + [m]))
            elif color.get(m, 0) == 0:
                dfs(m, stack + [m])
        color[n] = 2

    for n in graph:
        if color.get(n, 0) == 0:
            dfs(n, [n])
    if issues:
        print("VALIDATION ISSUES:")
        for i in issues:
            print("  -", i)
        sys.exit(1)
    print(f"ok: {len(tasks)} tasks valid")


def _nid(task_id):
    return task_id.replace("-", "_")


def _short(task_id):
    parts = task_id.split("-", 1)
    return parts[1] if len(parts) > 1 else task_id


def mermaid_pie(ndone, navail, nblocked):
    return ["```mermaid", "pie showData", "    title Task status",
            f'    "done" : {ndone}', f'    "available" : {navail}',
            f'    "blocked" : {nblocked}', "```", ""]


def mermaid_typebar(tasks, types):
    labels, vals = [], []
    for typ in types:
        tt = [t for t in tasks if t.get("type") == typ]
        if not tt:
            continue
        td = sum(1 for t in tt if t.get("status") == "done")
        labels.append(f'"{typ}"')
        vals.append(round(100 * td / len(tt)))
    return ["```mermaid", "xychart-beta",
            '    title "Progress by type (% done)"',
            "    x-axis [" + ", ".join(labels) + "]",
            '    y-axis "% done" 0 --> 100',
            "    bar [" + ", ".join(str(v) for v in vals) + "]",
            "```", ""]


def subgroup_table(tasks, types):
    rows = ["| type | subgroup | done | total |", "|---|---|--:|--:|"]
    for typ, groups in types.items():
        for g in groups:
            gt = [t for t in tasks if t.get("type") == typ and t.get("group") == g]
            if not gt:
                continue
            gd = sum(1 for t in gt if t.get("status") == "done")
            rows.append(f"| {typ} | {g} | {gd} | {len(gt)} |")
    rows.append("")
    return rows


def mermaid_graph(tasks, done, types):
    nd = [t for t in tasks if t.get("status") != "done"]
    nd_ids = {t["id"] for t in nd}
    lines = ["```mermaid", "flowchart LR"]
    by_type = {}
    for t in nd:
        by_type.setdefault(t["type"], []).append(t)
    for typ in types:
        ts = by_type.get(typ, [])
        if not ts:
            continue
        lines.append(f"  subgraph {typ}")
        for t in ts:
            lines.append(f'    {_nid(t["id"])}["{_short(t["id"])}"]')
        lines.append("  end")
    for t in nd:  # edges only among not-done tasks (satisfied blockers are hidden)
        for b in (t.get("blockers") or []):
            if b in nd_ids:
                lines.append(f"  {_nid(b)} --> {_nid(t['id'])}")
    avail = [_nid(t["id"]) for t in nd if unblocked(t, done)]
    blocked = [_nid(t["id"]) for t in nd if not unblocked(t, done)]
    lines.append("  classDef avail fill:#d6f5d6,stroke:#2e7d32,color:#1b3d1b;")
    lines.append("  classDef blocked fill:#f0f0f0,stroke:#9e9e9e,color:#555;")
    if avail:
        lines.append("  class " + ",".join(avail) + " avail;")
    if blocked:
        lines.append("  class " + ",".join(blocked) + " blocked;")
    lines += ["```", ""]
    return lines


def cmd_render(data):
    tasks = data["tasks"]
    done = done_ids(tasks)
    types = data["meta"].get("types", {})
    total, ndone = len(tasks), len(done)
    navail = sum(1 for t in tasks if t.get("status") != "done" and unblocked(t, done))
    out = [
        "# RallyRivals — Task Status", "",
        "> Generated by `python3 tasks.py render`. **Do not hand-edit** — edit `tasks.yaml`.", "",
        f"**Overall:** {ndone}/{total} done ({round(100 * ndone / total) if total else 0}%) · "
        f"{navail} available · {total - ndone - navail} blocked", "",
    ]
    out += mermaid_pie(ndone, navail, total - ndone - navail)
    out += ["## Progress by type", ""]
    out += mermaid_typebar(tasks, types)
    out += ["### By subgroup", ""]
    out += subgroup_table(tasks, types)
    avail = sorted([t for t in tasks if t.get("status") != "done" and unblocked(t, done)],
                   key=lambda t: (t.get("type"), t.get("group", "")))
    out += ["", f"## Available now ({len(avail)} unblocked)", ""]
    for t in avail:
        out.append(f"- `{t['id']}` [{t['type']}/{t.get('group', '-')}] ({t.get('size', 'default')}) — {t['title']}")
    blocked = [t for t in tasks if t.get("status") != "done" and not unblocked(t, done)]
    out += ["", f"## Blocked ({len(blocked)})", ""]
    for t in blocked:
        waiting = [b for b in (t.get("blockers") or []) if b not in done]
        out.append(f"- `{t['id']}` — waiting on: {', '.join(waiting)}")
    out += ["", "## Dependency graph (remaining work)",
            "", "_Green = available now · gray = blocked. Done tasks omitted._", ""]
    out += mermaid_graph(tasks, done, list(types))
    with open(STATUS, "w") as f:
        f.write("\n".join(out))
    print(f"rendered STATUS.md ({ndone}/{total} done, {len(avail)} available, {len(blocked)} blocked)")


def main():
    p = argparse.ArgumentParser(description="RallyRivals task backlog tool")
    sub = p.add_subparsers(dest="cmd")
    for name in ("next", "list"):
        sp = sub.add_parser(name)
        sp.add_argument("--type")
        sp.add_argument("--group")
        sp.add_argument("--size")
        if name == "list":
            sp.add_argument("--status", default="todo")
    sub.add_parser("done").add_argument("id")
    sub.add_parser("validate")
    sub.add_parser("render")
    sub.add_parser("sync")
    args = p.parse_args()
    if args.cmd == "done":
        return cmd_done(args)
    if not args.cmd:
        return p.print_help()
    data = load()
    if args.cmd == "next":
        cmd_next(data, args)
    elif args.cmd == "list":
        cmd_list(data, args)
    elif args.cmd == "validate":
        cmd_validate(data)
    elif args.cmd == "render":
        cmd_render(data)
    elif args.cmd == "sync":
        cmd_validate(data)
        cmd_render(data)


if __name__ == "__main__":
    main()
