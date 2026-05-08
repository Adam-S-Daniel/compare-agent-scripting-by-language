"""
Generate per-Claude-Code-version reference docs in each results directory.

For every CC version observed in `metrics.json` files under a results dir,
write `claude-code-<version>.md` containing:

  1. The full system prompt (concatenated from
     Piebald-AI/claude-code-system-prompts at tag v<version>'s
     `system-prompts/system-prompt-*.md` files).
  2. The default-tool descriptions documented at that version
     (`system-prompts/tool-description-*.md`), sorted alphabetically by
     tool name with a stable ordering for review-friendliness.
  3. The full chronological Anthropic Claude Code changelog from the
     lowest version observed across ANY benchmark in the repo through
     the version this file covers — both bounds inclusive.

Sources are fetched from raw.githubusercontent.com and cached under
`.cache/cc-versions/` (gitignored); subsequent runs reuse the cache.

CLI:
    # All results directories
    python3 version_docs.py

    # One specific run
    python3 version_docs.py results/2026-05-06_173435

The Piebald-AI repo (https://github.com/Piebald-AI/claude-code-system-prompts)
is the third-party authoritative archive of CC's per-version prompt; tags
exist for every CC release since v2.0.14.
"""

from __future__ import annotations

import json
import re
import sys
import urllib.request
from collections import defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).parent.resolve()
CACHE_DIR = REPO_ROOT / ".cache" / "cc-versions"
PIEBALD_OWNER_REPO = "Piebald-AI/claude-code-system-prompts"
ANTHROPIC_OWNER_REPO = "anthropics/claude-code"

VERSION_RE = re.compile(r"^\d+\.\d+\.\d+$")


