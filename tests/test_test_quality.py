"""Unit tests for test_quality.py — structural metric counters and helpers."""

import os
import tempfile
from pathlib import Path

import pytest

from test_quality import (
    _count_bash,
    _count_powershell,
    _count_python,
    _count_typescript,
    _detect_language,
    _is_impl_file,
    _is_test_file,
    compute_structural_metrics,
    _build_judge_message,
)


# =========================================================================
# Language detection
# =========================================================================

class TestDetectLanguage:
    def test_python_from_test_file(self):
        assert _detect_language(["test_foo.py", "foo.py"]) == "python"

    def test_python_from_run_tests(self):
        assert _detect_language(["run_tests.py", "app.py"]) == "python"

    def test_typescript_from_test_file(self):
        assert _detect_language(["app.test.ts", "app.ts"]) == "typescript"

    def test_powershell_from_test_file(self):
        assert _detect_language(["Foo.Tests.ps1", "Foo.ps1"]) == "powershell"

    def test_bash_from_bats(self):
        assert _detect_language(["test.bats", "script.sh"]) == "bash"

    def test_fallback_to_impl_extension(self):
        assert _detect_language(["app.ts"]) == "typescript"
        assert _detect_language(["script.sh"]) == "bash"
        assert _detect_language(["script.ps1"]) == "powershell"
        assert _detect_language(["main.py"]) == "python"

    def test_unknown_for_empty(self):
        assert _detect_language([]) == "unknown"

    def test_unknown_for_non_code(self):
        assert _detect_language(["data.json", "readme.md"]) == "unknown"

    def test_python_test_beats_typescript_impl(self):
        assert _detect_language(["utils.ts", "test_app.py"]) == "python"

    def test_bats_detected_first_in_loop(self):
        # bats is checked first in the detection loop, but test_helper.py
        # also matches as a python test file. With bats listed first in the
        # file list AND checked first in the loop, bats wins.
        assert _detect_language(["suite.bats", "test_helper.py"]) == "bash"
        # But python test file listed first means python is detected first
        assert _detect_language(["test_helper.py", "suite.bats"]) == "python"


# =========================================================================
# File classification
# =========================================================================

class TestFileClassification:
    def test_python_test_files(self):
        assert _is_test_file("test_foo.py", "python")
        assert _is_test_file("foo_test.py", "python")
        assert _is_test_file("run_tests.py", "python")
        assert not _is_test_file("foo.py", "python")
        assert not _is_test_file("main.py", "python")

    def test_python_impl_files(self):
        assert _is_impl_file("foo.py", "python")
        assert _is_impl_file("main.py", "python")
        # Note: _is_impl_file alone doesn't exclude test files.
        # compute_structural_metrics applies `not _is_test_file` separately.
        # So _is_impl_file("test_foo.py", ...) may return True.

    def test_typescript_test_files(self):
        assert _is_test_file("app.test.ts", "typescript")
        assert _is_test_file("app.spec.ts", "typescript")
        assert not _is_test_file("app.ts", "typescript")

    def test_powershell_test_files(self):
        assert _is_test_file("Foo.Tests.ps1", "powershell")
        assert not _is_test_file("Foo.ps1", "powershell")

    def test_bash_test_files(self):
        assert _is_test_file("test.bats", "bash")
        assert _is_test_file("run_tests.sh", "bash")
        assert not _is_test_file("deploy.sh", "bash")


# =========================================================================
# Python counter
# =========================================================================

