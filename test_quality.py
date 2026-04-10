#!/usr/bin/env python3
"""Test suite quality evaluation for benchmark runs.

Two evaluation approaches:
1. **Structural metrics** — fast, no external deps, always available.
   Counts tests, assertions, test-to-code ratio per generated code directory.
2. **LLM-as-judge** — sends code + tests + task spec to Claude for scoring.
   Requires ANTHROPIC_API_KEY. Results cached in test-quality-llm.json.

Usage:
    # Structural metrics only (always works, used by generate_results.py)
    python3 test_quality.py results/2026-04-08_192624

    # LLM-as-judge evaluation (requires ANTHROPIC_API_KEY)
    python3 test_quality.py --llm-judge results/2026-04-08_192624

    # Both, for all runs
    python3 test_quality.py --llm-judge --all
"""

import json
import os
import re
import sys
from pathlib import Path

from models import COST_PER_MTOK

# ---------------------------------------------------------------------------
# Language-aware file classification
# ---------------------------------------------------------------------------

TEST_FILE_PATTERNS = {
    "python": [r"test_.*\.py$", r".*_test\.py$", r"run_tests\.py$"],
    "typescript": [r".*\.test\.ts$", r".*\.spec\.ts$"],
    "powershell": [r".*\.Tests\.ps1$"],
    "bash": [r".*\.bats$", r"run_tests\.sh$"],
}

IMPL_FILE_PATTERNS = {
    "python": [r"(?!test_)(?!.*_test)(?!run_tests).*\.py$"],
    "typescript": [r"(?!.*\.test\.)(?!.*\.spec\.).*\.ts$"],
    "powershell": [r"(?!.*\.Tests\.).*\.ps1$"],
    "bash": [r"(?!.*\.bats$)(?!run_tests\.).*\.sh$"],
}

# Files to always skip (not code)
SKIP_PATTERNS = [
    r"act-result\.txt$",
    r"\.yml$", r"\.yaml$",
    r"\.json$", r"\.md$", r"\.txt$",
    r"__pycache__",
    r"node_modules",
    r"\.git/",
]


def _detect_language(files: list[str]) -> str:
    """Detect the primary test language from a list of filenames."""
    for f in files:
        if f.endswith(".bats"):
            return "bash"
        if f.endswith(".Tests.ps1"):
            return "powershell"
        if f.endswith(".test.ts") or f.endswith(".spec.ts"):
            return "typescript"
        if re.search(r"test_.*\.py$|.*_test\.py$|run_tests\.py$", f):
            return "python"
    # Fallback: look at implementation files
    for f in files:
        if f.endswith(".ps1"):
            return "powershell"
        if f.endswith(".ts"):
            return "typescript"
        if f.endswith(".sh"):
            return "bash"
        if f.endswith(".py"):
            return "python"
    return "unknown"


def _is_test_file(filepath: str, language: str) -> bool:
    """Check if a file is a test file based on language patterns."""
    name = os.path.basename(filepath)
    patterns = TEST_FILE_PATTERNS.get(language, [])
    return any(re.search(p, name) for p in patterns)


def _is_impl_file(filepath: str, language: str) -> bool:
    """Check if a file is an implementation file based on language patterns."""
    name = os.path.basename(filepath)
    # Skip non-code files
    if any(re.search(p, filepath) for p in SKIP_PATTERNS):
        return False
    patterns = IMPL_FILE_PATTERNS.get(language, [])
    return any(re.search(p, name) for p in patterns)


def _is_code_file(filepath: str) -> bool:
    """Check if a file is any kind of source code."""
    return filepath.endswith((".py", ".ts", ".ps1", ".sh", ".bats"))


# ---------------------------------------------------------------------------
# Counting tests and assertions per language
# ---------------------------------------------------------------------------

