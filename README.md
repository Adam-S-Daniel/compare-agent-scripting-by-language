# compare-agent-scripting-by-language

Benchmarks how well agents perform scripting tasks when asked to use various languages (and when not asked to use a particular language). **[Latest results](results/2026-04-09_152435/results.md)** | [All results](#benchmark-runs)

## Benchmark Versions

### [v1](benchmark-instructions-v1.md) — Baseline

First benchmark run. 18 general scripting tasks (data transformation, text processing, file manipulation, etc.) across 4 language modes: `default`, `powershell`, `powershell-strict`, `csharp-script`. 2 models (Opus, Sonnet). 144 total runs. Every task prompt requires red/green TDD with mocks. No syntax hooks. Tasks 11-18 have GitHub Actions themes but only produce standalone scripts.

### [v2](benchmark-instructions-v2.md) — Refined Prompts

Same 18 tasks and 4 modes as v1, with improved prompt wording. Partially completed (111/144 runs) before being superseded by v3.

### [v3](benchmark-instructions-v3.md) — GitHub Actions Workflows

Narrowed to 8 tasks (11-18, all GHA-category). Changed modes to `default`, `powershell`, `bash`, `typescript-bun`. Each task now requires a working `.github/workflows/*.yml` file that passes `actionlint` and executes in Docker via `act`. All agent tests must run through the workflow pipeline. PostToolUse syntax/lint hooks enabled on all runs. 64 total runs.

See also: [v3 design plan](design-and-planning-artifacts/PLAN-v3-gha.md) and other [design artifacts](design-and-planning-artifacts/).

## What it Tests

Each benchmark version defines a set of scripting tasks, language modes, and models. Agents receive only a prompt — no conversation context or prior results. Each run produces scripts, tests, and (in v3) GitHub Actions workflows. Results are evaluated on:

- Whether the agent's own tests pass
- Code quality metrics (lines, errors, turns, cost)
- Actionlint validation and act execution (v3 only)
- PostToolUse hook effectiveness (v3 only)

## Files

| File | Purpose |
|------|---------|
| `benchmark-instructions-v*.md` | Per-version methodology, task definitions, prompt templates |
| `models.py` | Model IDs and token pricing ([single source of truth](models.py)) |
| `runner.py` | Benchmark harness — invokes `claude -p`, collects metrics |
| `generate_results.py` | Generates `results.md` reports from metrics; updates this README |
| `hooks/syntax-check.py` | PostToolUse hook for syntax/lint checking (v3) |
| `run-benchmark.sh` | One-command launcher with prerequisite checks |
| `results/` | Structured output — metrics.json, generated code, console logs per run |
| `workspaces/` | Temporary agent working directories (git-ignored) |
| `AGENTS.md` | Agent instructions ([agents.md spec](https://agents.md)) |
| `skills/` | Agent skills ([agentskills.io spec](https://agentskills.io/specification)) |
| `design-and-planning-artifacts/` | Historical planning docs, v1 analysis, superseded files |

## Benchmark Runs

<!-- BEGIN BENCHMARK RUNS -->
| Run | Version | Runs | Cost | Results |
|-----|---------|------|------|---------|
| **2026-04-09_152435** (latest) | ? | 12/? | — | [results.md](results/2026-04-09_152435/results.md) |
| 2026-04-08_192624 | [v3](benchmark-instructions-v3.md) | 64/64 | $85.10 | [results.md](results/2026-04-08_192624/results.md) |
| 2026-04-08_180614 | ? | 2/? | — | [results.md](results/2026-04-08_180614/results.md) |
| 2026-04-08_180255 | ? | 0/? | — | [results.md](results/2026-04-08_180255/results.md) |
| 2026-04-08_174516 | ? | 1/? | — | [results.md](results/2026-04-08_174516/results.md) |
| 2026-04-08_170920 | ? | 4/? | — | [results.md](results/2026-04-08_170920/results.md) |
| 2026-04-08_170824 | ? | 0/? | — | — |
| 2026-04-08_161536 | ? | 7/? | — | [results.md](results/2026-04-08_161536/results.md) |
| 2026-04-08_114024 | ? | 3/? | — | [results.md](results/2026-04-08_114024/results.md) |
| 2026-04-08_113116 | ? | 1/? | — | [results.md](results/2026-04-08_113116/results.md) |
| 2026-04-07_225702 | [v2](benchmark-instructions-v2.md) | 111/144 | $75.38 | [results.md](results/2026-04-07_225702/results.md) |
| 2026-04-02_181500 | [v1](benchmark-instructions-v1.md) | 4/1 | $8.90 | [results.md](results/2026-04-02_181500/results.md) |
| 2026-04-02_163146 | [v1](benchmark-instructions-v1.md) | 144/144 | $436.67 | [results.md](results/2026-04-02_163146/results.md) |
<!-- END BENCHMARK RUNS -->

## Running a Benchmark

```bash
git clone https://github.com/Adam-S-Daniel/compare-agent-scripting-by-language.git
cd compare-agent-scripting-by-language

# Ensure claude CLI is installed and authenticated
# Then run:
./run-benchmark.sh
```

To resume a crashed/interrupted run:
```bash
./run-benchmark.sh --resume 2026-04-02_181500
```

To regenerate all results reports:
```bash
python3 generate_results.py --all
```
