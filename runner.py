#!/usr/bin/env python3
"""
Benchmark runner for comparing Claude Code agent scripting across languages.
Invokes Claude Code CLI subagents on scripting tasks under different language constraints.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
import threading
from datetime import datetime, timezone
from pathlib import Path

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

INSTRUCTIONS_FILE = "benchmark-instructions-v2.md"
INSTRUCTIONS_VERSION = "v2"

MODELS = {
    "opus": "claude-opus-4-6",
    "sonnet": "claude-sonnet-4-6",
}

COST_PER_MTOK = {
    "claude-opus-4-6":   {"input": 15.0, "output": 75.0, "cache_read": 1.5, "cache_write": 18.75},
    "claude-sonnet-4-6": {"input": 3.0,  "output": 15.0, "cache_read": 0.3, "cache_write": 3.75},
}

LANGUAGE_EXTENSIONS = {
    ".py": "python", ".js": "javascript", ".ts": "typescript", ".sh": "bash",
    ".ps1": "powershell", ".psm1": "powershell", ".psd1": "powershell",
    ".cs": "csharp", ".rb": "ruby", ".go": "go", ".rs": "rust",
    ".java": "java", ".pl": "perl", ".lua": "lua", ".r": "r",
}

INSTALL_PATTERNS = [
    r"apt[\s-]get\s+install", r"apt\s+install", r"pip\s+install", r"pip3\s+install",
    r"npm\s+install", r"yarn\s+add", r"dotnet\s+tool\s+install", r"Install-Module",
    r"Install-Package", r"brew\s+install", r"snap\s+install", r"cargo\s+install",
    r"gem\s+install", r"go\s+install",
]

# ---------------------------------------------------------------------------
# Task Definitions
# ---------------------------------------------------------------------------

TASKS = [
    {
        "id": "01-csv-report-generator",
        "name": "CSV Report Generator",
        "category": "Data Transformation",
        "description": (
            "Read a CSV file of employee records (name, department, salary, hire_date, status), "
            "filter to active employees only, compute aggregates (average salary by department, "
            "headcount by department, overall statistics), and output a formatted summary report "
            "to a text file. Create sample CSV test data as part of the test fixtures."
        ),
    },
    {
        "id": "02-log-file-analyzer",
        "name": "Log File Analyzer",
        "category": "Text Processing",
        "description": (
            "Parse a log file containing mixed formats (syslog-style lines and JSON-structured lines), "
            "extract all error and warning entries, produce a frequency table of error types with their "
            "first and last occurrence timestamps, and output the analysis as both a human-readable table "
            "and a JSON file. Create sample log data as test fixtures."
        ),
    },
    {
        "id": "03-directory-tree-sync",
        "name": "Directory Tree Sync",
        "category": "File Manipulation",
        "description": (
            "Compare two directory trees, identify files that differ (by content hash — SHA-256), "
            "files that exist in only one tree, and generate a sync plan. Implement both a dry-run "
            "mode (report only) and an execute mode (perform the sync). All file operations should "
            "be testable with mock directory structures."
        ),
    },
    {
        "id": "04-rest-api-client",
        "name": "REST API Client",
        "category": "API Interaction",
        "description": (
            "Build a script that queries a REST API (use JSONPlaceholder — https://jsonplaceholder.typicode.com), "
            "fetches posts and their comments, handles pagination, implements retry with exponential backoff "
            "on failure, and caches results locally in JSON files. Mock the HTTP calls for testing."
        ),
    },
    {
        "id": "05-process-monitor",
        "name": "Process Monitor",
        "category": "System Administration",
        "description": (
            "Create a script that reads process information (CPU%, memory, PID, name), filters by "
            "configurable resource usage thresholds, identifies the top N resource consumers, and "
            "generates an alert report. All process data must be mockable for testing — do not rely "
            "on live system state in tests."
        ),
    },
    {
        "id": "06-config-file-migrator",
        "name": "Config File Migrator",
        "category": "Data Transformation",
        "description": (
            "Read a configuration file in INI format, validate it against a simple schema (required keys, "
            "value types), and output equivalent configurations in JSON and YAML formats. Handle sections, "
            "comments, multi-line values, and type coercion (strings to numbers/booleans where appropriate). "
            "Create test fixtures with various edge cases."
        ),
    },
    {
        "id": "07-batch-file-renamer",
        "name": "Batch File Renamer",
        "category": "File Automation",
        "description": (
            "Rename files in a directory using regex-based patterns. Support: preview mode (show what would "
            "change without doing it), undo capability (generate an undo script that reverses the renames), "
            "and conflict detection (two files would get the same name). Test with mock file system structures."
        ),
    },
    {
        "id": "08-database-seed-script",
        "name": "Database Seed Script",
        "category": "Process Automation",
        "description": (
            "Create a SQLite database with a schema (users, orders, products tables with foreign keys), "
            "generate realistic mock data using deterministic randomization (seeded RNG), insert the data "
            "respecting referential integrity, and run verification queries that confirm data consistency. "
            "Tests should verify schema, data integrity, and query results."
        ),
    },
    {
        "id": "09-error-retry-pipeline",
        "name": "Error Retry Pipeline",
        "category": "Error Handling",
        "description": (
            "Build a pipeline that processes items from a queue (mocked), where processing can fail randomly. "
            "Implement: exponential backoff retry (configurable max retries), dead-letter queue for permanently "
            "failed items, progress reporting (items processed, failed, retrying), and a final summary. All "
            "queue and processing operations must be mockable."
        ),
    },
    {
        "id": "10-multi-file-search-replace",
        "name": "Multi-file Search and Replace",
        "category": "Text Processing",
        "description": (
            "Recursively search files matching a glob pattern for a regex pattern, perform search-and-replace "
            "with: preview mode (show matches with context without modifying), backup creation (copy originals "
            "before modifying), and a summary report of all changes made (file, line number, old text, new text). "
            "Test with mock directory structures and files."
        ),
    },
    {
        "id": "11-semantic-version-bumper",
        "name": "Semantic Version Bumper",
        "category": "GitHub Actions / Release Automation",
        "description": (
            "Parse a version file (or package.json) containing a semantic version string, determine the next "
            "version based on conventional commit messages (feat -> minor, fix -> patch, breaking -> major), "
            "update the version file, generate a changelog entry from the commits, and output the new version. "
            "Create mock commit logs as test fixtures."
        ),
    },
    {
        "id": "12-pr-label-assigner",
        "name": "PR Label Assigner",
        "category": "GitHub Actions / Triage",
        "description": (
            "Given a list of changed file paths (simulating a PR's changed files), apply labels based on "
            "configurable path-to-label mapping rules (e.g., docs/** -> documentation, src/api/** -> api, "
            "*.test.* -> tests). Support glob patterns, multiple labels per file, and priority ordering "
            "when rules conflict. Output the final label set. Mock the file list for testing."
        ),
    },
    {
        "id": "13-dependency-license-checker",
        "name": "Dependency License Checker",
        "category": "GitHub Actions / Compliance",
        "description": (
            "Parse a dependency manifest (package.json, requirements.txt, or similar), extract dependency "
            "names and versions, check each against an allow-list and deny-list of licenses (provided as "
            "config), and generate a compliance report listing each dependency's license status (approved, "
            "denied, unknown). Mock the license lookup for testing."
        ),
    },
    {
        "id": "14-docker-image-tag-generator",
        "name": "Docker Image Tag Generator",
        "category": "GitHub Actions / CI/CD",
        "description": (
            "Given git context (branch name, commit SHA, tags, PR number — all provided as mock inputs), "
            "generate appropriate Docker image tags following common conventions: latest for main, pr-{number} "
            "for PRs, v{semver} for tags, {branch}-{short-sha} for feature branches. Handle tag sanitization "
            "(lowercase, no special chars). Output the tag list."
        ),
    },
    {
        "id": "15-test-results-aggregator",
        "name": "Test Results Aggregator",
        "category": "GitHub Actions / CI Reporting",
        "description": (
            "Parse test result files in multiple formats (JUnit XML, and JSON), aggregate results across "
            "multiple files (simulating a matrix build), compute totals (passed, failed, skipped, duration), "
            "identify flaky tests (passed in some runs, failed in others), and generate a markdown summary "
            "suitable for a GitHub Actions job summary. Create sample test result files as fixtures."
        ),
    },
    {
        "id": "16-environment-matrix-generator",
        "name": "Environment Matrix Generator",
        "category": "GitHub Actions / CI Configuration",
        "description": (
            "Given a configuration describing OS options, language versions, and feature flags, generate a "
            "build matrix (as JSON) suitable for GitHub Actions strategy.matrix. Support include/exclude "
            "rules, max-parallel limits, and fail-fast configuration. Validate that the matrix doesn't exceed "
            "a maximum size. Output the complete matrix JSON."
        ),
    },
    {
        "id": "17-artifact-cleanup-script",
        "name": "Artifact Cleanup Script",
        "category": "GitHub Actions / Maintenance",
        "description": (
            "Given a list of artifacts with metadata (name, size, creation date, workflow run ID — provided "
            "as mock data), apply retention policies (max age, max total size, keep-latest-N per workflow), "
            "determine which artifacts to delete, and generate a deletion plan with a summary (total space "
            "reclaimed, artifacts retained vs deleted). Support dry-run mode."
        ),
    },
    {
        "id": "18-secret-rotation-validator",
        "name": "Secret Rotation Validator",
        "category": "GitHub Actions / Security",
        "description": (
            "Given a configuration of secrets with metadata (name, last-rotated date, rotation policy in days, "
            "required-by services — all mock data), identify secrets that are expired or expiring within a "
            "configurable warning window, generate a rotation report, and output notifications grouped by "
            "urgency (expired, warning, ok). Support multiple output formats (markdown table, JSON)."
        ),
    },
]

# ---------------------------------------------------------------------------
# Prompt Templates
# ---------------------------------------------------------------------------

PROMPT_TEMPLATES = {
    "default": (
        "You are completing a scripting task. Choose whatever programming language you think is best for this task.\n\n"
        "TASK: {task_description}\n\n"
        "REQUIREMENTS:\n"
        "1. Use red/green TDD methodology: write a failing test FIRST, then write the minimum code to make it pass, then refactor. Repeat for each piece of functionality.\n"
        "2. Create mocks and test fixtures as necessary for testability.\n"
        "3. All tests must be runnable and must pass at the end.\n"
        "4. Include clear comments explaining your approach.\n"
        "5. Handle errors gracefully with meaningful error messages.\n\n"
        "Create your solution in the current working directory. Start by writing your first failing test."
    ),
    "powershell": (
        "You are completing a scripting task. You MUST use PowerShell as your implementation language.\n\n"
        "TASK: {task_description}\n\n"
        "REQUIREMENTS:\n"
        "1. Use red/green TDD methodology: write a failing test FIRST, then write the minimum code to make it pass, then refactor. Repeat for each piece of functionality.\n"
        "2. Create mocks and test fixtures as necessary for testability. Use Pester as the testing framework.\n"
        "3. All tests must be runnable with `Invoke-Pester` and must pass at the end.\n"
        "4. Include clear comments explaining your approach.\n"
        "5. Handle errors gracefully with meaningful error messages.\n\n"
        "Create your solution in the current working directory. Start by writing your first failing test."
    ),
    "powershell-strict": (
        "You are completing a scripting task. You MUST use PowerShell with strict mode as your implementation language.\n\n"
        "TASK: {task_description}\n\n"
        "REQUIREMENTS:\n"
        "1. Use red/green TDD methodology: write a failing test FIRST, then write the minimum code to make it pass, then refactor. Repeat for each piece of functionality.\n"
        "2. Create mocks and test fixtures as necessary for testability. Use Pester as the testing framework.\n"
        "3. All tests must be runnable with `Invoke-Pester` and must pass at the end.\n"
        "4. Include clear comments explaining your approach.\n"
        "5. Handle errors gracefully with meaningful error messages.\n"
        "6. STRICT MODE REQUIREMENTS — every script and module file must include:\n"
        "   - `Set-StrictMode -Latest` at the top\n"
        "   - `$ErrorActionPreference = 'Stop'`\n"
        "   - All function parameters must be explicitly typed (e.g., `[string]$Name`, `[int]$Count`, `[hashtable]$Options`)\n"
        "   - All functions must declare `[OutputType()]` attributes\n"
        "   - No implicit type conversions — cast explicitly where needed\n"
        "   - Use `[CmdletBinding()]` on all functions\n\n"
        "Create your solution in the current working directory. Start by writing your first failing test."
    ),
    "csharp-script": (
        "You are completing a scripting task. You MUST use C# with .NET 10 file-based apps as your implementation language.\n\n"
        "TASK: {task_description}\n\n"
        "REQUIREMENTS:\n"
        "1. Use red/green TDD methodology: write a failing test FIRST, then write the minimum code to make it pass, then refactor. Repeat for each piece of functionality.\n"
        "2. Create mocks and test fixtures as necessary for testability.\n"
        "3. Use .NET 10 file-based apps — NO .csproj project files. Write single .cs files that run directly:\n"
        "   - Run code: `dotnet run app.cs` (top-level statements, no project file needed)\n"
        "   - Add NuGet packages with directives at the top of the file: `#:package PackageName@Version`\n"
        "   - For tests, create a test project with `dotnet new xunit` and `dotnet test`, OR write a self-contained test runner .cs file\n"
        "   - Example file-based app:\n"
        "     ```\n"
        "     #:package Newtonsoft.Json@13.0.3\n"
        "     using Newtonsoft.Json;\n"
        "     Console.WriteLine(JsonConvert.SerializeObject(new {{ hello = \"world\" }}));\n"
        "     ```\n"
        "4. All tests must be runnable and must pass at the end.\n"
        "5. Include clear comments explaining your approach.\n"
        "6. Handle errors gracefully with meaningful error messages.\n\n"
        "IMPORTANT: The .NET 10 SDK is pre-installed. `dotnet run file.cs` works immediately — do NOT create .csproj files for simple apps.\n\n"
        "PRO TIPS for .NET 10 file-based apps — read these carefully to avoid common errors:\n"
        "- File ordering: `#:package` directives first, then `using` statements, then top-level statements (executable code), then class/record/enum declarations at the bottom. Violating this order causes CS8803 and CS1529 errors.\n"
        "- Each .cs file is its own independent compilation unit. You CANNOT reference a class defined in one .cs file from another .cs file. Put all shared types (classes, records, enums) in the same file that uses them.\n"
        "- For tests: put your implementation classes and test runner code in one self-contained tests.cs file. Duplicate shared types into app.cs if you also need a standalone app.\n"
        "- There is no implicit project — no .csproj, no namespace resolution across files, no shared references. Each `dotnet run file.cs` is a standalone program.\n\n"
        "Create your solution in the current working directory. Start by writing your first failing test."
    ),
}

MODES = list(PROMPT_TEMPLATES.keys())

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

PUSH_INTERVAL = 60  # seconds between incremental git pushes
INCREMENTAL_PREFIX = "Incremental benchmark results:"


def log(msg: str) -> None:
    """Print progress to stderr."""
    print(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}", file=sys.stderr, flush=True)


def _last_commit_is_incremental(repo_root: Path) -> bool:
    """Check if the most recent commit is an incremental status update."""
    try:
        result = subprocess.run(
            ["git", "log", "-1", "--format=%s"],
            cwd=str(repo_root), capture_output=True, text=True, timeout=10,
        )
        return result.stdout.strip().startswith(INCREMENTAL_PREFIX)
    except Exception:
        return False


def git_push_results(
    repo_root: Path,
    branch: str,
    run_count: int,
    total_runs: int,
    *,
    final: bool = False,
) -> None:
    """Commit and push results, squashing consecutive incremental commits.

    Incremental commits (periodic progress snapshots) get squashed into a
    single commit so the history stays clean.  When ``final=True`` the commit
    message reflects the completed run instead of "Incremental …".
    """
    try:
        status = subprocess.run(
            ["git", "status", "--porcelain", "results/"],
            cwd=str(repo_root), capture_output=True, text=True, timeout=10,
        )
        if not status.stdout.strip():
            if not final:
                return  # nothing new for incremental pushes
            # For final push, still squash previous incrementals even if
            # there are no new changes to stage
            if not _last_commit_is_incremental(repo_root):
                return

        # Stage results
        subprocess.run(
            ["git", "add", "results/"],
            cwd=str(repo_root), capture_output=True, timeout=10,
        )

        # Squash: if previous commit was incremental, soft-reset to absorb it
        did_squash = False
        if _last_commit_is_incremental(repo_root):
            subprocess.run(
                ["git", "reset", "--soft", "HEAD~1"],
                cwd=str(repo_root), capture_output=True, timeout=10,
            )
            # Re-stage after reset (the index is preserved but we may need
            # to pick up anything the reset un-committed)
            subprocess.run(
                ["git", "add", "results/"],
                cwd=str(repo_root), capture_output=True, timeout=10,
            )
            did_squash = True

        if final:
            msg = f"Benchmark results: {run_count}/{total_runs} runs completed"
        else:
            msg = f"{INCREMENTAL_PREFIX} {run_count}/{total_runs} runs completed"

        subprocess.run(
            ["git", "commit", "-m", msg],
            cwd=str(repo_root), capture_output=True, timeout=30,
        )

        # Force-with-lease when we squashed (rewrote history) — safe because
        # only the runner touches this branch during a run.
        if did_squash:
            push_args = ["git", "push", "--force-with-lease", "-u", "origin", branch]
        else:
            push_args = ["git", "push", "-u", "origin", branch]
        subprocess.run(push_args, capture_output=True, timeout=60, cwd=str(repo_root))

        log(f"  [push] Pushed results ({run_count}/{total_runs} done{', FINAL' if final else ''})")
    except Exception as e:
        log(f"  [push] Warning: push failed: {e}")


class PeriodicPusher:
    """Background thread that periodically pushes results to git."""

    def __init__(self, repo_root: Path, branch: str, total_runs: int, run_dir: Path):
        self.repo_root = repo_root
        self.branch = branch
        self.total_runs = total_runs
        self.run_dir = run_dir
        self.run_count = 0
        self.all_metrics: list[dict] = []
        self._stop = threading.Event()
        self._thread = threading.Thread(target=self._run, daemon=True)

    def start(self):
        self._thread.start()

    def update(self, count: int, all_metrics: list[dict]):
        self.run_count = count
        self.all_metrics = list(all_metrics)

    def stop(self):
        self._stop.set()
        self._thread.join(timeout=120)

    def _run(self):
        while not self._stop.wait(PUSH_INTERVAL):
            try:
                generate_results_md(self.run_dir, self.all_metrics, self.total_runs, self.run_count)
            except Exception as e:
                log(f"  [push] Warning: results.md generation failed: {e}")
            git_push_results(self.repo_root, self.branch, self.run_count, self.total_runs)


def capture_workspace_listing(workspace: Path) -> str:
    """Return a recursive file listing of the workspace directory."""
    lines = []
    for root, dirs, files in os.walk(workspace):
        # skip hidden dirs
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        level = len(Path(root).relative_to(workspace).parts)
        indent = "  " * level
        lines.append(f"{indent}{Path(root).name}/")
        for f in sorted(files):
            if not f.startswith("."):
                fpath = Path(root) / f
                try:
                    size = fpath.stat().st_size
                except OSError:
                    size = 0
                lines.append(f"{indent}  {f} ({size} bytes)")
    return "\n".join(lines) if lines else "(empty)"


def copy_generated_files(workspace: Path, dest: Path) -> list[str]:
    """Copy non-instruction, non-hidden files from workspace to dest. Return list of relative paths."""
    dest.mkdir(parents=True, exist_ok=True)
    copied = []
    for root, dirs, files in os.walk(workspace):
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        for f in sorted(files):
            if f.startswith(".") or f == INSTRUCTIONS_FILE:
                continue
            src = Path(root) / f
            rel = src.relative_to(workspace)
            dst = dest / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            try:
                shutil.copy2(src, dst)
                copied.append(str(rel))
            except Exception as e:
                log(f"  Warning: could not copy {rel}: {e}")
    return copied


def count_lines(directory: Path) -> int:
    """Count total lines of code in a directory."""
    total = 0
    for root, dirs, files in os.walk(directory):
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        for f in files:
            if f.startswith("."):
                continue
            try:
                total += len((Path(root) / f).read_text(errors="replace").splitlines())
            except Exception:
                pass
    return total


def estimate_tokens(text: str) -> int:
    """Rough token estimate: chars / 4."""
    return len(text) // 4


def compute_language_breakdown(directory: Path) -> dict:
    """Compute language breakdown by lines of code from file extensions."""
    lang_lines: dict[str, int] = {}
    total = 0
    for root, dirs, files in os.walk(directory):
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        for f in files:
            if f.startswith("."):
                continue
            ext = Path(f).suffix.lower()
            lang = LANGUAGE_EXTENSIONS.get(ext)
            if lang:
                try:
                    lines = len((Path(root) / f).read_text(errors="replace").splitlines())
                    lang_lines[lang] = lang_lines.get(lang, 0) + lines
                    total += lines
                except Exception:
                    pass
    if total == 0:
        return {}
    return {lang: round(100 * count / total, 1) for lang, count in sorted(lang_lines.items(), key=lambda x: -x[1])}


def get_all_code_text(directory: Path) -> str:
    """Get all code text from files in directory for token counting."""
    texts = []
    for root, dirs, files in os.walk(directory):
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        for f in files:
            if f.startswith(".") or f == INSTRUCTIONS_FILE:
                continue
            try:
                texts.append((Path(root) / f).read_text(errors="replace"))
            except Exception:
                pass
    return "\n".join(texts)


def generate_results_md(run_dir: Path, all_metrics: list[dict], total_runs: int, run_count: int) -> None:
    """Generate/update a results.md file with tables, commentary, and status."""
    from zoneinfo import ZoneInfo

    et = ZoneInfo("America/New_York")
    now_et = datetime.now(et).strftime("%Y-%m-%d %I:%M:%S %p ET")

    completed = len(all_metrics)
    remaining = total_runs - run_count
    in_progress = run_count - completed

    total_cost = sum(m["cost"]["total_cost_usd"] for m in all_metrics)
    total_duration = sum(m["timing"]["grand_total_duration_ms"] for m in all_metrics) / 1000

    lines = []
    lines.append("# Benchmark Results: PowerShell vs Default Language")
    lines.append("")
    lines.append(f"**Last updated:** {now_et}")
    lines.append("")
    lines.append(f"**Status:** {completed}/{total_runs} runs completed, {remaining} remaining")
    lines.append(f"**Total cost so far:** ${total_cost:.4f}")
    lines.append(f"**Total agent time so far:** {total_duration:.0f}s ({total_duration/60:.1f} min)")
    lines.append("")

    if not all_metrics:
        lines.append("*No completed runs yet.*")
        (run_dir / "results.md").write_text("\n".join(lines))
        return

    # ── Per-run detail table ──
    lines.append("## Per-Run Results")
    lines.append("")
    lines.append("| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language |")
    lines.append("|------|------|-------|----------|-------|-------|--------|------|----------|")

    for m in all_metrics:
        dur = m["timing"]["grand_total_duration_ms"] / 1000
        lines.append(
            f"| {m['task_name'][:30]} "
            f"| {m['language_mode']} "
            f"| {m['model_short']} "
            f"| {dur:.0f}s "
            f"| {m['timing']['num_turns']} "
            f"| {m['code_metrics']['total_lines']} "
            f"| {m['quality']['error_count']} "
            f"| ${m['cost']['total_cost_usd']:.4f} "
            f"| {m['language_chosen']} |"
        )

    lines.append("")

    # ── Comparison by mode ──
    modes_seen = sorted(set(m["language_mode"] for m in all_metrics))
    if len(modes_seen) > 1:
        lines.append("## Comparison by Language Mode")
        lines.append("")
        lines.append("| Mode | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Total Cost |")
        lines.append("|------|------|-------------|-----------|------------|-----------|------------|")
        for mode in modes_seen:
            mm = [m for m in all_metrics if m["language_mode"] == mode]
            n = len(mm)
            avg_dur = sum(m["timing"]["grand_total_duration_ms"] for m in mm) / n / 1000
            avg_lines = sum(m["code_metrics"]["total_lines"] for m in mm) / n
            avg_errors = sum(m["quality"]["error_count"] for m in mm) / n
            avg_turns = sum(m["timing"]["num_turns"] for m in mm) / n
            cost = sum(m["cost"]["total_cost_usd"] for m in mm)
            lines.append(f"| {mode} | {n} | {avg_dur:.0f}s | {avg_lines:.0f} | {avg_errors:.1f} | {avg_turns:.0f} | ${cost:.4f} |")
        lines.append("")

    # ── Comparison by model ──
    models_seen = sorted(set(m["model_short"] for m in all_metrics))
    if len(models_seen) > 1:
        lines.append("## Comparison by Model")
        lines.append("")
        lines.append("| Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Total Cost |")
        lines.append("|-------|------|-------------|-----------|------------|-----------|------------|")
        for model in models_seen:
            mm = [m for m in all_metrics if m["model_short"] == model]
            n = len(mm)
            avg_dur = sum(m["timing"]["grand_total_duration_ms"] for m in mm) / n / 1000
            avg_lines = sum(m["code_metrics"]["total_lines"] for m in mm) / n
            avg_errors = sum(m["quality"]["error_count"] for m in mm) / n
            avg_turns = sum(m["timing"]["num_turns"] for m in mm) / n
            cost = sum(m["cost"]["total_cost_usd"] for m in mm)
            lines.append(f"| {model} | {n} | {avg_dur:.0f}s | {avg_lines:.0f} | {avg_errors:.1f} | {avg_turns:.0f} | ${cost:.4f} |")
        lines.append("")

    # ── Head-to-head: same task, different modes ──
    tasks_seen = sorted(set(m["task_id"] for m in all_metrics))
    h2h_rows = []
    for task_id in tasks_seen:
        task_metrics = [m for m in all_metrics if m["task_id"] == task_id]
        task_modes = {m["language_mode"]: m for m in task_metrics}
        if "default" in task_modes and any(k != "default" for k in task_modes):
            default = task_modes["default"]
            for mode, m in task_modes.items():
                if mode == "default":
                    continue
                d_dur = default["timing"]["grand_total_duration_ms"] / 1000
                m_dur = m["timing"]["grand_total_duration_ms"] / 1000
                dur_delta = ((m_dur - d_dur) / d_dur * 100) if d_dur > 0 else 0
                d_err = default["quality"]["error_count"]
                m_err = m["quality"]["error_count"]
                err_delta = m_err - d_err
                d_lines = default["code_metrics"]["total_lines"]
                m_lines = m["code_metrics"]["total_lines"]
                h2h_rows.append({
                    "task": default["task_name"][:25],
                    "model": m["model_short"],
                    "mode": mode,
                    "default_lang": default["language_chosen"],
                    "def_dur": d_dur, "mode_dur": m_dur, "dur_delta": dur_delta,
                    "def_err": d_err, "mode_err": m_err, "err_delta": err_delta,
                    "def_lines": d_lines, "mode_lines": m_lines,
                })

    if h2h_rows:
        lines.append("## Head-to-Head: Default vs Constrained Language")
        lines.append("")
        lines.append("| Task | Model | Mode | Default Lang | Def Dur | Mode Dur | Dur Delta | Def Err | Mode Err | Err Delta | Def Lines | Mode Lines |")
        lines.append("|------|-------|------|-------------|---------|----------|-----------|---------|----------|-----------|-----------|------------|")
        for r in h2h_rows:
            sign = "+" if r["dur_delta"] >= 0 else ""
            esign = "+" if r["err_delta"] >= 0 else ""
            lines.append(
                f"| {r['task']} | {r['model']} | {r['mode']} | {r['default_lang']} "
                f"| {r['def_dur']:.0f}s | {r['mode_dur']:.0f}s | {sign}{r['dur_delta']:.0f}% "
                f"| {r['def_err']} | {r['mode_err']} | {esign}{r['err_delta']} "
                f"| {r['def_lines']} | {r['mode_lines']} |"
            )
        lines.append("")

    # ── Commentary ──
    lines.append("## Observations")
    lines.append("")

    if completed >= 2:
        # Find most/least errors
        most_err = max(all_metrics, key=lambda m: m["quality"]["error_count"])
        least_err = min(all_metrics, key=lambda m: m["quality"]["error_count"])
        slowest = max(all_metrics, key=lambda m: m["timing"]["grand_total_duration_ms"])
        fastest = min(all_metrics, key=lambda m: m["timing"]["grand_total_duration_ms"])

        lines.append(f"- **Fastest run:** {fastest['task_name']} / {fastest['language_mode']} / {fastest['model_short']} — {fastest['timing']['grand_total_duration_ms']/1000:.0f}s")
        lines.append(f"- **Slowest run:** {slowest['task_name']} / {slowest['language_mode']} / {slowest['model_short']} — {slowest['timing']['grand_total_duration_ms']/1000:.0f}s")
        lines.append(f"- **Most errors:** {most_err['task_name']} / {most_err['language_mode']} / {most_err['model_short']} — {most_err['quality']['error_count']} errors")
        lines.append(f"- **Fewest errors:** {least_err['task_name']} / {least_err['language_mode']} / {least_err['model_short']} — {least_err['quality']['error_count']} errors")
        lines.append("")

        # Avg cost by model
        for model in models_seen:
            mm = [m for m in all_metrics if m["model_short"] == model]
            avg_cost = sum(m["cost"]["total_cost_usd"] for m in mm) / len(mm)
            lines.append(f"- **Avg cost per run ({model}):** ${avg_cost:.4f}")
        lines.append("")

    if completed < total_runs:
        if total_duration > 0 and completed > 0:
            est_remaining_s = (total_duration / completed) * (total_runs - run_count)
            est_remaining_h = est_remaining_s / 3600
            lines.append(f"- **Estimated time remaining:** {est_remaining_h:.1f} hours (based on avg {total_duration/completed:.0f}s per run)")
            est_total_cost = (total_cost / completed) * total_runs
            lines.append(f"- **Estimated total cost:** ${est_total_cost:.2f}")

    lines.append("")
    lines.append("---")
    lines.append(f"*Generated by runner.py, instructions version {INSTRUCTIONS_VERSION}*")

    (run_dir / "results.md").write_text("\n".join(lines))

# ---------------------------------------------------------------------------
# Stream Parsing
# ---------------------------------------------------------------------------

def parse_stream_output(raw_output: str) -> dict:
    """Parse the JSON stream output from claude CLI and extract metrics."""
    events = []
    console_lines = []
    claude_code_version = ""
    model_used = ""
    result_data = {}
    init_data = {}
    compaction_count = 0
    error_count = 0
    error_details = []
    install_commands = []
    install_duration_ms = 0
    tools_installed = []
    interpreter_versions = {}
    hook_events = []  # Collected from --include-hook-events

    for line in raw_output.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
            events.append(obj)
        except json.JSONDecodeError:
            continue

        event_type = obj.get("type", "")
        msg = obj.get("message", {}) if isinstance(obj.get("message"), dict) else {}
        content = msg.get("content", []) if isinstance(msg.get("content"), list) else []

        # Init event — capture all metadata about the session
        if event_type == "system" and obj.get("subtype") == "init":
            claude_code_version = obj.get("claude_code_version", "")
            model_used = obj.get("model", "")
            init_data = {
                "session_id": obj.get("session_id", ""),
                "model": model_used,
                "claude_code_version": claude_code_version,
                "permission_mode": obj.get("permissionMode", ""),
                "output_style": obj.get("output_style", ""),
                "fast_mode_state": obj.get("fast_mode_state", ""),
                "tools_available": obj.get("tools", []),
                "mcp_servers": obj.get("mcp_servers", []),
                "agents_available": obj.get("agents", []),
                "skills_available": obj.get("skills", []),
                "plugins": obj.get("plugins", []),
                "cwd": obj.get("cwd", ""),
            }

        # Assistant text
        if event_type == "assistant":
            for c in content:
                if isinstance(c, dict) and c.get("type") == "text":
                    text = c.get("text", "")
                    console_lines.append(f"[Assistant] {text}")

        # Tool use and results
        if event_type == "assistant":
            for c in content:
                if isinstance(c, dict) and c.get("type") == "tool_use":
                    tool_name = c.get("name", "")
                    tool_input = c.get("input", {})
                    if tool_name == "Bash":
                        cmd = tool_input.get("command", "")
                        console_lines.append(f"[Tool: {tool_name}] {cmd}")
                        # Check for install commands
                        for pattern in INSTALL_PATTERNS:
                            if re.search(pattern, cmd, re.IGNORECASE):
                                install_commands.append(cmd)
                                # Extract package names roughly
                                tools_installed.append(cmd.strip())
                                break
                        # Check for version commands
                        if re.search(r"--version|version|\$PSVersionTable|dotnet --info", cmd, re.IGNORECASE):
                            pass  # Version info will be in tool results
                    else:
                        detail = json.dumps(tool_input)[:200] if tool_input else ""
                        console_lines.append(f"[Tool: {tool_name}] {detail}")

        # Tool results
        if event_type == "user":
            for c in content:
                if isinstance(c, dict) and c.get("type") == "tool_result":
                    result_content = c.get("content", "")
                    is_error = c.get("is_error", False)
                    if isinstance(result_content, str):
                        console_lines.append(f"[Result{' ERROR' if is_error else ''}] {result_content[:1000]}")
                        if is_error:
                            error_count += 1
                            error_details.append(result_content[:200])
                        # Look for version strings
                        for vline in result_content.splitlines():
                            if "PSVersion" in vline:
                                parts = vline.split()
                                if len(parts) >= 2:
                                    interpreter_versions["powershell"] = parts[-1]
                            if re.match(r"^\d+\.\d+\.\d+", vline.strip()) and "dotnet" not in interpreter_versions:
                                # Could be dotnet version output
                                pass
                    elif isinstance(result_content, list):
                        for rc in result_content:
                            if isinstance(rc, dict):
                                text = rc.get("text", str(rc))[:500]
                                console_lines.append(f"[Result] {text}")

        # Compaction events
        if "compact" in event_type.lower() or "compact" in str(obj.get("subtype", "")).lower():
            compaction_count += 1

        # Hook events (from --include-hook-events)
        subtype = obj.get("subtype", "")
        if subtype in ("hook_started", "hook_response"):
            hook_entry = {
                "subtype": subtype,
                "hook_id": obj.get("hook_id", ""),
                "hook_name": obj.get("hook_name", ""),
                "hook_event": obj.get("hook_event", ""),
            }
            if subtype == "hook_response":
                hook_entry["exit_code"] = obj.get("exit_code")
                hook_entry["outcome"] = obj.get("outcome", "")
                hook_entry["stdout"] = (obj.get("stdout", "") or "")[:500]
                hook_entry["stderr"] = (obj.get("stderr", "") or "")[:500]
            hook_events.append(hook_entry)

        # Result event
        if event_type == "result":
            result_data = obj

    # Extract timing and usage from result
    duration_ms = result_data.get("duration_ms", 0)
    duration_api_ms = result_data.get("duration_api_ms", 0)
    num_turns = result_data.get("num_turns", 0)
    total_cost = result_data.get("total_cost_usd", 0.0)
    usage = result_data.get("usage", {})
    input_tokens = usage.get("input_tokens", 0)
    output_tokens = usage.get("output_tokens", 0)
    cache_read = usage.get("cache_read_input_tokens", usage.get("cache_read_tokens", 0))
    cache_creation = usage.get("cache_creation_input_tokens", usage.get("cache_creation_tokens", 0))

    # Estimate install duration from the stream: count bash tool uses that match install patterns
    # This is approximate — we track the commands but duration per command isn't in the stream
    # We'll use a heuristic: count install commands and note them
    # A more precise approach would require correlating tool_use IDs with their results

    # Extract detailed metadata from result event
    model_usage = result_data.get("modelUsage", {})
    result_meta = {
        "session_id": result_data.get("session_id", ""),
        "stop_reason": result_data.get("stop_reason", ""),
        "terminal_reason": result_data.get("terminal_reason", ""),
        "fast_mode_state": result_data.get("fast_mode_state", ""),
        "service_tier": usage.get("service_tier", ""),
        "speed": usage.get("speed", ""),
        "inference_geo": usage.get("inference_geo", ""),
        "model_usage": model_usage,
        "permission_denials": result_data.get("permission_denials", []),
        "context_window": None,
        "max_output_tokens": None,
    }
    # Extract context_window and max_output_tokens from modelUsage
    for model_key, model_info in model_usage.items():
        result_meta["context_window"] = model_info.get("contextWindow")
        result_meta["max_output_tokens"] = model_info.get("maxOutputTokens")
        break  # just take the first (should be only one)

    return {
        "events": events,
        "console_log": "\n".join(console_lines),
        "claude_code_version": claude_code_version,
        "model_used": model_used,
        "init_data": init_data,
        "result_meta": result_meta,
        "hook_events": hook_events,
        "duration_ms": duration_ms,
        "duration_api_ms": duration_api_ms,
        "num_turns": num_turns,
        "total_cost_usd": total_cost,
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "cache_read_tokens": cache_read,
        "cache_creation_tokens": cache_creation,
        "total_context_consumed": input_tokens + cache_read + cache_creation,
        "compaction_count": compaction_count,
        "error_count": error_count,
        "error_details": error_details,
        "install_commands": install_commands,
        "tools_installed": tools_installed,
        "interpreter_versions": interpreter_versions,
        "result_data": result_data,
    }

# ---------------------------------------------------------------------------
# Main Run Logic
# ---------------------------------------------------------------------------

def run_single_task(
    task: dict,
    mode: str,
    model_id: str,
    model_short: str,
    run_dir: Path,
    repo_root: Path,
    effort: str | None = None,
) -> dict:
    """Run a single task/mode/model combination and return metrics."""
    task_id = task["id"]
    task_name = task["name"]
    prompt = PROMPT_TEMPLATES[mode].format(task_description=task["description"])

    # Create workspace
    workspace = repo_root / "workspaces" / run_dir.name / task_id / f"{mode}-{model_short}"
    workspace.mkdir(parents=True, exist_ok=True)

    # Copy instructions file
    shutil.copy2(repo_root / INSTRUCTIONS_FILE, workspace / INSTRUCTIONS_FILE)

    # Create results directory
    result_dir = run_dir / "tasks" / task_id / f"{mode}-{model_short}"
    result_dir.mkdir(parents=True, exist_ok=True)

    # Capture workspace before
    workspace_before = capture_workspace_listing(workspace)
    (result_dir / "workspace-before.txt").write_text(workspace_before)

    log(f"  Starting: {task_id} | {mode} | {model_short}")
    log(f"  Workspace: {workspace}")

    # Build command
    cmd = [
        "claude",
        "-p", prompt,
        "--model", model_id,
        "--output-format", "stream-json",
        "--dangerously-skip-permissions",
        "--include-hook-events",
        "--verbose",
    ]
    if effort:
        cmd.extend(["--effort", effort])

    # Record timing
    timestamp_start = datetime.now(timezone.utc).isoformat()
    wall_start = time.time()

    # Ensure dotnet and pwsh are on PATH for the agent subprocess
    env = os.environ.copy()
    dotnet_root = Path.home() / ".dotnet"
    if dotnet_root.exists():
        env["DOTNET_ROOT"] = str(dotnet_root)
        env["PATH"] = f"{dotnet_root}:{env.get('PATH', '')}"

    # Execute
    try:
        result = subprocess.run(
            cmd,
            cwd=str(workspace),
            capture_output=True,
            text=True,
            timeout=1800,  # 30 minutes
            env=env,
        )
        raw_stdout = result.stdout
        raw_stderr = result.stderr
        exit_code = result.returncode
    except subprocess.TimeoutExpired:
        raw_stdout = ""
        raw_stderr = "TIMEOUT: Process exceeded 30 minute limit"
        exit_code = -1
        log(f"  TIMEOUT: {task_id} | {mode} | {model_short}")
    except Exception as e:
        raw_stdout = ""
        raw_stderr = f"ERROR: {str(e)}"
        exit_code = -2
        log(f"  ERROR: {task_id} | {mode} | {model_short}: {e}")

    wall_end = time.time()
    timestamp_end = datetime.now(timezone.utc).isoformat()
    grand_total_duration_ms = int((wall_end - wall_start) * 1000)

    # Parse stream output
    parsed = parse_stream_output(raw_stdout)

    # Capture workspace after
    workspace_after = capture_workspace_listing(workspace)
    (result_dir / "workspace-after.txt").write_text(workspace_after)

    # Copy generated files
    gen_dir = result_dir / "generated-code"
    generated_files = copy_generated_files(workspace, gen_dir)

    # Code metrics
    total_lines = count_lines(gen_dir) if gen_dir.exists() else 0
    all_code = get_all_code_text(gen_dir) if gen_dir.exists() else ""
    total_tokens_est = estimate_tokens(all_code)
    language_breakdown = compute_language_breakdown(gen_dir) if gen_dir.exists() else {}

    # Determine language chosen (primary language by %)
    language_chosen = ""
    if language_breakdown:
        language_chosen = max(language_breakdown, key=language_breakdown.get)
    elif mode in ("powershell", "powershell-strict"):
        language_chosen = "powershell"
    elif mode == "csharp-script":
        language_chosen = "csharp"
    elif mode == "bash":
        language_chosen = "bash"
    elif mode == "typescript-bun":
        language_chosen = "typescript"

    # Get runtime versions
    powershell_version = parsed["interpreter_versions"].get("powershell", "")
    dotnet_version = parsed["interpreter_versions"].get("dotnet", "")

    # Use parsed duration if available, fall back to wall clock
    duration_ms = parsed["duration_ms"] or grand_total_duration_ms
    api_duration_ms = parsed["duration_api_ms"] or 0
    exec_duration_ms = duration_ms - api_duration_ms if api_duration_ms else 0

    # Build metrics
    cost_rates = COST_PER_MTOK.get(model_id, {})
    metrics = {
        "task_id": task_id,
        "task_name": task_name,
        "task_category": task["category"],
        "language_mode": mode,
        "language_chosen": language_chosen,
        "language_breakdown": language_breakdown,
        "interpreter_versions": parsed["interpreter_versions"],
        "powershell_version": powershell_version,
        "dotnet_version": dotnet_version,
        "model": model_id,
        "model_short": model_short,
        "claude_code_version": parsed["claude_code_version"],
        "instructions_version": INSTRUCTIONS_VERSION,
        "timestamp_start": timestamp_start,
        "timestamp_end": timestamp_end,
        "prompt_text": prompt,
        "exit_code": exit_code,
        # Session & environment metadata — everything the CLI exposes
        "session": {
            "session_id": parsed.get("result_meta", {}).get("session_id", ""),
            "stop_reason": parsed.get("result_meta", {}).get("stop_reason", ""),
            "terminal_reason": parsed.get("result_meta", {}).get("terminal_reason", ""),
            "fast_mode_state": parsed.get("result_meta", {}).get("fast_mode_state", ""),
            "service_tier": parsed.get("result_meta", {}).get("service_tier", ""),
            "speed": parsed.get("result_meta", {}).get("speed", ""),
            "inference_geo": parsed.get("result_meta", {}).get("inference_geo", ""),
            "context_window": parsed.get("result_meta", {}).get("context_window"),
            "max_output_tokens": parsed.get("result_meta", {}).get("max_output_tokens"),
            "permission_mode": parsed.get("init_data", {}).get("permission_mode", ""),
            "output_style": parsed.get("init_data", {}).get("output_style", ""),
            "tools_available_count": len(parsed.get("init_data", {}).get("tools_available", [])),
            "mcp_servers": parsed.get("init_data", {}).get("mcp_servers", []),
            "permission_denials": parsed.get("result_meta", {}).get("permission_denials", []),
        },
        "model_usage_detail": parsed.get("result_meta", {}).get("model_usage", {}),
        "effort_level": effort,
        "timing": {
            "grand_total_duration_ms": grand_total_duration_ms,
            "total_api_duration_ms": api_duration_ms,
            "total_execution_duration_ms": exec_duration_ms,
            "num_turns": parsed["num_turns"],
        },
        "tokens": {
            "input_tokens": parsed["input_tokens"],
            "output_tokens": parsed["output_tokens"],
            "cache_read_tokens": parsed["cache_read_tokens"],
            "cache_creation_tokens": parsed["cache_creation_tokens"],
            "total_context_consumed": parsed["total_context_consumed"],
            "compaction_count": parsed["compaction_count"],
        },
        "cost": {
            "total_cost_usd": parsed["total_cost_usd"],
            "assumed_input_cost_per_mtok": cost_rates.get("input", 0),
            "assumed_output_cost_per_mtok": cost_rates.get("output", 0),
            "assumed_cache_read_cost_per_mtok": cost_rates.get("cache_read", 0),
            "assumed_cache_write_cost_per_mtok": cost_rates.get("cache_write", 0),
        },
        "code_metrics": {
            "total_lines": total_lines,
            "total_tokens_estimate": total_tokens_est,
            "file_count": len(generated_files),
            "files": generated_files,
        },
        "quality": {
            "tests_pass": None,  # Would need to actually run tests to determine
            "error_count": parsed["error_count"],
            "error_details": parsed["error_details"][:20],  # Cap at 20
            "areas_of_difficulty": [],
            "observations": "",
        },
        "tool_install": {
            "tool_install_duration_ms": 0,  # Approximate — see install_commands
            "tools_installed": parsed["tools_installed"][:20],
            "install_commands_count": len(parsed["install_commands"]),
        },
        "hooks": {
            "hook_fires": len([h for h in parsed.get("hook_events", []) if h["subtype"] == "hook_response"]),
            "hook_errors_caught": len([
                h for h in parsed.get("hook_events", [])
                if h["subtype"] == "hook_response" and h.get("stdout", "").strip()
            ]),
            "hook_failures": len([
                h for h in parsed.get("hook_events", [])
                if h["subtype"] == "hook_response" and h.get("exit_code", 0) != 0
            ]),
            "hook_events": parsed.get("hook_events", []),
        },
    }

    # Save outputs
    (result_dir / "cli-output.json").write_text(json.dumps(parsed["events"], indent=2, default=str))
    (result_dir / "console-log.txt").write_text(parsed["console_log"])
    (result_dir / "metrics.json").write_text(json.dumps(metrics, indent=2, default=str))

    if raw_stderr:
        (result_dir / "stderr.txt").write_text(raw_stderr)

    log(f"  Finished: {task_id} | {mode} | {model_short} | {grand_total_duration_ms/1000:.1f}s | ${parsed['total_cost_usd']:.4f}")
    return metrics

# ---------------------------------------------------------------------------
# CLI & Main
# ---------------------------------------------------------------------------

def print_summary_table(all_metrics: list[dict]) -> None:
    """Print a summary table of all runs."""
    print("\n" + "=" * 120)
    print("BENCHMARK RESULTS SUMMARY")
    print("=" * 120)
    print(f"{'Task':<35} {'Mode':<18} {'Model':<8} {'Duration':>10} {'Turns':>6} {'Lines':>6} {'Errors':>7} {'Cost':>10} {'Lang':<12}")
    print("-" * 120)

    total_cost = 0
    total_duration = 0

    for m in all_metrics:
        duration_s = m["timing"]["grand_total_duration_ms"] / 1000
        total_cost += m["cost"]["total_cost_usd"]
        total_duration += duration_s

        print(
            f"{m['task_name'][:34]:<35} "
            f"{m['language_mode']:<18} "
            f"{m['model_short']:<8} "
            f"{duration_s:>9.1f}s "
            f"{m['timing']['num_turns']:>6} "
            f"{m['code_metrics']['total_lines']:>6} "
            f"{m['quality']['error_count']:>7} "
            f"${m['cost']['total_cost_usd']:>9.4f} "
            f"{m['language_chosen'][:11]:<12}"
        )

    print("-" * 120)
    print(f"{'TOTALS':<63} {total_duration:>9.1f}s {'':>6} {'':>6} {'':>7} ${total_cost:>9.4f}")
    print("=" * 120)


def probe_model_metadata(model_id: str) -> dict:
    """Probe the Claude CLI to capture full model/environment metadata before the benchmark run.

    Runs a minimal `claude -p "say ok"` call and extracts every available field
    from the init and result events.  This lets us log the exact resolved model,
    service tier, context window, CLI version, etc. once at the start.
    """
    try:
        result = subprocess.run(
            ["claude", "-p", "say ok", "--model", model_id,
             "--output-format", "stream-json", "--dangerously-skip-permissions"],
            capture_output=True, text=True, timeout=60,
        )
        init_event = {}
        result_event = {}
        for line in result.stdout.splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            if obj.get("type") == "system" and obj.get("subtype") == "init":
                init_event = obj
            elif obj.get("type") == "result":
                result_event = obj
        model_usage = result_event.get("modelUsage", {})
        model_info = model_usage.get(model_id, {})
        return {
            "model_id_requested": model_id,
            "model_id_init": init_event.get("model", ""),
            "claude_code_version": init_event.get("claude_code_version", ""),
            "service_tier": result_event.get("usage", {}).get("service_tier", ""),
            "speed": result_event.get("usage", {}).get("speed", ""),
            "inference_geo": result_event.get("usage", {}).get("inference_geo", ""),
            "context_window": model_info.get("contextWindow"),
            "max_output_tokens": model_info.get("maxOutputTokens"),
            "fast_mode_state": result_event.get("fast_mode_state", ""),
            "permission_mode": init_event.get("permissionMode", ""),
            "tools_count": len(init_event.get("tools", [])),
            "mcp_servers": init_event.get("mcp_servers", []),
            "agents": init_event.get("agents", []),
            "plugins": init_event.get("plugins", []),
        }
    except Exception as e:
        log(f"  Warning: model probe for {model_id} failed: {e}")
        return {"model_id_requested": model_id, "error": str(e)}


def get_system_info() -> dict:
    """Capture system environment info for reproducibility."""
    info = {
        "platform": sys.platform,
        "python_version": sys.version,
        "hostname": "",
        "uname": "",
    }
    try:
        import platform as plat
        info["hostname"] = plat.node()
        info["uname"] = str(plat.uname())
    except Exception:
        pass
    # Tool versions
    for tool, cmd in [
        ("claude", ["claude", "--version"]),
        ("python", ["python3", "--version"]),
        ("node", ["node", "--version"]),
        ("bun", ["bun", "--version"]),
        ("pwsh", ["pwsh", "--version"]),
        ("dotnet", ["dotnet", "--version"]),
        ("actionlint", ["actionlint", "--version"]),
        ("shellcheck", ["shellcheck", "--version"]),
        ("bash", ["bash", "--version"]),
    ]:
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            info[f"{tool}_version"] = r.stdout.strip().split("\n")[0]
        except Exception:
            info[f"{tool}_version"] = "not found"
    return info


def main():
    parser = argparse.ArgumentParser(description="Benchmark Claude Code agents on scripting tasks")
    parser.add_argument(
        "--tasks", default="all",
        help="Comma-separated task numbers (1-18) or 'all' (default: all)"
    )
    parser.add_argument(
        "--models", default="opus,sonnet",
        help="Comma-separated model short names: opus,sonnet (default: opus,sonnet)"
    )
    parser.add_argument(
        "--modes", default="default,powershell,powershell-strict,csharp-script",
        help="Comma-separated language modes (default: default,powershell,powershell-strict,csharp-script)"
    )
    parser.add_argument(
        "--resume", default=None,
        help="Resume a previous run by providing its timestamp directory name (e.g., 2026-04-02_181500). Skips runs that already have metrics.json."
    )
    parser.add_argument(
        "--effort", default=None, choices=["low", "medium", "high", "max"],
        help="Reasoning effort level passed to claude CLI (default: not set, uses CLI default)"
    )
    args = parser.parse_args()

    # Parse tasks
    if args.tasks == "all":
        selected_tasks = TASKS
    else:
        task_nums = [int(t.strip()) for t in args.tasks.split(",")]
        selected_tasks = [TASKS[n - 1] for n in task_nums if 1 <= n <= len(TASKS)]

    # Parse models
    selected_models = [(short, MODELS[short]) for short in args.models.split(",") if short in MODELS]

    # Parse modes
    selected_modes = [m.strip() for m in args.modes.split(",") if m.strip() in PROMPT_TEMPLATES]

    if not selected_tasks or not selected_models or not selected_modes:
        print("Error: No valid tasks, models, or modes selected.", file=sys.stderr)
        sys.exit(1)

    # Create or resume run directory
    repo_root = Path(__file__).parent.resolve()
    if args.resume:
        run_timestamp = args.resume
        run_dir = repo_root / "results" / run_timestamp
        if not run_dir.exists():
            print(f"Error: Resume directory {run_dir} does not exist.", file=sys.stderr)
            sys.exit(1)
        log(f"Resuming run from {run_dir}")
    else:
        run_timestamp = datetime.now().strftime("%Y-%m-%d_%H%M%S")
        run_dir = repo_root / "results" / run_timestamp
    run_dir.mkdir(parents=True, exist_ok=True)

    total_runs = len(selected_tasks) * len(selected_models) * len(selected_modes)

    log(f"Benchmark starting: {len(selected_tasks)} tasks x {len(selected_models)} models x {len(selected_modes)} modes = {total_runs} runs")
    log(f"Tasks: {[t['id'] for t in selected_tasks]}")
    log(f"Models: {[m[0] for m in selected_models]}")
    log(f"Modes: {selected_modes}")
    log(f"Results: {run_dir}")
    log("")

    # Pre-flight: capture system info and probe each model
    log("Pre-flight: capturing system info...")
    system_info = get_system_info()
    log(f"  Claude CLI: {system_info.get('claude_version', 'unknown')}")
    log(f"  Python: {system_info.get('python_version', 'unknown')}")

    model_probes = {}
    for model_short, model_id in selected_models:
        log(f"Pre-flight: probing model {model_short} ({model_id})...")
        probe = probe_model_metadata(model_id)
        model_probes[model_short] = probe
        log(f"  Service tier: {probe.get('service_tier', '?')}, "
            f"Speed: {probe.get('speed', '?')}, "
            f"Context window: {probe.get('context_window', '?')}, "
            f"Max output: {probe.get('max_output_tokens', '?')}")

    # Run manifest
    manifest = {
        "run_id": run_timestamp,
        "instructions_version": INSTRUCTIONS_VERSION,
        "models_tested": [m[1] for m in selected_models],
        "modes_tested": selected_modes,
        "tasks_tested": [t["id"] for t in selected_tasks],
        "total_runs": total_runs,
        "started_at": datetime.now(timezone.utc).isoformat(),
        "completed_at": None,
        "cost_assumptions": COST_PER_MTOK,
        "total_cost_usd": 0,
        "system_info": system_info,
        "model_probes": model_probes,
        "effort_level": args.effort,
    }

    all_metrics = []
    run_count = 0

    # When resuming, load ALL existing metrics (not just ones matching current filters)
    # so that results.md reflects the full picture
    # Also use the full task count for total_runs in results.md reporting
    total_runs_for_report = total_runs
    if args.resume:
        for mf in sorted((run_dir / "tasks").rglob("metrics.json")):
            try:
                all_metrics.append(json.loads(mf.read_text()))
            except Exception:
                pass
        if all_metrics:
            log(f"Loaded {len(all_metrics)} previously completed run(s) from {run_dir}")
        # Use full benchmark size for reporting, not the filtered subset
        total_runs_for_report = len(TASKS) * len(MODELS) * len(PROMPT_TEMPLATES)

    # Detect git branch for periodic pushing
    try:
        branch_result = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            cwd=str(repo_root), capture_output=True, text=True, timeout=5,
        )
        git_branch = branch_result.stdout.strip() or "main"
    except Exception:
        git_branch = "main"

    # Start periodic pusher — seed with already-loaded metrics
    pusher = PeriodicPusher(repo_root, git_branch, total_runs_for_report, run_dir)
    pusher.update(len(all_metrics), all_metrics)
    pusher.start()
    log(f"Periodic git push enabled every {PUSH_INTERVAL}s to branch {git_branch}")

    for task in selected_tasks:
        for model_short, model_id in selected_models:
            for mode in selected_modes:
                run_count += 1
                # Check if already completed (for --resume)
                existing_metrics = run_dir / "tasks" / task["id"] / f"{mode}-{model_short}" / "metrics.json"
                if existing_metrics.exists():
                    log(f"Run {run_count}/{total_runs} — SKIPPED (already completed): {task['id']} | {mode} | {model_short}")
                    pusher.update(run_count, all_metrics)
                    continue
                log(f"Run {run_count}/{total_runs}")
                try:
                    metrics = run_single_task(
                        task=task,
                        mode=mode,
                        model_id=model_id,
                        model_short=model_short,
                        run_dir=run_dir,
                        repo_root=repo_root,
                        effort=args.effort,
                    )
                    all_metrics.append(metrics)
                except Exception as e:
                    log(f"  FATAL ERROR in {task['id']} | {mode} | {model_short}: {e}")
                    import traceback
                    traceback.print_exc(file=sys.stderr)
                pusher.update(run_count, all_metrics)
                log("")

    # Finalize manifest
    manifest["completed_at"] = datetime.now(timezone.utc).isoformat()
    manifest["total_cost_usd"] = sum(m["cost"]["total_cost_usd"] for m in all_metrics)
    (run_dir / "run-manifest.json").write_text(json.dumps(manifest, indent=2, default=str))

    # Summary
    summary = {
        "run_id": run_timestamp,
        "total_runs": len(all_metrics),
        "total_cost_usd": manifest["total_cost_usd"],
        "total_duration_s": sum(m["timing"]["grand_total_duration_ms"] for m in all_metrics) / 1000,
        "by_mode": {},
        "by_model": {},
        "tasks": [{
            "task_id": m["task_id"],
            "mode": m["language_mode"],
            "model": m["model_short"],
            "duration_s": m["timing"]["grand_total_duration_ms"] / 1000,
            "cost_usd": m["cost"]["total_cost_usd"],
            "lines": m["code_metrics"]["total_lines"],
            "errors": m["quality"]["error_count"],
            "language": m["language_chosen"],
            "turns": m["timing"]["num_turns"],
        } for m in all_metrics],
    }

    # Aggregate by mode
    for mode in selected_modes:
        mode_metrics = [m for m in all_metrics if m["language_mode"] == mode]
        if mode_metrics:
            summary["by_mode"][mode] = {
                "avg_duration_s": sum(m["timing"]["grand_total_duration_ms"] for m in mode_metrics) / len(mode_metrics) / 1000,
                "avg_lines": sum(m["code_metrics"]["total_lines"] for m in mode_metrics) / len(mode_metrics),
                "avg_errors": sum(m["quality"]["error_count"] for m in mode_metrics) / len(mode_metrics),
                "total_cost_usd": sum(m["cost"]["total_cost_usd"] for m in mode_metrics),
            }

    # Aggregate by model
    for model_short, _ in selected_models:
        model_metrics = [m for m in all_metrics if m["model_short"] == model_short]
        if model_metrics:
            summary["by_model"][model_short] = {
                "avg_duration_s": sum(m["timing"]["grand_total_duration_ms"] for m in model_metrics) / len(model_metrics) / 1000,
                "avg_lines": sum(m["code_metrics"]["total_lines"] for m in model_metrics) / len(model_metrics),
                "avg_errors": sum(m["quality"]["error_count"] for m in model_metrics) / len(model_metrics),
                "total_cost_usd": sum(m["cost"]["total_cost_usd"] for m in model_metrics),
            }

    (run_dir / "summary.json").write_text(json.dumps(summary, indent=2, default=str))

    # Print summary
    print_summary_table(all_metrics)

    # Final results.md and push — squashes any remaining incremental commits
    pusher.stop()
    generate_results_md(run_dir, all_metrics, total_runs, run_count)
    git_push_results(repo_root, git_branch, run_count, total_runs, final=True)
    log(f"Final results pushed to {git_branch}")

    log(f"\nResults saved to: {run_dir}")
    log(f"Total cost: ${manifest['total_cost_usd']:.4f}")


if __name__ == "__main__":
    main()