def _count_python(content: str) -> dict:
    """Count tests and assertions in Python code."""
    tests = len(re.findall(r"^\s*def\s+test_\w+", content, re.MULTILINE))
    # unittest-style class test methods
    tests += len(re.findall(r"^\s*def\s+test\w+\s*\(self", content, re.MULTILINE))
    # Custom record() pattern used in some harnesses: record("name", True/False)
    tests += len(re.findall(r"\brecord\s*\(\s*[\"']", content))

    # Custom harness pattern: TEST_CASES list of dicts with "name" keys.
    # Only count these if no standard test functions were found.
    if tests == 0:
        # Count dicts in test-case lists (each has a "name" key)
        tests += len(re.findall(r'^\s*"name"\s*:\s*"', content, re.MULTILINE))

    asserts = len(re.findall(r"^\s*assert\s+", content, re.MULTILINE))
    asserts += len(re.findall(r"self\.assert\w+\s*\(", content))
    asserts += len(re.findall(r"\bassert\w+\s*\(", content))  # pytest helpers
    # Deduplicate: self.assert* also matches assert*( — subtract overlap
    overlap = len(re.findall(r"self\.assert\w+\s*\(", content))
    asserts -= overlap  # remove double-count

    # Custom harness assertions: record_pass calls (record_pass/record_fail
    # are paired branches of the same check — count only the positive path).
    # Also count "PASS:" string writes (not FAIL — same pairing logic).
    custom_asserts = len(re.findall(r'\brecord_pass\s*\(', content))
    custom_asserts += len(re.findall(r'["\'].*?PASS\s*:', content))
    asserts += custom_asserts

    return {"tests": tests, "assertions": asserts}


def _count_typescript(content: str) -> dict:
    """Count tests and assertions in TypeScript (Bun/Jest) code."""
    # test("name", ...) or it("name", ...)
    tests = len(re.findall(r"(?:^|\s)(?:test|it)\s*\(", content, re.MULTILINE))
    asserts = len(re.findall(r"\bexpect\s*\(", content))
    return {"tests": tests, "assertions": asserts}


def _count_powershell(content: str) -> dict:
    """Count tests and assertions in PowerShell Pester code."""
    tests = len(re.findall(r"^\s*It\s+['\"]", content, re.MULTILINE))
    asserts = len(re.findall(r"\|\s*Should\b", content))
    return {"tests": tests, "assertions": asserts}


def _count_bash(content: str) -> dict:
    """Count tests and assertions in bats test code or shell test harnesses."""
    tests = len(re.findall(r"^@test\s+", content, re.MULTILINE))
    # bats assertions: [, [[, run + status check, assert_*
    asserts = len(re.findall(r"^\s*\[\s+", content, re.MULTILINE))
    asserts += len(re.findall(r"^\s*\[\[\s+", content, re.MULTILINE))
    asserts += len(re.findall(r"\bassert_\w+", content))
    # Shell test harness: log_result calls as test cases
    log_results = len(re.findall(r'\blog_result\s+', content))
    if tests == 0 and log_results > 0:
        tests = log_results
    # Embedded Python asserts in shell scripts
    asserts += len(re.findall(r"^\s*assert\s+", content, re.MULTILINE))
    # PASS string writes (not FAIL — paired with PASS)
    asserts += len(re.findall(r'["\'].*?PASS\s*:', content))
    return {"tests": tests, "assertions": asserts}


COUNTERS = {
    "python": _count_python,
    "typescript": _count_typescript,
    "powershell": _count_powershell,
    "bash": _count_bash,
}


# ---------------------------------------------------------------------------
# Structural metrics for a single run
# ---------------------------------------------------------------------------

