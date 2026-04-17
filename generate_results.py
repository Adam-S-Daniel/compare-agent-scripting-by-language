#!/usr/bin/env python3
"""Generate results.md from benchmark metrics.

Can be run standalone to regenerate results.md for any run directory,
or imported by runner.py during benchmark execution.

Usage:
    python3 generate_results.py [results-dir]
    python3 generate_results.py results/2026-04-08_192624
    python3 generate_results.py --all          # regenerate all runs
    python3 generate_results.py --update-readme # update README.md run index
"""

import json
import os
import re
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path

from models import COST_PER_MTOK, MODELS  # noqa: E402  (single source of truth)

INSTRUCTIONS_VERSION = "v4"


def _find_discrepancies(llm_rows: list[dict], tq_lookup: dict) -> list[dict]:
    """Find discrepancies between LLM judge scores and structural metrics.

    Each discrepancy is classified as:
    - "counter-gap": structural metrics are implausibly low (e.g. 0 tests or
      0 assertions despite high LLM scores). Likely a missing pattern in
      test_quality.py — should be investigated and fixed.
    - "qualitative": structural metrics look reasonable but the LLM disagrees
      on quality. The LLM is judging aspects (edge cases, test isolation,
      error paths) that raw counts can't measure. The LLM's summary is
      included as justification.

    Returns list of dicts with keys: task, mode, model, tests, asserts,
    cov, rig, des, ovr, flag, kind, justification.
    """
    discrepancies = []
    for lr in llm_rows:
        key = (lr["task"], lr["mode"], lr["model"])
        sq = tq_lookup.get(key)
        if not sq:
            continue

        tests = sq["tests"]
        asserts = sq["asserts"]
        ratio = sq["ratio"]
        summary = lr.get("summary", "")

        def _add(flag: str, kind: str):
            discrepancies.append({
                "task": lr["task"], "mode": lr["mode"], "model": lr["model"],
                "tests": tests, "asserts": asserts, "ratio": ratio,
                "cov": lr["coverage"], "rig": lr["rigor"],
                "des": lr["design"], "ovr": lr["overall"],
                "flag": flag, "kind": kind,
                "justification": summary if kind == "qualitative" else "",
            })

        # --- Counter-gap signals: structural metrics implausibly low ---

        # High LLM coverage but very few tests
        if lr["coverage"] >= 4 and tests <= 3:
            _add(f"LLM says high coverage ({lr['coverage']}/5) but only {tests} tests detected",
                 "counter-gap" if tests == 0 else "qualitative")

        # High LLM rigor but few assertions
        if lr["rigor"] >= 4 and asserts <= 5:
            _add(f"LLM says high rigor ({lr['rigor']}/5) but only {asserts} assertions detected",
                 "counter-gap" if asserts == 0 else "qualitative")

        # High LLM overall but no tests
        if lr["overall"] >= 4 and tests == 0:
            _add(f"LLM says high overall ({lr['overall']}/5) but 0 tests detected",
                 "counter-gap")

        # High LLM overall but zero assertions per test
        if lr["overall"] >= 4 and tests > 0 and asserts == 0:
            _add(f"LLM says high overall ({lr['overall']}/5) but 0 assertions detected",
                 "counter-gap")

        # High LLM overall but very low assertion density (non-zero)
        if lr["overall"] >= 4 and tests > 0 and 0 < asserts / tests < 0.5:
            _add(f"LLM says high overall ({lr['overall']}/5) but only {asserts/tests:.1f} assertions/test",
                 "qualitative")

        # --- Qualitative signals: metrics look reasonable, LLM disagrees ---

        # Low LLM coverage but many tests
        if lr["coverage"] <= 2 and tests >= 20:
            _add(f"LLM says low coverage ({lr['coverage']}/5) but {tests} tests detected",
                 "qualitative")

        # Low LLM rigor but many assertions
        if lr["rigor"] <= 2 and asserts >= 40:
            _add(f"LLM says low rigor ({lr['rigor']}/5) but {asserts} assertions detected",
                 "qualitative")

        # Low LLM design but high test-to-code ratio
        if lr["design"] <= 2 and ratio >= 2.0:
            _add(f"LLM says poor design ({lr['design']}/5) but test:code ratio is {ratio:.1f}",
                 "qualitative")

    return discrepancies


