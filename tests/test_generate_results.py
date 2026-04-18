"""Unit tests for generate_results.py — helper functions."""

import re

import pytest

from generate_results import (
    _categorize_tool_time,
    _collapsible_table,
    _detect_traps,
    _emit_sorted_variants,
    _find_discrepancies,
    _llm_tier,
    _rank,
    _ratio_tier,
    _spearman,
    _tier_num,
)


# =========================================================================
# _rank
# =========================================================================

class TestRank:
    def test_basic_ranking(self):
        assert _rank([10, 20, 30]) == [1.0, 2.0, 3.0]

    def test_reverse_order(self):
        assert _rank([30, 20, 10]) == [3.0, 2.0, 1.0]

    def test_ties_get_average_rank(self):
        # Values: [10, 20, 20, 30] -> sorted positions 1,2,3,4
        # The two 20s share positions 2 and 3 -> avg rank 2.5
        assert _rank([10, 20, 20, 30]) == [1.0, 2.5, 2.5, 4.0]

    def test_all_same(self):
        assert _rank([5, 5, 5]) == [2.0, 2.0, 2.0]

    def test_single_element(self):
        assert _rank([42]) == [1.0]

    def test_empty(self):
        assert _rank([]) == []


# =========================================================================
# _spearman
# =========================================================================

class TestSpearman:
    def test_perfect_positive(self):
        assert _spearman([1, 2, 3, 4], [10, 20, 30, 40]) == 1.0

    def test_perfect_negative(self):
        assert _spearman([1, 2, 3, 4], [40, 30, 20, 10]) == -1.0

    def test_no_correlation(self):
        # Not perfectly 0 but should be close
        r = _spearman([1, 2, 3, 4, 5], [3, 1, 4, 2, 5])
        assert r is not None
        assert -1.0 <= r <= 1.0

    def test_too_few_values(self):
        assert _spearman([1, 2], [3, 4]) is None
        assert _spearman([1], [2]) is None
        assert _spearman([], []) is None

    def test_constant_values_returns_none(self):
        # All same values -> zero variance -> None
        assert _spearman([5, 5, 5], [1, 2, 3]) is None

    def test_known_value(self):
        # rank([1,2,3,4,5]) vs rank([2,1,4,3,5]): d^2=4, rs = 1 - 6*4/120 = 0.80
        assert _spearman([1, 2, 3, 4, 5], [2, 1, 4, 3, 5]) == 0.8

    def test_mismatched_lengths(self):
        # Implementation uses zip, so shorter list determines length.
        # With only 2 pairs, should return None (< 3 elements).
        result = _spearman([1, 2, 3], [1, 2])
        # Either None (too few after zip) or a valid correlation
        assert result is None or -1.0 <= result <= 1.0


# =========================================================================
# _collapsible_table
# =========================================================================

class TestCollapsibleTable:
    def test_basic_structure(self):
        lines = _collapsible_table(
            "Click to expand",
            "| A | B |",
            "|---|---|",
            ["| 1 | 2 |", "| 3 | 4 |"],
        )
        text = "\n".join(lines)
        assert "<details>" in text
        assert "<summary>Click to expand</summary>" in text
        assert "| A | B |" in text
        assert "| 1 | 2 |" in text
        assert "</details>" in text

    def test_output_structural_order(self):
        lines = _collapsible_table(
            "My Summary", "| H1 | H2 |", "|----|-----|",
            ["| r1 | r2 |", "| r3 | r4 |"],
        )
        text = "\n".join(lines)
        for tag in ["<details>", "<summary>My Summary</summary>",
                     "| H1 | H2 |", "|----|-----|",
                     "| r1 | r2 |", "| r3 | r4 |", "</details>"]:
            assert tag in text
        # Verify ordering
        assert text.index("<details>") < text.index("<summary>")
        assert text.index("<summary>") < text.index("| H1 | H2 |")
        assert text.index("| r1 | r2 |") < text.index("</details>")

    def test_empty_rows(self):
        lines = _collapsible_table("Empty", "| H |", "|---|", [])
        text = "\n".join(lines)
        assert "<details>" in text
        assert "| H |" in text


# =========================================================================
# _categorize_tool_time
# =========================================================================