def compute_structural_metrics(generated_code_dir: Path) -> dict:
    """Compute structural test quality metrics for a generated code directory.

    Returns dict with:
        language: detected language
        test_file_count: number of test files
        impl_file_count: number of implementation files
        test_lines: total lines of test code
        impl_lines: total lines of implementation code
        test_to_code_ratio: test_lines / impl_lines (0 if no impl)
        test_count: number of individual test cases
        assertion_count: number of assertions
        assertions_per_test: assertion_count / test_count (0 if no tests)
    """
    if not generated_code_dir.exists():
        return _empty_structural()

    # Collect all files recursively
    all_files = []
    for root, _dirs, files in os.walk(generated_code_dir):
        # Skip hidden dirs and node_modules
        rel_root = os.path.relpath(root, generated_code_dir)
        if any(part.startswith(".") and part != "." for part in Path(rel_root).parts):
            if not rel_root.startswith(".github"):
                continue
        if "node_modules" in rel_root:
            continue
        for f in files:
            rel = os.path.relpath(os.path.join(root, f), generated_code_dir)
            all_files.append(rel)

    language = _detect_language(all_files)
    counter = COUNTERS.get(language)

    test_files = [f for f in all_files if _is_code_file(f) and _is_test_file(f, language)]
    impl_files = [f for f in all_files if _is_code_file(f) and _is_impl_file(f, language) and not _is_test_file(f, language)]

    test_lines = 0
    impl_lines = 0
    total_tests = 0
    total_assertions = 0

    for f in test_files:
        fp = generated_code_dir / f
        try:
            content = fp.read_text(errors="replace")
        except Exception:
            continue
        test_lines += len(content.splitlines())
        if counter:
            counts = counter(content)
            total_tests += counts["tests"]
            total_assertions += counts["assertions"]

    for f in impl_files:
        fp = generated_code_dir / f
        try:
            content = fp.read_text(errors="replace")
        except Exception:
            continue
        impl_lines += len(content.splitlines())

    return {
        "language": language,
        "test_file_count": len(test_files),
        "impl_file_count": len(impl_files),
        "test_files": test_files,
        "impl_files": impl_files,
        "test_lines": test_lines,
        "impl_lines": impl_lines,
        "test_to_code_ratio": round(test_lines / impl_lines, 2) if impl_lines > 0 else 0,
        "test_count": total_tests,
        "assertion_count": total_assertions,
        "assertions_per_test": round(total_assertions / total_tests, 1) if total_tests > 0 else 0,
    }


def _empty_structural() -> dict:
    return {
        "language": "unknown",
        "test_file_count": 0, "impl_file_count": 0,
        "test_files": [], "impl_files": [],
        "test_lines": 0, "impl_lines": 0,
        "test_to_code_ratio": 0,
        "test_count": 0, "assertion_count": 0,
        "assertions_per_test": 0,
    }


# ---------------------------------------------------------------------------
# LLM-as-Judge
# ---------------------------------------------------------------------------

LLM_JUDGE_MODEL = "claude-sonnet-4-6"
LLM_JUDGE_CACHE_FILE = "test-quality-llm.json"

JUDGE_SYSTEM_PROMPT = """\
You are an expert software testing evaluator. You will be given:
1. A task description that an AI agent was asked to implement
2. The implementation code the agent wrote
3. The test code the agent wrote

Evaluate the quality of the TEST SUITE (not the implementation) across these dimensions:

- **coverage** (1-5): Do the tests exercise the key requirements from the task description? 5 = all requirements tested, 1 = most requirements untested.
- **rigor** (1-5): Are edge cases, error scenarios, and boundary conditions tested? 5 = thorough edge case coverage, 1 = only happy path.
- **design** (1-5): Test organization, fixture quality, independence, readability. 5 = well-structured with clear fixtures, 1 = messy/brittle.
- **overall** (1-5): Holistic test suite quality. Would you trust this test suite to catch regressions?

Respond with ONLY a JSON object (no markdown fences) in this exact format:
{"coverage": N, "rigor": N, "design": N, "overall": N, "summary": "1-2 sentence explanation"}"""