def _detect_traps(events: list[dict], console: str, metrics: dict) -> list[dict]:
    """Detect time-costly debugging traps from a run's event stream.

    Returns list of {"name": str, "time_s": float, "desc": str} dicts for
    traps that wasted ≥15 seconds.

    ADDING NEW TRAPS
    ================
    When you discover a new recurring pattern that costs agents ≥15 seconds,
    add a numbered block below following the existing pattern:

    1. Give the trap a kebab-case name (e.g. "yaml-indent-errors").
    2. Write detection logic that examines bash_cmds, all_text (agent's
       reasoning), console (tool output), and/or metrics (hook counts, etc.).
    3. Estimate time_s — use the number of wasted commands × a per-command
       cost.  For Bash commands, 15-25s is typical (API turn + execution).
       For act push, use 50s.  For pwsh Pester, use 25-35s.
    4. Call _add(name, time_s, description_string).
    5. If the trap only applies to a specific mode, guard with
       `if mode == "..."`.  Otherwise it is tested on all runs.
    6. If the trap applies to a specific mode, add it to the trap_mode dict
       inside generate_results_md (search for "trap_mode") so the
       "applicable runs" denominator is correct.  Default is "all".

    To find new trap candidates: look at the slowest or highest-error runs
    in results.md, read their console-log.txt for repeated patterns or long
    debugging sequences, then generalise into a detection rule.
    """
    mode = metrics.get("language_mode", "")
    bash_cmds: list[str] = []
    texts: list[str] = []
    for e in events:
        if e.get("type") == "assistant":
            for c in e.get("message", {}).get("content", []):
                if isinstance(c, dict):
                    if c.get("type") == "tool_use" and c.get("name") == "Bash":
                        bash_cmds.append(c.get("input", {}).get("command", ""))
                    elif c.get("type") == "text":
                        texts.append(c.get("text", ""))
    all_text = "\n".join(texts)
    traps: list[dict] = []

    def _add(name, t, desc):
        if t >= 15:
            traps.append({"name": name, "time_s": t, "desc": desc})

    # 1. Pester CmdletBinding parameter binding spiral
    if mode in ("powershell", "powershell-tool"):
        diag = [c for c in bash_cmds if re.search(r"/tmp/test_\w+\.(?:ps1|Tests\.ps1)", c)]
        if len(diag) >= 2:
            _add("pester-cmdletbinding-spiral", len(diag) * 25,
                 f"{len(diag)} /tmp/test_*.ps1 diagnostic scripts bisecting Pester parameter binding")

    # 2. Wrong Pester assertion names
    if mode in ("powershell", "powershell-tool"):
        wrong = [n for n, p in [("BeInRange", r"Should\s+-BeInRange"),
                                 ("BeGreaterOrEqualTo", r"Should\s+-BeGreaterOrEqualTo"),
                                 ("BeLessOrEqualTo", r"Should\s+-BeLessOrEqualTo")]
                 if re.search(p, "\n".join(bash_cmds) + all_text)]
        if wrong and re.search(r"fix|correct|wrong|not.*valid|doesn.t exist", all_text, re.I):
            _add("pester-wrong-assertions", 45, f"Used nonexistent assertions: {', '.join(wrong)}")

    # 3. Docker PowerShell install exploration
    if mode in ("powershell", "powershell-tool"):
        dp = [c for c in bash_cmds if re.search(r"docker\s+run.*(?:powershell|pwsh|microsoft-prod)", c, re.I)]
        if len(dp) >= 2:
            _add("docker-pwsh-install", len(dp) * 45, f"{len(dp)} Docker runs exploring pwsh install")

    # 4. Module restructure mid-run
    if mode in ("powershell", "powershell-tool"):
        if (re.search(r"restructur|separate.*into.*module|\.psm1.*fix", all_text, re.I)
                and any(".psm1" in c for c in bash_cmds)):
            _add("mid-run-module-restructure", 120, "Restructured to .psm1 module mid-run")

    # 5. act push debug loops (>2 invocations)
    act_pushes = [c for c in bash_cmds if re.search(r"\bact\s+push", c)]
    if len(act_pushes) > 2:
        extra = len(act_pushes) - 2
        act_times = [t["duration_ms"] for t in metrics.get("tool_use_timing", {}).get("slowest_tool_uses", [])
                     if re.search(r"\bact\s+push", t.get("command", ""))]
        t = extra * (sum(act_times) / len(act_times) / 1000 if act_times else 50)
        _add("act-push-debug-loops", t, f"{len(act_pushes)} act push invocations ({extra} extra)")

    # 6. TypeScript type error fix cycles
    if mode == "typescript-bun":
        he = metrics.get("hooks", {}).get("hook_errors_caught", 0)
        if he >= 2:
            _add("ts-type-error-fix-cycles", he * 12, f"{he} type errors caught by hooks")

    # 7. Docker package install exploration (non-pwsh)
    dpkg = [c for c in bash_cmds if re.search(r"docker\s+run.*(?:pip\s+install|apt-get\s+install)", c, re.I)
            and not re.search(r"powershell|pwsh", c, re.I)]
    if len(dpkg) >= 2:
        _add("docker-pkg-install", len(dpkg) * 30, f"{len(dpkg)} Docker runs exploring package install")

    # 8. bats-core setup confusion
    if mode == "bash":
        bs = [c for c in bash_cmds if re.search(r"which bats|npm.*bats|install.*bats|load.*test_helper", c, re.I)]
        be = len(re.findall(r"bats.*not found|load.*error|helper.*not|cannot.*load", console, re.I))
        if len(bs) >= 3 and be >= 1:
            _add("bats-setup-issues", len(bs) * 15, f"{len(bs)} commands debugging bats setup")

    # 9. Fixture rework
    # Use word-boundary patterns to avoid matching filenames like "test_database"
    fc = [c for c in bash_cmds if re.search(
        r"fixture|sample[_\-\s]data|mock[_\-\s]data|test[_\-\s]data\b", c, re.I)]
    if len(fc) >= 4:
        _add("fixture-rework", (len(fc) - 2) * 15, f"{len(fc)} commands creating/fixing fixtures")

    # 10. Repeated identical test reruns
    cmd_cnt: dict[str, int] = {}
    for c in bash_cmds:
        if re.search(r"pytest|Invoke-Pester|bun\s+test|bats\s+|dotnet\s+test|unittest\b", c):
            key = re.sub(r"\s+2>&1.*|\s+\|.*", "", c)[:80]
            cmd_cnt[key] = cmd_cnt.get(key, 0) + 1
    for cmd, count in cmd_cnt.items():
        if count >= 4:
            _add("repeated-test-reruns", (count - 2) * 20, f"Same test run {count} times")

    # 11. actionlint fix cycles
    ar = [c for c in bash_cmds if "actionlint" in c]
    af = len(re.findall(r"actionlint.*error", console, re.I))
    if len(ar) >= 3 and af >= 2:
        _add("actionlint-fix-cycles", af * 20, f"{len(ar)} actionlint runs, {af} failures")

    # 12. Permission/path errors in act container
    # Only check when act was actually used in this run
    used_act = any(re.search(r"\bact\s+(push|run|pull)\b", c) for c in bash_cmds)
    if used_act:
        # Look for errors that specifically indicate act container issues, not general chmod/ENOENT
        pe = len(re.findall(
            r"Permission denied.*/home/runner|ENOENT.*/home/runner|"
            r"chmod\s+\+x.*&&.*act\b|"
            r"\bact\b.*not found|No such file.*\.github/workflows",
            console, re.I))
        if pe >= 2:
            _add("act-permission-path-errors", pe * 15, f"{pe} permission/path errors in act container")

    # 13. act fixture path issues
    if used_act and (re.search(r"Config file not found|fixture.*not found|No such file.*fixture", console, re.I)
            and re.search(r"fixture.*path|copy.*fixture|missing.*fixture", all_text, re.I)):
        _add("act-fixture-paths", 60, "Fixtures not found inside act Docker container")

    # 14. Permission denial retry loops (v1 harness issue — sandbox blocked commands)
    denial_count = len(re.findall(
        r"\[Result ERROR\].*(?:requires approval|haven't granted it yet|was blocked)", console))
    if denial_count >= 5:
        _add("permission-denial-loops", denial_count * 10,
             f"{denial_count} commands blocked by CLI sandbox (permission denials)")

    # 15. Dotnet SDK install loop (csharp-script agents stuck installing .NET)
    if mode == "csharp-script":
        dotnet_cmds = [c for c in bash_cmds if re.search(
            r"dotnet-install|dot\.net/v1|Install-DotNet|dotnet\s+--version", c, re.I)]
        dotnet_denials = len(re.findall(
            r"dotnet.*requires approval|dotnet.*Permission denied", console, re.I))
        total = len(dotnet_cmds) + dotnet_denials
        if total >= 5:
            _add("dotnet-install-loop", total * 12,
                 f"{total} attempts to install/verify .NET SDK")

    # 16. PowerShell invoked from bash instead of shell: pwsh
    # When agents use `pwsh -Command "..."` or `pwsh -File` inside bash run: steps,
    # they can hit: (a) bash parser errors from PS syntax (e.g. @'...'@ heredocs),
    # (b) variable/quoting issues passing structured data through bash to pwsh,
    # (c) scope/invocation issues requiring diagnostic scripts.
    # shell: pwsh works fine in act containers (act translates to docker exec pwsh),
    # but agents that invoke pwsh from bash waste time on cross-shell debugging.
    if mode in ("powershell", "powershell-tool"):
        # Signal 1: /tmp/scope_test*.ps1 diagnostic scripts (bisecting pwsh invocation)
        scope_scripts = [c for c in bash_cmds if re.search(
            r"/tmp/scope_test\d*\.ps1|/tmp/pwsh_debug\d*\.ps1", c)]
        # Signal 2: bash parser errors from PS syntax inside bash
        ps_in_bash_errors = len(re.findall(
            r"Unrecognized token in source text", console))
        # Signal 3: pwsh command not found inside act container (late discovery)
        pwsh_not_found_act = len(re.findall(
            r"line \d+: pwsh: command not found|"
            r"exec:.*pwsh.*executable file not found",
            console, re.I))
        # Signal 4: agent reasoning about quoting/escaping between bash and pwsh
        quoting_issues = len(re.findall(
            r"(?:quot|escap).*(?:bash.*pwsh|pwsh.*bash|variable.*pass)|"
            r"output isn.t visible.*(?:pwsh|PowerShell|JSON)|"
            r"(?:pwsh|PowerShell).*(?:quoting|embedded quotes)",
            all_text, re.I))
        # Signal 5: pwsh -Command invocations used as diagnostic probes (not normal script runs)
        pwsh_diag = [c for c in bash_cmds if re.search(
            r"pwsh\s+-Command.*(?:MyInvocation|ScriptName|InvocationName|Write-Host.*test|scope|param\b)",
            c, re.I)]
        total_signals = (len(scope_scripts) + ps_in_bash_errors + pwsh_not_found_act
                         + (1 if quoting_issues >= 1 else 0) + len(pwsh_diag))
        if total_signals >= 2:
            parts = []
            if scope_scripts:
                parts.append(f"{len(scope_scripts)} scope-test scripts")
            if ps_in_bash_errors:
                parts.append(f"{ps_in_bash_errors} bash parser errors from PS syntax")
            if pwsh_not_found_act:
                parts.append(f"{pwsh_not_found_act} pwsh-not-found in act")
            if quoting_issues:
                parts.append(f"{quoting_issues} quoting issue mentions")
            if pwsh_diag:
                parts.append(f"{len(pwsh_diag)} diagnostic pwsh probes")
            # Time estimate: scope scripts ~25s each (write + run + analyze),
            # parse errors ~30s each (error + investigate + fix),
            # not-found ~45s (act run + error + workflow rewrite),
            # quoting ~60s (investigate + rewrite workflow),
            # diagnostic probes ~20s each
            t = (len(scope_scripts) * 25 + ps_in_bash_errors * 30
                 + pwsh_not_found_act * 45 + quoting_issues * 60
                 + len(pwsh_diag) * 20)
            _add("pwsh-invoked-from-bash", t, "; ".join(parts))

    return traps



def _categorize_tool_time(tool_uses: list[dict]) -> dict:
    """Categorize Bash tool use durations into install, test, and act buckets."""
    install_ms = 0
    test_ms = 0
    act_ms = 0
    install_patterns = [
        r"docker\s+run.*(?:install|apt-get|wget|dpkg|curl.*download)",
        r"apt-get\s+(?:update|install)",
        r"pip3?\s+install",
        r"npm\s+install",
        r"Install-Module",
        r"dotnet\s+tool\s+install",
    ]
    test_patterns = [
        r"Invoke-Pester",
        r"pytest|python3?\s+-m\s+pytest",
        r"\bbats\b",
        r"bun\s+test",
        r"bun\s+run\s+\S*test",       # bun run run-act-tests.ts, etc.
        r"pwsh\s+.*Tests?\.ps1",
        r"run[-_](?:act[-_])?tests",   # run-tests, run_tests, run-act-tests
        r"test_harness",
        r"python3?\s+\S*test\S*\.py",  # python3 test_foo.py, python3 run_tests.py
        r"bash\s+\S*test\S*\.sh",      # bash run-act-tests.sh, bash test_foo.sh
        r"pwsh\s+\S*[Tt]est\S*\.ps1",  # pwsh Run-Tests.ps1, pwsh Test-Workflow.ps1
    ]
    act_patterns = [
        r"\bact\s+(?:push|pull_request)",
    ]
    for t in tool_uses:
        if t.get("tool_name") != "Bash":
            continue
        cmd = t.get("command", "")
        dur = t["duration_ms"]
        if any(re.search(p, cmd, re.IGNORECASE) for p in act_patterns):
            act_ms += dur
        elif any(re.search(p, cmd, re.IGNORECASE) for p in test_patterns):
            test_ms += dur
        elif any(re.search(p, cmd, re.IGNORECASE) for p in install_patterns):
            install_ms += dur
    return {
        "install_duration_ms": install_ms,
        "test_duration_ms": test_ms,
        "act_duration_ms": act_ms,
    }



