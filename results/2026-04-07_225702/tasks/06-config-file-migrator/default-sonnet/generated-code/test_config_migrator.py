"""
Config File Migrator Tests — TDD red/green cycle.

Each test is introduced as a failing test first, then minimum code is added
to make it pass. Tests are grouped by feature area.
"""
import json
import os
import textwrap
import pytest
import yaml

# The module under test — will fail to import until we create it.
from config_migrator import ConfigMigrator, ValidationError


# ---------------------------------------------------------------------------
# Fixtures — shared INI content strings and temp files
# ---------------------------------------------------------------------------

SIMPLE_INI = textwrap.dedent("""\
    [database]
    host = localhost
    port = 5432
    name = mydb

    [server]
    debug = true
    workers = 4
    timeout = 30.5
""")

COMMENTED_INI = textwrap.dedent("""\
    ; Top-level comment
    # Another comment style

    [app]
    # Inline section comment
    name = MyApp   ; trailing comment
    version = 1.0
""")

MULTILINE_INI = textwrap.dedent("""\
    [logging]
    handlers =
        file
        console
        syslog
    level = INFO
""")

EDGE_CASE_INI = textwrap.dedent("""\
    [types]
    bool_true = true
    bool_false = false
    bool_yes = yes
    bool_no = no
    bool_on = on
    bool_off = off
    integer = 42
    negative = -7
    float_val = 3.14
    empty_val =
    quoted = "hello world"
""")


@pytest.fixture
def tmp_ini(tmp_path):
    """Write an INI string to a temp file and return its path."""
    def _write(content, filename="test.ini"):
        p = tmp_path / filename
        p.write_text(content)
        return str(p)
    return _write


# ===========================================================================
# FEATURE 1: INI Parsing
# ===========================================================================

class TestIniParsing:
    """RED → GREEN cycle for basic INI file parsing."""

    def test_parse_returns_dict_with_sections(self, tmp_ini):
        """Parsed result must have top-level section keys."""
        path = tmp_ini(SIMPLE_INI)
        m = ConfigMigrator(path)
        result = m.parse()
        assert "database" in result
        assert "server" in result

    def test_parse_section_keys_and_values(self, tmp_ini):
        """Values inside a section are accessible by key."""
        path = tmp_ini(SIMPLE_INI)
        m = ConfigMigrator(path)
        result = m.parse()
        assert result["database"]["host"] == "localhost"
        assert result["database"]["name"] == "mydb"

    def test_parse_nonexistent_file_raises(self):
        """Parsing a missing file should raise FileNotFoundError."""
        with pytest.raises(FileNotFoundError):
            ConfigMigrator("/nonexistent/path.ini").parse()

    def test_parse_strips_comments(self, tmp_ini):
        """Comments (# and ;) must be stripped; they must not appear in values."""
        path = tmp_ini(COMMENTED_INI)
        m = ConfigMigrator(path)
        result = m.parse()
        assert result["app"]["name"] == "MyApp"
        assert ";" not in result["app"]["name"]
        # "1.0" coerces to float — compare as float
        assert result["app"]["version"] == 1.0

    def test_parse_multiline_values_as_list(self, tmp_ini):
        """Continuation-indented lines should be collected into a list."""
        path = tmp_ini(MULTILINE_INI)
        m = ConfigMigrator(path)
        result = m.parse()
        assert result["logging"]["handlers"] == ["file", "console", "syslog"]

    def test_parse_empty_value(self, tmp_ini):
        """An empty value (key =) should parse to None."""
        path = tmp_ini(EDGE_CASE_INI)
        m = ConfigMigrator(path)
        result = m.parse()
        assert result["types"]["empty_val"] is None


# ===========================================================================
# FEATURE 2: Type Coercion
# ===========================================================================

