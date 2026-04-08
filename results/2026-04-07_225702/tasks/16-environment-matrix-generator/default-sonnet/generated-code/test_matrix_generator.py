"""
Tests for the GitHub Actions Environment Matrix Generator.
Following red/green TDD: each test is written first (failing), then the
minimum code is added to pass it.
"""

import json
import pytest
from matrix_generator import MatrixGenerator, MatrixConfig, MatrixValidationError


# ── Fixtures ─────────────────────────────────────────────────────────────────

@pytest.fixture
def simple_config():
    """Minimal valid configuration with two axes."""
    return {
        "os": ["ubuntu-latest", "windows-latest"],
        "language_versions": {"python": ["3.11", "3.12"]},
        "feature_flags": {},
        "max_matrix_size": 256,
    }


@pytest.fixture
def full_config():
    """Configuration with all supported features."""
    return {
        "os": ["ubuntu-latest", "windows-latest", "macos-latest"],
        "language_versions": {
            "python": ["3.10", "3.11", "3.12"],
        },
        "feature_flags": {
            "experimental": [True, False],
        },
        "include": [
            # Add a coverage variable only on ubuntu+3.12
            {"os": "ubuntu-latest", "python": "3.12", "coverage": True},
        ],
        "exclude": [
            # Skip python 3.10 on windows
            {"os": "windows-latest", "python": "3.10"},
        ],
        "max_parallel": 4,
        "fail_fast": False,
        "max_matrix_size": 256,
    }


# ── Test 1: MatrixConfig dataclass parses a config dict ──────────────────────

class TestMatrixConfig:
    def test_parses_os_list(self, simple_config):
        cfg = MatrixConfig.from_dict(simple_config)
        assert cfg.os == ["ubuntu-latest", "windows-latest"]

    def test_parses_language_versions(self, simple_config):
        cfg = MatrixConfig.from_dict(simple_config)
        assert cfg.language_versions == {"python": ["3.11", "3.12"]}

    def test_parses_feature_flags(self, full_config):
        cfg = MatrixConfig.from_dict(full_config)
        assert cfg.feature_flags == {"experimental": [True, False]}

    def test_parses_include(self, full_config):
        cfg = MatrixConfig.from_dict(full_config)
        assert len(cfg.include) == 1

    def test_parses_exclude(self, full_config):
        cfg = MatrixConfig.from_dict(full_config)
        assert len(cfg.exclude) == 1

    def test_parses_max_parallel(self, full_config):
        cfg = MatrixConfig.from_dict(full_config)
        assert cfg.max_parallel == 4

    def test_parses_fail_fast(self, full_config):
        cfg = MatrixConfig.from_dict(full_config)
        assert cfg.fail_fast is False

    def test_default_fail_fast_is_true(self, simple_config):
        cfg = MatrixConfig.from_dict(simple_config)
        assert cfg.fail_fast is True  # GitHub Actions default

    def test_default_max_parallel_is_none(self, simple_config):
        cfg = MatrixConfig.from_dict(simple_config)
        assert cfg.max_parallel is None

    def test_missing_os_raises(self):
        with pytest.raises(ValueError, match="os"):
            MatrixConfig.from_dict({"language_versions": {}, "feature_flags": {}})


# ── Test 2: Base axes are built correctly ─────────────────────────────────────

class TestBuildAxes:
    def test_os_axis_present(self, simple_config):
        gen = MatrixGenerator(MatrixConfig.from_dict(simple_config))
        axes = gen.build_axes()
        assert "os" in axes
        assert axes["os"] == ["ubuntu-latest", "windows-latest"]

    def test_language_version_axes_present(self, simple_config):
        gen = MatrixGenerator(MatrixConfig.from_dict(simple_config))
        axes = gen.build_axes()
        assert "python" in axes
        assert axes["python"] == ["3.11", "3.12"]

    def test_feature_flag_axes_present(self, full_config):
        gen = MatrixGenerator(MatrixConfig.from_dict(full_config))
        axes = gen.build_axes()
        assert "experimental" in axes
        assert axes["experimental"] == [True, False]

    def test_multiple_language_axes(self):
        cfg = MatrixConfig.from_dict({
            "os": ["ubuntu-latest"],
            "language_versions": {"python": ["3.11"], "node": ["18", "20"]},
            "feature_flags": {},
            "max_matrix_size": 256,
        })
        axes = MatrixGenerator(cfg).build_axes()
        assert "python" in axes
        assert "node" in axes


# ── Test 3: Cartesian product (base combinations) ─────────────────────────────

class TestCombinations:
    def test_two_axes_produce_cartesian_product(self, simple_config):
        gen = MatrixGenerator(MatrixConfig.from_dict(simple_config))
        combos = gen.compute_base_combinations()
        # 2 OS × 2 python = 4
        assert len(combos) == 4

    def test_three_axes_product(self, full_config):
        gen = MatrixGenerator(MatrixConfig.from_dict(full_config))
        combos = gen.compute_base_combinations()
        # 3 OS × 3 python × 2 experimental = 18
        assert len(combos) == 18

    def test_each_combo_has_all_keys(self, simple_config):
        gen = MatrixGenerator(MatrixConfig.from_dict(simple_config))
        for combo in gen.compute_base_combinations():
            assert "os" in combo
            assert "python" in combo


# ── Test 4: Exclude rules remove combinations ─────────────────────────────────

