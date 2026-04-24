"""Unit tests for judge_audit.py — rationale auditing heuristic."""

import json
from pathlib import Path

import pytest

from judge_audit import (
    _classify,
    _extract_claimed_missing,
    _list_workspace_paths,
    audit_variant,
    SPAN_THRESHOLD,
)


class TestExtractClaimedMissing:
    """The heuristic is conservative: require both a MISSING_PHRASES
    marker and a file-like token in a ±140 char window. Bare prose
    without a concrete path must not produce claimed tokens — the
    audit has to be actionable."""

    def test_claim_with_named_file_extracted(self):
        s = ("CRITICAL: Workflow references tests/version_bumper.bats "
             "but file not provided. Test harness will fail.")
        out = _extract_claimed_missing(s)
        assert "tests/version_bumper.bats" in out

    def test_multiple_missing_files_all_captured(self):
        s = ("Missing test fixtures (mixed-secrets.json, all-ok.json, "
             "all-expired.json) referenced in workflow will cause "
             "immediate failure.")
        out = _extract_claimed_missing(s)
        for name in ("mixed-secrets.json", "all-ok.json", "all-expired.json"):
            assert name in out, f"expected {name} in {out}"

    def test_json_not_truncated_to_js(self):
        # Regression: alternation `js|json` would greedily eat only `.js`
        # from `.json`. Sort longest-first in the regex or this fails.
        s = "Missing file: config.json"
        out = _extract_claimed_missing(s)
        assert out == ["config.json"], out

    def test_no_marker_no_claim(self):
        # Rationale mentioning a file without a missing-phrase must
        # produce nothing — we are not auditing every filename the
        # judge cites, only the ones it asserted were absent.
        s = "Tests use tests/version_bumper.bats which covers 29 cases well."
        assert _extract_claimed_missing(s) == []

    def test_marker_without_nearby_path_yields_nothing(self):
        # Prose-only claims ("missing bats test files") without a
        # concrete path must not produce anything actionable.
        s = "Missing entirely: bats-core test files, installation step."
        assert _extract_claimed_missing(s) == []

    def test_deduplicates(self):
        s = ("missing foo.yml. The workflow also fails because foo.yml "
             "does not exist. The foo.yml file is required.")
        out = _extract_claimed_missing(s)
        assert out.count("foo.yml") == 1


class TestClassify:
    """_classify turns extracted tokens into a verdict against the
    workspace path set. Contradicted wins over confirmed_missing as
    soon as one claimed token is actually present — the rationale has
    a false claim in it, which is enough to flag it."""

    def test_empty_claim_is_no_testable_claims(self):
        verdict, contradicted, confirmed = _classify([], {"a.py"})
        assert verdict == "no_testable_claims"
        assert contradicted == []
        assert confirmed == []

    def test_all_claims_resolve_to_existing_files_is_contradicted(self):
        verdict, contradicted, _ = _classify(
            ["foo.yml", "tests/foo.bats"],
            {"foo.yml", "tests/foo.bats", "tests/", "foo.bats"},
        )
        assert verdict == "contradicted"
        assert set(contradicted) == {"foo.yml", "tests/foo.bats"}

    def test_all_claims_genuinely_missing_is_confirmed_missing(self):
        verdict, contradicted, confirmed = _classify(
            ["not-here.yml", "nope.py"], {"other.yml"}
        )
        assert verdict == "confirmed_missing"
        assert contradicted == []
        assert set(confirmed) == {"not-here.yml", "nope.py"}

    def test_mixed_claims_one_contradicted_wins(self):
        # If any claim is testably wrong, the judge's rationale has a
        # factual error — enough to flag even if other claims are
        # correct. This matches the user's drop rule exactly.
        verdict, contradicted, _ = _classify(
            ["present.py", "missing.py"],
            {"present.py"}
        )
        assert verdict == "contradicted"
        assert contradicted == ["present.py"]

    def test_basename_match_counts_as_present(self):
        # Judges cite files by name a lot ("bump-version.sh") without
        # the directory prefix. As long as some file with that basename
        # exists in the workspace, the claim is contradicted.
        verdict, contradicted, _ = _classify(
            ["bump-version.sh"],
            {"scripts/bump-version.sh", "bump-version.sh"}
        )
        assert verdict == "contradicted"


class TestListWorkspacePaths:
    def test_includes_relpaths_directories_and_basenames(self, tmp_path):
        gen = tmp_path / "generated-code"
        (gen / "tests").mkdir(parents=True)
        (gen / ".github" / "workflows").mkdir(parents=True)
        (gen / "tests" / "foo.bats").write_text("x")
        (gen / ".github" / "workflows" / "w.yml").write_text("x")

        paths = _list_workspace_paths(gen)
        assert ".github/workflows/w.yml" in paths
        assert "tests/foo.bats" in paths
        # directory tokens carry a trailing slash so the _DIR_RE match
        # in the extractor matches them directly
        assert "tests/" in paths
        # basenames present for bare-filename claims
        assert "w.yml" in paths
        assert "foo.bats" in paths

    def test_missing_directory_returns_empty(self, tmp_path):
        assert _list_workspace_paths(tmp_path / "nope") == set()


