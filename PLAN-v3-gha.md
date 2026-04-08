# Plan: v3 — GitHub Actions Benchmark

**Branch:** `gha-benchmark-v3`
**Date:** 2026-04-08
**Status:** Planning — not yet implemented

---

## Goal

Test how well Claude Code agents can write **real GitHub Actions workflows + supporting scripts** across language modes, validated with `actionlint` and optionally `act`.

## Scope Changes from v2

| | v2 | v3 |
|---|---|---|
| **Tasks** | 18 (general scripting) | 8 (tasks 11-18, all GHA-category) |
| **Modes** | default, powershell, powershell-strict, csharp-script | default, powershell, bash, typescript-bun |
| **Models** | opus, sonnet | opus, sonnet |
| **Hooks** | None (prototype only) | syntax/lint hooks on all modes |
| **Validation** | Tests pass (agent-reported) | Tests pass + `actionlint` on any .yml in `.github/workflows/` |
| **Total runs** | 144 | 8 tasks × 4 modes × 2 models = 64 runs |

## Task Redesign (Tasks 11-18)

These tasks already have GHA-themed descriptions but currently produce standalone scripts. For v3, each prompt should require the agent to produce:

1. **A working GitHub Actions workflow** (`.github/workflows/<name>.yml`) that uses the script
2. **The script itself** in the constrained language
3. **Tests** for the script logic (same as v2)

The workflow doesn't need to be runnable (no real repo context), but it must pass `actionlint` static analysis. This tests whether the agent can produce valid workflow YAML alongside the implementation.

### Task-by-Task Prompt Adjustments

| # | Task | What the workflow should do |
|---|---|---|
| 11 | Semantic Version Bumper | Triggered on push to main, runs the version bump script, commits the result |
| 12 | PR Label Assigner | Triggered on `pull_request`, reads changed files via `github.event`, runs label script |
| 13 | Dependency License Checker | Triggered on `pull_request` or schedule, runs compliance check, posts comment |
| 14 | Docker Image Tag Generator | Triggered on push/PR/tag, generates tags, outputs them as step outputs |
| 15 | Test Results Aggregator | Triggered after matrix build, downloads artifacts, runs aggregation, posts summary |
| 16 | Environment Matrix Generator | Reusable workflow or composite action that outputs a matrix JSON |
| 17 | Artifact Cleanup Script | Triggered on schedule, runs cleanup with dry-run option via input |
| 18 | Secret Rotation Validator | Triggered on schedule, runs validation, creates issue if secrets expiring |

### Key Prompt Change

Each prompt gets an additional requirement block:

```
GITHUB ACTIONS REQUIREMENT:
In addition to the script and tests, create a GitHub Actions workflow file at
.github/workflows/<task-name>.yml that would use your script in a real CI/CD pipeline.
The workflow must:
- Use appropriate trigger events (push, pull_request, schedule, workflow_dispatch, etc.)
- Reference your script correctly
- Pass actionlint validation (valid YAML, valid action references, correct syntax)
- Include appropriate permissions, environment variables, and job dependencies

The workflow does NOT need to actually run — it just needs to be syntactically valid
and demonstrate how your script would be integrated into a CI/CD pipeline.
```

## Language Modes

### Kept
- **default** — Agent picks language (almost always Python). Baseline.
- **powershell** — Tests non-default but well-known scripting language.

### Added
- **bash** — `bash script.sh` with testing via `bats-core` (or agent can use plain bash test scripts). The "is this really just a shell script?" control case.
- **typescript-bun** — `bun run app.ts`, `bun test` (built-in test runner). Zero config like Python but typed. Bun 1.3.11 already installed.

### Removed
- **powershell-strict** — Interesting data but v2 showed it's mostly just "powershell but 1.7x slower due to type annotation overhead." Not enough incremental insight for v3's tighter scope.
- **csharp-script** — Too many compilation/scaffolding artifacts. Not a natural GHA scripting language.

## Hooks — Syntax/Lint Checking

The existing `hooks/syntax-check.py` PostToolUse hook will be integrated into the runner for all modes. Additionally, a **new `actionlint` hook** will validate workflow YAML on every Write/Edit.

### Hook Architecture

```
hooks/
  syntax-check.py      — existing, handles .cs/.ts/.fsx/.ps1 files
  gha-lint-hook.py     — NEW, runs actionlint on .yml files in .github/workflows/
```

Or: extend `syntax-check.py` to also handle `.yml` files with `actionlint`.

### Per-Mode Checking

| File Extension | Checker | Already in syntax-check.py? |
|---|---|---|
| `.py` | `python -m py_compile` or `ruff check` | No — add |
| `.ps1` | `Invoke-ScriptAnalyzer` | Yes |
| `.sh` | `shellcheck` (if available) or `bash -n` | No — add |
| `.ts` | `bunx tsc --noEmit` | Yes |
| `.yml` (in `.github/workflows/`) | `actionlint` | No — add |

### Runner Integration

For each run, the runner creates `.claude/settings.json` in the workspace:

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

## Post-Run Validation

After each agent run, the runner should:

1. **Find workflow files**: glob `workspace/.github/workflows/*.yml`
2. **Run `actionlint`** on each workflow file
3. **Record results** in metrics under `quality.actionlint_errors` and `quality.actionlint_pass`
4. **Run agent's tests**: execute the test command and record pass/fail

This gives us two quality dimensions per run:
- Did the agent's own tests pass?
- Did the workflow YAML pass static analysis?

