#!/usr/bin/env python3
"""Audit LLM judge rationales for testable factual claims that the
workspace contradicts.

Context: the Judge Consistency Summary flags rows where two panel
judges disagree by 4 points on a 1-5 scale (Haiku=1 / Gemini=5).
`results/analysis/judge_disagreement_1-vs-5_2026-04-21.md` traced the
first three such rows: all three were Haiku insisting required files
were "missing" when they in fact lived under the run's
`generated-code/` subtree. The heuristic here bounds how often that
pattern appears across every span-4 row, and produces a verdict per
judge so downstream reports can drop the contradicted scores.

Verdicts per (run, judge) pair:
  - "contradicted": rationale claims one or more files are missing
    that in fact exist in the run's `generated-code/` tree.
  - "no_testable_claims": rationale makes no file-existence claim we
    can verify against the workspace. Keep the score.
  - "confirmed_missing": rationale claims a file is missing and that
    file genuinely is absent. Keep the score (judge was right).

Drop rule the reports apply:
  - If one judge is "contradicted" and the other isn't → use only the
    non-contradicted judge's score.
  - If both are "contradicted" → drop both; panel mean becomes None
    for that row.
  - If neither is "contradicted" → keep both (panel mean unchanged).

Usage (CLI — optional, the functions below are the public API):
    python3 judge_audit.py results/2026-04-17_004319 results/2026-04-09_152435

Output: one `judge-audit.json` per flagged variant directory, and a
combined `judge-audit-summary.json` in the first results root for the
report builder to consume.
"""
from __future__ import annotations

import json
import re
import sys
from dataclasses import dataclass, asdict, field
from pathlib import Path

SPAN_THRESHOLD = 4  # |haiku_overall - gemini_overall| ≥ this → flagged
KINDS = ("test-quality", "deliverable-quality")
JUDGE_SHORTS = ("haiku45", "gemini31pro")

# Phrases that precede a "the file is not there" factual claim in
# the rationale text. Case-insensitive; each is matched as a word or
# phrase, not a substring, so "not provided" doesn't trip on "not
# provided with".
MISSING_PHRASES = (
    "missing",
    "not provided",
    "not present",
    "does not exist",
    "doesn't exist",
    "not in submission",
    "not in the submission",
    "not found in",
    "not included",
    "non-existent",
    "nonexistent",
    "no such file",
    "no mechanism shown",  # borderline, but appears verbatim in Haiku's rationales
)

# File tokens we will look for. Paths like `tests/foo.bats` are
# captured as single tokens; bare filenames like `bump-version.sh`
# are captured via the simpler pattern. Avoid matching URL fragments
# or trivial `.txt` log files that the judge wouldn't sensibly flag
# as a "required" missing file — restrict to code/config extensions.
_FILE_EXTS = ("py", "ts", "js", "yml", "yaml", "bats", "sh", "ps1",
              "bash", "json", "toml", "md", "tsx", "mjs", "cjs")
# Alternation is greedy left-to-right, so `js` would shadow `json`
# when both can match. Sort longest-first so `json` wins on `foo.json`.
_EXT_RE = "|".join(sorted(_FILE_EXTS, key=len, reverse=True))
_PATH_RE = re.compile(
    r"`?([\w./\-]+?\.(?:" + _EXT_RE + r"))`?",
    re.IGNORECASE,
)

# Directory-style claims — e.g. "test_fixtures/ does not exist".
_DIR_RE = re.compile(
    r"`?([\w./\-]+?/)[`']?(?=[\s.,;\)\]]|$)",
)


@dataclass
class JudgeVerdict:
    judge_short: str
    overall: float | int | None
    verdict: str           # "contradicted" | "no_testable_claims" | "confirmed_missing"
    contradicted_paths: list[str] = field(default_factory=list)
    confirmed_missing_paths: list[str] = field(default_factory=list)
    claimed_missing_raw: list[str] = field(default_factory=list)
    summary_excerpt: str = ""


