# compare-agent-scripting-by-language

Benchmarks how well Claude Code agents perform scripting tasks in PowerShell (and other constrained languages) versus their default language choice.

## Quick Start (Sprites or any VM)

```bash
git clone https://github.com/Adam-S-Daniel/compare-agent-scripting-by-language.git
cd compare-agent-scripting-by-language
git checkout claude/powershell-benchmark-tests-Q5vR5

# Ensure claude CLI is installed and authenticated
# Then run:
./run-benchmark.sh
```

To resume a crashed/interrupted run:
```bash
./run-benchmark.sh --resume 2026-04-02_181500
```

## What it Tests

**18 scripting tasks** across categories: data transformation, text processing, file manipulation, API interaction, system administration, error handling, and GitHub Actions automation.

**4 language modes** per task:
- `default` — agent chooses freely (typically Python)
- `powershell` — must use PowerShell + Pester
- `powershell-strict` — PowerShell with strict mode, typed params, CmdletBinding
- `csharp-script` — C# with .NET 10 file-based apps

**2 models:** Claude Opus 4.6, Claude Sonnet 4.6

**Total: 144 runs** (18 tasks x 2 models x 4 modes)

Every task prompt requires **red/green TDD** with mocks.

## Metrics Collected

Per run: exact model, Claude Code version, timestamp, full prompt, grand total duration, API duration, execution duration, turns, input/output/cache tokens, cost, code lines, token estimate, file count, error count, error details, language breakdown, compaction count.

## Files

| File | Purpose |
|------|---------|
| `benchmark-instructions-v1.md` | Versioned methodology, task definitions, prompt templates |
| `runner.py` | Main runner — invokes `claude -p`, collects metrics, generates results.md |
| `run-benchmark.sh` | One-command launcher with prerequisite checks |
| `watchdog.sh` | Auto-restart wrapper (for environments that kill background processes) |
| `results/` | Structured output — metrics.json, generated code, console logs per run |
| `workspaces/` | Temporary agent working directories (git-ignored) |

## Results

Live results are pushed to git every 60 seconds during a run. See `results/<timestamp>/results.md` for the latest summary with comparison tables.
