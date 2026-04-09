# "Write More, Iterate Less" — Opus vs Sonnet Strategy Differences

This document illustrates the fundamental behavioral difference between Claude Opus 4.6 and Claude Sonnet 4.6 when completing the same scripting tasks in the benchmark. **Sonnet front-loads large, complete code artifacts in fewer turns, while Opus takes many small incremental steps** — often getting trapped in retry loops that burn tokens and cost.

## The Numbers

| Metric | Opus (avg) | Sonnet (avg) | Ratio |
|---|---|---|---|
| Turns per task | 148 | 46 | 3.2x |
| Output tokens per turn | ~250 | ~620 | 0.4x |
| Errors per task | 148 | 37 | 4.0x |
| Cost per task | $3.87 | $1.14 | 3.4x |
| Median cost ratio (paired) | — | — | 2.87x more for Opus |
| Sonnet wins on cost | — | — | 64 of 67 head-to-head matchups |

> Opus costs nearly 3x more for the same output — not because it thinks harder per turn, but because it takes **3x more turns** and gets trapped in permission-denial loops at a much higher rate.

---

## Example 1: Multi-File Search & Replace (Task 10)

**Opus**: 229 turns, 185 errors, $4.45  
**Sonnet**: 50 turns, 26 errors, $0.71 — **6.3x cheaper**

### Sonnet's approach: two big writes, done

Sonnet reads the instructions, then immediately writes a comprehensive 326-line test file importing 7 functions that don't exist yet:

```
Turn 3:  "I'll use Python with pytest, following strict red/green TDD."
Turn 4:  Write(test_search_replace.py, 326 lines)   ← entire test suite
Turn 14: Write(search_replace.py, 377 lines)         ← full implementation
Turn 25: Write(smoke_test.py, 87 lines)              ← bonus smoke test
```

The test file front-loads every feature in one shot — glob-pattern discovery, regex matching, preview mode, backup creation, replacement, and report generation:

```python
# Sonnet's first write: 326-line test file with full API surface
from search_replace import (
    find_files,
    find_matches,
    preview_matches,
    create_backup,
    perform_replace,
    generate_report,
    run_search_replace,
)

# ... 15 test classes covering every feature, written in one turn
```

### Opus's approach: tiny first step, then 60+ permission-denial retries

Opus writes a minimal 52-line test covering only the first feature (`find_files`), then tries to run it:

```
Turn 4:  Write(test_search_replace.py, 52 lines)  ← only glob matching
Turn 5:  Bash(python -m pytest test_search_replace.py -v)
         ERROR: This command requires approval
Turn 6:  Bash(python -m pytest test_search_replace.py -v)
         ERROR: This command requires approval
...
Turn 34: (still retrying the same command)
Turn 35: (gives up, tries python3 instead)
Turn 36: Bash(which python3 && python3 --version)
...
Turn 73: Write(run_tests.py, 5 lines)  ← workaround wrapper script
```

**Opus spent 60+ turns retrying a denied Bash command** before writing 5 more lines of code. Sonnet encountered the same permission denials but pivoted faster and wrote more code per productive turn.

---

## Example 2: Secret Rotation Validator (Task 18)

**Opus**: 174 turns, 88 errors, $3.43  
**Sonnet**: 50 turns, 19 errors, $0.58 — **5.9x cheaper**

### Sonnet: comprehensive test + implementation in 2 writes

```
Turn 5:  Write(test_secret_rotation.py, 283 lines)  ← full test suite
Turn 17: Write(secret_rotation.py, 192 lines)        ← complete implementation
Turn 36: Write(main.py, 114 lines)                   ← CLI entrypoint
```

Sonnet's first write immediately defines the full data model (`Secret`, `RotationStatus`), imports functions that don't exist yet, and covers edge cases:

```python
# Sonnet's 283-line test file, written in a single turn
from secret_rotation import (
    Secret, RotationStatus, classify_secret,
    generate_report, format_markdown, format_json,
)

def make_secret(name="db-password", last_rotated_days_ago=30, ...):
    """Helper to create a Secret with relative dates."""
    ...

# 12+ test methods covering classification, report generation,
# formatting, edge cases, and empty-state handling
```