class TestExcludeRules:
    def test_exclude_removes_matching_combo(self, full_config):
        gen = MatrixGenerator(MatrixConfig.from_dict(full_config))
        combos = gen.apply_excludes(gen.compute_base_combinations())
        # Excluded: windows-latest + python 3.10
        for combo in combos:
            assert not (combo["os"] == "windows-latest" and combo["python"] == "3.10")

    def test_exclude_reduces_count_by_one(self, full_config):
        gen = MatrixGenerator(MatrixConfig.from_dict(full_config))
        base = gen.compute_base_combinations()  # 18
        filtered = gen.apply_excludes(base)
        # 18 - 2 (windows+3.10 × both experimental values) = 16
        assert len(filtered) == 16

    def test_no_excludes_leaves_combos_unchanged(self, simple_config):
        gen = MatrixGenerator(MatrixConfig.from_dict(simple_config))
        base = gen.compute_base_combinations()
        filtered = gen.apply_excludes(base)
        assert len(filtered) == len(base)


# ── Test 5: Include rules add / augment combinations ─────────────────────────

class TestIncludeRules:
    def test_include_adds_extra_entry(self, full_config):
        """Includes that don't match any existing combo are appended."""
        gen = MatrixGenerator(MatrixConfig.from_dict(full_config))
        # The include in full_config augments an existing combo (ubuntu+3.12)
        # with coverage=True — it doesn't add a new row in the base matrix sense;
        # the GitHub Actions spec just passes includes through.
        result = gen.generate()
        assert result["matrix"]["include"] == full_config["include"]

    def test_include_is_absent_when_empty(self, simple_config):
        gen = MatrixGenerator(MatrixConfig.from_dict(simple_config))
        result = gen.generate()
        assert "include" not in result["matrix"]

    def test_standalone_include_not_in_base_axes(self):
        """An include that references a key not in any axis is valid."""
        cfg = MatrixConfig.from_dict({
            "os": ["ubuntu-latest"],
            "language_versions": {},
            "feature_flags": {},
            "include": [{"os": "macos-latest", "python": "3.12"}],
            "max_matrix_size": 256,
        })
        gen = MatrixGenerator(cfg)
        result = gen.generate()
        assert result["matrix"]["include"] == [{"os": "macos-latest", "python": "3.12"}]


# ── Test 6: Matrix size validation ───────────────────────────────────────────

class TestMatrixSizeValidation:
    def test_exceeding_max_size_raises(self):
        cfg = MatrixConfig.from_dict({
            "os": ["ubuntu-latest", "windows-latest", "macos-latest"],
            "language_versions": {"python": ["3.9", "3.10", "3.11", "3.12"]},
            "feature_flags": {"experimental": [True, False]},
            "max_matrix_size": 10,  # 3×4×2=24 > 10
            "max_parallel": None,
        })
        gen = MatrixGenerator(cfg)
        with pytest.raises(MatrixValidationError, match="exceeds maximum"):
            gen.generate()

    def test_within_max_size_succeeds(self, full_config):
        gen = MatrixGenerator(MatrixConfig.from_dict(full_config))
        result = gen.generate()  # should not raise
        assert result is not None

    def test_exact_max_size_succeeds(self):
        cfg = MatrixConfig.from_dict({
            "os": ["ubuntu-latest", "windows-latest"],
            "language_versions": {"python": ["3.11", "3.12"]},
            "feature_flags": {},
            "max_matrix_size": 4,  # 2×2 = exactly 4
        })
        gen = MatrixGenerator(cfg)
        result = gen.generate()
        assert result is not None


# ── Test 7: fail-fast and max-parallel in output ─────────────────────────────

class TestStrategyOptions:
    def test_fail_fast_false_in_output(self, full_config):
        gen = MatrixGenerator(MatrixConfig.from_dict(full_config))
        result = gen.generate()
        assert result["fail-fast"] is False

    def test_fail_fast_true_default(self, simple_config):
        gen = MatrixGenerator(MatrixConfig.from_dict(simple_config))
        result = gen.generate()
        assert result["fail-fast"] is True

    def test_max_parallel_in_output(self, full_config):
        gen = MatrixGenerator(MatrixConfig.from_dict(full_config))
        result = gen.generate()
        assert result["max-parallel"] == 4

    def test_max_parallel_absent_when_none(self, simple_config):
        gen = MatrixGenerator(MatrixConfig.from_dict(simple_config))
        result = gen.generate()
        assert "max-parallel" not in result


# ── Test 8: Full JSON output structure ───────────────────────────────────────

class TestFullOutput:
    def test_output_has_matrix_key(self, full_config):
        gen = MatrixGenerator(MatrixConfig.from_dict(full_config))
        result = gen.generate()
        assert "matrix" in result

    def test_matrix_has_os_axis(self, full_config):
        gen = MatrixGenerator(MatrixConfig.from_dict(full_config))
        result = gen.generate()
        assert result["matrix"]["os"] == full_config["os"]

    def test_matrix_has_language_axes(self, full_config):
        gen = MatrixGenerator(MatrixConfig.from_dict(full_config))
        result = gen.generate()
        assert result["matrix"]["python"] == ["3.10", "3.11", "3.12"]

    def test_matrix_has_exclude(self, full_config):
        gen = MatrixGenerator(MatrixConfig.from_dict(full_config))
        result = gen.generate()
        assert result["matrix"]["exclude"] == full_config["exclude"]

    def test_output_is_json_serialisable(self, full_config):
        gen = MatrixGenerator(MatrixConfig.from_dict(full_config))
        result = gen.generate()
        serialised = json.dumps(result)
        assert isinstance(serialised, str)

    def test_to_json_string(self, full_config):
        gen = MatrixGenerator(MatrixConfig.from_dict(full_config))
        json_str = gen.to_json()
        parsed = json.loads(json_str)
        assert "matrix" in parsed

    def test_computed_size_reported(self, full_config):
        """generate() should expose how many combinations were computed."""
        gen = MatrixGenerator(MatrixConfig.from_dict(full_config))
        gen.generate()
        # 3 OS × 3 python × 2 experimental = 18, minus 2 excluded = 16
        assert gen.computed_size == 16