def _collapsible_table(summary: str, header: str, separator: str, rows: list[str]) -> list[str]:
    """Wrap a markdown table in a <details> block."""
    out = ["", "<details>", f"<summary>{summary}</summary>", ""]
    out.append(header)
    out.append(separator)
    out.extend(rows)
    out.append("")
    out.append("</details>")
    return out


def _rank(values):
    """Assign ranks to values (average rank for ties)."""
    indexed = sorted(enumerate(values), key=lambda x: x[1])
    ranks = [0.0] * len(values)
    i = 0
    while i < len(indexed):
        j = i
        while j < len(indexed) and indexed[j][1] == indexed[i][1]:
            j += 1
        avg_rank = (i + j + 1) / 2  # 1-based average rank
        for k in range(i, j):
            ranks[indexed[k][0]] = avg_rank
        i = j
    return ranks


def _spearman(xs, ys):
    """Compute Spearman rank correlation coefficient."""
    if len(xs) < 3:
        return None
    rx, ry = _rank(xs), _rank(ys)
    n = len(xs)
    mean_rx = sum(rx) / n
    mean_ry = sum(ry) / n
    num = sum((a - mean_rx) * (b - mean_ry) for a, b in zip(rx, ry))
    den_x = sum((a - mean_rx) ** 2 for a in rx) ** 0.5
    den_y = sum((b - mean_ry) ** 2 for b in ry) ** 0.5
    if den_x == 0 or den_y == 0:
        return None
    return round(num / (den_x * den_y), 2)



def _emit_sorted_variants(header: str, separator: str, data_rows: list[dict],
                           sort_specs: list[tuple[str, str, bool]],
                           row_formatter) -> list[str]:
    """Emit multiple collapsed copies of a table, each sorted differently.

    sort_specs: list of (summary_label, sort_key, reverse).
    row_formatter: callable(row_dict) -> markdown row string.
    """
    out: list[str] = []
    for label, key, reverse in sort_specs:
        sorted_rows = sorted(data_rows, key=lambda r: (r.get(key, 0) if isinstance(r.get(key, 0), (int, float)) else str(r.get(key, ""))), reverse=reverse)
        row_strs = [row_formatter(r) for r in sorted_rows]
        out.extend(_collapsible_table(label, header, separator, row_strs))
    return out



