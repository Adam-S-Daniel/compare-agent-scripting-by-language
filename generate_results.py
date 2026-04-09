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

INSTRUCTIONS_VERSION = "v3"


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
    if mode == "powershell":
        diag = [c for c in bash_cmds if re.search(r"/tmp/test_\w+\.(?:ps1|Tests\.ps1)", c)]
        if len(diag) >= 2:
            _add("pester-cmdletbinding-spiral", len(diag) * 25,
                 f"{len(diag)} /tmp/test_*.ps1 diagnostic scripts bisecting Pester parameter binding")

    # 2. Wrong Pester assertion names
    if mode == "powershell":
        wrong = [n for n, p in [("BeInRange", r"Should\s+-BeInRange"),
                                 ("BeGreaterOrEqualTo", r"Should\s+-BeGreaterOrEqualTo"),
                                 ("BeLessOrEqualTo", r"Should\s+-BeLessOrEqualTo")]
                 if re.search(p, "\n".join(bash_cmds) + all_text)]
        if wrong and re.search(r"fix|correct|wrong|not.*valid|doesn.t exist", all_text, re.I):
            _add("pester-wrong-assertions", 45, f"Used nonexistent assertions: {', '.join(wrong)}")

    # 3. Docker PowerShell install exploration
    if mode == "powershell":
        dp = [c for c in bash_cmds if re.search(r"docker\s+run.*(?:powershell|pwsh|microsoft-prod)", c, re.I)]
        if len(dp) >= 2:
            _add("docker-pwsh-install", len(dp) * 45, f"{len(dp)} Docker runs exploring pwsh install")

    # 4. Module restructure mid-run
    if mode == "powershell":
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
    fc = [c for c in bash_cmds if re.search(r"fixture|sample.*data|test.*data|mock.*data", c, re.I)]
    if len(fc) >= 4:
        _add("fixture-rework", (len(fc) - 2) * 15, f"{len(fc)} commands creating/fixing fixtures")

    # 10. Repeated identical test reruns
    cmd_cnt: dict[str, int] = {}
    for c in bash_cmds:
        if re.search(r"pytest|Invoke-Pester|bun\s+test|bats\s+", c):
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
    pe = len(re.findall(r"Permission denied|chmod\s+\+x|not found.*act|ENOENT", console, re.I))
    if pe >= 3:
        _add("act-permission-path-errors", pe * 15, f"{pe} permission/path errors in act container")

    # 13. act fixture path issues
    if (re.search(r"Config file not found|fixture.*not found|No such file.*fixture", console, re.I)
            and re.search(r"fixture.*path|copy.*fixture|missing.*fixture", all_text, re.I)):
        _add("act-fixture-paths", 60, "Fixtures not found inside act Docker container")

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
        r"pwsh\s+.*Tests?\.ps1",
        r"run[-_]tests",
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
    modes_seen = sorted(set(m["language_mode"] for m in all_metrics))
    models_seen = sorted(set(m["model_short"] for m in all_metrics))

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
            mm = [m for m in successful if m["language_mode"] == mode and m["model_short"] == model]
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
    TEST_RUN_COST_S = {"default": 8, "powershell": 35, "bash": 12, "typescript-bun": 8}
    _write_durs_by_mode = {}
    for m in all_metrics:
        md = m["language_mode"]
        for t in m.get("tool_use_timing", {}).get("slowest_tool_uses", []):
            if t["tool_name"] in ("Write", "Edit"):
                _write_durs_by_mode.setdefault(md, []).append(t["duration_ms"] / 1000)
    HOOK_OVERHEAD_S = {
        md: max(0, (sum(ds) / len(ds)) - 0.05) if ds else 0.5
        for md, ds in _write_durs_by_mode.items()
    }

    trap_instances = []
    hook_by_combo = {}
    combo_run_counts = {}

    for m in all_metrics:
        mode, model = m["language_mode"], m["model_short"]
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

        caught = m.get("hooks", {}).get("hook_errors_caught", 0)
        fires = m.get("hooks", {}).get("hook_fires", 0)
        gross_saved = caught * TEST_RUN_COST_S.get(mode, 10)
        overhead = fires * HOOK_OVERHEAD_S.get(mode, 0.5)
        test_time = m.get("tool_use_timing", {}).get("test_duration_ms", 0) / 1000
        if combo not in hook_by_combo:
            hook_by_combo[combo] = {"fires": 0, "caught": 0, "gross_saved": 0, "overhead": 0, "test_time": 0}
        hook_by_combo[combo]["fires"] += fires
        hook_by_combo[combo]["caught"] += caught
        hook_by_combo[combo]["gross_saved"] += gross_saved
        hook_by_combo[combo]["overhead"] += overhead
        hook_by_combo[combo]["test_time"] += test_time

    # ── Prompt cache data ──
    cache_data = []
    cache_read_rates = {s: COST_PER_MTOK[mid]["cache_read"] for s, mid in MODELS.items() if mid in COST_PER_MTOK}
    cache_create_rates = {s: COST_PER_MTOK[mid]["cache_write"] for s, mid in MODELS.items() if mid in COST_PER_MTOK}
    for m in all_metrics:
        cli_path = run_dir / "tasks" / m["task_id"] / f"{m['language_mode']}-{m['model_short']}" / "cli-output.json"
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
                ms = m["model_short"]
                saved = cr * (cache_create_rates.get(ms, 0) - cache_read_rates.get(ms, 0)) / 1_000_000 if cr else 0
                status = "full_hit" if cr > 0 and cc == 0 else "partial" if cr > 0 else "miss"
                cache_data.append({"mode": m["language_mode"], "model": ms, "saved": saved, "status": status})
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
                f"| {m['task_name'][:30]} | {m['language_mode']} | {m['model_short']} "
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
        cmp_hdr = "| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |"
        cmp_sep = "|------|-------|------|-------------|-----------|------------|-----------|----------|------------|"
        def _fmt_cmp(r):
            return (f"| {r['mode']} | {r['model']} | {r['n']} | {_dur(r['avg_dur'])} | {r['avg_lines']:.0f} "
                    f"| {r['avg_errors']:.1f} | {r['avg_turns']:.0f} | ${r['avg_cost']:.2f} | ${r['total_cost']:.2f} |")
        lines.append(cmp_hdr)
        lines.append(cmp_sep)
        for r in cmp_rows:
            lines.append(_fmt_cmp(r))
        lines.append("")
        lines.extend(_emit_sorted_variants(cmp_hdr, cmp_sep, cmp_rows, [
            ("Sorted by avg cost (most expensive first)", "avg_cost", True),
            ("Sorted by avg errors (fewest first)", "avg_errors", False),
            ("Sorted by avg lines (fewest first)", "avg_lines", False),
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
    hook_hdr = ("| Mode | Model | Fires | Caught | Rate "
                "| Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time "
                "| Test Run Time | % of Test Time |")
    hook_sep = ("|------|-------|-------|--------|------"
                "|------------|-----------|----------|-----------|-----------|-----------|"
                "---------------|----------------|")
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
        return (f"| {r['mode']} | {r['model']} | {r['fires']} | {r['caught']} | {r['rate']:.1f}% "
                f"| {_dur(r['gross'])} | {r['gross_pct']:.1f}% "
                f"| {_dur(r['overhead'])} | {r['overhead_pct']:.1f}% "
                f"| {_dur(r['net'])} | {r['net_pct']:.1f}% "
                f"| {_dur(r['test_time'])} | {r['test_time_pct']:.1f}% |")
    lines.append(hook_hdr)
    lines.append(hook_sep)
    for r in hook_rows:
        lines.append(_fmt_hook(r))
    total_hook_fires = sum(r["fires"] for r in hook_rows)
    total_hook_caught = sum(r["caught"] for r in hook_rows)
    total_gross = sum(r["gross"] for r in hook_rows)
    total_overhead = sum(r["overhead"] for r in hook_rows)
    total_net = total_gross - total_overhead
    total_test_time = sum(r["test_time"] for r in hook_rows)
    if total_hook_fires:
        lines.append(
            f"| **Total** | | **{total_hook_fires}** | **{total_hook_caught}** "
            f"| **{total_hook_caught/total_hook_fires*100:.1f}%** "
            f"| **{_dur(total_gross)}** | **{total_gross/total_duration*100:.1f}%** "
            f"| **{_dur(total_overhead)}** | **{total_overhead/total_duration*100:.1f}%** "
            f"| **{_dur(total_net)}** | **{total_net/total_duration*100:.1f}%** "
            f"| **{_dur(total_test_time)}** "
            f"| **{total_net/total_test_time*100:.1f}%** |" if total_test_time else
            f"| **—** | **—** |"
        )
    lines.append("")
    lines.extend(_emit_sorted_variants(hook_hdr, hook_sep, hook_rows, [
        ("Sorted by net saved (most first)", "net", True),
        ("Sorted by net % of test time (most first)", "test_time_pct", True),
        ("Sorted by catch rate (highest first)", "rate", True),
    ], _fmt_hook))
    lines.append("")

    # ── Trap Analysis by Language/Model/Category ──
    if trap_instances:
        trap_applicable_mode = {
            "pester-cmdletbinding-spiral": "powershell",
            "pester-wrong-assertions": "powershell",
            "docker-pwsh-install": "powershell",
            "mid-run-module-restructure": "powershell",
            "ts-type-error-fix-cycles": "typescript-bun",
            "bats-setup-issues": "bash",
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
        }

        trap_agg = defaultdict(list)
        for t in trap_instances:
            trap_agg[t["name"]].append(t)
        mode_run_totals = {md: sum(1 for m in all_metrics if m["language_mode"] == md) for md in modes_seen}

        # Build rows: one per (trap, mode, model) combo that actually occurred
        tlmc_rows = []
        for trap_name in sorted(trap_agg, key=lambda k: -sum(t["time_s"] for t in trap_agg[k])):
            insts = trap_agg[trap_name]
            tmode = trap_applicable_mode.get(trap_name, "all")
            n_app = mode_run_totals.get(tmode, completed) if tmode != "all" else completed
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
        lines.append(
            f"| **Total** | | | **{total_trapped} runs** "
            f"| **{_dur(total_trap_time)}** | **{total_trap_time/total_duration*100:.1f}%** "
            f"| **${total_trap_cost:.2f}** | **{total_trap_cost/total_cost*100:.2f}%** |")
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
        tlm_hdr = "| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |"
        tlm_sep = "|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|"
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
            return (f"| {r['mode']} | {r['model']} | {r['n']} | {r['trapped']} | {r['rate']:.0f}% "
                    f"| {r['traps']} | {_dur(r['time_lost'])} | {r['time_pct']:.1f}% "
                    f"| ${r['cost_lost']:.2f} | {r['cost_pct']:.2f}% |")
        lines.append(tlm_hdr)
        lines.append(tlm_sep)
        for r in tlm_rows:
            lines.append(_fmt_tlm(r))
        lines.append(
            f"| **Total** | | **{completed}** | **{total_trapped}** "
            f"| **{total_trapped/completed*100:.0f}%** "
            f"| **{len(trap_instances)}** | **{_dur(total_trap_time)}** | **{total_trap_time/total_duration*100:.1f}%** "
            f"| **${total_trap_cost:.2f}** | **{total_trap_cost/total_cost*100:.2f}%** |")
        lines.append("")
        lines.extend(_emit_sorted_variants(tlm_hdr, tlm_sep, tlm_rows, [
            ("Sorted by time lost (least first)", "time_lost", False),
            ("Sorted by $ lost (least first)", "cost_lost", False),
            ("Sorted by trap rate (lowest first)", "rate", False),
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
        lines.append(f"| **Total** | **{len(cache_data)}** | **${cache_total_saved:.2f}** | **{cache_pct:.2f}%** |")
        lines.append("")

    # ==================================================================
    # PER-RUN RESULTS
    # ==================================================================
    lines.append("## Per-Run Results")
    lines.append("")
    pr_hdr = "| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |"
    pr_sep = "|------|------|-------|----------|-------|-------|--------|------|----------|--------|"
    pr_rows = []
    for m in all_metrics:
        dur = m["timing"]["grand_total_duration_ms"] / 1000
        status = "ok" if m in successful else m.get("failure_reason", "failed")
        pr_rows.append({
            "task": m["task_name"][:30], "mode": m["language_mode"], "model": m["model_short"],
            "dur": dur, "turns": m["timing"]["num_turns"],
            "lines": m["code_metrics"]["total_lines"],
            "errors": m["quality"]["error_count"],
            "cost": m["cost"]["total_cost_usd"],
            "lang": m["language_chosen"], "status": status,
        })
    def _fmt_pr(r):
        return (f"| {r['task']} | {r['mode']} | {r['model']} "
                f"| {_dur(r['dur'])} | {r['turns']} | {r['lines']} "
                f"| {r['errors']} | ${r['cost']:.2f} "
                f"| {r['lang']} | {r['status']} |")
    lines.append(pr_hdr)
    lines.append(pr_sep)
    for r in pr_rows:
        lines.append(_fmt_pr(r))
    lines.append("")
    lines.extend(_emit_sorted_variants(pr_hdr, pr_sep, pr_rows, [
        ("Sorted by cost (most expensive first)", "cost", True),
        ("Sorted by duration (longest first)", "dur", True),
        ("Sorted by errors (fewest first)", "errors", False),
        ("Sorted by lines (fewest first)", "lines", False),
        ("Sorted by turns (fewest first)", "turns", False),
    ], _fmt_pr))
    lines.append("")

    lines.append("---")
    lines.append(f"*Generated by generate_results.py, instructions version {INSTRUCTIONS_VERSION}*")

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
        ver_links = {"v1": "benchmark-instructions-v1.md", "v2": "benchmark-instructions-v2.md", "v3": "benchmark-instructions-v3.md"}
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