## Implementation Steps

### Phase 1: Infrastructure (do first, enables everything else)

1. **Install `actionlint`** — single binary, no dependencies
   ```bash
   # Download actionlint binary
   curl -sL "https://github.com/rhysd/actionlint/releases/latest/download/actionlint_$(uname -s)_$(uname -m | sed 's/x86_64/amd64/').tar.gz" | tar xz -C /usr/local/bin actionlint
   # OR without sudo:
   mkdir -p ~/.local/bin && curl -sL ... | tar xz -C ~/.local/bin actionlint
   ```

2. **Install `shellcheck`** — for bash syntax checking
   ```bash
   # Usually available via apt or snap
   sudo apt-get install shellcheck
   # OR download binary
   ```

3. **Install `bats-core`** — for bash testing
   ```bash
   npm install -g bats
   # OR git clone + install
   ```

4. **Verify bun** — already installed at 1.3.11

### Phase 2: Hook Script Updates

5. **Extend `hooks/syntax-check.py`** to handle:
   - `.py` → `python3 -m py_compile file.py`
   - `.sh` → `bash -n file.sh` (syntax check) + `shellcheck file.sh` (lint, if available)
   - `.yml` → `actionlint file.yml` (only if path contains `.github/workflows/`)

### Phase 3: Runner Changes

6. **Update `PROMPT_TEMPLATES`** in runner.py:
   - Add `bash` and `typescript-bun` templates
   - Remove `csharp-script` and `powershell-strict` templates
   - Add GHA workflow requirement to ALL templates for tasks 11-18
   - Keep task descriptions for 11-18 as-is (they're already GHA-themed)

7. **Add GHA-specific prompt addendum** — a function that appends the workflow YAML requirement to the prompt when the task is in the GHA category (tasks 11-18)

8. **Update `--modes` default** to `default,powershell,bash,typescript-bun`

9. **Add workspace hook setup** — in `run_single_task()`, create `.claude/settings.json` in the workspace directory before launching the agent

10. **Add post-run `actionlint` validation** — after the agent finishes, find any `.github/workflows/*.yml` and run `actionlint`, store results in metrics

11. **Update `LANGUAGE_EXTENSIONS`** — ensure `.sh` → `bash`, `.yml` → `yaml` are present

12. **Update `run_single_task()`** language detection for new modes

### Phase 4: Instructions & Docs

13. **Create `benchmark-instructions-v3.md`** — updated for GHA focus, new modes, new pre-installed tools

14. **Update `INSTRUCTIONS_FILE` and `INSTRUCTIONS_VERSION`** in runner.py

### Phase 5: Run

15. **Pilot run** — 2 tasks × 4 modes × 1 model = 8 runs to validate everything works
16. **Full run** — 8 tasks × 4 modes × 2 models = 64 runs
17. **Analysis** — compare actionlint pass rates, test pass rates, cost, turns across modes

## Estimated Cost

Based on v2 data (where non-C# runs averaged ~$0.40/run for Opus, ~$0.10/run for Sonnet):
- 32 Opus runs × $0.40 = ~$12.80
- 32 Sonnet runs × $0.10 = ~$3.20
- **Total estimate: ~$16** (may be higher with workflow complexity)
- GHA tasks may cost 1.5-2x more due to extra YAML authoring → estimate $24-32

## Key Questions / Decisions

1. **Should we also run tasks 1-10 with the new modes (bash, typescript-bun)?**
   - Pro: More data points for mode comparison
   - Con: 10 more tasks × 4 modes × 2 models = 80 more runs, ~$40 more
   - Recommendation: Defer to after v3 GHA results are analyzed

2. **Should we compare hooked vs unhooked runs?**
   - Pro: Measures hook impact directly
   - Con: Doubles the run count (128 runs)
   - Recommendation: Run all with hooks. Compare v3 (hooked) vs v2 (unhooked) for default+powershell overlap on tasks 11-18

3. **Should `actionlint` pass be a hard success criteria or just a metric?**
   - Recommendation: Just a metric. Record it, compare across modes, but don't fail the run

4. **How to handle the workflow file requirement in prompts?**
   - Option A: Bake into each mode's prompt template (duplicated text)
   - Option B: Append as a separate block in `run_single_task()` when task category is "GitHub Actions"
   - Recommendation: Option B — cleaner, task-category-driven

## Files That Will Change

| File | Change |
|---|---|
| `runner.py` | New mode templates, GHA prompt addendum, hook setup, post-run actionlint, remove old modes |
| `hooks/syntax-check.py` | Add .py, .sh, .yml handlers |
| `benchmark-instructions-v3.md` | New (created from v2) |
| `run-benchmark.sh` | Add actionlint, shellcheck, bats installation |
| `STATUS.md` | Update with v3 plan |

## Session Strategy

This plan is designed to be implementable in chunks that can be checkpointed:

1. **Chunk 1** (this session or next): Phase 1 + 2 (install tools, update hooks) — pure infrastructure, low risk
2. **Chunk 2**: Phase 3 (runner changes) — the bulk of the work, testable with `--tasks 11 --modes default --models sonnet` 
3. **Chunk 3**: Phase 4 (docs) — quick
4. **Chunk 4**: Phase 5 (run + analyze) — long-running, hands-off

Each chunk produces a committable state. If context runs out mid-chunk, the plan in this file plus STATUS.md provides full resumption context.