def generate_results_md(run_dir, all_metrics, total_runs, run_count):
    """Generate/update a results.md file with tables, commentary, and status."""
    from zoneinfo import ZoneInfo
    from pathlib import Path
    import json, re
    from collections import defaultdict

    et = ZoneInfo("America/New_York")
    now_et = datetime.now(et).strftime("%Y-%m-%d %I:%M:%S %p ET")

    completed = len(all_metrics)
    remaining = total_runs - run_count

    total_cost = sum(m["cost"]["total_cost_usd"] for m in all_metrics)
    total_duration = sum(m["timing"]["grand_total_duration_ms"] for m in all_metrics) / 1000

    lines = []
    lines.append("# Benchmark Results: Language Mode Comparison")
    lines.append("")
    lines.append(f"**Last updated:** {now_et}")
    lines.append("")
    lines.append(f"**Status:** {completed}/{total_runs} runs completed, {remaining} remaining")
    lines.append(f"**Total cost so far:** ${total_cost:.2f}")
    lines.append(f"**Total agent time so far:** {total_duration/60:.1f} min")
    lines.append("")

    if not all_metrics:
        lines.append("*No completed runs yet.*")
        (run_dir / "results.md").write_text("\n".join(lines))
        return

    # Separate successful and failed runs
    successful = [m for m in all_metrics if m.get("run_success", m.get("exit_code", 0) == 0 and m.get("timing", {}).get("num_turns", 0) > 0)]
    failed = [m for m in all_metrics if m not in successful]

    def _label(m):
        """Variant label used for grouping and display in tables. Encodes
        effort into the model short (e.g. `opus47-1m-xhigh`) so one results
        dir can hold multiple effort levels without collision. Pre-effort
        runs (effort_level None) fall back to plain model_short."""
        eff = m.get("effort_level")
        return f"{m['model_short']}-{eff}" if eff else m["model_short"]

    modes_seen = sorted(set(m["language_mode"] for m in all_metrics))
    models_seen = sorted(set(_label(m) for m in all_metrics))
    # Map variant label -> plain model_short for pricing lookups (keyed by
    # COST_PER_MTOK, which indexes on model_short only).
    _label_to_model_short = {_label(m): m["model_short"] for m in all_metrics}

    # ── Helper: format duration as minutes ──
    def _dur(seconds):
        return f"{seconds/60:.1f}min"

    # ==================================================================
    # COLLECT ALL ANALYSIS DATA UP FRONT
    # ==================================================================

    # ── Comparison by Language/Model ──
    cmp_rows = []
    for mode in modes_seen:
        for model in models_seen:
            mm = [m for m in successful if m["language_mode"] == mode and _label(m) == model]
            n = len(mm)
            if n == 0:
                continue
            cmp_rows.append({
                "mode": mode, "model": model, "n": n,
                "avg_dur": sum(m["timing"]["grand_total_duration_ms"] for m in mm) / n / 1000,
                "avg_lines": sum(m["code_metrics"]["total_lines"] for m in mm) / n,
                "avg_errors": sum(m["quality"]["error_count"] for m in mm) / n,
                "avg_turns": sum(m["timing"]["num_turns"] for m in mm) / n,
                "avg_cost": sum(m["cost"]["total_cost_usd"] for m in mm) / n,
                "total_cost": sum(m["cost"]["total_cost_usd"] for m in mm),
            })

    # ── Trap & Hook data ──
    TEST_RUN_COST_S = {"default": 8, "powershell": 35, "powershell-tool": 35, "bash": 12, "typescript-bun": 8}
    # Compute per-(mode, model) hook overhead from actual Write/Edit durations.
    # Use all_tool_uses when available (full list), fall back to slowest_tool_uses.
    # Subtract 0.05s baseline for the Write operation itself.
    _write_durs_by_combo: dict[tuple, list] = {}
    for m in all_metrics:
        combo = (m["language_mode"], _label(m))
        source = m.get("tool_use_timing", {}).get("all_tool_uses") or m.get("tool_use_timing", {}).get("slowest_tool_uses", [])
        for t in source:
            if t["tool_name"] in ("Write", "Edit"):
                _write_durs_by_combo.setdefault(combo, []).append(t["duration_ms"] / 1000)
    HOOK_OVERHEAD_BY_COMBO = {
        combo: max(0, (sum(ds) / len(ds)) - 0.05) if ds else 0.5
        for combo, ds in _write_durs_by_combo.items()
    }

    trap_instances = []
    hook_by_combo = {}
    combo_run_counts = {}

    for m in all_metrics:
        mode, model = m["language_mode"], _label(m)
        combo = (mode, model)
        combo_run_counts[combo] = combo_run_counts.get(combo, 0) + 1

        cli_path = run_dir / "tasks" / m["task_id"] / f"{mode}-{model}" / "cli-output.json"
        console_path = run_dir / "tasks" / m["task_id"] / f"{mode}-{model}" / "console-log.txt"
        try:
            evts = json.loads(cli_path.read_text())
        except Exception:
            evts = []
        console_text = console_path.read_text() if console_path.exists() else ""

        for trap in _detect_traps(evts, console_text, m):
            trap_instances.append({
                "mode": mode, "model": model, "task_id": m["task_id"],
                "task_name": m["task_name"],
                "dur_s": m["timing"]["grand_total_duration_ms"] / 1000,
                "cost": m["cost"]["total_cost_usd"],
                **trap,
            })

        # Trap: PowerShell runtime install overhead (pwsh + Pester pre-installed on
        # real GitHub runners but must be installed in act containers every run).
        # Primary source: act-result.txt step timings.  Fallback: event stream.
        if mode in ("powershell", "powershell-tool"):
            act_result_path = (run_dir / "tasks" / m["task_id"]
                               / f"{mode}-{model}" / "generated-code" / "act-result.txt")
            act_text = act_result_path.read_text() if act_result_path.exists() else ""
            # Primary: parse exact step durations from act output
            pwsh_times = [float(x) for x in re.findall(
                r"Install PowerShell \[(\d+\.?\d*)s\]", act_text)]
            pester_times = [float(x) for x in re.findall(
                r"Install Pester \[(\d+\.?\d*)s\]", act_text)]
            # Fallback: if act-result.txt had no timings, check event stream
            if not pwsh_times and not pester_times:
                for ev in evts:
                    if not isinstance(ev, dict) or ev.get("type") != "user":
                        continue
                    for c in (ev.get("message", {}).get("content", []) or []):
                        if isinstance(c, dict) and c.get("type") == "tool_result":
                            txt = str(c.get("content", ""))
                            pwsh_times.extend(float(x) for x in re.findall(
                                r"Install PowerShell \[(\d+\.?\d*)s\]", txt))
                            pester_times.extend(float(x) for x in re.findall(
                                r"Install Pester \[(\d+\.?\d*)s\]", txt))
            pwsh_secs = sum(pwsh_times)
            pester_secs = sum(pester_times)
            total_overhead = pwsh_secs + pester_secs
            if total_overhead >= 15:
                parts = []
                if pwsh_times:
                    parts.append(f"{len(pwsh_times)} pwsh installs ({pwsh_secs:.0f}s)")
                if pester_times:
                    parts.append(f"{len(pester_times)} Pester installs ({pester_secs:.0f}s)")
                trap_instances.append({
                    "mode": mode, "model": model, "task_id": m["task_id"],
                    "task_name": m["task_name"],
                    "dur_s": m["timing"]["grand_total_duration_ms"] / 1000,
                    "cost": m["cost"]["total_cost_usd"],
                    "name": "pwsh-runtime-install-overhead",
                    "time_s": total_overhead,
                    "desc": "; ".join(parts),
                })

        caught = m.get("hooks", {}).get("hook_errors_caught", 0)
        fires = m.get("hooks", {}).get("hook_fires", 0)
        gross_saved = caught * TEST_RUN_COST_S.get(mode, 10)
        overhead = fires * HOOK_OVERHEAD_BY_COMBO.get(combo, 0.5)
        # Only include test time if we have real durations from all_tool_uses.
        # Older runs that only have top-5/10 slowest_tool_uses produce a lower
        # bound that's misleading — omit rather than show bad data.
        all_uses = m.get("tool_use_timing", {}).get("all_tool_uses", [])
        has_real_test_time = bool(all_uses)
        test_time = _categorize_tool_time(all_uses)["test_duration_ms"] / 1000 if all_uses else 0
        if combo not in hook_by_combo:
            hook_by_combo[combo] = {"fires": 0, "caught": 0, "gross_saved": 0, "overhead": 0,
                                     "test_time": 0, "has_real_test_time": True}
        hook_by_combo[combo]["fires"] += fires
        hook_by_combo[combo]["caught"] += caught
        hook_by_combo[combo]["gross_saved"] += gross_saved
        hook_by_combo[combo]["overhead"] += overhead
        if has_real_test_time:
            hook_by_combo[combo]["test_time"] += test_time
        else:
            hook_by_combo[combo]["has_real_test_time"] = False

    # ── Aggregate trap time/cost by (mode, model) for net-of-traps columns ──
    trap_time_by_combo: dict[tuple, float] = defaultdict(float)
    trap_cost_by_combo: dict[tuple, float] = defaultdict(float)
    for t in trap_instances:
        combo = (t["mode"], t["model"])
        trap_time_by_combo[combo] += t["time_s"]
        # Estimate cost proportional to time fraction of the run
        if t["dur_s"] > 0 and t["cost"] > 0:
            trap_cost_by_combo[combo] += t["time_s"] / t["dur_s"] * t["cost"]

    for r in cmp_rows:
        combo = (r["mode"], r["model"])
        n = r["n"]
        r["avg_trap_dur"] = trap_time_by_combo.get(combo, 0) / n
        r["avg_dur_net"] = r["avg_dur"] - r["avg_trap_dur"]

    # ── Prompt cache data ──
    cache_data = []
    cache_read_rates = {s: COST_PER_MTOK[mid]["cache_read"] for s, mid in MODELS.items() if mid in COST_PER_MTOK}
    cache_create_rates = {s: COST_PER_MTOK[mid]["cache_write"] for s, mid in MODELS.items() if mid in COST_PER_MTOK}
    for m in all_metrics:
        cli_path = run_dir / "tasks" / m["task_id"] / f"{m['language_mode']}-{_label(m)}" / "cli-output.json"
        if not cli_path.exists():
            continue
        try:
            evts = json.loads(cli_path.read_text())
        except Exception:
            continue
        for e in evts:
            if e.get("type") == "assistant":
                usage = e.get("message", {}).get("usage", {})
                cr = usage.get("cache_read_input_tokens", 0)
                cc = usage.get("cache_creation_input_tokens", 0)
                # Pricing lookup uses plain model_short; display label includes effort.
                ms_price = m["model_short"]
                ms_label = _label(m)
                saved = cr * (cache_create_rates.get(ms_price, 0) - cache_read_rates.get(ms_price, 0)) / 1_000_000 if cr else 0
                status = "full_hit" if cr > 0 and cc == 0 else "partial" if cr > 0 else "miss"
                cache_data.append({"mode": m["language_mode"], "model": ms_label, "saved": saved, "status": status})
                break

    # ==================================================================
    # OBSERVATIONS (at top of document)
    # ==================================================================
    if len(successful) >= 2 and len(cmp_rows) >= 2:
        lines.append("## Observations")
        lines.append("")

        def _fmt_combo(r, field, fmt="dur"):
            label = f"{r['mode']}/{r['model']}"
            if fmt == "dur":
                return f"{label} — {_dur(r[field])}"
            return f"{label} — ${r[field]:.2f}"

        by_dur = sorted(cmp_rows, key=lambda r: r["avg_dur"])
        by_cost = sorted(cmp_rows, key=lambda r: r["avg_cost"])

        lines.append(f"- **Fastest (avg):** {_fmt_combo(by_dur[0], 'avg_dur')}, then {_fmt_combo(by_dur[1], 'avg_dur')}")
        lines.append(f"- **Slowest (avg):** {_fmt_combo(by_dur[-1], 'avg_dur')}, then {_fmt_combo(by_dur[-2], 'avg_dur')}")
        lines.append(f"- **Cheapest (avg):** {_fmt_combo(by_cost[0], 'avg_cost', 'cost')}, then {_fmt_combo(by_cost[1], 'avg_cost', 'cost')}")
        lines.append(f"- **Most expensive (avg):** {_fmt_combo(by_cost[-1], 'avg_cost', 'cost')}, then {_fmt_combo(by_cost[-2], 'avg_cost', 'cost')}")
        lines.append("")

        if completed < total_runs and total_duration > 0 and completed > 0:
            est_remaining_s = (total_duration / completed) * (total_runs - run_count)
            lines.append(f"- **Estimated time remaining:** {_dur(est_remaining_s)}")
            est_total_cost = (total_cost / completed) * total_runs
            lines.append(f"- **Estimated total cost:** ${est_total_cost:.2f}")
            lines.append("")

    # ── Failed runs (if any) ──
    if failed:
        lines.append("## Failed / Timed-Out Runs")
        lines.append("")
        lines.append("| Task | Mode | Model | Duration | Reason | Lines | actionlint | act-result.txt |")
        lines.append("|------|------|-------|----------|--------|-------|------------|----------------|")
        for m in failed:
            dur = m["timing"]["grand_total_duration_ms"] / 1000
            reason = m.get("failure_reason", "exit_code=" + str(m.get("exit_code", "?")))
            alint_val = m.get("quality", {}).get("actionlint_pass")
            alint = "pass" if alint_val else ("fail" if alint_val is False else "n/a")
            act = "yes" if m.get("quality", {}).get("act_result_txt_exists") else "no"
            lines.append(
                f"| {m['task_name'][:30]} | {m['language_mode']} | {_label(m)} "
                f"| {_dur(dur)} | {reason} | {m['code_metrics']['total_lines']} | {alint} | {act} |")
        lines.append("")
        lines.append(f"*{len(failed)} run(s) excluded from averages below.*")
        lines.append("")

    # ==================================================================
    # COMPARISON BY LANGUAGE/MODEL
    # ==================================================================
    if cmp_rows:
        lines.append("## Comparison by Language/Model")
        if failed:
            lines.append("*(averages exclude failed/timed-out runs)*")
        lines.append("")
        cmp_hdr = "| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |"
        cmp_sep = "|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|"
        def _fmt_cmp(r):
            return (f"| {r['mode']} | {r['model']} | {r['n']} | {_dur(r['avg_dur'])} | {_dur(r['avg_dur_net'])} "
                    f"| {r['avg_errors']:.1f} | {r['avg_turns']:.0f} | ${r['avg_cost']:.2f} | ${r['total_cost']:.2f} |")
        lines.append(cmp_hdr)
        lines.append(cmp_sep)
        for r in cmp_rows:
            lines.append(_fmt_cmp(r))
        lines.append("")
        lines.extend(_emit_sorted_variants(cmp_hdr, cmp_sep, cmp_rows, [
            ("Sorted by avg cost (cheapest first)", "avg_cost", False),
            ("Sorted by avg duration (fastest first)", "avg_dur", False),
            ("Sorted by avg duration net of traps (fastest first)", "avg_dur_net", False),
            ("Sorted by avg errors (fewest first)", "avg_errors", False),
            ("Sorted by avg turns (fewest first)", "avg_turns", False),
        ], _fmt_cmp))
        lines.append("")

    # ==================================================================
    # SAVINGS ANALYSIS
    # ==================================================================
    lines.append("## Savings Analysis")
    lines.append("")

    # ── Hook Savings by Language/Model ──
    lines.append("### Hook Savings by Language/Model")
    lines.append("")
    lines.append("Each hook-caught error avoids one test run that would otherwise have been needed to discover it.")
    lines.append("Every hook fire (hit or miss) costs execution time for the syntax/type checker.")
    lines.append("")

    # Determine if we have real test time data (all_tool_uses with durations)
    has_test_time = all(hs.get("has_real_test_time", False) for hs in hook_by_combo.values() if hs.get("fires", 0) > 0)

    if has_test_time:
        hook_hdr = ("| Mode | Model | Fires | Caught | Rate "
                    "| Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time "
                    "| Test Run Time | % of Test Time Saved |")
        hook_sep = ("|------|-------|-------|--------|------"
                    "|------------|-----------|----------|-----------|-----------|-----------|"
                    "---------------|----------------------|")
    else:
        hook_hdr = ("| Mode | Model | Fires | Caught | Rate "
                    "| Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time |")
        hook_sep = ("|------|-------|-------|--------|------"
                    "|------------|-----------|----------|-----------|-----------|-----------|")

    hook_rows = []
    for mode in modes_seen:
        for model in models_seen:
            hs = hook_by_combo.get((mode, model), {})
            f_count = hs.get("fires", 0)
            c_count = hs.get("caught", 0)
            if f_count == 0:
                continue
            gross = hs["gross_saved"]
            overhead = hs["overhead"]
            net = gross - overhead
            test_t = hs.get("test_time", 0)
            hook_rows.append({
                "mode": mode, "model": model, "fires": f_count, "caught": c_count,
                "rate": c_count / f_count * 100,
                "gross": gross, "gross_pct": gross / total_duration * 100 if total_duration else 0,
                "overhead": overhead, "overhead_pct": overhead / total_duration * 100 if total_duration else 0,
                "net": net, "net_pct": net / total_duration * 100 if total_duration else 0,
                "test_time": test_t, "test_time_pct": net / test_t * 100 if test_t else 0,
            })

    def _fmt_hook(r):
        base = (f"| {r['mode']} | {r['model']} | {r['fires']} | {r['caught']} | {r['rate']:.1f}% "
                f"| {_dur(r['gross'])} | {r['gross_pct']:.1f}% "
                f"| {_dur(r['overhead'])} | {r['overhead_pct']:.1f}% "
                f"| {_dur(r['net'])} | {r['net_pct']:.1f}%")
        if has_test_time:
            return base + f" | {_dur(r['test_time'])} | {r['test_time_pct']:.1f}% |"
        return base + " |"

    lines.append(hook_hdr)
    lines.append(hook_sep)
    for r in hook_rows:
        lines.append(_fmt_hook(r))
    lines.append("")

    sort_specs = [
        ("Sorted by net saved (most first)", "net", True),
        ("Sorted by catch rate (highest first)", "rate", True),
    ]
    if has_test_time:
        sort_specs.insert(1, ("Sorted by net % of test time saved (most first)", "test_time_pct", True))
    lines.extend(_emit_sorted_variants(hook_hdr, hook_sep, hook_rows, sort_specs, _fmt_hook))
    lines.append("")

    # ── Trap Analysis by Language/Model/Category ──
    if trap_instances:
        # Each value is a tuple of modes the trap applies to. A trap that can
        # fire in any PowerShell variant uses the full PS family so its
        # catch-rate denominator counts runs of both `powershell` and
        # `powershell-tool` modes.
        PS_FAMILY = ("powershell", "powershell-tool")
        trap_applicable_mode = {
            "pester-cmdletbinding-spiral": PS_FAMILY,
            "pester-wrong-assertions": PS_FAMILY,
            "docker-pwsh-install": PS_FAMILY,
            "mid-run-module-restructure": PS_FAMILY,
            "ts-type-error-fix-cycles": ("typescript-bun",),
            "bats-setup-issues": ("bash",),
            "dotnet-install-loop": ("csharp-script",),
            "pwsh-invoked-from-bash": PS_FAMILY,
            "pwsh-runtime-install-overhead": PS_FAMILY,
        }
        trap_descriptions = {
            "act-push-debug-loops": "Agent ran `act push` more than twice, indicating repeated workflow debugging.",
            "ts-type-error-fix-cycles": "TypeScript type errors caught by `tsc --noEmit` hooks; each requires a fix cycle.",
            "fixture-rework": "Agent wrote, broke, and rewrote test fixture data (4+ fixture-related commands).",
            "repeated-test-reruns": "Same test command executed 4+ times without the underlying code changing.",
            "docker-pwsh-install": "Multiple Docker test runs trying to figure out how to install PowerShell in act's container.",
            "act-permission-path-errors": "Files not found or permission denied inside the act Docker container.",
            "docker-pkg-install": "Multiple Docker test runs exploring non-PowerShell package installation for act.",
            "actionlint-fix-cycles": "Workflow YAML required 3+ actionlint runs and 2+ fixes to pass.",
            "pester-cmdletbinding-spiral": "Agent wrote many /tmp/test_*.ps1 scripts to bisect a Pester parameter binding conflict.",
            "pester-wrong-assertions": "Agent used nonexistent Pester assertion names (e.g. BeInRange).",
            "mid-run-module-restructure": "Agent restructured from a flat .ps1 script to a .psm1 module mid-run.",
            "bats-setup-issues": "Agent struggled with bats-core test framework setup or load helpers.",
            "act-fixture-paths": "Test fixtures not found inside the act Docker container due to path issues.",
            "permission-denial-loops": "CLI sandbox blocked commands and agent retried instead of adapting (v1 harness issue).",
            "dotnet-install-loop": "Agent stuck in loop trying to install/verify .NET SDK, blocked by CLI sandbox.",
            "pwsh-invoked-from-bash": "Agent used `pwsh -Command`/`-File` from bash `run:` steps instead of `shell: pwsh`, causing cross-shell debugging (parse errors, quoting issues, scope problems, late pwsh discovery in act).",
            "pwsh-runtime-install-overhead": "Time spent installing PowerShell and Pester inside act containers. Both are pre-installed on real GitHub runners but must be downloaded (~56MB) and installed in each act job. Measured from act step durations.",
        }

        trap_agg = defaultdict(list)
        for t in trap_instances:
            trap_agg[t["name"]].append(t)
        mode_run_totals = {md: sum(1 for m in all_metrics if m["language_mode"] == md) for md in modes_seen}

        # Build rows: one per (trap, mode, model) combo that actually occurred
        tlmc_rows = []
        for trap_name in sorted(trap_agg, key=lambda k: -sum(t["time_s"] for t in trap_agg[k])):
            insts = trap_agg[trap_name]
            tmodes = trap_applicable_mode.get(trap_name)  # tuple or None (=all)
            if tmodes is None:
                n_app = completed
            else:
                n_app = sum(mode_run_totals.get(m, 0) for m in tmodes)
            n_fell = len(insts)
            t_time = sum(t["time_s"] for t in insts)
            t_cost = sum(t["time_s"] / t["dur_s"] * t["cost"] for t in insts if t["dur_s"] > 0 and t["cost"] > 0)
            rate = n_fell / n_app * 100 if n_app else 0

            # Break down by mode/model
            by_combo = defaultdict(list)
            for t in insts:
                by_combo[(t["mode"], t["model"])].append(t)

            for (tmode_k, tmodel_k), combo_insts in sorted(by_combo.items()):
                combo_time = sum(t["time_s"] for t in combo_insts)
                combo_cost = sum(t["time_s"] / t["dur_s"] * t["cost"] for t in combo_insts if t["dur_s"] > 0 and t["cost"] > 0)
                tlmc_rows.append({
                    "trap": trap_name, "mode": tmode_k, "model": tmodel_k,
                    "fell_in": len(combo_insts), "applicable": n_app, "rate": rate,
                    "time_lost": combo_time,
                    "time_pct": combo_time / total_duration * 100 if total_duration else 0,
                    "cost_lost": combo_cost,
                    "cost_pct": combo_cost / total_cost * 100 if total_cost else 0,
                })

        lines.append("### Trap Analysis by Language/Model/Category")
        lines.append("")
        tlmc_hdr = "| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |"
        tlmc_sep = "|------|------|-------|---------|-----------|-----------|--------|--------|"
        def _fmt_tlmc(r):
            return (f"| {r['trap']} | {r['mode']} | {r['model']} | {r['fell_in']} "
                    f"| {_dur(r['time_lost'])} | {r['time_pct']:.1f}% | ${r['cost_lost']:.2f} | {r['cost_pct']:.2f}% |")
        lines.append(tlmc_hdr)
        lines.append(tlmc_sep)
        for r in tlmc_rows:
            lines.append(_fmt_tlmc(r))
        total_trap_time = sum(t["time_s"] for t in trap_instances)
        total_trap_cost = sum(t["time_s"] / t["dur_s"] * t["cost"] for t in trap_instances if t["dur_s"] > 0 and t["cost"] > 0)
        total_trapped = len(set((t["task_id"], t["mode"], t["model"]) for t in trap_instances))
        lines.append("")
        lines.extend(_emit_sorted_variants(tlmc_hdr, tlmc_sep, tlmc_rows, [
            ("Sorted by time lost (least first)", "time_lost", False),
            ("Sorted by $ lost (least first)", "cost_lost", False),
            ("Sorted by fell-in count (fewest first)", "fell_in", False),
        ], _fmt_tlmc))
        lines.append("")

        # Trap descriptions and column explanations
        lines.append("#### Trap Descriptions")
        lines.append("")
        for trap_name in sorted(trap_agg):
            desc = trap_descriptions.get(trap_name, "No description available.")
            lines.append(f"- **{trap_name}**: {desc}")
        lines.append("")
        lines.append("#### Column Definitions")
        lines.append("")
        lines.append("- **Fell In**: Number of runs (within that mode/model) where this trap was detected.")
        lines.append("- **Time Lost**: Estimated wall-clock seconds wasted on the trap, based on the number of")
        lines.append("  wasted commands multiplied by a per-command cost (15\u201325s for typical Bash, 45s for Docker runs, 50s for act push).")
        lines.append("- **% of Time**: Time Lost as a percentage of total benchmark duration.")
        lines.append("- **$ Lost**: Proportional cost impact, calculated as (Time Lost / Run Duration) \u00d7 Run Cost for each affected run.")
        lines.append("- **% of $**: $ Lost as a percentage of total benchmark cost.")
        lines.append("")

    # ── Traps by Language/Model ──
    if trap_instances:
        lines.append("### Traps by Language/Model")
        lines.append("")
        tlm_hdr = "| Mode | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |"
        tlm_sep = "|------|-------|------|-------|-----------|-----------|--------|--------|"
        trapped_runs_by_combo = {}
        trap_count_by_combo = {}
        trap_time_by_combo = {}
        trap_cost_by_combo = {}
        for t in trap_instances:
            combo = (t["mode"], t["model"])
            trapped_runs_by_combo.setdefault(combo, set()).add(t["task_id"])
            trap_count_by_combo[combo] = trap_count_by_combo.get(combo, 0) + 1
            trap_time_by_combo[combo] = trap_time_by_combo.get(combo, 0) + t["time_s"]
            if t["dur_s"] > 0 and t["cost"] > 0:
                trap_cost_by_combo[combo] = trap_cost_by_combo.get(combo, 0) + t["time_s"] / t["dur_s"] * t["cost"]

        tlm_rows = []
        for mode in modes_seen:
            for model in models_seen:
                combo = (mode, model)
                n = combo_run_counts.get(combo, 0)
                if n == 0:
                    continue
                n_trapped = len(trapped_runs_by_combo.get(combo, set()))
                rate = n_trapped / n * 100 if n else 0
                tc = trap_count_by_combo.get(combo, 0)
                tt = trap_time_by_combo.get(combo, 0)
                tcc = trap_cost_by_combo.get(combo, 0)
                tlm_rows.append({
                    "mode": mode, "model": model, "n": n, "trapped": n_trapped,
                    "rate": rate, "traps": tc,
                    "time_lost": tt, "time_pct": tt / total_duration * 100 if total_duration else 0,
                    "cost_lost": tcc, "cost_pct": tcc / total_cost * 100 if total_cost else 0,
                })
        def _fmt_tlm(r):
            return (f"| {r['mode']} | {r['model']} | {r['n']} "
                    f"| {r['traps']} | {_dur(r['time_lost'])} | {r['time_pct']:.1f}% "
                    f"| ${r['cost_lost']:.2f} | {r['cost_pct']:.2f}% |")
        lines.append(tlm_hdr)
        lines.append(tlm_sep)
        for r in tlm_rows:
            lines.append(_fmt_tlm(r))
        lines.append("")
        lines.extend(_emit_sorted_variants(tlm_hdr, tlm_sep, tlm_rows, [
            ("Sorted by time lost (least first)", "time_lost", False),
            ("Sorted by $ lost (least first)", "cost_lost", False),
        ], _fmt_tlm))
        lines.append("")

    # ── Prompt Cache Savings (at end of savings) ──
    if cache_data:
        cache_total_saved = sum(d["saved"] for d in cache_data)
        cache_pct = cache_total_saved / total_cost * 100 if total_cost else 0
        lines.append("### Prompt Cache Savings")
        lines.append("")
        lines.append("| Status | Runs | $ Saved | % of $ |")
        lines.append("|--------|------|---------|--------|")
        for label, st in [("Full hit (100%)", "full_hit"), ("Partial", "partial"), ("Miss", "miss")]:
            sv = sum(d["saved"] for d in cache_data if d["status"] == st)
            pct = sv / total_cost * 100 if total_cost else 0
            cnt = sum(1 for d in cache_data if d["status"] == st)
            lines.append(f"| {label} | {cnt} | ${sv:.2f} | {pct:.2f}% |")
        lines.append("")

    # ==================================================================
    # TEST QUALITY EVALUATION
    # ==================================================================
    from test_quality import compute_structural_metrics, LLM_JUDGE_CACHE_FILE

    tq_rows = []
    llm_rows = []
    has_llm = False
    for m in all_metrics:
        variant_dir = run_dir / "tasks" / m["task_id"] / f"{m['language_mode']}-{_label(m)}"
        gen_dir = variant_dir / "generated-code"
        sq = compute_structural_metrics(gen_dir)

        tq_rows.append({
            "task": m["task_name"][:30], "mode": m["language_mode"], "model": _label(m),
            "tests": sq["test_count"], "asserts": sq["assertion_count"],
            "apt": sq["assertions_per_test"],
            "t_lines": sq["test_lines"], "i_lines": sq["impl_lines"],
            "ratio": sq["test_to_code_ratio"],
            "lang": sq["language"],
        })

        # LLM-as-judge scores (from cache if available)
        llm_cache = variant_dir / LLM_JUDGE_CACHE_FILE
        if llm_cache.exists():
            try:
                lj = json.loads(llm_cache.read_text())
                has_llm = True
                llm_rows.append({
                    "task": m["task_name"][:30], "mode": m["language_mode"], "model": _label(m),
                    "coverage": lj.get("coverage", 0), "rigor": lj.get("rigor", 0),
                    "design": lj.get("design", 0), "overall": lj.get("overall", 0),
                    "summary": lj.get("summary", ""),
                    "judge_cost": lj.get("judge_cost_usd", 0),
                })
            except Exception:
                pass

    lines.append("## Test Quality Evaluation")
    lines.append("")

    # ── Structural Metrics by Language/Model ──
    lines.append("### Structural Metrics by Language/Model")
    lines.append("")
    lines.append("Automated analysis of test files: test count, assertion count, and test-to-code line ratio.")
    lines.append("")

    sq_agg = {}
    for r in tq_rows:
        key = (r["mode"], r["model"])
        if key not in sq_agg:
            sq_agg[key] = {"mode": r["mode"], "model": r["model"],
                           "tests": [], "asserts": [], "ratios": []}
        sq_agg[key]["tests"].append(r["tests"])
        sq_agg[key]["asserts"].append(r["asserts"])
        sq_agg[key]["ratios"].append(r["ratio"])

    sq_hdr = "| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |"
    sq_sep = "|------|-------|-----------|----------------|-----------------|---------------------|"
    sq_summary_rows = []
    for key in sorted(sq_agg):
        a = sq_agg[key]
        n = len(a["tests"])
        avg_tests = sum(a["tests"]) / n
        avg_asserts = sum(a["asserts"]) / n
        avg_apt = avg_asserts / avg_tests if avg_tests > 0 else 0
        avg_ratio = sum(a["ratios"]) / n
        sq_summary_rows.append({
            "mode": a["mode"], "model": a["model"],
            "avg_tests": avg_tests, "avg_asserts": avg_asserts,
            "avg_apt": avg_apt, "avg_ratio": avg_ratio,
        })

    def _fmt_sq(r):
        return (f"| {r['mode']} | {r['model']} | {r['avg_tests']:.1f} "
                f"| {r['avg_asserts']:.1f} | {r['avg_apt']:.1f} | {r['avg_ratio']:.2f} |")

    lines.append(sq_hdr)
    lines.append(sq_sep)
    for r in sq_summary_rows:
        lines.append(_fmt_sq(r))
    lines.append("")
    lines.extend(_emit_sorted_variants(sq_hdr, sq_sep, sq_summary_rows, [
        ("Sorted by avg tests (most first)", "avg_tests", True),
        ("Sorted by avg assertions (most first)", "avg_asserts", True),
        ("Sorted by avg test:code ratio (highest first)", "avg_ratio", True),
    ], _fmt_sq))
    lines.append("")

    # ── Per-Run Structural Metrics ──
    tq_hdr = "| Task | Mode | Model | Tests | Assertions | Assert/Test | Test Lines | Impl Lines | Test:Code |"
    tq_sep = "|------|------|-------|-------|------------|-------------|------------|------------|-----------|"
    def _fmt_tq(r):
        return (f"| {r['task']} | {r['mode']} | {r['model']} "
                f"| {r['tests']} | {r['asserts']} | {r['apt']:.1f} "
                f"| {r['t_lines']} | {r['i_lines']} | {r['ratio']:.2f} |")
    lines.extend(_collapsible_table("Per-run structural metrics", tq_hdr, tq_sep,
                                    [_fmt_tq(r) for r in tq_rows]))
    lines.append("")

    # ── LLM-as-Judge Scores ──
    if has_llm and llm_rows:
        lines.append("### LLM-as-Judge Scores")
        lines.append("")
        lines.append("An LLM evaluates each test suite on four dimensions (1-5 scale):")
        lines.append("")
        lines.append("- **Coverage** (1-5): Do tests exercise the key requirements? 1 = most untested, 5 = all covered.")
        lines.append("- **Rigor** (1-5): Edge cases, error handling, boundary conditions? 1 = happy path only, 5 = thorough.")
        lines.append("- **Design** (1-5): Test organization, fixtures, readability? 1 = messy/brittle, 5 = well-structured.")
        lines.append("- **Overall** (1-5): Holistic quality — would you trust this suite to catch regressions? 1 = no, 5 = absolutely. Use this as the primary ranking metric.")
        lines.append("")

        # Aggregate by mode/model
        lj_agg = {}
        for r in llm_rows:
            key = (r["mode"], r["model"])
            if key not in lj_agg:
                lj_agg[key] = {"mode": r["mode"], "model": r["model"],
                               "cov": [], "rig": [], "des": [], "ovr": [], "cost": []}
            lj_agg[key]["cov"].append(r["coverage"])
            lj_agg[key]["rig"].append(r["rigor"])
            lj_agg[key]["des"].append(r["design"])
            lj_agg[key]["ovr"].append(r["overall"])
            lj_agg[key]["cost"].append(r["judge_cost"])

        lj_hdr = "| Mode | Model | Avg Overall | Avg Coverage | Avg Rigor | Avg Design | Judge Cost |"
        lj_sep = "|------|-------|-------------|-------------|-----------|------------|------------|"
        lj_summary_rows = []
        for key in sorted(lj_agg):
            a = lj_agg[key]
            n = len(a["cov"])
            lj_summary_rows.append({
                "mode": a["mode"], "model": a["model"],
                "avg_cov": sum(a["cov"]) / n, "avg_rig": sum(a["rig"]) / n,
                "avg_des": sum(a["des"]) / n, "avg_ovr": sum(a["ovr"]) / n,
                "cost": sum(a["cost"]),
            })
        def _fmt_lj(r):
            return (f"| {r['mode']} | {r['model']} | **{r['avg_ovr']:.1f}** "
                    f"| {r['avg_cov']:.1f} | {r['avg_rig']:.1f} "
                    f"| {r['avg_des']:.1f} "
                    f"| ${r['cost']:.4f} |")

        lines.append(lj_hdr)
        lines.append(lj_sep)
        for r in lj_summary_rows:
            lines.append(_fmt_lj(r))
        total_judge_cost = sum(r["cost"] for r in lj_summary_rows)
        lines.append(f"| **Total** | | | | | | **${total_judge_cost:.4f}** |")
        lines.append("")
        lines.extend(_emit_sorted_variants(lj_hdr, lj_sep, lj_summary_rows, [
            ("Sorted by avg overall (highest first)", "avg_ovr", True),
            ("Sorted by avg coverage (highest first)", "avg_cov", True),
            ("Sorted by avg rigor (highest first)", "avg_rig", True),
            ("Sorted by avg design (highest first)", "avg_des", True),
        ], _fmt_lj))
        lines.append("")

        # Per-run LLM scores
        lj_pr_hdr = "| Task | Mode | Model | Cov | Rig | Des | Ovr | Summary |"
        lj_pr_sep = "|------|------|-------|-----|-----|-----|-----|---------|"
        def _fmt_lj_pr(r):
            return (f"| {r['task']} | {r['mode']} | {r['model']} "
                    f"| {r['coverage']} | {r['rigor']} "
                    f"| {r['design']} | {r['overall']} "
                    f"| {r['summary'][:60]} |")
        lines.extend(_collapsible_table("Per-run LLM judge scores", lj_pr_hdr, lj_pr_sep,
                                        [_fmt_lj_pr(r) for r in llm_rows]))
        lines.append("")

    # ── Cross-comparison: LLM scores vs structural metrics ──
    if has_llm and llm_rows and tq_rows:
        # Build lookup from (task, mode, model) -> structural data
        tq_lookup = {}
        for r in tq_rows:
            tq_lookup[(r["task"], r["mode"], r["model"])] = r

        # Collect paired data
        paired_tests, paired_asserts, paired_ratio = [], [], []
        paired_cov, paired_rig, paired_des, paired_ovr = [], [], [], []
        for lr in llm_rows:
            key = (lr["task"], lr["mode"], lr["model"])
            sq = tq_lookup.get(key)
            if not sq:
                continue
            paired_tests.append(sq["tests"])
            paired_asserts.append(sq["asserts"])
            paired_ratio.append(sq["ratio"])
            paired_cov.append(lr["coverage"])
            paired_rig.append(lr["rigor"])
            paired_des.append(lr["design"])
            paired_ovr.append(lr["overall"])

        if len(paired_tests) >= 5:
            lines.append("### Correlation: Structural Metrics vs LLM Scores")
            lines.append("")
            lines.append("Spearman rank correlation between automated counts and LLM judge scores.")
            lines.append("Values near +1.0 indicate the LLM agrees with the structural signal; near 0 means no relationship.")
            lines.append("")
            lines.append("| Structural Metric | vs Coverage | vs Rigor | vs Design | vs Overall |")
            lines.append("|-------------------|------------|---------|----------|-----------|")
            for label, vals in [("Test count", paired_tests),
                                ("Assertion count", paired_asserts),
                                ("Test:code ratio", paired_ratio)]:
                rc = _spearman(vals, paired_cov)
                rr = _spearman(vals, paired_rig)
                rd = _spearman(vals, paired_des)
                ro = _spearman(vals, paired_ovr)
                lines.append(
                    f"| {label} | {rc if rc is not None else 'n/a'} "
                    f"| {rr if rr is not None else 'n/a'} "
                    f"| {rd if rd is not None else 'n/a'} "
                    f"| {ro if ro is not None else 'n/a'} |")
            lines.append("")
            lines.append(f"*Based on {len(paired_tests)} runs with both structural and LLM scores.*")
            lines.append("")

        discrepancies = _find_discrepancies(llm_rows, tq_lookup)

        if discrepancies:
            counter_gaps = [d for d in discrepancies if d["kind"] == "counter-gap"]
            qualitative = [d for d in discrepancies if d["kind"] == "qualitative"]

            lines.append("### LLM vs Structural Discrepancies")
            lines.append("")

            if counter_gaps:
                lines.append("**Probable counter gaps** — structural counters may be missing "
                             "a test pattern. Investigate and fix `test_quality.py`.")
                lines.append("")
                lines.append("| Task | Mode | Model | Tests | Asserts | Cov | Rig | Des | Ovr | Flag |")
                lines.append("|------|------|-------|-------|---------|-----|-----|-----|-----|------|")
                for d in counter_gaps:
                    lines.append(
                        f"| {d['task']} | {d['mode']} | {d['model']} "
                        f"| {d['tests']} | {d['asserts']} "
                        f"| {d['cov']} | {d['rig']} | {d['des']} | {d['ovr']} "
                        f"| {d['flag']} |")
                lines.append("")

            if qualitative:
                lines.append("**Qualitative disagreements** — structural metrics look reasonable; "
                             "the LLM judge is weighing factors the counters can't measure.")
                lines.append("")
                lines.append("| Task | Mode | Model | Tests | Asserts | Cov | Rig | Des | Ovr | Flag | Justification |")
                lines.append("|------|------|-------|-------|---------|-----|-----|-----|-----|------|---------------|")
                for d in qualitative:
                    # Truncate justification to keep table readable
                    justification = d.get("justification", "")
                    if len(justification) > 200:
                        justification = justification[:197] + "..."
                    # Escape pipes in justification text
                    justification = justification.replace("|", "\\|")
                    lines.append(
                        f"| {d['task']} | {d['mode']} | {d['model']} "
                        f"| {d['tests']} | {d['asserts']} "
                        f"| {d['cov']} | {d['rig']} | {d['des']} | {d['ovr']} "
                        f"| {d['flag']} | {justification} |")
                lines.append("")

    # ==================================================================
    # PER-RUN RESULTS
    # ==================================================================
    lines.append("## Per-Run Results")
    lines.append("")
    pr_hdr = "| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |"
    pr_sep = "|------|------|-------|----------|-------|--------|------|----------|--------|"
    pr_rows = []
    for m in all_metrics:
        dur = m["timing"]["grand_total_duration_ms"] / 1000
        status = "ok" if m in successful else m.get("failure_reason", "failed")
        pr_rows.append({
            "task": m["task_name"][:30], "mode": m["language_mode"], "model": _label(m),
            "dur": dur, "turns": m["timing"]["num_turns"],
            "errors": m["quality"]["error_count"],
            "cost": m["cost"]["total_cost_usd"],
            "lang": m["language_chosen"], "status": status,
        })
    def _fmt_pr(r):
        return (f"| {r['task']} | {r['mode']} | {r['model']} "
                f"| {_dur(r['dur'])} | {r['turns']} "
                f"| {r['errors']} | ${r['cost']:.2f} "
                f"| {r['lang']} | {r['status']} |")
    lines.append(pr_hdr)
    lines.append(pr_sep)
    for r in pr_rows:
        lines.append(_fmt_pr(r))
    lines.append("")
    lines.extend(_emit_sorted_variants(pr_hdr, pr_sep, pr_rows, [
        ("Sorted by cost (cheapest first)", "cost", False),
        ("Sorted by duration (fastest first)", "dur", False),
        ("Sorted by errors (fewest first)", "errors", False),
        ("Sorted by turns (fewest first)", "turns", False),
    ], _fmt_pr))
    lines.append("")

    lines.append("---")
    # Determine the instructions version from the run data, not from the
    # current generate_results.py constant (which may have moved on to a
    # newer version since these runs were executed).
    run_versions = sorted(set(
        m.get("instructions_version", "?") for m in all_metrics if m.get("instructions_version")))
    run_ver_str = ", ".join(run_versions) if run_versions else "unknown"
    lines.append(f"*Generated by generate_results.py — benchmark instructions {run_ver_str}*")

    (run_dir / "results.md").write_text("\n".join(lines))