class TestTypeCoercion:
    """RED → GREEN cycle for automatic type coercion."""

    def test_coerce_integers(self, tmp_ini):
        path = tmp_ini(SIMPLE_INI)
        m = ConfigMigrator(path)
        result = m.parse()
        assert result["database"]["port"] == 5432
        assert isinstance(result["database"]["port"], int)

    def test_coerce_floats(self, tmp_ini):
        path = tmp_ini(SIMPLE_INI)
        m = ConfigMigrator(path)
        result = m.parse()
        assert result["server"]["timeout"] == 30.5
        assert isinstance(result["server"]["timeout"], float)

    def test_coerce_booleans_true_variants(self, tmp_ini):
        path = tmp_ini(EDGE_CASE_INI)
        m = ConfigMigrator(path)
        result = m.parse()
        assert result["types"]["bool_true"] is True
        assert result["types"]["bool_yes"] is True
        assert result["types"]["bool_on"] is True

    def test_coerce_booleans_false_variants(self, tmp_ini):
        path = tmp_ini(EDGE_CASE_INI)
        m = ConfigMigrator(path)
        result = m.parse()
        assert result["types"]["bool_false"] is False
        assert result["types"]["bool_no"] is False
        assert result["types"]["bool_off"] is False

    def test_coerce_negative_integer(self, tmp_ini):
        path = tmp_ini(EDGE_CASE_INI)
        m = ConfigMigrator(path)
        result = m.parse()
        assert result["types"]["negative"] == -7

    def test_quoted_string_strips_quotes(self, tmp_ini):
        path = tmp_ini(EDGE_CASE_INI)
        m = ConfigMigrator(path)
        result = m.parse()
        assert result["types"]["quoted"] == "hello world"


# ===========================================================================
# FEATURE 3: Schema Validation
# ===========================================================================

SCHEMA = {
    "database": {
        "required": ["host", "port", "name"],
        "types": {
            "host": str,
            "port": int,
            "name": str,
        },
    },
    "server": {
        "required": ["debug", "workers"],
        "types": {
            "debug": bool,
            "workers": int,
            "timeout": float,
        },
    },
}


class TestSchemaValidation:
    """RED → GREEN cycle for schema validation."""

    def test_validate_passes_valid_config(self, tmp_ini):
        path = tmp_ini(SIMPLE_INI)
        m = ConfigMigrator(path, schema=SCHEMA)
        m.parse()
        # Should not raise
        m.validate()

    def test_validate_raises_for_missing_section(self, tmp_ini):
        """Schema references a section not in the file."""
        ini = "[server]\ndebug = true\nworkers = 2\n"
        path = tmp_ini(ini)
        m = ConfigMigrator(path, schema=SCHEMA)
        m.parse()
        with pytest.raises(ValidationError, match="missing section.*database"):
            m.validate()

    def test_validate_raises_for_missing_key(self, tmp_ini):
        """Required key absent from an existing section."""
        ini = "[database]\nhost = localhost\nport = 5432\n[server]\ndebug = true\nworkers = 2\n"
        path = tmp_ini(ini)
        m = ConfigMigrator(path, schema=SCHEMA)
        m.parse()
        with pytest.raises(ValidationError, match="missing required key.*name"):
            m.validate()

    def test_validate_raises_for_wrong_type(self, tmp_ini):
        """A key present but typed incorrectly (port must be int, not str)."""
        ini = (
            "[database]\nhost = localhost\nport = notanumber\nname = mydb\n"
            "[server]\ndebug = true\nworkers = 2\n"
        )
        path = tmp_ini(ini)
        m = ConfigMigrator(path, schema=SCHEMA)
        m.parse()
        with pytest.raises(ValidationError, match="type.*port"):
            m.validate()

    def test_validate_allows_optional_keys_absent(self, tmp_ini):
        """Keys in schema 'types' but not in 'required' may be missing."""
        ini = (
            "[database]\nhost = localhost\nport = 5432\nname = mydb\n"
            "[server]\ndebug = true\nworkers = 2\n"
            # 'timeout' is not required — should not raise
        )
        path = tmp_ini(ini)
        m = ConfigMigrator(path, schema=SCHEMA)
        m.parse()
        m.validate()  # must not raise


# ===========================================================================
# FEATURE 4: JSON Output
# ===========================================================================

class TestJsonOutput:
    """RED → GREEN cycle for JSON serialisation."""

    def test_to_json_returns_valid_json_string(self, tmp_ini):
        path = tmp_ini(SIMPLE_INI)
        m = ConfigMigrator(path)
        m.parse()
        output = m.to_json()
        parsed = json.loads(output)  # must not raise
        assert parsed["database"]["host"] == "localhost"

    def test_to_json_preserves_types(self, tmp_ini):
        path = tmp_ini(SIMPLE_INI)
        m = ConfigMigrator(path)
        m.parse()
        parsed = json.loads(m.to_json())
        assert isinstance(parsed["database"]["port"], int)
        assert isinstance(parsed["server"]["debug"], bool)
        assert isinstance(parsed["server"]["timeout"], float)

    def test_to_json_file_writes_file(self, tmp_ini, tmp_path):
        path = tmp_ini(SIMPLE_INI)
        out_path = str(tmp_path / "out.json")
        m = ConfigMigrator(path)
        m.parse()
        m.to_json_file(out_path)
        assert os.path.exists(out_path)
        with open(out_path) as f:
            data = json.load(f)
        assert data["database"]["name"] == "mydb"


