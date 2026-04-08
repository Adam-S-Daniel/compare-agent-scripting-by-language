"""Tests for config file migrator — INI to JSON/YAML with schema validation.

TDD approach: each test is written before the implementation code that makes it pass.
"""

import pytest
import json
import yaml
import os
import tempfile

from config_migrator import parse_ini, validate, to_json, to_yaml, MigrationError


# ── Fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture
def basic_ini(tmp_path):
    """Simple INI with two sections."""
    content = """\
[server]
host = localhost
port = 8080
debug = true

[database]
name = myapp
max_connections = 10
"""
    path = tmp_path / "basic.ini"
    path.write_text(content)
    return str(path)


@pytest.fixture
def basic_schema():
    """Schema requiring server.host (str) and server.port (int)."""
    return {
        "server": {
            "host": {"type": "string", "required": True},
            "port": {"type": "integer", "required": True},
            "debug": {"type": "boolean", "required": False},
        },
        "database": {
            "name": {"type": "string", "required": True},
            "max_connections": {"type": "integer", "required": False},
        },
    }


# ── Cycle 1: Basic INI parsing ───────────────────────────────────────────────

class TestParseIni:
    def test_parses_sections_and_keys(self, basic_ini):
        """RED→GREEN: parse_ini returns a nested dict of sections → key/value."""
        result = parse_ini(basic_ini)
        assert "server" in result
        assert result["server"]["host"] == "localhost"
        assert "database" in result
        assert result["database"]["name"] == "myapp"

    def test_values_are_strings_before_coercion(self, basic_ini):
        """All raw parsed values should be strings (coercion is a separate step)."""
        result = parse_ini(basic_ini)
        assert result["server"]["port"] == "8080"
        assert result["server"]["debug"] == "true"

    def test_file_not_found_raises(self):
        """Graceful error for missing file."""
        with pytest.raises(MigrationError, match="not found"):
            parse_ini("/nonexistent/path.ini")


# ── Cycle 2: Comments and blank lines ────────────────────────────────────────

class TestCommentsAndBlanks:
    def test_comments_and_blanks_ignored(self, tmp_path):
        content = """\
; This is a comment
# This is also a comment

[section]
key = value
; inline section comment
other = data
"""
        path = tmp_path / "comments.ini"
        path.write_text(content)
        result = parse_ini(str(path))
        assert result["section"]["key"] == "value"
        assert result["section"]["other"] == "data"
        assert len(result["section"]) == 2  # comments not stored


# ── Cycle 3: Multi-line values ───────────────────────────────────────────────

class TestMultiLineValues:
    def test_continuation_lines(self, tmp_path):
        """Lines starting with whitespace continue the previous value."""
        content = """\
[paths]
search_dirs = /usr/local/bin
    /usr/bin
    /bin
name = test
"""
        path = tmp_path / "multiline.ini"
        path.write_text(content)
        result = parse_ini(str(path))
        # Multi-line values are joined with newlines, leading whitespace stripped
        assert "/usr/local/bin" in result["paths"]["search_dirs"]
        assert "/usr/bin" in result["paths"]["search_dirs"]
        assert "/bin" in result["paths"]["search_dirs"]
        assert result["paths"]["name"] == "test"


# ── Cycle 4: Type coercion ───────────────────────────────────────────────────

class TestTypeCoercion:
    def test_integers_coerced(self, basic_ini, basic_schema):
        config = parse_ini(basic_ini)
        validated = validate(config, basic_schema)
        assert validated["server"]["port"] == 8080
        assert isinstance(validated["server"]["port"], int)

    def test_booleans_coerced(self, basic_ini, basic_schema):
        config = parse_ini(basic_ini)
        validated = validate(config, basic_schema)
        assert validated["server"]["debug"] is True

    def test_strings_stay_strings(self, basic_ini, basic_schema):
        config = parse_ini(basic_ini)
        validated = validate(config, basic_schema)
        assert validated["server"]["host"] == "localhost"
        assert isinstance(validated["server"]["host"], str)

    def test_boolean_variants(self, tmp_path):
        """Various boolean representations should all coerce correctly."""
        content = """\
[flags]
a = true
b = false
c = yes
d = no
e = on
f = off
g = 1
h = 0
"""
        path = tmp_path / "bools.ini"
        path.write_text(content)
        schema = {
            "flags": {
                "a": {"type": "boolean"}, "b": {"type": "boolean"},
                "c": {"type": "boolean"}, "d": {"type": "boolean"},
                "e": {"type": "boolean"}, "f": {"type": "boolean"},
                "g": {"type": "boolean"}, "h": {"type": "boolean"},
            }
        }
        config = parse_ini(str(path))
        validated = validate(config, schema)
        assert validated["flags"]["a"] is True
        assert validated["flags"]["b"] is False
        assert validated["flags"]["c"] is True
        assert validated["flags"]["d"] is False
        assert validated["flags"]["e"] is True
        assert validated["flags"]["f"] is False
        assert validated["flags"]["g"] is True
        assert validated["flags"]["h"] is False