class TestCategorizeToolTime:
    def test_install_commands(self):
        tool_uses = [
            {"tool_name": "Bash", "command": "pip install requests", "duration_ms": 5000},
            {"tool_name": "Bash", "command": "apt-get install curl", "duration_ms": 3000},
        ]
        r = _categorize_tool_time(tool_uses)
        assert r["install_duration_ms"] == 8000
        assert r["test_duration_ms"] == 0
        assert r["act_duration_ms"] == 0

    def test_test_commands(self):
        tool_uses = [
            {"tool_name": "Bash", "command": "pytest test_foo.py", "duration_ms": 2000},
            {"tool_name": "Bash", "command": "Invoke-Pester", "duration_ms": 5000},
            {"tool_name": "Bash", "command": "bun test", "duration_ms": 1500},
        ]
        r = _categorize_tool_time(tool_uses)
        assert r["test_duration_ms"] == 8500
        assert r["install_duration_ms"] == 0

    def test_act_commands(self):
        tool_uses = [
            {"tool_name": "Bash", "command": "act push --rm", "duration_ms": 60000},
        ]
        r = _categorize_tool_time(tool_uses)
        assert r["act_duration_ms"] == 60000

    def test_ignores_non_bash(self):
        tool_uses = [
            {"tool_name": "Write", "command": "test_foo.py", "duration_ms": 100},
        ]
        r = _categorize_tool_time(tool_uses)
        assert r["install_duration_ms"] == 0
        assert r["test_duration_ms"] == 0

    def test_empty_list(self):
        r = _categorize_tool_time([])
        assert r["install_duration_ms"] == 0
        assert r["test_duration_ms"] == 0
        assert r["act_duration_ms"] == 0

    def test_tool_use_without_command_key(self):
        tool_uses = [
            {"tool_name": "Read", "file_path": "foo.py", "duration_ms": 100},
            {"tool_name": "Write", "duration_ms": 200},
        ]
        r = _categorize_tool_time(tool_uses)
        assert r["install_duration_ms"] == 0
        assert r["test_duration_ms"] == 0
        assert r["act_duration_ms"] == 0

    def test_act_takes_precedence_over_test(self):
        # "act push" should be categorized as act, not test
        tool_uses = [
            {"tool_name": "Bash", "command": "act push --rm 2>&1 | tee result.txt", "duration_ms": 50000},
        ]
        r = _categorize_tool_time(tool_uses)
        assert r["act_duration_ms"] == 50000
        assert r["test_duration_ms"] == 0


# =========================================================================
# _detect_traps (basic smoke tests — full coverage requires event fixtures)
# =========================================================================

class TestDetectTraps:
    def test_no_traps_in_clean_run(self):
        events = [
            {"type": "assistant", "message": {"content": [
                {"type": "tool_use", "name": "Bash", "input": {"command": "python3 app.py"}},
                {"type": "text", "text": "Running the script."},
            ]}},
        ]
        metrics = {"language_mode": "default"}
        traps = _detect_traps(events, "", metrics)
        assert traps == []

    def test_repeated_test_reruns(self):
        # Same test command 5 times -> should trigger trap
        events = [
            {"type": "assistant", "message": {"content": [
                {"type": "tool_use", "name": "Bash", "input": {"command": "pytest test_app.py"}}
            ]}}
            for _ in range(5)
        ]
        metrics = {"language_mode": "default"}
        traps = _detect_traps(events, "", metrics)
        names = [t["name"] for t in traps]
        assert "repeated-test-reruns" in names

    def test_pester_wrong_assertions(self):
        events = [
            {"type": "assistant", "message": {"content": [
                {"type": "tool_use", "name": "Bash", "input": {"command": "Invoke-Pester"}},
                {"type": "text", "text": "Should -BeInRange doesn't exist, need to fix the wrong assertion"},
            ]}},
        ]
        metrics = {"language_mode": "powershell"}
        traps = _detect_traps(events, "", metrics)
        names = [t["name"] for t in traps]
        assert "pester-wrong-assertions" in names

    def test_repeated_reruns_boundary_below_threshold(self):
        # 3 reruns should NOT trigger (threshold is 4)
        events = [
            {"type": "assistant", "message": {"content": [
                {"type": "tool_use", "name": "Bash", "input": {"command": "pytest test_app.py"}}
            ]}}
            for _ in range(3)
        ]
        metrics = {"language_mode": "default"}
        traps = _detect_traps(events, "", metrics)
        assert "repeated-test-reruns" not in [t["name"] for t in traps]

    def test_trap_payload_has_required_keys(self):
        events = [
            {"type": "assistant", "message": {"content": [
                {"type": "tool_use", "name": "Bash", "input": {"command": "pytest test_app.py"}}
            ]}}
            for _ in range(5)
        ]
        traps = _detect_traps(events, "", {"language_mode": "default"})
        for trap in traps:
            assert "name" in trap and isinstance(trap["name"], str)
            assert "time_s" in trap and isinstance(trap["time_s"], (int, float))
            assert "desc" in trap and isinstance(trap["desc"], str)

    def test_empty_events(self):
        assert _detect_traps([], "", {"language_mode": "default"}) == []