# ===========================================================================
# FEATURE 5: YAML Output
# ===========================================================================

class TestYamlOutput:
    """RED → GREEN cycle for YAML serialisation."""

    def test_to_yaml_returns_valid_yaml_string(self, tmp_ini):
        path = tmp_ini(SIMPLE_INI)
        m = ConfigMigrator(path)
        m.parse()
        output = m.to_yaml()
        parsed = yaml.safe_load(output)
        assert parsed["database"]["host"] == "localhost"

    def test_to_yaml_preserves_types(self, tmp_ini):
        path = tmp_ini(SIMPLE_INI)
        m = ConfigMigrator(path)
        m.parse()
        parsed = yaml.safe_load(m.to_yaml())
        assert isinstance(parsed["database"]["port"], int)
        assert isinstance(parsed["server"]["debug"], bool)

    def test_to_yaml_file_writes_file(self, tmp_ini, tmp_path):
        path = tmp_ini(SIMPLE_INI)
        out_path = str(tmp_path / "out.yaml")
        m = ConfigMigrator(path)
        m.parse()
        m.to_yaml_file(out_path)
        assert os.path.exists(out_path)
        with open(out_path) as f:
            data = yaml.safe_load(f)
        assert data["server"]["workers"] == 4

    def test_to_yaml_multiline_as_sequence(self, tmp_ini):
        """List values should appear as YAML sequences."""
        path = tmp_ini(MULTILINE_INI)
        m = ConfigMigrator(path)
        m.parse()
        parsed = yaml.safe_load(m.to_yaml())
        assert isinstance(parsed["logging"]["handlers"], list)
        assert "file" in parsed["logging"]["handlers"]


# ===========================================================================
# FEATURE 6: End-to-end / edge cases
# ===========================================================================

COMPLEX_INI = textwrap.dedent("""\
    ; Production configuration
    # Written by deploy tool

    [database]
    host = db.prod.example.com
    port = 5432
    name = production
    ssl = true
    pool_size = 10

    [cache]
    backend = redis
    ttl = 3600
    # hosts listed one per line
    hosts =
        cache1.example.com
        cache2.example.com

    [feature_flags]
    new_dashboard = false
    beta_search = true
    max_results = 100
""")


class TestEndToEnd:
    """Full-pipeline tests covering parse → validate → export."""

    def test_complex_config_roundtrip_json(self, tmp_ini):
        path = tmp_ini(COMPLEX_INI)
        m = ConfigMigrator(path)
        m.parse()
        out = json.loads(m.to_json())
        assert out["database"]["ssl"] is True
        assert out["database"]["pool_size"] == 10
        assert isinstance(out["cache"]["hosts"], list)
        assert len(out["cache"]["hosts"]) == 2
        assert out["feature_flags"]["new_dashboard"] is False

    def test_complex_config_roundtrip_yaml(self, tmp_ini):
        path = tmp_ini(COMPLEX_INI)
        m = ConfigMigrator(path)
        m.parse()
        out = yaml.safe_load(m.to_yaml())
        assert out["cache"]["ttl"] == 3600
        assert out["feature_flags"]["beta_search"] is True

    def test_parse_before_validate_raises(self, tmp_ini):
        """validate() called before parse() should raise RuntimeError."""
        path = tmp_ini(SIMPLE_INI)
        m = ConfigMigrator(path, schema=SCHEMA)
        with pytest.raises(RuntimeError, match="parse"):
            m.validate()

    def test_parse_before_export_raises(self, tmp_ini):
        """to_json() / to_yaml() before parse() should raise RuntimeError."""
        path = tmp_ini(SIMPLE_INI)
        m = ConfigMigrator(path)
        with pytest.raises(RuntimeError, match="parse"):
            m.to_json()
        with pytest.raises(RuntimeError, match="parse"):
            m.to_yaml()
