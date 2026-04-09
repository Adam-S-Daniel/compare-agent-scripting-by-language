# Language Mode Insights — Why Do Different Modes Cost Different Amounts?

Each language mode imposes a different "tax" on the agent. This document digs into the transcripts to explain *why* — not just surface-level metrics, but the specific behavioral patterns that drive cost, duration, and error counts.

---

## The Cost Ladder

| Mode | Avg Cost | vs Default | Primary Cost Driver |
|---|---|---|---|
| Default (Python) | $2.50 | baseline | Permission-denial retry loops |
| PowerShell | $2.63 | 1.05x | Similar to default; sometimes cheaper |
| PowerShell Strict | $3.33 | 1.33x | Strict mode violations → extra debugging |
| C# Script | $4.18 | 1.67x | dotnet scaffolding overhead before any code |

> But these averages hide enormous per-task variance. PowerShell is cheaper than default on 14 of 36 task/model pairs. C# is >2x more expensive on 13 of 34 pairs.

---

## Default Mode: The Python Baseline

**What happens**: Both models choose Python in 35 of 36 runs (Opus picked JavaScript once). Python's zero-setup advantage means the agent writes code on its **first productive turn** — typically by turn 4-5.

**Characteristic pattern**:
```
Turn 2: Bash(ls workspace)
Turn 3: "I'll use Python with pytest."
Turn 4: Write(test_*.py, 174 lines avg)     ← first code, right away
Turn 5: Bash(python -m pytest ...)           ← ERROR: requires approval
Turn 6: Bash(python -m pytest ...)           ← ERROR (retry loop begins)
...
```

**Why it's the cheapest**: Python needs no project scaffolding, no package restore, no compilation step. The agent goes directly from "read instructions" to "write code." The only overhead is the permission-denial retry loop when trying to run tests.

**The permission tax**: Even in default mode, permission denials dominate the error breakdown (89-100% of all errors). The agent repeatedly tries to run `python -m pytest` or `python3 script.py` and gets blocked by the benchmark harness's tool-approval system. This is a benchmark artifact, not a language issue — but it does interact differently with each model:

- **Opus retries 20-40x** before changing strategy
- **Sonnet retries 2-4x** then pivots (tries a different command, or just moves on to writing more code)

**Key insight**: Default mode's advantage isn't that Python is "better" — it's that Python requires zero overhead before the first line of code. Every turn spent on scaffolding is a turn that could hit a permission wall.

---

## PowerShell: Surprisingly Competitive

**What happens**: The agent writes `.ps1` files with Pester test framework. Like Python, PowerShell is available in the benchmark environment and needs minimal setup.

**Characteristic pattern**:
```
Turn 2: Bash(ls workspace)
Turn 3: Bash(pwsh --version)                 ← verify pwsh exists
Turn 4: Read(benchmark-instructions-v1.md)
Turn 5: "I'll use PowerShell with Pester."
Turn 6: Write(Test-*.ps1, 193 lines avg)     ← first code by turn ~7
Turn 7: Bash(pwsh -Command "Invoke-Pester")  ← ERROR: requires approval
...
```

**Why it sometimes BEATS default**:

PowerShell was cheaper than Python (default) in **14 of 36** task/model pairs. The biggest wins:

| Task | Model | PS Cost | Default Cost | Savings |
|---|---|---|---|---|
| dependency-license-checker | sonnet | $0.59 | $1.18 | **51% cheaper** |
| test-results-aggregator | opus | $3.10 | $4.97 | **38% cheaper** |
| csv-report-generator | opus | $3.04 | $4.92 | **38% cheaper** |
| process-monitor | sonnet | $1.10 | $1.60 | **31% cheaper** |

**Why does this happen?** When the agent is constrained to PowerShell, it can't deliberate about language choice or tool setup — it just starts writing. The constraint removes decision-making overhead. In Python default mode, the agent sometimes:
- Spends turns debating language choice
- Creates virtual environments or installs packages
- Sets up more complex project structures (multiple modules, __init__.py)

PowerShell's simpler ecosystem (single .ps1 file + Pester) means fewer turns before productive code.

**Key insight**: Language *constraints* can be *freeing* — by eliminating choice, the agent avoids the meta-work of deciding how to structure the project.

**First-write comparison**:
- Default (Python): avg 174 lines, first write at turn 10.6
- PowerShell: avg 193 lines, first write at turn 16.5

PowerShell starts slightly later (turns spent checking `pwsh --version`), but writes slightly more code in the first file.

---

## PowerShell Strict: The Debugging Tax

