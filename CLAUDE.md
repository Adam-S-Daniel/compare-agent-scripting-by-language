# Repository Rules

## No workflows in this repo

Do NOT create or modify files in `.github/workflows/` at the repository root.
The `.github/workflows/` directory is reserved for agent workspaces only — each
benchmark agent creates workflows inside its own isolated workspace directory
under `workspaces/`. The repo root must never contain GitHub Actions workflows.

## Only spawned agents fix their own YAML

If a benchmark agent produces a broken workflow YAML file, only that agent
(running inside its workspace via `runner.py`) is responsible for fixing it.
Do not manually fix, edit, or patch workflow files in `workspaces/` or
`results/*/generated-code/`. The whole point of the benchmark is to measure
what the agent produces autonomously.

## Benchmark workspace isolation

Each benchmark run creates isolated workspaces under `workspaces/<run-id>/`.
These are throwaway directories. Do not commit workspace contents to git.
The `results/` directory contains the archived outputs (metrics, generated code,
transcripts) and IS committed.

## runner.py is the harness, not a participant

`runner.py` orchestrates benchmark runs, collects metrics, and runs post-run
validation (actionlint, act). It must not modify the agent's code or fix errors
on the agent's behalf. Its role is observe and record, not intervene.

---

# Architecture

## Key files

- `models.py` — single source of truth for model IDs and token pricing.
  Update here when Anthropic changes prices.
- `runner.py` — benchmark harness. Runs agents, collects metrics, pushes
  results. Imports from `models.py` and `generate_results.py`.
- `generate_results.py` — generates `results.md` reports and updates
  `README.md`. Can be run standalone: `python3 generate_results.py --all`.
- `benchmark-instructions-v*.md` — per-version specs given to agents.
- `hooks/syntax-check.py` — PostToolUse hook for syntax/lint checking.

## Adding new trap detectors

See the docstring on `_detect_traps()` in `generate_results.py` for
step-by-step instructions on adding new trap patterns. If the new trap
applies to a specific mode, also update the `trap_applicable_mode` dict
inside `generate_results_md()`.

## Regenerating reports

After changing `generate_results.py`, run:
```bash
python3 generate_results.py --all
```
This regenerates `results.md` for every run directory and updates `README.md`.

---

# Current state (2026-04-09)

## v3 benchmark — complete

64/64 runs finished (8 tasks x 4 modes x 2 models). Results in
`results/2026-04-08_192624/`. All runs passed actionlint and produced
act-result.txt. One run (task 18/powershell/sonnet) originally timed out
at 30min and was re-run with unlimited timeout (completed in 12.7min).
Three powershell-sonnet runs had metrics reparsed due to a double-result
bug (background task notifications created spurious second CLI result events).

## Key findings

- Opus is 1.84x faster than Sonnet on average (won 25 of 31 paired comparisons).
- Default mode always chose Python (except once: Opus chose Bash for task 16).
- PowerShell is the slowest mode (avg 15min vs 9min for default/opus).
- TypeScript hooks are the most productive (50% catch rate, net positive time savings).
- PowerShell hooks are net negative (low catch rate, high overhead from Invoke-ScriptAnalyzer).
- Traps consumed 12% of total benchmark time; hooks saved 0.7% net.
- No context compactions occurred — 200K window was always sufficient.

## Earlier versions

- v1: `results/2026-04-02_163146/` — 144 runs, all 18 tasks, 4 modes (default/powershell/powershell-strict/csharp-script). Had permission-denial artifacts (88% of errors).
- v2: `results/2026-04-07_225702/` — 111/144 runs. Fixed permissions. Superseded by v3 before completion.
- See `design-and-planning-artifacts/` for historical analysis and planning docs.
