# Agent Instructions

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

## Architecture

- `models.py` — single source of truth for model IDs and token pricing.
- `runner.py` — benchmark harness. Imports from `models.py` and `generate_results.py`.
- `generate_results.py` — report generator. Imports from `models.py`. Can run standalone.
- `hooks/syntax-check.py` — PostToolUse hook for syntax/lint checking.
- `benchmark-instructions-v*.md` — per-version specs given to agents during runs.

## Key conventions

- **No `.github/workflows/` at repo root.** Workflows only exist inside agent workspaces.
- **Never fix agent-generated code.** The benchmark measures autonomous output.
- **`runner.py` observes and records, never intervenes** on agent code.
- **Workspaces are throwaway.** Don't commit `workspaces/` contents.
- **`results/` is committed.** It contains archived metrics, generated code, and transcripts.

## Before every PR

1. Run `python3 generate_results.py --all` and verify no errors.
2. Spot-check a few numbers in results.md against raw metrics.json.
3. Verify all import paths work: `python3 -c "from runner import main"`.
4. If you changed architecture or findings, update `CLAUDE.md`.
5. If you added files or moved things, update the Files table in `README.md`.

## Adding new trap detectors

See the docstring on `_detect_traps()` in `generate_results.py`. Each trap needs:
a kebab-case name, detection logic over bash_cmds/console/metrics, a time estimate,
and an entry in `trap_applicable_mode` if mode-specific.

## Updating model pricing

Edit `models.py`. Check https://docs.anthropic.com/en/docs/about-claude/models and
https://www.anthropic.com/pricing. Then run `python3 generate_results.py --all`.
