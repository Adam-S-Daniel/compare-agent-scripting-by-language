# Benchmark v2 — Current Status & Context

**Last updated**: 2026-04-08
**Run directory**: `results/2026-04-07_225702/`

---

## What This Project Is

A benchmark comparing how Claude Code agents perform scripting tasks across different language constraints and models. 18 scripting tasks × N language modes × 2 models (Opus, Sonnet). Each run is an isolated Claude Code agent that receives a prompt and works autonomously.

## Benchmark v1 → v2 Changes

v1 (in `results/2026-04-02_163146/`) had two major artifacts that dominated the data:
1. **Permission denials** — 88-89% of ALL errors were the benchmark harness blocking tool use. Opus retried 20-40x per denial vs Sonnet 2-4x.
2. **C# scaffolding trap** — Agents spent 30-100 turns trying to create .csproj files before writing any code.

v2 fixes:
- `--dangerously-skip-permissions` flag eliminates permission denials
- .NET 10 file-based apps (`dotnet run file.cs`) eliminates .csproj scaffolding
- Pre-installed runtimes (pwsh, Pester, .NET 10 SDK) — no tool installation overhead
- `DOTNET_ROOT` and `PATH` injected via `subprocess.run(env=...)` in runner.py (line ~857)

## Current State of v2 Runs

### Completed (108 runs)
| Mode | Opus | Sonnet | Status |
|---|---|---|---|
| default (Python) | 18 ✅ | 18 ✅ | Done |
| powershell | 18 ✅ | 18 ✅ | Done |
| powershell-strict | 18 ✅ | 18 ✅ | Done |

### C# Script (partially complete, stopped)
- 3 runs completed with the "pro tips" prompt (01-csv-report-generator opus+sonnet, 02-log-file-analyzer opus)
- **Stopped** to redesign with hooks-based syntax checking
- Previous C# results were deleted and restarted fresh with the pro-tips prompt
- The prompt includes tips about file ordering (CS8803), single-file isolation (CS0103), etc.

### Key files modified for v2
- `runner.py` lines 23-24: `INSTRUCTIONS_FILE = "benchmark-instructions-v2.md"`, `INSTRUCTIONS_VERSION = "v2"`
- `runner.py` line 848: `"--dangerously-skip-permissions"` replaces `"--permission-mode", "acceptEdits"` + `"--allowedTools"`
- `runner.py` line 312: C# example braces escaped `{{ }}` for `.format()` compatibility (was causing FATAL ERROR on all C# runs)
- `runner.py` lines 856-861: `env` dict with `DOTNET_ROOT` and `PATH` passed to `subprocess.run`
- `runner.py` lines 298-319: C# prompt template with pro tips about file ordering, single-file compilation
- `run-benchmark.sh`: Complete rewrite with pre-installation of pwsh, Pester, .NET 10 SDK
- `run-benchmark.sh` lines 22-29: Claude CLI test updated to handle JSON array output format
- `benchmark-instructions-v2.md`: Created from v1, added changelog, pre-installed tools section, C# pro tips

## v2 Early Results (108 runs)