class TestAuditVariantEndToEnd:
    """End-to-end: given a variant directory containing two judge
    caches and a generated-code tree, audit_variant returns a
    RowAudit with the right panel decision."""

    def _scaffold(self, tmp_path, haiku_overall, haiku_summary,
                  gemini_overall, gemini_summary, files):
        variant = tmp_path / "tasks" / "11-task" / "bash-opus"
        (variant / "generated-code").mkdir(parents=True)
        for rel, content in files.items():
            p = variant / "generated-code" / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(content)
        (variant / "test-quality-haiku45.json").write_text(json.dumps({
            "coverage": 1, "rigor": 1, "design": 1,
            "overall": haiku_overall, "summary": haiku_summary,
        }))
        (variant / "test-quality-gemini31pro.json").write_text(json.dumps({
            "coverage": 5, "rigor": 5, "design": 5,
            "overall": gemini_overall, "summary": gemini_summary,
        }))
        return variant

    def test_contradicted_haiku_drops_haiku(self, tmp_path):
        variant = self._scaffold(
            tmp_path,
            haiku_overall=1,
            haiku_summary=("CRITICAL: workflow references "
                           "tests/foo.bats but file not provided."),
            gemini_overall=5,
            gemini_summary="Excellent modular Bash; tests run cleanly.",
            files={"tests/foo.bats": "@test 'x' { : }"},
        )
        audit = audit_variant(tmp_path, variant.parent, variant, "test-quality")
        assert audit is not None
        assert audit.span == 4
        assert audit.panel_decision == "drop_haiku45"
        assert audit.adjusted_mean == 5.0
        assert audit.verdicts["haiku45"].verdict == "contradicted"
        assert "tests/foo.bats" in audit.verdicts["haiku45"].contradicted_paths
        assert audit.verdicts["gemini31pro"].verdict == "no_testable_claims"

    def test_both_contradicted_drops_both_panel_mean_none(self, tmp_path):
        variant = self._scaffold(
            tmp_path,
            haiku_overall=1,
            haiku_summary="Missing foo.yml entirely.",
            gemini_overall=5,
            gemini_summary="Tests fail because bar.py does not exist in submission.",
            files={"foo.yml": "", "bar.py": ""},
        )
        audit = audit_variant(tmp_path, variant.parent, variant, "test-quality")
        assert audit.panel_decision == "drop_both"
        assert audit.adjusted_mean is None

    def test_neither_contradicted_keeps_both(self, tmp_path):
        variant = self._scaffold(
            tmp_path,
            haiku_overall=1,
            haiku_summary="Tests are sparse; edge cases missing entirely.",
            gemini_overall=5,
            gemini_summary="Thorough coverage across all requirements.",
            files={"impl.py": ""},
        )
        audit = audit_variant(tmp_path, variant.parent, variant, "test-quality")
        assert audit.panel_decision == "keep_both"
        assert audit.adjusted_mean == 3.0

    def test_span_below_threshold_returns_none(self, tmp_path):
        # Only 2-point gap — not flag-worthy, audit skipped entirely.
        variant = self._scaffold(
            tmp_path, haiku_overall=3,
            haiku_summary="Meh tests; missing foo.yml, maybe fine.",
            gemini_overall=5,
            gemini_summary="Good.",
            files={},
        )
        assert audit_variant(tmp_path, variant.parent, variant, "test-quality") is None

    def test_confirmed_missing_does_not_drop(self, tmp_path):
        # Haiku claims a file missing that genuinely is — keep the score.
        variant = self._scaffold(
            tmp_path,
            haiku_overall=1,
            haiku_summary="Workflow references needed.py but it does not exist.",
            gemini_overall=5,
            gemini_summary="Good.",
            files={"other.py": ""},
        )
        audit = audit_variant(tmp_path, variant.parent, variant, "test-quality")
        assert audit.panel_decision == "keep_both"
        assert audit.verdicts["haiku45"].verdict == "confirmed_missing"

    def test_missing_judge_caches_returns_none(self, tmp_path):
        variant = tmp_path / "tasks" / "x" / "y"
        variant.mkdir(parents=True)
        assert audit_variant(tmp_path, variant.parent, variant, "test-quality") is None


class TestSpanThresholdConstant:
    def test_threshold_is_four(self):
        # Hard-coded so tests can assume the "1 vs 5 on a 1-5 scale"
        # semantics. Changing it would change what the audit considers
        # flag-worthy and should be a conscious decision.
        assert SPAN_THRESHOLD == 4