def evaluate_with_llm(task_description: str, impl_code: str, test_code: str,
                      api_key: str | None = None) -> dict | None:
    """Send code + tests to Claude for quality scoring.

    Returns dict with coverage, rigor, design, overall (1-5), summary.
    Returns None if API is unavailable.
    """
    try:
        import anthropic
    except ImportError:
        print("  anthropic SDK not installed; skipping LLM judge", file=sys.stderr)
        return None

    key = api_key or os.environ.get("ANTHROPIC_API_KEY")
    if not key:
        print("  ANTHROPIC_API_KEY not set; skipping LLM judge", file=sys.stderr)
        return None

    client = anthropic.Anthropic(api_key=key)

    user_msg = f"""## Task Description
{task_description}

## Implementation Code
```
{impl_code}
```

## Test Code
```
{test_code}
```

Evaluate the test suite quality."""

    # Truncate if too long (keep under ~100K tokens ≈ 400K chars)
    if len(user_msg) > 400_000:
        # Trim implementation code first (tests are more important for judging)
        max_impl = 200_000
        if len(impl_code) > max_impl:
            impl_code = impl_code[:max_impl] + "\n... (truncated)"
            user_msg = f"""## Task Description
{task_description}

## Implementation Code
```
{impl_code}
```

## Test Code
```
{test_code}
```

Evaluate the test suite quality."""

    try:
        response = client.messages.create(
            model=LLM_JUDGE_MODEL,
            max_tokens=300,
            system=JUDGE_SYSTEM_PROMPT,
            messages=[{"role": "user", "content": user_msg}],
        )
        text = response.content[0].text.strip()
        # Parse JSON response
        scores = json.loads(text)
        # Validate expected keys
        for k in ("coverage", "rigor", "design", "overall"):
            if k not in scores or not isinstance(scores[k], (int, float)):
                return None
            scores[k] = max(1, min(5, int(scores[k])))
        # Track cost
        usage = response.usage
        cost_rates = COST_PER_MTOK.get(LLM_JUDGE_MODEL, {})
        input_cost = (usage.input_tokens / 1_000_000) * cost_rates.get("input", 0)
        output_cost = (usage.output_tokens / 1_000_000) * cost_rates.get("output", 0)
        cache_read_cost = (getattr(usage, "cache_read_input_tokens", 0) / 1_000_000) * cost_rates.get("cache_read", 0)
        cache_write_cost = (getattr(usage, "cache_creation_input_tokens", 0) / 1_000_000) * cost_rates.get("cache_write", 0)
        scores["judge_cost_usd"] = round(input_cost + output_cost + cache_read_cost + cache_write_cost, 4)
        scores["judge_input_tokens"] = usage.input_tokens
        scores["judge_output_tokens"] = usage.output_tokens
        return scores
    except json.JSONDecodeError:
        print(f"  LLM judge returned non-JSON: {text[:200]}", file=sys.stderr)
        return None
    except Exception as e:
        print(f"  LLM judge error: {e}", file=sys.stderr)
        return None


def _read_files_concat(directory: Path, file_list: list[str]) -> str:
    """Read and concatenate files with headers."""
    parts = []
    for f in file_list:
        fp = directory / f
        if fp.exists():
            try:
                content = fp.read_text(errors="replace")
                parts.append(f"### {f}\n{content}")
            except Exception:
                pass
    return "\n\n".join(parts)


def evaluate_run_llm(run_variant_dir: Path, metrics: dict, structural: dict,
                     api_key: str | None = None, force: bool = False) -> dict | None:
    """Evaluate a single run with LLM-as-judge, with caching.

    Checks for cached results in test-quality-llm.json. Skips if cached
    unless force=True.
    """
    cache_path = run_variant_dir / LLM_JUDGE_CACHE_FILE
    if cache_path.exists() and not force:
        try:
            return json.loads(cache_path.read_text())
        except Exception:
            pass

    gen_dir = run_variant_dir / "generated-code"
    if not gen_dir.exists():
        return None

    task_desc = metrics.get("prompt_text", "")
    impl_code = _read_files_concat(gen_dir, structural.get("impl_files", []))
    test_code = _read_files_concat(gen_dir, structural.get("test_files", []))

    if not test_code.strip():
        return None

    scores = evaluate_with_llm(task_desc, impl_code, test_code, api_key=api_key)
    if scores:
        cache_path.write_text(json.dumps(scores, indent=2))
    return scores