@dataclass
class RowAudit:
    results_root: str
    task_id: str
    variant_subdir: str
    kind: str                               # "test-quality" | "deliverable-quality"
    scores: dict                            # {"haiku45": 1, "gemini31pro": 5}
    span: float                             # abs(haiku - gemini)
    verdicts: dict                          # {"haiku45": JudgeVerdict, "gemini31pro": JudgeVerdict}
    panel_decision: str                     # "keep_both" | "drop_haiku45" | "drop_gemini31pro" | "drop_both"
    adjusted_mean: float | None             # panel mean after applying the decision

    def to_dict(self) -> dict:
        return {
            "results_root": self.results_root,
            "task_id": self.task_id,
            "variant_subdir": self.variant_subdir,
            "kind": self.kind,
            "scores": self.scores,
            "span": self.span,
            "verdicts": {k: asdict(v) for k, v in self.verdicts.items()},
            "panel_decision": self.panel_decision,
            "adjusted_mean": self.adjusted_mean,
        }


def _list_workspace_paths(gen_dir: Path) -> set[str]:
    """Every file path under gen_dir, relative to gen_dir, plus the
    basenames. Used as the truth set we test rationale claims against.
    Directory paths are included as `relpath/` with trailing slash so
    the directory-regex tokens match."""
    paths: set[str] = set()
    if not gen_dir.is_dir():
        return paths
    for p in gen_dir.rglob("*"):
        try:
            rel = p.relative_to(gen_dir).as_posix()
        except ValueError:
            continue
        if p.is_dir():
            paths.add(rel + "/")
        else:
            paths.add(rel)
            paths.add(Path(rel).name)
    return paths


def _extract_claimed_missing(summary: str) -> list[str]:
    """Find file/dir tokens that appear near one of the MISSING_PHRASES
    in the rationale. Returns the raw tokens (deduplicated, order-
    preserved) so downstream code can resolve them against the
    workspace."""
    if not summary:
        return []
    low = summary.lower()
    spans: list[tuple[int, int]] = []
    for phrase in MISSING_PHRASES:
        start = 0
        while True:
            idx = low.find(phrase, start)
            if idx < 0:
                break
            # Claim window: 140 chars on either side of the phrase.
            # Wide enough to catch "File X is missing — the workflow
            # references it" where the filename sits to the left of
            # "missing", and "missing Y; the workflow fails" where it
            # sits to the right.
            spans.append((max(0, idx - 140), min(len(summary), idx + 140)))
            start = idx + len(phrase)
    if not spans:
        return []

    found: list[str] = []
    seen: set[str] = set()
    for lo, hi in spans:
        window = summary[lo:hi]
        for m in _PATH_RE.finditer(window):
            tok = m.group(1).strip().strip("`.,;:")
            if tok and tok not in seen:
                found.append(tok)
                seen.add(tok)
        for m in _DIR_RE.finditer(window):
            tok = m.group(1).strip().strip("`.,;:")
            # Only accept directory tokens that look like real paths
            # — reject trivial matches like "the/" or noise like "2/".
            if "/" in tok and len(tok) >= 4 and tok not in seen:
                found.append(tok)
                seen.add(tok)
    return found


def _classify(claimed: list[str], workspace: set[str]) -> tuple[str, list[str], list[str]]:
    """Return (verdict, contradicted, confirmed_missing)."""
    if not claimed:
        return "no_testable_claims", [], []
    contradicted: list[str] = []
    confirmed: list[str] = []
    for token in claimed:
        # Exact match, trailing-slash match, or basename match all
        # count as "present". A token like `.github/workflows/foo.yml`
        # should also match if the workspace contains it exactly.
        tok = token.strip()
        if not tok:
            continue
        # Normalize: strip leading `./`.
        norm = tok.removeprefix("./")
        # Direct present?
        if (norm in workspace
                or (norm + "/") in workspace
                or Path(norm).name in workspace):
            contradicted.append(token)
        else:
            confirmed.append(token)
    if contradicted:
        return "contradicted", contradicted, confirmed
    return "confirmed_missing", contradicted, confirmed