# ── Cycle 5: Schema validation — required keys ──────────────────────────────

class TestSchemaValidation:
    def test_missing_required_key_raises(self, tmp_path):
        content = """\
[server]
debug = true
"""
        path = tmp_path / "incomplete.ini"
        path.write_text(content)
        schema = {
            "server": {
                "host": {"type": "string", "required": True},
                "port": {"type": "integer", "required": True},
            }
        }
        config = parse_ini(str(path))
        with pytest.raises(MigrationError, match="required.*host"):
            validate(config, schema)

    def test_missing_required_section_raises(self, tmp_path):
        content = """\
[other]
key = value
"""
        path = tmp_path / "missing_section.ini"
        path.write_text(content)
        schema = {
            "server": {
                "host": {"type": "string", "required": True},
            }
        }
        config = parse_ini(str(path))
        with pytest.raises(MigrationError, match="required.*server"):
            validate(config, schema)

    def test_invalid_integer_value_raises(self, tmp_path):
        content = """\
[server]
port = not_a_number
"""
        path = tmp_path / "bad_type.ini"
        path.write_text(content)
        schema = {"server": {"port": {"type": "integer", "required": True}}}
        config = parse_ini(str(path))
        with pytest.raises(MigrationError, match="cannot convert.*port.*integer"):
            validate(config, schema)

    def test_optional_keys_can_be_absent(self, tmp_path):
        content = """\
[server]
host = localhost
"""
        path = tmp_path / "minimal.ini"
        path.write_text(content)
        schema = {
            "server": {
                "host": {"type": "string", "required": True},
                "port": {"type": "integer", "required": False},
            }
        }
        config = parse_ini(str(path))
        validated = validate(config, schema)
        assert "port" not in validated["server"]

    def test_extra_keys_without_schema_kept_as_strings(self, tmp_path):
        """Keys present in INI but not in schema are kept as-is (strings)."""
        content = """\
[server]
host = localhost
extra = something
"""
        path = tmp_path / "extra.ini"
        path.write_text(content)
        schema = {"server": {"host": {"type": "string", "required": True}}}
        config = parse_ini(str(path))
        validated = validate(config, schema)
        assert validated["server"]["extra"] == "something"

    def test_extra_sections_without_schema_kept(self, tmp_path):
        """Sections not in schema are passed through with auto-coercion."""
        content = """\
[server]
host = localhost

[logging]
level = info
verbose = true
count = 42
"""
        path = tmp_path / "extra_section.ini"
        path.write_text(content)
        schema = {"server": {"host": {"type": "string", "required": True}}}
        config = parse_ini(str(path))
        validated = validate(config, schema)
        assert validated["logging"]["level"] == "info"
        # Auto-coercion for values without schema
        assert validated["logging"]["verbose"] is True
        assert validated["logging"]["count"] == 42


# ── Cycle 6: JSON output ─────────────────────────────────────────────────────

class TestJsonOutput:
    def test_produces_valid_json(self, basic_ini, basic_schema):
        config = parse_ini(basic_ini)
        validated = validate(config, basic_schema)
        json_str = to_json(validated)
        parsed = json.loads(json_str)
        assert parsed["server"]["host"] == "localhost"
        assert parsed["server"]["port"] == 8080
        assert parsed["server"]["debug"] is True

    def test_json_is_pretty_printed(self, basic_ini, basic_schema):
        config = parse_ini(basic_ini)
        validated = validate(config, basic_schema)
        json_str = to_json(validated)
        # Pretty-printed JSON has newlines and indentation
        assert "\n" in json_str
        assert "  " in json_str


# ── Cycle 7: YAML output ─────────────────────────────────────────────────────

class TestYamlOutput:
    def test_produces_valid_yaml(self, basic_ini, basic_schema):
        config = parse_ini(basic_ini)
        validated = validate(config, basic_schema)
        yaml_str = to_yaml(validated)
        parsed = yaml.safe_load(yaml_str)
        assert parsed["server"]["host"] == "localhost"
        assert parsed["server"]["port"] == 8080
        assert parsed["database"]["max_connections"] == 10

    def test_yaml_preserves_types(self, basic_ini, basic_schema):
        config = parse_ini(basic_ini)
        validated = validate(config, basic_schema)
        yaml_str = to_yaml(validated)
        parsed = yaml.safe_load(yaml_str)
        assert isinstance(parsed["server"]["port"], int)
        assert isinstance(parsed["server"]["debug"], bool)


# ── Cycle 8: Edge cases ──────────────────────────────────────────────────────