**What happens**: Same as PowerShell, but the agent is instructed to use `Set-StrictMode -Latest`. This enables stricter variable checking, undefined variable errors, and property-not-found errors.

**Characteristic pattern**:
```
Turn 6: Write(Module.psm1)
        # Includes: Set-StrictMode -Version Latest
Turn 8: Bash(pwsh -Command "Invoke-Pester")  ← ERROR: permission
...
(When tests finally run, strict mode catches things regular PS doesn't)
Turn 40: Bash(pwsh ...)
         ERROR: PropertyNotFoundException: The property 'Name' cannot be found
Turn 41: Edit(Module.psm1)  ← fix the strict-mode violation
Turn 42: Bash(pwsh ...)
         ERROR: another strict-mode violation
...
```

**The strict-mode cost multiplier**: Strict mode is 1.33x the cost of default and 1.27x the cost of regular PowerShell, but the premium varies wildly:

| Task | Model | PS Cost | PS-Strict Cost | Multiplier |
|---|---|---|---|---|
| dependency-license-checker | sonnet | $0.59 | $2.20 | **3.8x** |
| semantic-version-bumper | opus | $3.84 | $7.96 | **2.1x** |
| multi-file-search-replace | sonnet | $1.17 | $2.41 | **2.1x** |

**Why strict mode hurts**: Strict mode turns runtime lenience into runtime errors. Code that "works" in regular PowerShell — like accessing a property that doesn't exist on an object, or using an uninitialized variable — throws exceptions in strict mode. The agent then enters fix→retry→fix cycles:

1. Write code that works conceptually
2. Strict mode catches an edge case (e.g., `$null.Property` access)
3. Fix that specific line
4. Run again, strict mode catches a different edge case
5. Repeat

This pattern adds 1.3x more turns and 1.3x more errors compared to regular PowerShell. The errors compound with the existing permission-denial retry overhead.

**Key insight**: Strict mode acts as a stricter type checker — it catches real bugs but each catch costs multiple agent turns. In a cost-sensitive environment, the debugging overhead outweighs the code quality benefit.

---

## C# Script: The Scaffolding Trap

**What happens**: C# requires a complete project structure (.csproj, NuGet package references, namespace declarations) before a single line of business logic. This creates a massive scaffolding overhead that dominates the early turns.

**The critical bottleneck — dotnet CLI permission denials**:

```
Turn 2: Bash(dotnet --version)             ← ERROR: requires approval
Turn 3: Bash(dotnet --version)             ← ERROR (retry)
Turn 4: Bash(dotnet --version)             ← ERROR (retry)
...
Turn 15: Bash(dotnet new xunit -n Tests)    ← ERROR: requires approval
Turn 16: Bash(dotnet new xunit -n Tests)    ← ERROR (retry)
...
Turn 30: Write(Tests.csproj, 18 lines)      ← finally gives up on dotnet CLI
```

**C# scaffolding requires far more pre-code turns**:

| Mode | Avg turn of first code write | Avg first-write size |
|---|---|---|
| Default (Python) | Turn 10.6 | 174 lines |
| PowerShell | Turn 16.5 | 193 lines |
| PowerShell Strict | Turn 15.2 | 201 lines |
| **C# Script** | **Turn 39.8** | **21 lines** |

The agent doesn't write any code until turn 40 on average — and when it does, the first file is a 21-line `.csproj` project definition, not actual code. The first actual `.cs` file doesn't appear until much later.

**The scaffolding sequence**:

A typical C# run does this before writing any business logic:

1. **Check for dotnet CLI** (5-60 turns of `dotnet --version` retries)
2. **Try `dotnet new`** to scaffold a project (10-20 more denied retries)
3. **Give up on CLI, manually write .csproj** (the XML project file)
4. **Write a second .csproj** for the test project
5. **Add NuGet package references** (xUnit, Moq, etc.)
6. **Create directory structure** (`mkdir -p src/ tests/`)
7. **Finally write the first .cs test file**

This sequence burns 30-100 turns before a single line of business logic exists. Compare to Python, where the agent writes a working test file on turn 4-5.

**Opus is especially punished by C# scaffolding**:

Opus gets trapped in dotnet CLI retry loops far longer than Sonnet:

| Metric | C# Opus | C# Sonnet |
|---|---|---|
| Avg first .cs code file | Turn 75 | Turn 22 |
| Total turns | 148 | 78 |
| Cost per task | $5.55 | $2.81 |

Opus often spends 60+ turns retrying `dotnet --version` and `dotnet new xunit` before accepting that the CLI requires approval and falling back to manual .csproj writing. Sonnet tries 3-5 times, then immediately writes the .csproj by hand.

