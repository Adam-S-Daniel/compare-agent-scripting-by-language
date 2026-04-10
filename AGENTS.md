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

# Run a benchmark (v4, all tasks/modes/models)
python3 runner.py --tasks 11,12,13,14,15,16,17,18 --modes default,powershell,bash,typescript-bun --models opus,sonnet

# Build custom act container (optional, eliminates pwsh install overhead)
docker build -t act-ubuntu-pwsh:latest -f Dockerfile.act .
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
- `Dockerfile.act` — custom act container image with pwsh + Pester pre-installed. Build with `docker build -t act-ubuntu-pwsh:latest -f Dockerfile.act .`. Runner.py auto-detects it and injects `.actrc` into workspaces.
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

## Current state (2026-04-10)

### v4 benchmark — complete

64/64 runs finished (8 tasks x 4 modes x 2 models). Results in
`results/2026-04-09_152435/`. Zero failures, zero timeouts, zero
double-result bugs. Total cost $86.90, avg 8.6min/run.

v4 added trap-awareness guidance from v3 findings, `shell: pwsh` for
PowerShell mode, "limit to 3 act push" instruction, and a custom act
Docker image with pwsh/Pester pre-installed. This cut average run time
by 24% vs v3 (8.6min vs 11.4min).

### Key findings (v4)

- Opus is faster than Sonnet across all modes.
- Default mode always chooses Python.
- PowerShell/sonnet is the slowest and most expensive combo.
- TypeScript hooks have ~50% catch rate but are net negative for Opus
  (tsc --noEmit takes 12-21s per Write on large files) and net positive
  for Sonnet (smaller writes, 2-3s per check).
- PowerShell hooks catch almost nothing (0-4% rate) — net negative.
- v4 trap-awareness guidance eliminated the timeout and double-result
  bugs that occurred in v3.

### Earlier versions

- v3: `results/2026-04-08_192624/` — 64 runs, same tasks/modes/models as v4. Had 1 timeout, 3 double-result bugs. Avg 11.4min/run.
- v2: `results/2026-04-07_225702/` — 111/144 runs. 18 tasks, modes: default/powershell/powershell-strict/csharp-script. Superseded by v3.
- v1: `results/2026-04-02_163146/` — 144 runs, same as v2. Had permission-denial artifacts (88% of errors).
- See `design-and-planning-artifacts/` for historical analysis and planning docs.
