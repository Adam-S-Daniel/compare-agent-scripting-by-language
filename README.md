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

## Benchmark Runs

<!-- BEGIN BENCHMARK RUNS -->
| Run | Version | Runs | Cost | Results |
|-----|---------|------|------|---------|
| **2026-04-08_192624** (latest) | v3 | 64/64 | $85.10 | [results.md](results/2026-04-08_192624/results.md) |
| 2026-04-08_180614 | ? | 2/? | — | [results.md](results/2026-04-08_180614/results.md) |
| 2026-04-08_180255 | ? | 0/? | — | [results.md](results/2026-04-08_180255/results.md) |
| 2026-04-08_174516 | ? | 1/? | — | [results.md](results/2026-04-08_174516/results.md) |
| 2026-04-08_170920 | ? | 4/? | — | [results.md](results/2026-04-08_170920/results.md) |
| 2026-04-08_170824 | ? | 0/? | — | — |
| 2026-04-08_161536 | ? | 7/? | — | [results.md](results/2026-04-08_161536/results.md) |
| 2026-04-08_114024 | ? | 3/? | — | [results.md](results/2026-04-08_114024/results.md) |
| 2026-04-08_113116 | ? | 1/? | — | [results.md](results/2026-04-08_113116/results.md) |
| 2026-04-07_225702 | v2 | 111/144 | $75.38 | [results.md](results/2026-04-07_225702/results.md) |
| 2026-04-02_181500 | v1 | 4/1 | $8.90 | [results.md](results/2026-04-02_181500/results.md) |
| 2026-04-02_163146 | v1 | 144/144 | $436.67 | [results.md](results/2026-04-02_163146/results.md) |
<!-- END BENCHMARK RUNS -->
