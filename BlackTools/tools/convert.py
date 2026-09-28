#!/usr/bin/env python3
"""Brace unbraced [expr ...] calls in BlackTools, verified by tclsh.

Stage 1: scan each file for "[expr " and find the matching "]".
Stage 2: classify: skip anything with braces, backslashes or ${...};
         candidates get a braced form, or an incr form for counters.
Stage 3: verify.tcl checks braced syntax with placeholders and runs old
         vs new with several sets of sample values. Only conversions that
         pass everything are written; everything else is reported.
"""
import json, os, re, subprocess, sys

ROOT = sys.argv[1]
SKIP_DIRS = {"Addons"}           # vendored http.tcl / json.tcl

def files():
    for d, dirs, fs in os.walk(ROOT):
        dirs[:] = [x for x in dirs if x not in SKIP_DIRS and not x.startswith(".")]
        for f in fs:
            if f.endswith(".tcl"):
                yield os.path.join(d, f)

def find_close(s, i):
    """s[i-1] is '['; return index of the matching ']' or -1."""
    depth, inq = 1, False
    while i < len(s):
        c = s[i]
        if c == "\\":
            i += 2; continue
        if c == '"':
            inq = not inq
        elif c == "[":
            depth += 1
        elif c == "]":
            depth -= 1
            if depth == 0:
                return i
        elif c == "\n" and depth == 1 and not inq:
            return -1                # expr args never span lines here
        i += 1
    return -1

def on_comment_line(s, pos):
    line_start = s.rfind("\n", 0, pos) + 1
    return s[line_start:pos].lstrip().startswith("#")

VAR = r"\$(?:::)?[A-Za-z0-9_:]+(?:\([^()\s\[\]]*(?:\$[A-Za-z0-9_:]+[^()\s\[\]]*)*\))?"
INCR = re.compile(r"(?P<pre>\bset\s+)(?P<v>(?:::)?[A-Za-z0-9_:]+(?:\([^()\s]*\))?)\s+\[expr\s+"
                  r"\$(?P=v)\s*(?P<op>[+-])\s*(?P<n>\d+)\s*\]")

def candidates(path):
    s = open(path, encoding="latin-1").read()
    out = []
    for m in re.finditer(r"\[expr(\s+)", s):
        start = m.start()
        if on_comment_line(s, start):
            continue
        end = find_close(s, m.end())
        if end < 0:
            out.append(dict(kind="skip", why="no closing bracket on the line", start=start, end=start + 5, old=s[start:start + 40]))
            continue
        args = s[m.end():end].strip()
        old = s[start:end + 1]
        if args.startswith("{"):
            continue                                    # already braced
        why = None
        if "{" in re.sub(r"\$\{[A-Za-z0-9_:-]+\}", "", args) or "}" in re.sub(r"\$\{[A-Za-z0-9_:-]+\}", "", args):
            why = "contains braces"
        elif "\\" in args: why = "contains backslash"
        elif args.startswith('"') and args.endswith('"') and args.count('"') == 2:
            args = args[1:-1]                           # single quoted word
        elif '"' in args and not re.fullmatch(r'[^"]*("[^"$\[\]]*"[^"]*)*', args):
            why = "complex quoting"
        if why:
            out.append(dict(kind="skip", why=why, start=start, end=end + 1, old=old))
            continue
        out.append(dict(kind="brace", start=start, end=end + 1, old=old, expr=args,
                        new="[expr {" + args + "}]"))
    # counters: "set V [expr $V + N]" -> "incr V N"
    for m in INCR.finditer(s):
        if on_comment_line(s, m.start()):
            continue
        n = m.group("n"); v = m.group("v")
        amount = n if m.group("op") == "+" else "-" + n
        new = m.group("pre").replace("set", "incr", 1) + v + ("" if amount == "1" else " " + amount)
        e0 = s.index("[expr", m.start())
        out = [c for c in out if c["start"] != e0]        # replaces the brace candidate
        out.append(dict(kind="incr", start=m.start(), end=m.end(), old=m.group(0), new=new,
                        var=v, expr=s[e0 + 5:m.end() - 1].strip()))
    return s, sorted(out, key=lambda c: c["start"])

def one_pass():
    report = {"converted": [], "skipped": [], "failed": []}
    todo = []
    for path in sorted(files()):
        s, cands = candidates(path)
        for c in cands:
            c["file"] = os.path.relpath(path, ROOT)
            c["line"] = s.count("\n", 0, c["start"]) + 1
        todo.append((path, s, cands))
    checks = [dict(id=f"{i}:{j}", kind=c["kind"], expr=c["expr"], var=c.get("var"), new=c["new"])
              for i, (_, _, cands) in enumerate(todo) for j, c in enumerate(cands) if c["kind"] != "skip"]
    with open("/tmp/checks.tsv", "w", encoding="latin-1") as f:
        for c in checks:
            assert "\t" not in c["expr"] and "\n" not in c["expr"]
            f.write("\t".join([c["id"], c["kind"], c["var"] or "", c["expr"], c["new"]]) + "\n")
    r = subprocess.run(["tclsh", os.path.join(os.path.dirname(__file__), "verify.tcl"), "/tmp/checks.tsv"],
                       capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit("verify.tcl failed:\n" + r.stderr)
    verdict = dict(line.split("\t", 1) for line in r.stdout.splitlines() if "\t" in line)
    for i, (path, s, cands) in enumerate(todo):
        new_s, last, changed = [], 0, 0
        for j, c in enumerate(cands):
            rec = {k: c[k] for k in ("file", "line", "old")}
            if c["kind"] == "skip":
                report["skipped"].append(dict(rec, why=c["why"])); continue
            v = verdict.get(f"{i}:{j}", "missing")
            if v != "ok":
                report["failed"].append(dict(rec, why=v)); continue
            if c["start"] < last:            # overlapping match; leave for review
                report["failed"].append(dict(rec, why="overlaps another change")); continue
            new_s.append(s[last:c["start"]]); new_s.append(c["new"]); last = c["end"]
            report["converted"].append(dict(rec, new=c["new"], kind=c["kind"])); changed += 1
        new_s.append(s[last:])
        if changed:
            open(path, "w", encoding="latin-1").write("".join(new_s))
    return report

# nested exprs are converted from the outside in, one layer per pass
converted, n = [], 0
while True:
    n += 1
    rep = one_pass()
    converted += rep["converted"]
    print(f"pass {n}: converted {len(rep['converted'])}")
    if not rep["converted"]:
        break
rep["converted"] = converted
json.dump(rep, open("/tmp/report.json", "w"), indent=1)
for k in rep:
    print(f"{k}: {len(rep[k])}")
