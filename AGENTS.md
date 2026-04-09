# Agent Instructions

All agent-facing instructions live in this file. `CLAUDE.md` contains only a
reference here. If you are a Claude Code agent, you have already loaded this
via `CLAUDE.md`. Other agents: read this file directly.

## Build and test

```bash
# Validate imports
python3 -c "from runner import main"
python3 -c "from generate_results import generate_results_md"

# Regenerate all reports
python3 generate_results.py --all

# Run a benchmark (v3, all tasks/modes/models)
python3 runner.py --tasks 11,12,13,14,15,16,17,18 --modes default,powershell,bash,typescript-bun --models opus,sonnet
```

## Code style

- Python 3.12+. No type stubs or mypy. Use type hints where they aid readability.
- Dollar amounts in results.md: round to nearest penny (`.2f`).
- Durations in results.md: always in minutes with 1 decimal (`{seconds/60:.1f}min`).
- No emojis in code or docs unless the user asks.

## Repository rules

- **No `.github/workflows/` at repo root.** Workflows only exist inside agent workspaces under `workspaces/`.
- **Never fix agent-generated code.** The benchmark measures autonomous output. Do not manually fix, edit, or patch workflow files in `workspaces/` or `results/*/generated-code/`.
- **`runner.py` observes and records, never intervenes** on agent code or errors.
- **Workspaces are throwaway.** Don't commit `workspaces/` contents.
- **`results/` is committed.** It contains archived metrics, generated code, and transcripts.
- **`CLAUDE.md` is only a pointer.** All instructions go in `AGENTS.md`. Never put substantive content in `CLAUDE.md` — it should only reference this file.

## Architecture

### Key files

- `models.py` — single source of truth for model IDs and token pricing. Update here when Anthropic changes prices.
- `runner.py` — benchmark harness. Runs agents via `claude -p`, collects metrics, pushes results. Imports from `models.py` and `generate_results.py`.
- `generate_results.py` — generates `results.md` reports and updates `README.md`. Can run standalone: `python3 generate_results.py --all`.
- `benchmark-instructions-v*.md` — per-version specs given to agents during runs.
- `hooks/syntax-check.py` — PostToolUse hook for syntax/lint checking.
- `skills/` — agent skills following [agentskills.io](https://agentskills.io/specification) spec.

### Adding new trap detectors

See the docstring on `_detect_traps()` in `generate_results.py`. Each trap needs:
a kebab-case name, detection logic over bash_cmds/console/metrics, a time estimate,
and an entry in `trap_applicable_mode` if mode-specific.

### Updating model pricing

Edit `models.py`. Check https://docs.anthropic.com/en/docs/about-claude/models and
https://www.anthropic.com/pricing. Then run `python3 generate_results.py --all`.

### Regenerating reports

After changing `generate_results.py`, run:
```bash
python3 generate_results.py --all
```
This regenerates `results.md` for every run directory and updates `README.md`.

## Before every PR

1. Run `python3 generate_results.py --all` and verify no errors.
2. Spot-check a few numbers in results.md against raw metrics.json.
3. Verify all import paths work: `python3 -c "from runner import main"`.
4. If you changed architecture or findings, update this file (`AGENTS.md`).
5. If you added files or moved things, update the Files table in `README.md`.

## Current state (2026-04-09)

### v3 benchmark — complete

64/64 runs finished (8 tasks x 4 modes x 2 models). Results in
`results/2026-04-08_192624/`. All runs passed actionlint and produced
act-result.txt. One run (task 18/powershell/sonnet) originally timed out
at 30min and was re-run with unlimited timeout (completed in 12.7min).
Three powershell-sonnet runs had metrics reparsed due to a double-result
bug (background task notifications created spurious second CLI result events).

### Key findings

- Opus is 1.84x faster than Sonnet on average (won 25 of 31 paired comparisons).
- Default mode always chose Python (except once: Opus chose Bash for task 16).
- PowerShell is the slowest mode (avg 15min vs 9min for default/opus).
- Net of traps, powershell/opus is the cheapest ($0.93) and nearly tied for fastest (6.9min vs 6.8min for default/opus).
- TypeScript hooks are the most productive (50% catch rate, net positive time savings).
- PowerShell hooks are net negative (low catch rate, high overhead from Invoke-ScriptAnalyzer).
- Traps consumed 15.8% of total benchmark time ($12.71, 115min); hooks saved 0.4% net.
- pwsh-runtime-install-overhead is the largest trap by total time (26.2min across 15 runs) — wouldn't exist on real GitHub runners.
- No context compactions occurred — 200K window was always sufficient.

### Earlier versions

- v1: `results/2026-04-02_163146/` — 144 runs, all 18 tasks, 4 modes (default/powershell/powershell-strict/csharp-script). Had permission-denial artifacts (88% of errors).
- v2: `results/2026-04-07_225702/` — 111/144 runs. Fixed permissions. Superseded by v3 before completion.
- See `design-and-planning-artifacts/` for historical analysis and planning docs.