# ---------------------------------------------------------------------------
# README index
# ---------------------------------------------------------------------------

def update_readme(repo_root: Path) -> None:
    """Update README.md with a table linking to every run's results.md."""
    results_dir = repo_root / "results"
    if not results_dir.exists():
        return

    runs: list[dict] = []
    for d in sorted(results_dir.iterdir(), reverse=True):
        if not d.is_dir() or d.name.startswith("."):
            continue
        results_md = d / "results.md"
        manifest = d / "run-manifest.json"
        n_metrics = len(list(d.glob("tasks/*/*/metrics.json")))
        info: dict = {"dir": d.name, "n_runs": n_metrics, "link": f"results/{d.name}/results.md"}
        if manifest.exists():
            try:
                mf = json.loads(manifest.read_text())
                info["total_planned"] = mf.get("total_runs", "?")
                info["version"] = mf.get("instructions_version", "?")
                info["cost"] = mf.get("total_cost_usd", 0)
                info["started"] = mf.get("started_at", "")[:19]
            except Exception:
                pass
        if results_md.exists():
            info["has_results"] = True
        else:
            info["has_results"] = False
        runs.append(info)

    if not runs:
        return

    # Build the table
    table_lines = []
    table_lines.append("<!-- BEGIN BENCHMARK RUNS -->")
    table_lines.append("| Run | Version | Runs | Cost | Results |")
    table_lines.append("|-----|---------|------|------|---------|")
    for i, r in enumerate(runs):
        name = r["dir"]
        if i == 0:
            name = f"**{name}** (latest)"
        ver_raw = r.get("version", "?")
        # Linkify version to the instructions doc
        ver_links = {"v1": "benchmark-instructions-v1.md", "v2": "benchmark-instructions-v2.md", "v3": "benchmark-instructions-v3.md", "v4": "benchmark-instructions-v4.md"}
        ver = f"[{ver_raw}]({ver_links[ver_raw]})" if ver_raw in ver_links else ver_raw
        count = f"{r['n_runs']}/{r.get('total_planned', '?')}"
        cost = f"${r.get('cost', 0):.2f}" if r.get("cost") else "—"
        link = f"[results.md]({r['link']})" if r.get("has_results") else "—"
        table_lines.append(f"| {name} | {ver} | {count} | {cost} | {link} |")
    table_lines.append("<!-- END BENCHMARK RUNS -->")

    # Update README.md — replace between markers or append
    readme_path = repo_root / "README.md"
    if readme_path.exists():
        content = readme_path.read_text()
    else:
        content = "# compare-agent-scripting-by-language\n\n"

    begin = "<!-- BEGIN BENCHMARK RUNS -->"
    end = "<!-- END BENCHMARK RUNS -->"
    if begin in content and end in content:
        before = content[:content.index(begin)]
        after = content[content.index(end) + len(end):]
        new_content = before + "\n".join(table_lines) + after
    else:
        # Append section
        new_content = content.rstrip() + "\n\n## Benchmark Runs\n\n" + "\n".join(table_lines) + "\n"

    # Keep the "Latest results" link in the subtitle current
    if runs and runs[0].get("has_results"):
        latest_link = runs[0]["link"]
        new_content = re.sub(
            r"\*\*\[Latest results\]\([^)]*\)\*\*",
            f"**[Latest results]({latest_link})**",
            new_content,
        )

    readme_path.write_text(new_content)
    print(f"Updated {readme_path} with {len(runs)} run(s)", file=sys.stderr)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _regenerate_run(run_dir: Path) -> None:
    """Load metrics from a run directory and regenerate its results.md."""
    metrics_files = sorted(run_dir.glob("tasks/*/*/metrics.json"))
    if not metrics_files:
        print(f"  Skipping {run_dir.name}: no metrics files", file=sys.stderr)
        return
    all_metrics = []
    for f in metrics_files:
        try:
            all_metrics.append(json.loads(f.read_text()))
        except Exception:
            pass
    # Determine total_runs from manifest or count
    manifest_path = run_dir / "run-manifest.json"
    total_runs = len(all_metrics)
    if manifest_path.exists():
        try:
            total_runs = json.loads(manifest_path.read_text()).get("total_runs", total_runs)
        except Exception:
            pass
    generate_results_md(run_dir, all_metrics, total_runs, total_runs)
    print(f"  Generated {run_dir / 'results.md'} ({len(all_metrics)} runs)", file=sys.stderr)


def main():
    repo_root = Path(__file__).parent.resolve()
    results_dir = repo_root / "results"

    if "--update-readme" in sys.argv:
        update_readme(repo_root)
        return

    if "--all" in sys.argv:
        for d in sorted(results_dir.iterdir()):
            if d.is_dir() and not d.name.startswith("."):
                _regenerate_run(d)
        update_readme(repo_root)
        return

    # Specific directory or most recent
    if len(sys.argv) > 1 and not sys.argv[1].startswith("-"):
        target = Path(sys.argv[1])
        if not target.is_absolute():
            target = repo_root / target
    else:
        dirs = sorted(d for d in results_dir.iterdir() if d.is_dir() and not d.name.startswith("."))
        if not dirs:
            print("No results directories found.", file=sys.stderr)
            sys.exit(1)
        target = dirs[-1]

    _regenerate_run(target)
    update_readme(repo_root)


if __name__ == "__main__":
    main()