class TestEdgeCases:
    def test_empty_file(self, tmp_path):
        path = tmp_path / "empty.ini"
        path.write_text("")
        result = parse_ini(str(path))
        assert result == {}

    def test_empty_values(self, tmp_path):
        content = """\
[section]
empty_key =
another =
"""
        path = tmp_path / "empty_vals.ini"
        path.write_text(content)
        result = parse_ini(str(path))
        assert result["section"]["empty_key"] == ""
        assert result["section"]["another"] == ""

    def test_values_with_equals_signs(self, tmp_path):
        """Values containing '=' should be preserved."""
        content = """\
[section]
equation = x = y + z
connection = host=localhost;port=5432
"""
        path = tmp_path / "equals.ini"
        path.write_text(content)
        result = parse_ini(str(path))
        assert result["section"]["equation"] == "x = y + z"
        assert result["section"]["connection"] == "host=localhost;port=5432"

    def test_quoted_values_unquoted(self, tmp_path):
        """Surrounding quotes on values should be stripped."""
        content = """\
[section]
single = 'hello world'
double = "hello world"
inner = say "hi" please
"""
        path = tmp_path / "quoted.ini"
        path.write_text(content)
        result = parse_ini(str(path))
        assert result["section"]["single"] == "hello world"
        assert result["section"]["double"] == "hello world"
        assert result["section"]["inner"] == 'say "hi" please'

    def test_inline_comments_stripped(self, tmp_path):
        """Comments after values (;) should be stripped."""
        content = """\
[section]
key = value ; this is a comment
other = data # also a comment
"""
        path = tmp_path / "inline_comments.ini"
        path.write_text(content)
        result = parse_ini(str(path))
        assert result["section"]["key"] == "value"
        assert result["section"]["other"] == "data"

    def test_float_coercion(self, tmp_path):
        content = """\
[metrics]
threshold = 3.14
ratio = 0.5
"""
        path = tmp_path / "floats.ini"
        path.write_text(content)
        schema = {
            "metrics": {
                "threshold": {"type": "float", "required": True},
                "ratio": {"type": "float"},
            }
        }
        config = parse_ini(str(path))
        validated = validate(config, schema)
        assert validated["metrics"]["threshold"] == pytest.approx(3.14)
        assert validated["metrics"]["ratio"] == pytest.approx(0.5)

    def test_invalid_float_raises(self, tmp_path):
        content = """\
[metrics]
threshold = not_a_float
"""
        path = tmp_path / "bad_float.ini"
        path.write_text(content)
        schema = {"metrics": {"threshold": {"type": "float", "required": True}}}
        config = parse_ini(str(path))
        with pytest.raises(MigrationError, match="cannot convert.*threshold.*float"):
            validate(config, schema)

    def test_whitespace_around_keys_and_values(self, tmp_path):
        content = """\
[section]
  key  =  value
  spaced  =  hello
"""
        path = tmp_path / "whitespace.ini"
        path.write_text(content)
        result = parse_ini(str(path))
        assert result["section"]["key"] == "value"
        assert result["section"]["spaced"] == "hello"

    def test_colon_as_delimiter(self, tmp_path):
        """Colons can also be used as key-value delimiters in INI."""
        content = """\
[section]
key: value
other: data
"""
        path = tmp_path / "colon.ini"
        path.write_text(content)
        result = parse_ini(str(path))
        assert result["section"]["key"] == "value"
        assert result["section"]["other"] == "data"

    def test_auto_coerce_numbers_and_bools_without_schema(self, tmp_path):
        """When no schema is provided, auto-detect and coerce types."""
        content = """\
[section]
count = 42
rate = 3.14
flag = true
name = hello
"""
        path = tmp_path / "auto.ini"
        path.write_text(content)
        config = parse_ini(str(path))
        validated = validate(config, schema=None)
        assert validated["section"]["count"] == 42
        assert validated["section"]["rate"] == pytest.approx(3.14)
        assert validated["section"]["flag"] is True
        assert validated["section"]["name"] == "hello"


# ── Cycle 9: Full round-trip integration ─────────────────────────────────────

class TestIntegration:
    def test_full_pipeline_json(self, basic_ini, basic_schema, tmp_path):
        """Parse → validate → JSON → re-parse should round-trip."""
        config = parse_ini(basic_ini)
        validated = validate(config, basic_schema)
        json_str = to_json(validated)

        out_path = tmp_path / "output.json"
        out_path.write_text(json_str)
        reloaded = json.loads(out_path.read_text())

        assert reloaded["server"]["port"] == 8080
        assert reloaded["server"]["debug"] is True
        assert reloaded["database"]["max_connections"] == 10

    def test_full_pipeline_yaml(self, basic_ini, basic_schema, tmp_path):
        """Parse → validate → YAML → re-parse should round-trip."""
        config = parse_ini(basic_ini)
        validated = validate(config, basic_schema)
        yaml_str = to_yaml(validated)

        out_path = tmp_path / "output.yaml"
        out_path.write_text(yaml_str)
        reloaded = yaml.safe_load(out_path.read_text())

        assert reloaded["server"]["host"] == "localhost"
        assert reloaded["database"]["name"] == "myapp"
