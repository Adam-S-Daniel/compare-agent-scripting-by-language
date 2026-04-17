"""Unit tests for runner.select_tasks — --tasks CLI argument resolution."""

from runner import TASKS, PROMPT_TEMPLATES, select_tasks


class TestSelectTasks:
    def test_all_returns_full_task_list(self):
        result = select_tasks("all")
        assert len(result) == len(TASKS)
        assert result[0]["id"] == TASKS[0]["id"]

    def test_single_id(self):
        result = select_tasks("11")
        assert len(result) == 1
        assert result[0]["id"].startswith("11-")

    def test_multiple_ids_preserves_order(self):
        result = select_tasks("11,12,13")
        assert [t["id"].split("-", 1)[0] for t in result] == ["11", "12", "13"]

    def test_task_15_selects_by_id_not_position(self):
        # Regression: task 14 was archived, so position 15 would map to task 16.
        # Selecting by ID must still find "15-test-results-aggregator".
        result = select_tasks("15")
        assert len(result) == 1
        assert result[0]["id"] == "15-test-results-aggregator"

    def test_archived_task_id_14_silently_skipped(self):
        # Task 14 is archived — specifying it should silently drop it, not crash.
        result = select_tasks("11,14,15")
        assert [t["id"].split("-", 1)[0] for t in result] == ["11", "15"]

    def test_gha_task_range_returns_all_seven(self):
        # The canonical post-v4 GHA task set (see AGENTS.md usage example).
        result = select_tasks("11,12,13,15,16,17,18")
        ids = [t["id"].split("-", 1)[0] for t in result]
        assert ids == ["11", "12", "13", "15", "16", "17", "18"]

    def test_unknown_ids_skipped(self):
        result = select_tasks("999,11")
        assert len(result) == 1
        assert result[0]["id"].startswith("11-")

    def test_whitespace_tolerant(self):
        result = select_tasks(" 11 , 12 ")
        assert [t["id"].split("-", 1)[0] for t in result] == ["11", "12"]


class TestPromptTemplates:
    def test_powershell_tool_mode_exists(self):
        assert "powershell-tool" in PROMPT_TEMPLATES

    def test_powershell_modes_share_prompt_body(self):
        # The two PS modes must differ only in tool setup, not in user-facing
        # prompt content — otherwise we'd be comparing two different tasks.
        assert PROMPT_TEMPLATES["powershell"] == PROMPT_TEMPLATES["powershell-tool"]