class TestCountPython:
    def test_standard_pytest_functions(self):
        code = """
def test_add():
    assert 1 + 1 == 2

def test_subtract():
    assert 3 - 1 == 2
"""
        r = _count_python(code)
        assert r["tests"] == 2
        assert r["assertions"] == 2

    def test_unittest_style(self):
        code = """
class TestMath(unittest.TestCase):
    def test_add(self):
        self.assertEqual(1 + 1, 2)
        self.assertTrue(True)

    def test_sub(self):
        self.assertIn(1, [1, 2])
"""
        r = _count_python(code)
        assert r["tests"] == 2
        assert r["assertions"] >= 3

    def test_record_pattern(self):
        code = """
record("test_one", True)
record("test_two", False, "oops")
"""
        r = _count_python(code)
        assert r["tests"] == 2

    def test_custom_harness_test_cases(self):
        code = """
TEST_CASES = [
    {
        "name": "TC1: basic test",
        "expected": "foo",
    },
    {
        "name": "TC2: edge case",
        "expected": "bar",
    },
]
"""
        r = _count_python(code)
        assert r["tests"] == 2

    def test_record_pass_assertions(self):
        code = """
if ok:
    record_pass("test1")
else:
    record_fail("test1", "bad")
"""
        r = _count_python(code)
        assert r["assertions"] >= 1

    def test_camelcase_unittest_methods(self):
        code = """
class TestCalc(unittest.TestCase):
    def testAdd(self):
        self.assertEqual(1 + 1, 2)

    def testSubtract(self):
        self.assertTrue(3 - 1 == 2)
"""
        r = _count_python(code)
        assert r["tests"] == 2
        assert r["assertions"] == 2

    def test_camelcase_and_underscore_not_double_counted(self):
        code = """
def test_add():
    assert 1 + 1 == 2

class TestCalc(unittest.TestCase):
    def testSub(self):
        self.assertEqual(3 - 1, 2)
"""
        r = _count_python(code)
        assert r["tests"] == 2

    def test_test_cases_suppressed_when_standard_tests_exist(self):
        code = """
def test_alpha():
    assert True

TEST_CASES = [
    {"name": "TC1: should work", "expected": "foo"},
]
"""
        r = _count_python(code)
        # def test_alpha counts as 1; TEST_CASES should NOT add more
        assert r["tests"] == 1

    def test_empty_file(self):
        r = _count_python("")
        assert r["tests"] == 0
        assert r["assertions"] == 0


# =========================================================================
# TypeScript counter
# =========================================================================

class TestCountTypescript:
    def test_basic_tests(self):
        code = """
test("should add numbers", () => {
    expect(add(1, 2)).toBe(3);
    expect(add(0, 0)).toBe(0);
});

it("should subtract", () => {
    expect(sub(3, 1)).toBe(2);
});
"""
        r = _count_typescript(code)
        assert r["tests"] == 2
        assert r["assertions"] == 3

    def test_empty(self):
        r = _count_typescript("")
        assert r["tests"] == 0
        assert r["assertions"] == 0


# =========================================================================
# PowerShell counter
# =========================================================================

class TestCountPowershell:
    def test_pester_tests(self):
        code = """
Describe "Calculator" {
    It "should add" {
        $result = Add 1 2
        $result | Should -Be 3
    }
    It "should subtract" {
        $result = Sub 3 1
        $result | Should -Be 2
        $result | Should -Not -BeNullOrEmpty
    }
}
"""
        r = _count_powershell(code)
        assert r["tests"] == 2
        assert r["assertions"] == 3

    def test_empty(self):
        r = _count_powershell("")
        assert r["tests"] == 0
        assert r["assertions"] == 0


# =========================================================================
# Bash counter
# =========================================================================

class TestCountBash:
    def test_bats_tests(self):
        code = """
@test "should list files" {
    run ls /tmp
    [ "$status" -eq 0 ]
    [[ "$output" =~ "test" ]]
}

@test "should fail on missing dir" {
    run ls /nonexistent
    [ "$status" -ne 0 ]
}
"""
        r = _count_bash(code)
        assert r["tests"] == 2
        assert r["assertions"] >= 3

    def test_log_result_pattern(self):
        code = """
log_result "test1" "PASS" "ok"
log_result "test2" "FAIL" "bad"
log_result "test3" "PASS" "ok"
"""
        r = _count_bash(code)
        assert r["tests"] == 3

    def test_bats_takes_priority_over_log_result(self):
        code = """
@test "real bats test" {
    run foo
    [ "$status" -eq 0 ]
}
log_result "test1" "PASS" "ok"
log_result "test2" "PASS" "ok"
"""
        r = _count_bash(code)
        assert r["tests"] == 1  # log_result must not add to @test count

    def test_empty(self):
        r = _count_bash("")
        assert r["tests"] == 0
        assert r["assertions"] == 0