# =========================================================================
# _find_discrepancies
# =========================================================================

class TestFindDiscrepancies:
    def _llm(self, task="Task", mode="default", model="opus",
             cov=3, rig=3, des=3, ovr=3, summary="Good tests."):
        return {"task": task, "mode": mode, "model": model,
                "coverage": cov, "rigor": rig, "design": des,
                "overall": ovr, "summary": summary}

    def _sq(self, task="Task", mode="default", model="opus",
            tests=10, asserts=20, ratio=1.5):
        return {(task, mode, model): {
            "tests": tests, "asserts": asserts, "ratio": ratio,
        }}

    def test_no_discrepancies(self):
        llm = [self._llm(cov=3, rig=3, des=3, ovr=3)]
        sq = self._sq(tests=10, asserts=20)
        assert _find_discrepancies(llm, sq) == []

    def test_counter_gap_zero_tests_high_coverage(self):
        llm = [self._llm(cov=4)]
        sq = self._sq(tests=0, asserts=5)
        result = _find_discrepancies(llm, sq)
        gaps = [d for d in result if d["kind"] == "counter-gap"]
        assert len(gaps) >= 1
        assert any("0 tests" in d["flag"] for d in gaps)

    def test_counter_gap_zero_asserts_high_overall(self):
        llm = [self._llm(ovr=4)]
        sq = self._sq(tests=10, asserts=0)
        result = _find_discrepancies(llm, sq)
        gaps = [d for d in result if d["kind"] == "counter-gap"]
        assert len(gaps) >= 1
        assert any("0 assertions" in d["flag"] for d in gaps)

    def test_qualitative_low_rigor_many_asserts(self):
        llm = [self._llm(rig=2, summary="Tests lack edge cases.")]
        sq = self._sq(tests=15, asserts=50)
        result = _find_discrepancies(llm, sq)
        qual = [d for d in result if d["kind"] == "qualitative"]
        assert len(qual) == 1
        assert "low rigor" in qual[0]["flag"]
        assert qual[0]["justification"] == "Tests lack edge cases."

    def test_qualitative_has_justification(self):
        llm = [self._llm(rig=2, summary="No boundary tests.")]
        sq = self._sq(tests=20, asserts=45)
        result = _find_discrepancies(llm, sq)
        for d in result:
            if d["kind"] == "qualitative":
                assert d["justification"] != ""

    def test_counter_gap_has_no_justification(self):
        llm = [self._llm(ovr=4, summary="Great tests.")]
        sq = self._sq(tests=0, asserts=0)
        result = _find_discrepancies(llm, sq)
        for d in result:
            if d["kind"] == "counter-gap":
                assert d["justification"] == ""

    def test_missing_lookup_key_skipped(self):
        llm = [self._llm(task="Missing")]
        sq = self._sq(task="Other")
        assert _find_discrepancies(llm, sq) == []


# =========================================================================
# _ratio_tier — bin lower-is-better ratios (duration, cost) into A-E
# =========================================================================

class TestRatioTier:
    def test_best_itself_is_A(self):
        assert _ratio_tier(1.0) == "A"

    def test_boundary_of_A_band_inclusive(self):
        assert _ratio_tier(1.15) == "A"
        assert _ratio_tier(1.150001) == "B"

    def test_boundary_of_B_band(self):
        assert _ratio_tier(1.40) == "B"
        assert _ratio_tier(1.40001) == "C"

    def test_boundary_of_C_band(self):
        assert _ratio_tier(1.80) == "C"
        assert _ratio_tier(1.80001) == "D"

    def test_boundary_of_D_band(self):
        assert _ratio_tier(2.50) == "D"
        assert _ratio_tier(2.50001) == "E"

    def test_far_out_is_E(self):
        assert _ratio_tier(10.0) == "E"

    def test_mid_band_examples(self):
        assert _ratio_tier(1.30) == "B"
        assert _ratio_tier(1.60) == "C"
        assert _ratio_tier(2.00) == "D"