**Some Opus runs attempt to INSTALL dotnet from scratch**:

In several tasks, Opus creates `install-dotnet.sh` scripts as its first Write (6 of 18 Opus C# runs). It tries to download and install the .NET SDK from Microsoft's servers before realizing this won't work either. These runs have the highest costs:

```
Turn 63: Write(install-dotnet.sh, 6 lines)   ← first "code" is an install script
Turn 64: Bash(chmod +x install-dotnet.sh && ./install-dotnet.sh)
         ERROR: requires approval
...
Turn 95: Write(Tests.csproj, 17 lines)        ← finally gives up and scaffolds manually
```

**The verbosity factor**:

C# code is inherently more verbose than Python, but this matters less than you'd think:

| Mode | Lines of code (Opus avg) | Lines of code (Sonnet avg) |
|---|---|---|
| Default | 606 | 755 |
| C# Script | 14,454* | 1,258 |

*The Opus C# number is inflated by one extreme outlier. The correlation between lines of code and cost is only r=0.08 — lines don't drive cost, turns do.

C# verbosity shows up in:
- Boilerplate: `namespace`, `using` statements, class declarations, explicit types
- Project files: `.csproj` XML, `global.json`, `.editorconfig`
- Multiple files: C# convention puts each class in its own file (avg 5-8 files vs 2-4 for Python)

But this boilerplate is a small fraction of the total token budget compared to the scaffolding/retry overhead.

**Key insight**: C#'s cost isn't about writing more code — it's about the 30-100 turns spent trying to interact with the dotnet CLI before writing any code at all. In an environment where CLI commands require approval, languages that need CLI tooling for project setup (dotnet, npm, cargo) are at a structural disadvantage versus languages where you can just write a `.py` file and run it.

---

## Cross-Mode Patterns

### The permission-denial multiplier varies by language

All modes suffer from the same benchmark artifact (tool-permission denials), but they interact differently:

| Mode | What gets denied | Impact |
|---|---|---|
| Default | `python -m pytest` | Moderate — agent eventually runs `python3 script.py` |
| PowerShell | `pwsh -Command "Invoke-Pester"` | Moderate — similar to Python |
| PowerShell Strict | Same as PS + strict-mode runtime errors | Higher — two types of errors compound |
| C# Script | `dotnet --version`, `dotnet new`, `dotnet test`, `dotnet restore` | **Severe** — every project lifecycle command is denied |

C# is uniquely punished because it needs CLI interaction not just for *testing* but for *project creation* and *dependency resolution*. Python and PowerShell can write code with zero CLI interaction.

### When to choose each mode (from this benchmark data)

| Scenario | Best Mode | Why |
|---|---|---|
| Minimize cost | Default (Python) | Zero setup, fewest turns to first code |
| Simple scripting tasks | PowerShell (sometimes) | Constraint removes decision overhead; 14/36 runs beat default |
| Code correctness matters | PowerShell Strict | Catches real bugs, but at 1.3x cost premium |
| C# ecosystem required | C# Script | Only use when you specifically need .NET |

### The environment matters more than the language

The single biggest finding: **88-89% of all errors across every mode are permission denials** — the same benchmark artifact. The true language-specific differences (strict mode violations, dotnet scaffolding, Pester framework issues) are <12% of errors. In a real-world environment with full permissions:

- C#'s scaffolding overhead would drop dramatically (one `dotnet new` instead of 30 retries)
- All modes would have far fewer turns (no retry loops)
- The cost differences would likely narrow significantly

The benchmark amplifies language-specific friction through the permission-denial mechanism: languages that need more CLI interaction generate more denial events, each of which triggers a retry loop.

---

## Summary Table

| Factor | Default (Python) | PowerShell | PS Strict | C# Script |
|---|---|---|---|---|
| First code write | Turn 10.6 | Turn 16.5 | Turn 15.2 | Turn 39.8 |
| First write size | 174 lines | 193 lines | 201 lines | 21 lines (.csproj) |
| First .cs/.py file | Turn 10.6 | N/A | N/A | Turn 47 (avg) |
| CLI commands needed | 0 before coding | 1 (pwsh --version) | 1 (pwsh --version) | 3-5 (version, new, restore) |
| Permission-denial % | 99% | 89% | 88% | 89% + dotnet-specific |
| Scaffolding files | 0 | 0 | 0 | 2-3 (.csproj, global.json) |
| Language-specific errors | ~0 | ~0 | 6% strict violations | 1% dotnet tooling |
| Cost multiplier vs default | 1.0x | 1.05x | 1.33x | 1.67x |