# =========================================================================
# compute_structural_metrics (integration with filesystem)
# =========================================================================

class TestComputeStructuralMetrics:
    def test_python_project(self, tmp_path):
        (tmp_path / "app.py").write_text("def add(a, b):\n    return a + b\n")
        (tmp_path / "test_app.py").write_text(
            "def test_add():\n    assert add(1, 2) == 3\n"
            "def test_zero():\n    assert add(0, 0) == 0\n"
        )

        r = compute_structural_metrics(tmp_path)
        assert r["language"] == "python"
        assert r["test_file_count"] == 1
        assert r["impl_file_count"] == 1
        assert r["test_count"] == 2
        assert r["assertion_count"] == 2
        assert r["test_lines"] == 4
        assert r["impl_lines"] == 2
        assert r["test_to_code_ratio"] == 2.0

    def test_nonexistent_directory(self):
        r = compute_structural_metrics(Path("/tmp/nonexistent_dir_abc123"))
        assert r["language"] == "unknown"
        assert r["test_count"] == 0

    def test_skips_non_code_files(self, tmp_path):
        (tmp_path / "data.json").write_text('{"key": "value"}')
        (tmp_path / "readme.md").write_text("# Hello")
        (tmp_path / "app.py").write_text("print('hi')\n")
        (tmp_path / "test_app.py").write_text("def test_x():\n    assert True\n")

        r = compute_structural_metrics(tmp_path)
        assert r["impl_file_count"] == 1
        assert r["test_file_count"] == 1

    def test_only_test_file_no_impl(self, tmp_path):
        (tmp_path / "test_only.py").write_text("def test_x():\n    assert True\n")
        r = compute_structural_metrics(tmp_path)
        assert r["impl_file_count"] == 0
        assert r["impl_lines"] == 0
        assert r["test_to_code_ratio"] == 0  # no ZeroDivisionError

    def test_zero_tests_no_crash(self, tmp_path):
        (tmp_path / "app.py").write_text("def add(a, b): return a + b\n")
        (tmp_path / "test_app.py").write_text("# placeholder\n")
        r = compute_structural_metrics(tmp_path)
        assert r["test_count"] == 0
        assert r["assertions_per_test"] == 0  # no ZeroDivisionError

    def test_nested_subdirectory_traversal(self, tmp_path):
        (tmp_path / "src").mkdir()
        (tmp_path / "src" / "app.py").write_text("def add(a, b): return a + b\n")
        (tmp_path / "tests").mkdir()
        (tmp_path / "tests" / "test_app.py").write_text(
            "def test_add():\n    assert add(1,2)==3\n"
        )
        r = compute_structural_metrics(tmp_path)
        assert r["impl_file_count"] == 1
        assert r["test_file_count"] == 1
        assert r["test_count"] == 1

    def test_skips_hidden_directories(self, tmp_path):
        hidden = tmp_path / ".cache"
        hidden.mkdir()
        (hidden / "test_secret.py").write_text("def test_hidden():\n    assert True\n")
        (tmp_path / "app.py").write_text("x = 1\n")
        r = compute_structural_metrics(tmp_path)
        assert r["test_file_count"] == 0  # .cache/ must be skipped


# =========================================================================
# _build_judge_message
# =========================================================================

class TestBuildJudgeMessage:
    def test_basic_message(self):
        msg = _build_judge_message("Do X", "def foo(): pass", "def test_foo(): assert True")
        assert "## Task Description" in msg
        assert "Do X" in msg
        assert "## Implementation Code" in msg
        assert "## Test Code" in msg

    def test_truncates_long_impl(self):
        long_impl = "x" * 300_000
        msg = _build_judge_message("task", long_impl, "test")
        assert "(truncated)" in msg
        assert len(msg) < 400_000