| Metric | v1 (144 runs) | v2 (108 runs, no C#) |
|---|---|---|
| Avg errors/task | ~90-150 | 0.5 |
| Opus avg turns | 148 | ~25 |
| Sonnet avg turns | 46 | ~17 |
| Opus-Sonnet cost ratio | 3.4x | 2.5x |
| Total cost | ~$437 | $75.38 (108 runs) |

Duration by mode (v2):
- Default: mean 195s, median 181s
- PowerShell: mean 237s, median 219s
- PS-Strict: mean 327s, median 272s
- 83-87% of wall time is API calls, not tool execution

## Planned New Language Modes

### Decided
1. **typescript-bun** — `bun run app.ts`, `bun test` (built-in). Zero config like Python but typed. Bun 1.3.11 already installed.
2. **fsharp-script** — `dotnet fsi app.fsx`. Functional paradigm, interpreted (no build step). .NET 10 already installed.
3. **bash** — `bash script.sh` with bats testing framework. Control case for "is this really a scripting task?"

### Rationale
- Bun TS fills the gap between Python (dynamic, zero-setup) and C# (typed, high-setup)
- F# tests functional paradigm + agent unfamiliarity
- Bash tests which tasks are truly "scripting" vs "software engineering"

### Other candidates considered but deferred
- TypeScript via Node (overlaps with Bun but adds npm install overhead)
- Go (interesting but needs installation)
- Ruby (similar to Python, lower insight value)
- Perl (already installed but too niche)
- Deno (overlaps with Bun)

## Hooks-Based Syntax Checking (In Progress)

### The idea
Use Claude Code's PostToolUse hooks to automatically run syntax/type checkers when the agent writes code files. The diagnostics appear as `additionalContext` before the agent's next turn — saving the write→run→error→fix cycle.

### Implementation status
- **Hook script created**: `hooks/syntax-check.py` — works, tested
  - C#: `dotnet build file.cs` → catches CS errors
  - TypeScript: `bunx tsc --noEmit file.ts` → catches TS type errors
  - F#: `dotnet fsi file.fsx` → catches FS errors
  - PowerShell: `Invoke-ScriptAnalyzer` → catches PS analyzer warnings (needs PSScriptAnalyzer installed)
- **Old shell version**: `hooks/syntax-check.sh` — superseded by .py version, can be deleted

### How it would work in the runner
For "checked" mode variants (e.g., `csharp-script-checked`), the runner would create a `.claude/settings.json` in the workspace directory with:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "python3 /absolute/path/to/hooks/syntax-check.py",
            "timeout": 15
          }
        ]
      }
    ]
  }
}
```

### NOT YET DONE
- Integration into `runner.py` (adding checked mode variants, workspace hook config setup)
- Testing that hooks actually work with `claude -p` (prompt mode)
- PSScriptAnalyzer installation for PowerShell checking
- Adding new modes (typescript-bun, fsharp-script, bash) to runner.py

## Test Suite Quality Evaluation

Four approaches discussed for evaluating test quality across runs:
1. **Structural metrics** (count tests, assertions, test-to-code ratio) — **Implemented** in `test_quality.py`
2. **Mutation testing** (mutmut for Python, Stryker for C#) — gold standard, expensive. Not started.
3. **LLM-as-judge** (send code + tests + task spec to Claude for scoring) — **Implemented** in `test_quality.py`
4. **Cross-validation** (run tests from run A against implementation from run B) — clever but complex. Not started.

### Implementation details (approaches 1 & 3)

- **`test_quality.py`** — standalone module, also imported by `generate_results.py`.
  - `compute_structural_metrics(generated_code_dir)` — language-aware counting of tests,
    assertions, test-to-code ratio. Supports Python, TypeScript/Bun, PowerShell/Pester,
    and Bash/bats (including custom test harness patterns used by Opus).
  - `evaluate_with_llm(task_desc, impl_code, test_code, provider_name)` — sends code
    to an LLM for scoring on coverage, rigor, design, and overall quality (1-5 scale).
    Uses a pluggable provider via `llm_providers.py`. Results cached per run in
    `test-quality-llm.json`.
- **`llm_providers.py`** — pluggable LLM provider abstraction. The benchmark runner
  (`runner.py`) is inherently Claude CLI-based, but evaluation tasks use this provider
  layer so alternative LLM access methods can be added cleanly.
  - Current provider: `claude-cli` (pre-authenticated Claude Code CLI, no API key needed).
  - See docstring in `llm_providers.py` for instructions on adding new providers.
- **`generate_results.py`** — new "Test Quality Evaluation" section in results.md:
  - Structural Metrics by Language/Model/Effort (aggregate table + sorted variants)
  - Per-run structural metrics (collapsible)
  - LLM-as-Judge Scores with explanations (aggregate + per-run, shown only when cached scores exist)

### LLM-as-Judge scoring dimensions

- **Coverage** (1-5): Do tests exercise the key requirements? 1 = most untested, 5 = all covered.
- **Rigor** (1-5): Edge cases, error handling, boundary conditions? 1 = happy path only, 5 = thorough.
- **Design** (1-5): Test organization, fixtures, readability? 1 = messy/brittle, 5 = well-structured.
- **Overall** (1-5): Holistic quality — primary ranking metric. Would you trust this suite to catch regressions?

### Usage

```bash
# Structural metrics only (runs during report generation)
python3 test_quality.py results/2026-04-08_192624