# ---------------------------------------------------------------------------
# Batch evaluation for a full run directory
# ---------------------------------------------------------------------------

def evaluate_run_directory(run_dir: Path, llm_judge: bool = False,
                           force: bool = False) -> list[dict]:
    """Evaluate all runs in a results directory.

    Returns list of dicts, one per run variant, with:
        task_id, mode, model, structural: {...}, llm_scores: {...} | None
    """
    results = []
    metrics_files = sorted(run_dir.glob("tasks/*/*/metrics.json"))

    for mf in metrics_files:
        variant_dir = mf.parent
        gen_dir = variant_dir / "generated-code"

        try:
            metrics = json.loads(mf.read_text())
        except Exception:
            continue

        structural = compute_structural_metrics(gen_dir)

        llm_scores = None
        if llm_judge:
            llm_scores = evaluate_run_llm(variant_dir, metrics, structural, force=force)

        parts = variant_dir.name.rsplit("-", 1)
        model = parts[-1] if len(parts) == 2 else "unknown"
        mode = parts[0] if len(parts) == 2 else variant_dir.name

        results.append({
            "task_id": metrics.get("task_id", ""),
            "task_name": metrics.get("task_name", ""),
            "mode": metrics.get("language_mode", mode),
            "model": metrics.get("model_short", model),
            "structural": structural,
            "llm_scores": llm_scores,
        })

    return results


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    repo_root = Path(__file__).parent.resolve()
    results_dir = repo_root / "results"

    llm_judge = "--llm-judge" in sys.argv
    force = "--force" in sys.argv
    do_all = "--all" in sys.argv

    # Determine target directories
    if do_all:
        targets = sorted(d for d in results_dir.iterdir()
                         if d.is_dir() and not d.name.startswith("."))
    elif len(sys.argv) > 1 and not sys.argv[-1].startswith("-"):
        t = Path(sys.argv[-1])
        targets = [t if t.is_absolute() else repo_root / t]
    else:
        dirs = sorted(d for d in results_dir.iterdir()
                      if d.is_dir() and not d.name.startswith("."))
        targets = [dirs[-1]] if dirs else []

    for run_dir in targets:
        print(f"\n{'='*60}", file=sys.stderr)
        print(f"Evaluating: {run_dir.name}", file=sys.stderr)
        print(f"{'='*60}", file=sys.stderr)

        results = evaluate_run_directory(run_dir, llm_judge=llm_judge, force=force)

        total_cost = 0.0
        for r in results:
            s = r["structural"]
            llm = r.get("llm_scores") or {}
            llm_str = ""
            if llm:
                llm_str = (f"  LLM: cov={llm['coverage']} rig={llm['rigor']} "
                           f"des={llm['design']} ovr={llm['overall']}")
                total_cost += llm.get("judge_cost_usd", 0)
            print(
                f"  {r['task_id'][:30]:<32} {r['mode']:<16} {r['model']:<8} "
                f"tests={s['test_count']:>3}  asserts={s['assertion_count']:>3}  "
                f"ratio={s['test_to_code_ratio']:.2f}"
                f"{llm_str}",
                file=sys.stderr,
            )

        if llm_judge and total_cost > 0:
            print(f"\n  LLM judge cost: ${total_cost:.4f}", file=sys.stderr)

        # Save summary
        summary_path = run_dir / "test-quality-summary.json"
        summary = []
        for r in results:
            entry = {
                "task_id": r["task_id"],
                "task_name": r["task_name"],
                "mode": r["mode"],
                "model": r["model"],
                **{f"sq_{k}": v for k, v in r["structural"].items()
                   if k not in ("test_files", "impl_files")},
            }
            if r.get("llm_scores"):
                for k, v in r["llm_scores"].items():
                    entry[f"lj_{k}"] = v
            summary.append(entry)
        summary_path.write_text(json.dumps(summary, indent=2))
        print(f"  Wrote {summary_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