def _fetch(url: str, cache_path: Path) -> str:
    """GET `url` once, cache result on disk, return text."""
    if cache_path.exists():
        return cache_path.read_text()
    cache_path.parent.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(url, headers={"User-Agent": "version-docs.py/1.0"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        text = resp.read().decode("utf-8", errors="replace")
    cache_path.write_text(text)
    return text


def list_files_at_tag(version: str) -> list[str]:
    """Return all blob paths at Piebald-AI's tag v<version>."""
    cache = CACHE_DIR / f"piebald-tree-v{version}.json"
    url = f"https://api.github.com/repos/{PIEBALD_OWNER_REPO}/git/trees/v{version}?recursive=1"
    text = _fetch(url, cache)
    tree = json.loads(text).get("tree", [])
    return [t["path"] for t in tree if t.get("type") == "blob"]


def fetch_piebald_file(version: str, path: str) -> str:
    """Fetch a single file from Piebald-AI at tag v<version>."""
    cache = CACHE_DIR / f"piebald-v{version}-{path.replace('/', '_')}"
    url = f"https://raw.githubusercontent.com/{PIEBALD_OWNER_REPO}/v{version}/{path}"
    return _fetch(url, cache)


def fetch_anthropic_changelog() -> str:
    """Fetch Anthropic's CHANGELOG.md (always main; entries are append-only)."""
    cache = CACHE_DIR / "anthropic-changelog-main.md"
    url = f"https://raw.githubusercontent.com/{ANTHROPIC_OWNER_REPO}/main/CHANGELOG.md"
    if cache.exists():
        cache.unlink()  # Always refetch CHANGELOG; cheap and ensures freshness.
    return _fetch(url, cache)


def discover_versions_in_dir(run_dir: Path) -> set[str]:
    """Versions of CC that ran any task within `run_dir`."""
    versions: set[str] = set()
    for mf in run_dir.rglob("metrics.json"):
        try:
            v = json.loads(mf.read_text()).get("claude_code_version", "")
        except Exception:
            continue
        if VERSION_RE.match(v):
            versions.add(v)
    return versions


def discover_all_versions(results_root: Path) -> set[str]:
    """Union of CC versions observed across every run dir under `results/`."""
    versions: set[str] = set()
    for run_dir in results_root.iterdir():
        if not run_dir.is_dir() or run_dir.name.startswith("results_") or run_dir.name == "analysis":
            continue
        versions |= discover_versions_in_dir(run_dir)
    return versions


def version_tuple(v: str) -> tuple[int, ...]:
    return tuple(int(x) for x in v.split("."))


def assemble_system_prompt(version: str, files: list[str]) -> str:
    """Concatenate every `system-prompts/system-prompt-*.md` at this tag."""
    chunks: list[str] = []
    sp_files = sorted(f for f in files if f.startswith("system-prompts/system-prompt-")
                      and f.endswith(".md"))
    for fpath in sp_files:
        body = fetch_piebald_file(version, fpath).rstrip()
        # Filename → stable section heading.
        stem = Path(fpath).stem.replace("system-prompt-", "")
        chunks.append(f"#### `{stem}`\n\n{body}\n")
    return "\n".join(chunks)


def assemble_tool_descriptions(version: str, files: list[str]) -> str:
    """Each `tool-description-*.md` rendered as one section, sorted by tool name."""
    chunks: list[str] = []
    td_files = sorted(f for f in files if f.startswith("system-prompts/tool-description-")
                      and f.endswith(".md"))
    for fpath in td_files:
        body = fetch_piebald_file(version, fpath).rstrip()
        # Strip the prefix: tool-description-Bash.md → Bash; tool-description-bash-grep.md
        # has dashes already so collapse hyphens for display fidelity.
        tool_name = Path(fpath).stem.replace("tool-description-", "")
        chunks.append(f"#### `{tool_name}`\n\n{body}\n")
    return "\n".join(chunks)


def slice_changelog(full_changelog: str, lower_version: str, upper_version: str) -> str:
    """Return changelog entries with versions in [lower, upper], chronological.

    Anthropic's CHANGELOG.md is reverse-chronological (newest first) with
    `## <version>` headers. We extract only entries inside [lower, upper]
    inclusive, then reverse so output is chronological (oldest first), per
    the spec.
    """
    sections: list[tuple[str, str]] = []  # (version, raw_section_including_header)
    lines = full_changelog.splitlines()
    i = 0
    while i < len(lines):
        m = re.match(r"^## (\d+\.\d+\.\d+)\s*$", lines[i])
        if m:
            ver = m.group(1)
            j = i + 1
            while j < len(lines) and not re.match(r"^## \d+\.\d+\.\d+\s*$", lines[j]):
                j += 1
            section_text = "\n".join(lines[i:j]).rstrip()
            sections.append((ver, section_text))
            i = j
        else:
            i += 1

    lo = version_tuple(lower_version)
    hi = version_tuple(upper_version)
    in_range = [s for s in sections if lo <= version_tuple(s[0]) <= hi]
    in_range.sort(key=lambda s: version_tuple(s[0]))  # oldest first
    return "\n\n".join(s[1] for s in in_range)


def build_doc(version: str, lowest_repo_version: str, full_changelog: str) -> str:
    """Compose the per-version markdown file content."""
    files = list_files_at_tag(version)
    sp_md = assemble_system_prompt(version, files)
    td_md = assemble_tool_descriptions(version, files)
    changelog_md = slice_changelog(full_changelog, lowest_repo_version, version)

    sp_count = sum(1 for f in files
                   if f.startswith("system-prompts/system-prompt-") and f.endswith(".md"))
    td_count = sum(1 for f in files
                   if f.startswith("system-prompts/tool-description-") and f.endswith(".md"))

    return (
        f"# Claude Code v{version} — system prompt, tools, and changelog\n"
        "\n"
        f"Reference snapshot of Claude Code v{version} as it ran in this benchmark.\n"
        f"Compiled from upstream sources by `version_docs.py`.\n"
        "\n"
        "## Sources\n"
        "\n"
        f"- System prompt + tool descriptions: "
        f"[`Piebald-AI/claude-code-system-prompts` @ v{version}](https://github.com/{PIEBALD_OWNER_REPO}/tree/v{version}/system-prompts) "
        f"({sp_count} system-prompt fragments, {td_count} tool descriptions).\n"
        f"- Changelog: [`anthropics/claude-code` `CHANGELOG.md`](https://github.com/{ANTHROPIC_OWNER_REPO}/blob/main/CHANGELOG.md), "
        f"sliced to **[{lowest_repo_version}, {version}]** inclusive — `{lowest_repo_version}` is the lowest CC version observed across any benchmark in this repo.\n"
        "\n"
        "## Table of Contents\n"
        "\n"
        "- [System Prompt (full)](#system-prompt-full)\n"
        "- [Default Tool Descriptions (sorted)](#default-tool-descriptions-sorted)\n"
        f"- [Changelog ({lowest_repo_version} → {version}, chronological)](#changelog)\n"
        "\n"
        "## System Prompt (full)\n"
        "\n"
        f"Each `### ` heading below is one fragment from `system-prompts/system-prompt-*.md` at "
        f"`v{version}`. Different fragments are conditionally combined at runtime depending on "
        f"session context (memory mode, plan mode, fast mode, etc.); this section is the union "
        f"of all fragments shipped in this version.\n"
        "\n"
        f"{sp_md}\n"
        "\n"
        "## Default Tool Descriptions (sorted)\n"
        "\n"
        f"One section per `tool-description-*.md`, sorted by tool name.\n"
        "\n"
        f"{td_md}\n"
        "\n"
        f"## Changelog ({lowest_repo_version} → {version}, chronological)\n"
        "\n"
        f"Verbatim from upstream, oldest first.\n"
        "\n"
        f"{changelog_md}\n"
    )


def main() -> int:
    args = sys.argv[1:]
    results_root = REPO_ROOT / "results"

    if args:
        run_dirs = [Path(a).resolve() for a in args]
    else:
        run_dirs = [d for d in results_root.iterdir()
                    if d.is_dir() and not d.name.startswith("results_") and d.name != "analysis"]

    all_versions = discover_all_versions(results_root)
    if not all_versions:
        print("No CC versions found in any results dir; nothing to do.", file=sys.stderr)
        return 1
    lowest = min(all_versions, key=version_tuple)
    print(f"Lowest CC version observed across repo: {lowest}")
    print(f"Distinct versions across all runs: {sorted(all_versions, key=version_tuple)}")

    full_changelog = fetch_anthropic_changelog()
    print(f"Fetched Anthropic changelog ({len(full_changelog):,} chars).")

    for run_dir in sorted(run_dirs):
        if not run_dir.exists():
            print(f"  skipping missing dir: {run_dir}", file=sys.stderr)
            continue
        versions_here = discover_versions_in_dir(run_dir)
        if not versions_here:
            continue
        print(f"\n{run_dir.relative_to(REPO_ROOT)}: versions {sorted(versions_here, key=version_tuple)}")
        for ver in sorted(versions_here, key=version_tuple):
            out_path = run_dir / f"claude-code-{ver}.md"
            try:
                content = build_doc(ver, lowest, full_changelog)
            except Exception as e:
                print(f"  ! failed to build doc for v{ver}: {e}", file=sys.stderr)
                continue
            out_path.write_text(content)
            print(f"  wrote {out_path.relative_to(REPO_ROOT)} ({len(content):,} chars)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
