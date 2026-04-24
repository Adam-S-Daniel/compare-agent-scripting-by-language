"""Unit tests for judge_consistency_report.py — focused on audit-
aware record collection."""

import json
from pathlib import Path

import pytest

from judge_consistency_report import _collect


def _seed_variant(tmp_path: Path, task_id: str, variant: str,
                  tq_scores: dict, dq_scores: dict,
                  tq_audit: dict | None = None,
                  dq_audit: dict | None = None) -> Path:
    """Write a fake variant directory with per-judge caches and
    optional audit files."""
    variant_dir = tmp_path / "tasks" / task_id / variant
    variant_dir.mkdir(parents=True)
    for judge, overall in tq_scores.items():
        (variant_dir / f"test-quality-{judge}.json").write_text(json.dumps({
            "coverage": overall, "rigor": overall, "design": overall,
            "overall": overall, "summary": "",
            "judge_short": judge,
        }))
    for judge, overall in dq_scores.items():
        (variant_dir / f"deliverable-quality-{judge}.json").write_text(json.dumps({
            "best_practices": overall, "conciseness": overall,
            "readability": overall, "maintainability": overall,
            "overall": overall, "summary": "",
            "judge_short": judge,
        }))
    if tq_audit is not None:
        (variant_dir / "judge-audit-test-quality.json").write_text(
            json.dumps(tq_audit))
    if dq_audit is not None:
        (variant_dir / "judge-audit-deliverable-quality.json").write_text(
            json.dumps(dq_audit))
    return variant_dir


class TestCollectHonorsAuditDrops:
    """Downstream rankings + Spearman in the JCS summary must not see
    a judge's score on a row where the audit has marked that judge's
    rationale as contradicted — otherwise the metric we cite would
    diverge from what every other report table renders."""

    def test_drop_haiku_removes_only_haiku_from_that_kind(self, tmp_path):
        _seed_variant(
            tmp_path, "11-task", "bash-opus",
            tq_scores={"haiku45": 1, "gemini31pro": 5},
            dq_scores={"haiku45": 4, "gemini31pro": 4},
            tq_audit={"panel_decision": "drop_haiku45"},
        )
        records = _collect(tmp_path)
        assert len(records) == 1
        r = records[0]
        # test-quality: haiku dropped, only gemini remains.
        assert set(r["tests_by_judge"].keys()) == {"gemini31pro"}
        # deliverable-quality: audit did not touch this kind.
        assert set(r["deliv_by_judge"].keys()) == {"haiku45", "gemini31pro"}

    def test_drop_gemini_works_symmetrically(self, tmp_path):
        _seed_variant(
            tmp_path, "11-task", "bash-opus",
            tq_scores={"haiku45": 3, "gemini31pro": 1},
            dq_scores={},
            tq_audit={"panel_decision": "drop_gemini31pro"},
        )
        records = _collect(tmp_path)
        assert set(records[0]["tests_by_judge"].keys()) == {"haiku45"}

    def test_drop_both_empties_that_kind_for_that_row(self, tmp_path):
        _seed_variant(
            tmp_path, "11-task", "bash-opus",
            tq_scores={"haiku45": 1, "gemini31pro": 5},
            dq_scores={"haiku45": 3, "gemini31pro": 3},
            tq_audit={"panel_decision": "drop_both"},
        )
        records = _collect(tmp_path)
        # tests_by_judge empty → record still included because
        # deliv_by_judge has entries. The test-quality-only consumers
        # will skip this row naturally.
        assert records[0]["tests_by_judge"] == {}
        assert set(records[0]["deliv_by_judge"].keys()) == {"haiku45", "gemini31pro"}

    def test_keep_both_is_a_noop(self, tmp_path):
        _seed_variant(
            tmp_path, "11-task", "bash-opus",
            tq_scores={"haiku45": 2, "gemini31pro": 5},
            dq_scores={},
            tq_audit={"panel_decision": "keep_both"},
        )
        records = _collect(tmp_path)
        assert set(records[0]["tests_by_judge"].keys()) == {"haiku45", "gemini31pro"}

    def test_absent_audit_file_means_default_behavior(self, tmp_path):
        # No audit file at all — same behaviour as pre-audit era.
        _seed_variant(
            tmp_path, "11-task", "bash-opus",
            tq_scores={"haiku45": 2, "gemini31pro": 4},
            dq_scores={"haiku45": 2, "gemini31pro": 4},
        )
        records = _collect(tmp_path)
        assert set(records[0]["tests_by_judge"].keys()) == {"haiku45", "gemini31pro"}
        assert set(records[0]["deliv_by_judge"].keys()) == {"haiku45", "gemini31pro"}

    def test_row_omitted_entirely_if_both_kinds_drop_both(self, tmp_path):
        # A variant where audit drops both kinds entirely has no
        # usable score left and must not appear in the record list —
        # including it would mean every ranking+correlation has to
        # handle an all-empty row, which complicates downstream code
        # for zero signal.
        _seed_variant(
            tmp_path, "11-task", "bash-opus",
            tq_scores={"haiku45": 1, "gemini31pro": 5},
            dq_scores={"haiku45": 1, "gemini31pro": 5},
            tq_audit={"panel_decision": "drop_both"},
            dq_audit={"panel_decision": "drop_both"},
        )
        records = _collect(tmp_path)
        assert records == []