class TestLoadPanelScoresRespectsAudit:
    """load_panel_scores is the single read site consumed by the
    combined report and by _load_judge_scores in combine_results.py.
    An audit verdict file sitting next to the judge caches must
    change the panel mean accordingly — otherwise the drop rule has
    no effect on what the report renders."""

    def _write_judge(self, variant_dir, kind, judge_short, overall):
        variant_dir.mkdir(parents=True, exist_ok=True)
        (variant_dir / f"{kind}-{judge_short}.json").write_text(json.dumps({
            "coverage": overall, "rigor": overall, "design": overall,
            "overall": overall, "summary": "",
            "judge_short": judge_short,
        }))

    def test_drop_haiku_uses_only_gemini_mean(self, tmp_path):
        from test_quality import load_panel_scores
        variant = tmp_path / "tasks" / "11" / "bash-opus"
        self._write_judge(variant, "test-quality", "haiku45", 1)
        self._write_judge(variant, "test-quality", "gemini31pro", 5)
        (variant / "judge-audit-test-quality.json").write_text(json.dumps({
            "panel_decision": "drop_haiku45",
            "adjusted_mean": 5.0,
        }))
        panel = load_panel_scores(variant, "test-quality")
        assert panel is not None
        assert panel["overall"] == 5.0
        assert panel["judges"] == ["gemini31pro"]
        assert panel["n_judges"] == 1

    def test_drop_gemini_uses_only_haiku_mean(self, tmp_path):
        from test_quality import load_panel_scores
        variant = tmp_path / "tasks" / "11" / "bash-opus"
        self._write_judge(variant, "test-quality", "haiku45", 3)
        self._write_judge(variant, "test-quality", "gemini31pro", 1)
        (variant / "judge-audit-test-quality.json").write_text(json.dumps({
            "panel_decision": "drop_gemini31pro",
        }))
        panel = load_panel_scores(variant, "test-quality")
        assert panel["overall"] == 3.0
        assert panel["judges"] == ["haiku45"]

    def test_drop_both_returns_none(self, tmp_path):
        # Both judges factually wrong — no usable panel score.
        from test_quality import load_panel_scores
        variant = tmp_path / "tasks" / "11" / "bash-opus"
        self._write_judge(variant, "test-quality", "haiku45", 1)
        self._write_judge(variant, "test-quality", "gemini31pro", 5)
        (variant / "judge-audit-test-quality.json").write_text(json.dumps({
            "panel_decision": "drop_both",
        }))
        assert load_panel_scores(variant, "test-quality") is None

    def test_keep_both_uses_panel_mean(self, tmp_path):
        from test_quality import load_panel_scores
        variant = tmp_path / "tasks" / "11" / "bash-opus"
        self._write_judge(variant, "test-quality", "haiku45", 1)
        self._write_judge(variant, "test-quality", "gemini31pro", 5)
        (variant / "judge-audit-test-quality.json").write_text(json.dumps({
            "panel_decision": "keep_both",
        }))
        panel = load_panel_scores(variant, "test-quality")
        assert panel["overall"] == 3.0
        assert panel["n_judges"] == 2

    def test_no_audit_file_means_panel_mean_unchanged(self, tmp_path):
        # Absence of an audit file is the default behaviour — the
        # report must keep averaging both judges the way it did before
        # the audit feature existed.
        from test_quality import load_panel_scores
        variant = tmp_path / "tasks" / "11" / "bash-opus"
        self._write_judge(variant, "test-quality", "haiku45", 2)
        self._write_judge(variant, "test-quality", "gemini31pro", 4)
        panel = load_panel_scores(variant, "test-quality")
        assert panel["overall"] == 3.0
        assert panel["n_judges"] == 2

    def test_audit_scoped_to_kind(self, tmp_path):
        # Test-quality audit must not affect a deliverable-quality
        # load, and vice versa. Separate cache files, separate audits.
        from test_quality import load_panel_scores
        variant = tmp_path / "tasks" / "11" / "bash-opus"
        self._write_judge(variant, "test-quality", "haiku45", 1)
        self._write_judge(variant, "test-quality", "gemini31pro", 5)
        self._write_judge(variant, "deliverable-quality", "haiku45", 1)
        self._write_judge(variant, "deliverable-quality", "gemini31pro", 5)
        # Drop Haiku only on test-quality; deliverable-quality stays
        # a full panel mean.
        (variant / "judge-audit-test-quality.json").write_text(json.dumps({
            "panel_decision": "drop_haiku45",
        }))
        tq = load_panel_scores(variant, "test-quality")
        dq = load_panel_scores(variant, "deliverable-quality")
        assert tq["overall"] == 5.0 and tq["n_judges"] == 1
        assert dq["overall"] == 3.0 and dq["n_judges"] == 2
