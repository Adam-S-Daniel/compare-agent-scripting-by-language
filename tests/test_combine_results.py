"""Unit tests for combine_results — cross-run-dir comparison markdown."""
import json
from pathlib import Path
import pytest

from combine_results import (
    intersect_task_ids,
    filter_to_tasks,
    infer_default_effort,
    aggregate_rows,
    combine,
)


def _mk_metric(task_id: str, mode: str = "default", model: str = "opus",
               effort: str | None = None, cost: float = 1.0,
               duration_ms: int = 60_000, total_lines: int = 100,
               error_count: int = 0, num_turns: int = 10,
               task_name: str | None = None) -> dict:
    return {
        "task_id": task_id,
        "task_name": task_name or task_id.split("-", 1)[-1].replace("-", " ").title(),
        "language_mode": mode,
        "model_short": model,
        "effort_level": effort,
        "timing": {"grand_total_duration_ms": duration_ms, "num_turns": num_turns},
        "code_metrics": {"total_lines": total_lines},
        "cost": {"total_cost_usd": cost},
        "quality": {"error_count": error_count},
        "run_success": True,
        "exit_code": 0,
    }


class TestIntersectTaskIds:
    def test_empty(self):
        assert intersect_task_ids([]) == set()

    def test_single_list_returns_all_its_task_ids(self):
        mm = [_mk_metric("11"), _mk_metric("12")]
        assert intersect_task_ids([mm]) == {"11", "12"}

    def test_intersection_drops_task_missing_from_any(self):
        # A has 11, 12, 14; B has 11, 12, 13. Common = {11, 12}.
        a = [_mk_metric("11"), _mk_metric("12"), _mk_metric("14")]
        b = [_mk_metric("11"), _mk_metric("12"), _mk_metric("13")]
        assert intersect_task_ids([a, b]) == {"11", "12"}

    def test_three_way_intersection(self):
        a = [_mk_metric("11"), _mk_metric("12")]
        b = [_mk_metric("11"), _mk_metric("12"), _mk_metric("13")]
        c = [_mk_metric("11"), _mk_metric("14")]
        assert intersect_task_ids([a, b, c]) == {"11"}

    def test_empty_intersection(self):
        a = [_mk_metric("11")]
        b = [_mk_metric("13")]
        assert intersect_task_ids([a, b]) == set()


class TestFilterToTasks:
    def test_keeps_only_matching(self):
        mm = [_mk_metric("11"), _mk_metric("12"), _mk_metric("14")]
        assert [m["task_id"] for m in filter_to_tasks(mm, {"11", "12"})] == ["11", "12"]

    def test_empty_filter_drops_all(self):
        mm = [_mk_metric("11"), _mk_metric("12")]
        assert filter_to_tasks(mm, set()) == []


class TestInferDefaultEffort:
    def test_null_effort_gets_default(self):
        m = _mk_metric("11", effort=None)
        out = infer_default_effort(m, "medium")
        assert out["effort_level"] == "medium"

    def test_existing_effort_unchanged(self):
        m = _mk_metric("11", effort="xhigh")
        out = infer_default_effort(m, "medium")
        assert out["effort_level"] == "xhigh"

    def test_does_not_mutate_input(self):
        m = _mk_metric("11", effort=None)
        infer_default_effort(m, "medium")
        assert m["effort_level"] is None


class TestAggregateRows:
    def test_averages_over_only_intersected_tasks(self):
        # If we naively averaged over all three tasks, avg cost would be
        # ($5 + $5 + $100) / 3 ≈ $36.67. After filtering to {11, 12},
        # avg must be $5 — this is the whole point of the intersection.
        mm = [
            _mk_metric("11", mode="default", model="opus", cost=5.0),
            _mk_metric("12", mode="default", model="opus", cost=5.0),
            _mk_metric("14", mode="default", model="opus", cost=100.0),
        ]
        filtered = filter_to_tasks(mm, {"11", "12"})
        rows = aggregate_rows(filtered)
        assert len(rows) == 1
        r = rows[0]
        assert r["n"] == 2
        assert r["avg_cost"] == pytest.approx(5.0)
        assert r["total_cost"] == pytest.approx(10.0)

    def test_groups_by_language_model_effort(self):
        mm = [
            _mk_metric("11", mode="default", model="opus", effort="xhigh", cost=3.0),
            _mk_metric("12", mode="default", model="opus", effort="xhigh", cost=5.0),
            _mk_metric("11", mode="default", model="opus", effort="medium", cost=1.0),
            _mk_metric("12", mode="bash", model="opus", effort="xhigh", cost=4.0),
        ]
        rows = aggregate_rows(mm)
        # `opus` is renamed to `opus46` in the display, matching the way
        # combine/generate reports disambiguate legacy plain short names.
        by_key = {(r["mode"], r["model"], r["effort"]): r for r in rows}
        assert by_key[("default", "opus46", "xhigh")]["avg_cost"] == pytest.approx(4.0)
        assert by_key[("default", "opus46", "medium")]["n"] == 1
        assert by_key[("bash", "opus46", "xhigh")]["n"] == 1

    def test_handles_empty(self):
        assert aggregate_rows([]) == []


class TestCombineIntegration:
    def _write_run_dir(self, root: Path, name: str, metrics: list[dict]) -> Path:
        run = root / name
        for m in metrics:
            d = run / "tasks" / m["task_id"] / f"{m['language_mode']}-{m['model_short']}"
            d.mkdir(parents=True, exist_ok=True)
            (d / "metrics.json").write_text(json.dumps(m))
        return run

    def test_end_to_end_excludes_archived_task(self, tmp_path):
        # dir_a (fresh) has tasks 11, 12. dir_b (old, v4-style) has 11, 12, 14.
        a = self._write_run_dir(tmp_path, "run_a", [
            _mk_metric("11", effort="xhigh", cost=2.0),
            _mk_metric("12", effort="xhigh", cost=3.0),
        ])
        b = self._write_run_dir(tmp_path, "run_b", [
            _mk_metric("11", model="sonnet", cost=0.5),   # effort=None (v4-era)
            _mk_metric("12", model="sonnet", cost=0.7),
            _mk_metric("14", model="sonnet", cost=50.0),  # must NOT count
        ])
        out = tmp_path / "combined.md"
        summary = combine([a, b], out, inferred_default_effort="medium")
        assert out.exists()
        text = out.read_text()
        # Task 14 is explicitly excluded; filtered totals must not include it.
        assert summary["common_task_ids"] == {"11", "12"}
        assert summary["dropped"]["run_b"] == {"14"}
        # Sanity: the combined markdown does not mention task 14 in body.
        assert "14-" not in text
        # v4 runs (effort=None) got annotated as medium, and `sonnet` is
        # display-renamed to `sonnet46` to disambiguate from future defaults.
        assert "sonnet46-medium" in text

    def test_empty_intersection_still_writes_file_with_warning(self, tmp_path):
        a = self._write_run_dir(tmp_path, "A", [_mk_metric("11", cost=1.0)])
        b = self._write_run_dir(tmp_path, "B", [_mk_metric("13", cost=1.0)])
        out = tmp_path / "empty.md"
        summary = combine([a, b], out)
        assert out.exists()
        assert summary["common_task_ids"] == set()
        assert "No tasks in common" in out.read_text()