# LLM-as-judge evaluation (requires --provider; default: claude-cli)
python3 test_quality.py --llm-judge --provider claude-cli results/2026-04-08_192624

# Regenerate reports (structural metrics auto-included, LLM scores from cache)
python3 generate_results.py --all
```

## File Layout

```
runner.py                          — Main benchmark runner (1219 lines)
run-benchmark.sh                   — Setup script (installs runtimes, launches runner)
test_quality.py                    — Test quality evaluation (structural metrics + LLM-as-judge)
llm_providers.py                   — Pluggable LLM provider abstraction for evaluation tasks
benchmark-instructions-v1.md       — Original instructions (v1)
benchmark-instructions-v2.md       — Updated instructions (v2)
hooks/syntax-check.py              — PostToolUse hook for syntax checking (tested, working)
hooks/syntax-check.sh              — Old shell version (superseded)
analysis.ipynb                     — Jupyter notebook with v1 analysis (48 cells)
language-mode-insights.md          — Deep analysis of why each mode costs differently
write-more-iterate-less.md         — Opus vs Sonnet strategy comparison with transcript examples
results/2026-04-02_163146/         — v1 benchmark results (144 runs, complete)
results/2026-04-07_225702/         — v2 benchmark results (108 complete + 3 C# runs)
workspaces/                        — Isolated agent workspace directories
```

## v3 Implementation (2026-04-08, branch `gha-benchmark-v3`)

**See `PLAN-v3-gha.md` for original plan. See `benchmark-instructions-v3.md` for current spec.**

v3 pivots from general scripting to GitHub Actions workflow authoring:
- **Tasks**: Only 11-18 (GHA-category tasks)
- **Modes**: default, powershell, bash, typescript-bun (dropped c#, powershell-strict)
- **Hooks**: PostToolUse syntax/lint hooks on all modes (.py, .sh, .ts, .ps1, .yml via actionlint)
- **Validation**: actionlint + `act` execution in Docker — all agent tests must run through the GHA pipeline
- **Key artifact**: `act-result.txt` — mandatory proof that the workflow ran with correct outputs
- **Metrics**: Per-tool-use timing via real-time Popen streaming, actionlint pass rates, hook effectiveness
- **Branch**: `gha-benchmark-v3`
- **Estimated runs**: 8 tasks × 4 modes × 2 models = 64 runs

### Phases completed
1. Infrastructure: actionlint, shellcheck, bats-core installed
2. Hooks: syntax-check.py extended for .py, .sh, .yml
3. Runner: new modes, GHA prompt addendum, workspace hook setup, Popen streaming
4. Instructions: benchmark-instructions-v3.md created
5. Pilot runs: task 11 tested across modes, iterating on prompt design

### Key design decisions made during implementation
- All tests must run through `act` — no direct script testing
- No `.github/workflows/` at repo root (only in agent workspaces)
- Only spawned agents fix their own YAML (runner observes, never intervenes)
- Runner's independent `act push` removed — agent's `act-result.txt` is ground truth
- MCP servers disabled on agent instances (--strict-mcp-config)
- Git push squashing removed (caused repo corruption under concurrent access)

### To Resume: Next Steps

1. Complete pilot run: task 11 × 4 modes × 2 models
2. Run analysis notebook on results
3. Full run: tasks 11-18 × 4 modes × 2 models = 64 runs
4. Cross-mode analysis of actionlint pass rates, act success rates, hook effectiveness