### Opus: false start with TypeScript, then 80 productive turns in Python

Opus initially tries to scaffold a TypeScript project (4 config files over turns 19-21), hits permission walls trying to install npm packages, abandons that approach, switches to Python at turn 43, and then incrementally builds tests one at a time:

```
Turn 19: Write(package.json, 19 lines)       ← TypeScript scaffolding
Turn 20: Write(tsconfig.json, 13 lines)
Turn 21: Write(jest.config.js, 7 lines)
...
Turn 39: Bash(rm package.json tsconfig.json)  ← abandon TypeScript
Turn 43: Write(test_secret_config.py, 80 lines)  ← restart in Python
```

**Opus wasted 20 turns on a TypeScript approach that never produced any test or implementation code**, before pivoting to Python. Sonnet went straight to Python and wrote 283 lines of tests on its 5th turn.

---

## Example 3: Directory Tree Sync (Task 03)

**Opus**: 172 turns (122 non-stalled), 107 errors, $3.24  
**Sonnet**: 28 turns, 9 errors, $0.42 — **7.7x cheaper**

The most extreme case. Sonnet writes everything in 2 turns:

```
Turn 6:  Write(test_dirsync.py, 428 lines)  ← comprehensive test suite
Turn 15: Write(dirsync.py, 253 lines)       ← complete implementation
```

Opus starts with a 36-line test, then spends **43 consecutive turns** retrying `python -m pytest` against a permission wall:

```
Turn 5:  Write(test_dirsync.py, 36 lines)
Turn 6:  Bash(python -m pytest ...) → ERROR
Turn 7:  Bash(python -m pytest ...) → ERROR
...
Turn 47: (still retrying, 42 turns later)
Turn 48: Write(test_dirsync.py, 56 lines)   ← slightly expanded
...
Turn 91: Write(test_dirsync.py, 415 lines)  ← finally the full suite
Turn 93: Write(dirsync.py, 246 lines)
```

---

## Root Cause Analysis

The turn-count difference is driven by **three compounding factors**:

### 1. Front-loading vs incremental writing
Sonnet designs the full API surface mentally, then writes hundreds of lines in a single tool call. Opus follows strict incremental TDD — one small test, try to run it, then expand. This is arguably more methodical, but it **multiplies the number of tool calls** and creates more opportunities for permission denials.

### 2. Permission-denial recovery
Both models encounter the same tool-permission errors (the benchmark runs headless with `--dangerously-skip-permissions` but some Bash commands still get flagged). The critical difference:
- **Sonnet retries 2-4 times**, then pivots (uses a different tool, writes more code, or moves on)
- **Opus retries 20-40 times** on the same denied command before changing strategy

This is the single largest contributor to the turn and cost gap.

### 3. Technology choice false starts
In 2 of 18 tasks, Opus began with a language/framework (TypeScript, Node) that required package installation, hit permission walls during `npm install`, then restarted from scratch in Python. Sonnet chose Python directly in every default-mode run.

### The cost cascade

```
More turns → more context tokens → higher cache-read bills → higher cost
     ↑                                                           |
     └────── permission denials cause retry turns ←──────────────┘
```

The correlation matrix confirms this:
- **Turns ↔ Cost**: r = +0.94
- **Errors ↔ Turns**: r = +0.95
- **Errors ↔ Cost**: r = +0.90
- **Lines of code ↔ Cost**: r = +0.08 (essentially irrelevant)

**It's not how much code you write — it's how many turns you take to get there.**

---

## Summary

| Strategy | Opus | Sonnet |
|---|---|---|
| First test file | 36-80 lines (one feature) | 143-428 lines (full suite) |
| Approach | Strict incremental TDD | "Design it all, write it all" |
| Permission denial handling | Retry 20-40x | Retry 2-4x, then pivot |
| False starts | Occasional (TypeScript) | None observed |
| Productive turns | ~40 of ~170 | ~20 of ~50 |
| **Cost efficiency** | $3.87/task | $1.14/task |