# =========================================================================
# _llm_tier — absolute 1-5 score bands
# =========================================================================

class TestLlmTier:
    def test_perfect_score_is_A(self):
        assert _llm_tier(5.0) == "A"

    def test_boundary_of_A_band_inclusive(self):
        assert _llm_tier(4.5) == "A"
        assert _llm_tier(4.49) == "B"

    def test_boundary_of_B_band(self):
        assert _llm_tier(3.5) == "B"
        assert _llm_tier(3.49) == "C"

    def test_boundary_of_C_band(self):
        assert _llm_tier(2.5) == "C"
        assert _llm_tier(2.49) == "D"

    def test_boundary_of_D_band(self):
        assert _llm_tier(1.5) == "D"
        assert _llm_tier(1.49) == "E"

    def test_minimum_is_E(self):
        assert _llm_tier(1.0) == "E"


# =========================================================================
# Display rename — `opus` / `sonnet` resolve to `opus46` / `sonnet46`
# in combined or multi-run reports so plain names aren't ambiguous
# now that 4.7 exists.
# =========================================================================

class TestDisplayRename:
    def test_combine_results_renames_legacy_opus(self):
        from combine_results import _label
        m = {"model_short": "opus", "effort_level": "medium"}
        assert _label(m) == "opus46-medium"

    def test_combine_results_renames_legacy_sonnet(self):
        from combine_results import _label
        m = {"model_short": "sonnet", "effort_level": None}
        assert _label(m) == "sonnet46"

    def test_combine_results_leaves_explicit_names_untouched(self):
        from combine_results import _label
        # opus47-1m is already explicit about the version; no rename.
        m = {"model_short": "opus47-1m", "effort_level": "xhigh"}
        assert _label(m) == "opus47-1m-xhigh"

    def test_combine_results_path_label_never_renames(self):
        # Filesystem subdirs keep their original plain names even when
        # the display label rewrites them.
        from combine_results import _path_label
        m = {"model_short": "opus", "effort_level": None}
        assert _path_label(m) == "opus"


# =========================================================================
# _tier_num — map tier letter to numeric rank for compound sort keys
# =========================================================================

class TestTierNum:
    def test_letter_mapping(self):
        assert _tier_num("A") == 1
        assert _tier_num("B") == 2
        assert _tier_num("C") == 3
        assert _tier_num("D") == 4
        assert _tier_num("E") == 5

    def test_em_dash_sorts_last(self):
        # "—" (U+2014) is the "no data" marker and must always outrank E
        # so unranked rows sink to the bottom when sorting ascending.
        assert _tier_num("—") == 6
        assert _tier_num("—") > _tier_num("E")

    def test_unknown_defaults_to_last(self):
        assert _tier_num("Z") == 6


# =========================================================================
# _emit_sorted_variants — callable sort key supports compound ordering
# =========================================================================

class TestEmitSortedVariantsCallableKey:
    def test_callable_key_enables_secondary_sort(self):
        # Two rows tie on primary axis "a" but differ on "b"; the
        # compound callable sort key must break the tie on b.
        rows = [
            {"name": "X", "a": 1, "b": 2},
            {"name": "Y", "a": 1, "b": 1},
            {"name": "Z", "a": 2, "b": 0},
        ]
        out = _emit_sorted_variants(
            "| name |", "|------|", rows,
            [("primary a then b", lambda r: (r["a"], r["b"]), False)],
            lambda r: f"| {r['name']} |",
        )
        # Expected order: Y (a=1,b=1), X (a=1,b=2), Z (a=2,b=0)
        names = [line for line in out if line.startswith("| ") and "name" not in line and "---" not in line]
        assert names == ["| Y |", "| X |", "| Z |"]

    def test_string_key_still_works(self):
        # Regression: the pre-callable behavior (plain dict-key lookup)
        # must keep working for existing callers.
        rows = [{"k": 3}, {"k": 1}, {"k": 2}]
        out = _emit_sorted_variants(
            "| k |", "|---|", rows,
            [("asc", "k", False)],
            lambda r: f"| {r['k']} |",
        )
        ks = [line for line in out if line.startswith("| ") and "k |" not in line and "---" not in line]
        assert ks == ["| 1 |", "| 2 |", "| 3 |"]