def audit_variant(results_root: Path, task_dir: Path, variant_dir: Path,
                  kind: str) -> RowAudit | None:
    """Audit one (task, variant, kind) triple. Returns None if the
    pair of judge caches don't exist or the span isn't flag-worthy."""
    jpaths = {
        j: variant_dir / f"{kind}-{j}.json" for j in JUDGE_SHORTS
    }
    if not all(p.exists() for p in jpaths.values()):
        return None
    try:
        judges_data = {j: json.loads(p.read_text()) for j, p in jpaths.items()}
    except Exception:
        return None
    scores = {j: judges_data[j].get("overall") for j in JUDGE_SHORTS}
    if not all(isinstance(v, (int, float)) for v in scores.values()):
        return None
    span = abs(scores["haiku45"] - scores["gemini31pro"])
    if span < SPAN_THRESHOLD:
        return None

    gen_dir = variant_dir / "generated-code"
    workspace = _list_workspace_paths(gen_dir)

    verdicts: dict[str, JudgeVerdict] = {}
    for j in JUDGE_SHORTS:
        summary = judges_data[j].get("summary", "") or ""
        claimed = _extract_claimed_missing(summary)
        verdict, contradicted, confirmed = _classify(claimed, workspace)
        verdicts[j] = JudgeVerdict(
            judge_short=j,
            overall=scores[j],
            verdict=verdict,
            contradicted_paths=contradicted,
            confirmed_missing_paths=confirmed,
            claimed_missing_raw=claimed,
            summary_excerpt=summary[:500],
        )

    # Panel decision.
    h_bad = verdicts["haiku45"].verdict == "contradicted"
    g_bad = verdicts["gemini31pro"].verdict == "contradicted"
    if h_bad and g_bad:
        decision = "drop_both"
        adjusted: float | None = None
    elif h_bad:
        decision = "drop_haiku45"
        adjusted = float(scores["gemini31pro"])
    elif g_bad:
        decision = "drop_gemini31pro"
        adjusted = float(scores["haiku45"])
    else:
        decision = "keep_both"
        adjusted = (scores["haiku45"] + scores["gemini31pro"]) / 2

    return RowAudit(
        results_root=results_root.name,
        task_id=task_dir.name,
        variant_subdir=variant_dir.name,
        kind=kind,
        scores=scores,
        span=float(span),
        verdicts=verdicts,
        panel_decision=decision,
        adjusted_mean=adjusted,
    )


def audit_all(results_roots: list[Path]) -> list[RowAudit]:
    """Scan every run directory under each root; return the list of
    flagged rows with verdicts applied."""
    out: list[RowAudit] = []
    for root in results_roots:
        if not root.is_dir():
            continue
        for variant_dir in sorted(root.glob("tasks/*/*/")):
            task_dir = variant_dir.parent
            for kind in KINDS:
                row = audit_variant(root, task_dir, variant_dir, kind)
                if row is not None:
                    out.append(row)
    return out


def write_per_variant_caches(audits: list[RowAudit], roots: list[Path]) -> None:
    """Persist one judge-audit.json per flagged variant directory
    (next to the per-judge score caches). Downstream report builders
    read these back to annotate the JCS-flagged rows."""
    by_root = {r.name: r for r in roots}
    for a in audits:
        root = by_root.get(a.results_root)
        if root is None:
            continue
        variant_dir = root / "tasks" / a.task_id / a.variant_subdir
        # Each cache file is named per kind so test-quality vs
        # deliverable-quality audits don't clobber one another.
        target = variant_dir / f"judge-audit-{a.kind}.json"
        target.write_text(json.dumps(a.to_dict(), indent=2))


def load_audit(variant_dir: Path, kind: str) -> dict | None:
    """Read a cached audit for (variant_dir, kind); None if absent."""
    p = variant_dir / f"judge-audit-{kind}.json"
    if not p.exists():
        return None
    try:
        return json.loads(p.read_text())
    except Exception:
        return None


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: judge_audit.py <run_dir> [<run_dir> ...]", file=sys.stderr)
        return 2
    roots = [Path(a) for a in sys.argv[1:]]
    audits = audit_all(roots)
    write_per_variant_caches(audits, roots)
    # Print a compact summary to stdout.
    counts = {"contradicted": 0, "no_testable_claims": 0,
              "confirmed_missing": 0}
    for a in audits:
        for v in a.verdicts.values():
            counts[v.verdict] = counts.get(v.verdict, 0) + 1
    print(f"Flagged rows: {len(audits)}")
    print(f"Per-judge verdicts: {counts}")
    dec_counts: dict[str, int] = {}
    for a in audits:
        dec_counts[a.panel_decision] = dec_counts.get(a.panel_decision, 0) + 1
    print(f"Panel decisions: {dec_counts}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
