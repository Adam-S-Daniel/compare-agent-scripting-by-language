"""Tests for the environment matrix generator.

Built TDD-style: each test was added as a failing test, then implementation
in `matrix_gen.py` was written to make it pass before adding the next test.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from matrix_gen import (  # noqa: E402
    MatrixError,
    expand_matrix,
    generate,
    load_config,
)


# ---------- Basic expansion ---------------------------------------------------


def test_expand_matrix_single_dimension():
    """A single dimension expands into one combo per value."""
    combos = expand_matrix({"os": ["ubuntu-latest", "macos-latest"]})
    assert combos == [
        {"os": "ubuntu-latest"},
        {"os": "macos-latest"},
    ]


def test_expand_matrix_cartesian_product():
    """Multiple dimensions produce the full cartesian product."""
    combos = expand_matrix(
        {
            "os": ["ubuntu-latest", "macos-latest"],
            "python": ["3.11", "3.12"],
        }
    )
    assert len(combos) == 4
    # Order is os-major, python-minor (nested loop semantics).
    assert combos[0] == {"os": "ubuntu-latest", "python": "3.11"}
    assert combos[-1] == {"os": "macos-latest", "python": "3.12"}


def test_expand_matrix_empty_axes_yields_empty_combos():
    """No axes -> no combinations at all."""
    assert expand_matrix({}) == []


# ---------- Excludes ----------------------------------------------------------


def test_generate_respects_excludes():
    """An exclude rule strips every combination that fully matches its keys."""
    config = {
        "matrix": {
            "os": ["ubuntu-latest", "macos-latest"],
            "python": ["3.11", "3.12"],
        },
        "exclude": [{"os": "macos-latest", "python": "3.11"}],
    }
    out = generate(config)
    assert len(out["include"]) == 3
    assert {"os": "macos-latest", "python": "3.11"} not in out["include"]


def test_generate_exclude_with_partial_keys_drops_all_matches():
    """An exclude rule that names only some keys still matches subsets."""
    config = {
        "matrix": {
            "os": ["ubuntu-latest", "macos-latest"],
            "python": ["3.11", "3.12"],
        },
        "exclude": [{"os": "macos-latest"}],
    }
    out = generate(config)
    assert all(c["os"] != "macos-latest" for c in out["include"])
    assert len(out["include"]) == 2


# ---------- Includes ---------------------------------------------------------


def test_generate_include_adds_new_combination():
    """Include entries that aren't matched by existing combos are appended."""
    config = {
        "matrix": {
            "os": ["ubuntu-latest"],
            "python": ["3.11"],
        },
        "include": [
            {"os": "macos-latest", "python": "3.12", "experimental": True}
        ],
    }
    out = generate(config)
    assert len(out["include"]) == 2
    assert {
        "os": "macos-latest",
        "python": "3.12",
        "experimental": True,
    } in out["include"]


def test_generate_include_augments_existing_combination():
    """An include that matches an existing combo augments it in place."""
    config = {
        "matrix": {
            "os": ["ubuntu-latest", "macos-latest"],
            "python": ["3.11"],
        },
        "include": [{"os": "ubuntu-latest", "coverage": True}],
    }
    out = generate(config)
    # ubuntu-latest/3.11 combo gets coverage=True; macos-latest/3.11 does not.
    ubuntu = next(c for c in out["include"] if c["os"] == "ubuntu-latest")
    macos = next(c for c in out["include"] if c["os"] == "macos-latest")
    assert ubuntu.get("coverage") is True
    assert "coverage" not in macos


# ---------- Fail-fast + max-parallel ----------------------------------------


def test_generate_passes_fail_fast_and_max_parallel_through():
    config = {
        "matrix": {"os": ["ubuntu-latest"]},
        "fail-fast": False,
        "max-parallel": 2,
    }
    out = generate(config)
    assert out["fail-fast"] is False
    assert out["max-parallel"] == 2


def test_generate_defaults_fail_fast_and_max_parallel():
    """Defaults: fail-fast true, no max-parallel cap."""
    out = generate({"matrix": {"os": ["ubuntu-latest"]}})
    assert out["fail-fast"] is True
    assert "max-parallel" not in out


# ---------- Max-size validation ---------------------------------------------


def test_generate_raises_when_matrix_exceeds_max_size():
    config = {
        "matrix": {
            "os": ["a", "b", "c"],
            "v": [1, 2, 3],
            "f": ["x", "y"],
        },
        "max-size": 10,  # 18 combos > 10
    }
    with pytest.raises(MatrixError, match="exceeds max-size"):
        generate(config)


def test_generate_within_max_size_ok():
    config = {
        "matrix": {"os": ["a", "b"], "v": [1, 2]},
        "max-size": 4,
    }
    out = generate(config)
    assert len(out["include"]) == 4


# ---------- Error handling --------------------------------------------------


def test_generate_rejects_missing_matrix_key():
    with pytest.raises(MatrixError, match="missing 'matrix'"):
        generate({})


def test_generate_rejects_non_list_axis():
    with pytest.raises(MatrixError, match="must be a list"):
        generate({"matrix": {"os": "ubuntu-latest"}})


def test_generate_rejects_empty_axis():
    with pytest.raises(MatrixError, match="must not be empty"):
        generate({"matrix": {"os": []}})


def test_generate_rejects_invalid_max_parallel():
    with pytest.raises(MatrixError, match="max-parallel"):
        generate({"matrix": {"os": ["a"]}, "max-parallel": 0})


def test_load_config_reports_file_not_found():
    with pytest.raises(MatrixError, match="not found"):
        load_config(Path("/nonexistent/doesnotexist.json"))


def test_load_config_reports_bad_json(tmp_path):
    bad = tmp_path / "bad.json"
    bad.write_text("{not valid json")
    with pytest.raises(MatrixError, match="invalid JSON"):
        load_config(bad)


# ---------- CLI smoke test --------------------------------------------------


def test_cli_reads_json_file_and_prints_matrix_json(tmp_path):
    """Integration: the CLI entry point reads config JSON and prints matrix JSON."""
    cfg = tmp_path / "cfg.json"
    cfg.write_text(
        json.dumps(
            {
                "matrix": {"os": ["ubuntu-latest"], "python": ["3.12"]},
                "fail-fast": False,
                "max-parallel": 1,
            }
        )
    )
    result = subprocess.run(
        [sys.executable, str(ROOT / "matrix_gen.py"), str(cfg)],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr
    out = json.loads(result.stdout)
    assert out["fail-fast"] is False
    assert out["max-parallel"] == 1
    assert out["include"] == [{"os": "ubuntu-latest", "python": "3.12"}]


def test_cli_exits_nonzero_on_error(tmp_path):
    cfg = tmp_path / "cfg.json"
    cfg.write_text(json.dumps({"matrix": {"os": []}}))
    result = subprocess.run(
        [sys.executable, str(ROOT / "matrix_gen.py"), str(cfg)],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode != 0
    assert "must not be empty" in result.stderr
