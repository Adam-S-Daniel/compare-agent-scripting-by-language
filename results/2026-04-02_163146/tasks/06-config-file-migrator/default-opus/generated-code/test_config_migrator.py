"""
Tests for config_migrator module.

TDD approach: each test class represents a RED phase where tests were written
BEFORE the corresponding implementation code. The implementation was then
written to make these tests pass (GREEN), followed by refactoring.

Test execution order follows the development cycle:
  1. Basic INI parsing (sections, key-value pairs)
  2. Type coercion (strings -> numbers, booleans, null)
  3. Schema validation (required keys, type checking)
  4. JSON output generation
  5. YAML output generation
  6. Edge cases (comments, multi-line values, whitespace, errors)
"""

import json
import os
import tempfile

import pytest

# Path to test fixtures
FIXTURES_DIR = os.path.join(os.path.dirname(__file__), "fixtures")


def fixture_path(name):
    """Helper to get absolute path to a test fixture file."""
    return os.path.join(FIXTURES_DIR, name)


# =============================================================================
# RED/GREEN PHASE 1: Basic INI parsing - sections and key-value pairs
# =============================================================================

class TestBasicParsing:
    """Test that we can parse a simple INI file into a nested dict of strings."""

    def test_parse_returns_dict_with_sections_as_keys(self):
        from config_migrator import parse_ini
        result = parse_ini(fixture_path("basic.ini"))
        assert isinstance(result, dict)
        assert "server" in result
        assert "database" in result

    def test_parse_extracts_key_value_pairs(self):
        from config_migrator import parse_ini
        result = parse_ini(fixture_path("basic.ini"))
        # At parse stage, all values are raw strings (no coercion yet)
        assert result["server"]["host"] == "localhost"
        assert result["server"]["port"] == "8080"
        assert result["database"]["host"] == "db.example.com"
        assert result["database"]["name"] == "myapp"

    def test_parse_empty_file_returns_empty_dict(self):
        from config_migrator import parse_ini
        result = parse_ini(fixture_path("empty.ini"))
        assert result == {}

    def test_parse_nonexistent_file_raises_error(self):
        from config_migrator import parse_ini
        with pytest.raises(FileNotFoundError, match="not_here.ini"):
            parse_ini(fixture_path("not_here.ini"))

    def test_parse_strips_whitespace_from_keys_and_values(self):
        """Keys and values should be trimmed of leading/trailing whitespace."""
        from config_migrator import parse_ini
        result = parse_ini(fixture_path("comments_and_whitespace.ini"))
        assert result["section1"]["key3"] == "value3"

    def test_parse_handles_no_spaces_around_equals(self):
        """key=value (no spaces) should parse the same as key = value."""
        from config_migrator import parse_ini
        result = parse_ini(fixture_path("comments_and_whitespace.ini"))
        assert result["section1"]["key2"] == "value2"


# =============================================================================
# RED/GREEN PHASE 2: Comment handling
# =============================================================================

class TestCommentHandling:
    """Test that semicolon and hash comments are properly ignored."""

    def test_semicolon_comments_are_ignored(self):
        from config_migrator import parse_ini
        result = parse_ini(fixture_path("comments_and_whitespace.ini"))
        # Comments should not appear as keys
        for section in result.values():
            for key in section:
                assert not key.startswith(";")
                assert "comment" not in key.lower()

    def test_hash_comments_are_ignored(self):
        from config_migrator import parse_ini
        result = parse_ini(fixture_path("comments_and_whitespace.ini"))
        for section in result.values():
            for key in section:
                assert not key.startswith("#")

    def test_values_with_special_characters_preserved(self):
        """URLs and paths with special chars should be kept intact."""
        from config_migrator import parse_ini
        result = parse_ini(fixture_path("comments_and_whitespace.ini"))
        assert result["section2"]["path"] == "/usr/local/bin"
        assert result["section2"]["url"] == "https://example.com/api?key=abc&format=json"


# =============================================================================
# RED/GREEN PHASE 3: Multi-line value support
# =============================================================================

class TestMultiLineValues:
    """Test that continuation lines (indented) are joined into a single value."""

    def test_multiline_description(self):
        from config_migrator import parse_ini
        result = parse_ini(fixture_path("multiline.ini"))
        desc = result["app"]["description"]
        # Multi-line values should be joined with newlines
        assert "multi-line" in desc
        assert "multiple lines" in desc

    def test_multiline_does_not_affect_next_key(self):
        from config_migrator import parse_ini
        result = parse_ini(fixture_path("multiline.ini"))
        assert result["app"]["version"] == "1.2.3"

    def test_multiline_logging_format(self):
        from config_migrator import parse_ini
        result = parse_ini(fixture_path("multiline.ini"))
        fmt = result["logging"]["format"]
        assert "%(asctime)s" in fmt
        assert "%(message)s" in fmt


# =============================================================================
# RED/GREEN PHASE 4: Type coercion
# =============================================================================

class TestTypeCoercion:
    """Test automatic type coercion from string values to native Python types."""

    def test_integer_coercion(self):
        from config_migrator import coerce_types
        data = {"section": {"port": "8080", "count": "-5"}}
        result = coerce_types(data)
        assert result["section"]["port"] == 8080
        assert result["section"]["count"] == -5
        assert isinstance(result["section"]["port"], int)

    def test_float_coercion(self):
        from config_migrator import coerce_types
        data = {"section": {"rate": "3.14", "neg": "-2.718"}}
        result = coerce_types(data)
        assert result["section"]["rate"] == pytest.approx(3.14)
        assert result["section"]["neg"] == pytest.approx(-2.718)

    def test_boolean_coercion(self):
        from config_migrator import coerce_types
        data = {"section": {
            "a": "true", "b": "false",
            "c": "yes", "d": "no",
            "e": "on", "f": "off",
            "g": "True", "h": "FALSE",
        }}
        result = coerce_types(data)
        assert result["section"]["a"] is True
        assert result["section"]["b"] is False
        assert result["section"]["c"] is True
        assert result["section"]["d"] is False
        assert result["section"]["e"] is True
        assert result["section"]["f"] is False
        assert result["section"]["g"] is True
        assert result["section"]["h"] is False

    def test_null_coercion(self):
        from config_migrator import coerce_types
        data = {"section": {"a": "null", "b": "none", "c": ""}}
        result = coerce_types(data)
        assert result["section"]["a"] is None
        assert result["section"]["b"] is None
        assert result["section"]["c"] is None

    def test_strings_remain_strings(self):
        """Values that look like strings should not be coerced."""
        from config_migrator import coerce_types
        data = {"section": {
            "name": "hello world",
            "leading_zero": "007",          # not a plain integer
            "ip": "192.168.1.1",            # not a number
        }}
        result = coerce_types(data)
        assert result["section"]["name"] == "hello world"
        assert result["section"]["leading_zero"] == "007"
        assert result["section"]["ip"] == "192.168.1.1"

    def test_coerce_types_with_fixture(self):
        """End-to-end test: parse INI then coerce types."""
        from config_migrator import parse_ini, coerce_types
        raw = parse_ini(fixture_path("type_coercion.ini"))
        result = coerce_types(raw)
        assert result["types"]["integer"] == 42
        assert result["types"]["negative_int"] == -17
        assert result["types"]["float_val"] == pytest.approx(3.14)
        assert result["types"]["bool_true"] is True
        assert result["types"]["bool_false"] is False
        assert result["types"]["bool_yes"] is True
        assert result["types"]["bool_no"] is False
        assert result["types"]["string_val"] == "hello world"
        assert result["types"]["empty_val"] is None
        assert result["types"]["null_val"] is None
        assert result["types"]["numeric_string"] == "007"
        assert result["types"]["ip_address"] == "192.168.1.1"


# =============================================================================
# RED/GREEN PHASE 5: Schema validation
# =============================================================================

class TestSchemaValidation:
    """Test validation of parsed config against a JSON schema."""

    def test_valid_config_passes_validation(self):
        from config_migrator import parse_ini, coerce_types, validate_schema
        raw = parse_ini(fixture_path("basic.ini"))
        data = coerce_types(raw)
        schema = json.load(open(fixture_path("schema.json")))
        errors = validate_schema(data, schema)
        assert errors == []

    def test_missing_required_keys_detected(self):
        from config_migrator import parse_ini, coerce_types, validate_schema
        raw = parse_ini(fixture_path("invalid_missing_required.ini"))
        data = coerce_types(raw)
        schema = json.load(open(fixture_path("schema.json")))
        errors = validate_schema(data, schema)
        # Should report missing keys
        assert len(errors) > 0
        error_text = "\n".join(errors)
        assert "host" in error_text
        assert "port" in error_text

    def test_type_mismatch_detected(self):
        from config_migrator import parse_ini, coerce_types, validate_schema
        raw = parse_ini(fixture_path("invalid_types.ini"))
        data = coerce_types(raw)
        schema = json.load(open(fixture_path("schema.json")))
        errors = validate_schema(data, schema)
        assert len(errors) > 0
        error_text = "\n".join(errors)
        # "port" in server should fail because "not_a_number" stays a string
        assert "port" in error_text or "not_a_number" in error_text

    def test_missing_section_detected(self):
        """If schema expects a section that doesn't exist, report it."""
        from config_migrator import validate_schema
        data = {"server": {"host": "localhost", "port": 8080}}
        schema = json.load(open(fixture_path("schema.json")))
        errors = validate_schema(data, schema)
        error_text = "\n".join(errors)
        assert "database" in error_text

    def test_extra_keys_are_allowed(self):
        """Keys not in the schema should not cause errors (open-world)."""
        from config_migrator import validate_schema
        data = {
            "server": {"host": "x", "port": 80, "debug": True, "extra_key": "ok"},
            "database": {"host": "x", "port": 5432, "name": "db"},
        }
        schema = json.load(open(fixture_path("schema.json")))
        errors = validate_schema(data, schema)
        assert errors == []

    def test_validate_schema_returns_meaningful_messages(self):
        """Error messages should clearly indicate what went wrong."""
        from config_migrator import validate_schema
        data = {"server": {"debug": True}}
        schema = json.load(open(fixture_path("schema.json")))
        errors = validate_schema(data, schema)
        # Each error should mention the section and key
        for err in errors:
            assert "server" in err or "database" in err


# =============================================================================
# RED/GREEN PHASE 6: JSON output
# =============================================================================

class TestJsonOutput:
    """Test conversion of parsed config data to JSON format."""

    def test_to_json_produces_valid_json(self):
        from config_migrator import to_json
        data = {"server": {"host": "localhost", "port": 8080}}
        result = to_json(data)
        parsed = json.loads(result)
        assert parsed == data

    def test_to_json_is_pretty_printed(self):
        from config_migrator import to_json
        data = {"server": {"host": "localhost"}}
        result = to_json(data)
        # Pretty-printed JSON has newlines and indentation
        assert "\n" in result
        assert "    " in result or "\t" in result

    def test_to_json_handles_all_types(self):
        from config_migrator import to_json
        data = {
            "types": {
                "str_val": "hello",
                "int_val": 42,
                "float_val": 3.14,
                "bool_val": True,
                "null_val": None,
            }
        }
        result = to_json(data)
        parsed = json.loads(result)
        assert parsed["types"]["null_val"] is None
        assert parsed["types"]["bool_val"] is True
        assert parsed["types"]["int_val"] == 42

    def test_to_json_file_output(self):
        """to_json should optionally write to a file."""
        from config_migrator import to_json
        data = {"app": {"name": "test"}}
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            path = f.name
        try:
            to_json(data, output_path=path)
            with open(path) as f:
                parsed = json.load(f)
            assert parsed == data
        finally:
            os.unlink(path)


# =============================================================================
# RED/GREEN PHASE 7: YAML output
# =============================================================================

class TestYamlOutput:
    """Test conversion of parsed config data to YAML format."""

    def test_to_yaml_produces_valid_yaml(self):
        import yaml
        from config_migrator import to_yaml
        data = {"server": {"host": "localhost", "port": 8080}}
        result = to_yaml(data)
        parsed = yaml.safe_load(result)
        assert parsed == data

    def test_to_yaml_preserves_types(self):
        import yaml
        from config_migrator import to_yaml
        data = {
            "types": {
                "str_val": "hello",
                "int_val": 42,
                "float_val": 3.14,
                "bool_val": True,
                "null_val": None,
            }
        }
        result = to_yaml(data)
        parsed = yaml.safe_load(result)
        assert parsed["types"]["null_val"] is None
        assert parsed["types"]["bool_val"] is True

    def test_to_yaml_file_output(self):
        """to_yaml should optionally write to a file."""
        import yaml
        from config_migrator import to_yaml
        data = {"app": {"name": "test"}}
        with tempfile.NamedTemporaryFile(mode="w", suffix=".yaml", delete=False) as f:
            path = f.name
        try:
            to_yaml(data, output_path=path)
            with open(path) as f:
                parsed = yaml.safe_load(f)
            assert parsed == data
        finally:
            os.unlink(path)


# =============================================================================
# RED/GREEN PHASE 8: End-to-end integration and edge cases
# =============================================================================

class TestEndToEnd:
    """Integration tests: parse -> coerce -> validate -> output."""

    def test_full_pipeline_basic(self):
        """Parse basic.ini, coerce types, validate, and convert to JSON + YAML."""
        import yaml
        from config_migrator import parse_ini, coerce_types, validate_schema, to_json, to_yaml

        raw = parse_ini(fixture_path("basic.ini"))
        data = coerce_types(raw)
        schema = json.load(open(fixture_path("schema.json")))
        errors = validate_schema(data, schema)
        assert errors == []

        # JSON round-trip
        json_str = to_json(data)
        json_data = json.loads(json_str)
        assert json_data["server"]["port"] == 8080
        assert json_data["server"]["debug"] is True
        assert json_data["database"]["ssl_enabled"] is False

        # YAML round-trip
        yaml_str = to_yaml(data)
        yaml_data = yaml.safe_load(yaml_str)
        assert yaml_data["server"]["port"] == 8080
        assert yaml_data["database"]["max_connections"] == 100

    def test_full_pipeline_with_multiline(self):
        """Multi-line values should survive the full pipeline."""
        import yaml
        from config_migrator import parse_ini, coerce_types, to_json, to_yaml

        raw = parse_ini(fixture_path("multiline.ini"))
        data = coerce_types(raw)

        # JSON round-trip preserves multi-line as a single string
        json_str = to_json(data)
        json_data = json.loads(json_str)
        assert "multi-line" in json_data["app"]["description"]

        # YAML round-trip
        yaml_str = to_yaml(data)
        yaml_data = yaml.safe_load(yaml_str)
        assert "multi-line" in yaml_data["app"]["description"]


class TestEdgeCases:
    """Test various edge cases and error conditions."""

    def test_parse_string_input(self):
        """parse_ini should accept a string content via parse_ini_string."""
        from config_migrator import parse_ini_string
        content = "[section]\nkey = value\n"
        result = parse_ini_string(content)
        assert result["section"]["key"] == "value"

    def test_parse_ini_string_empty(self):
        from config_migrator import parse_ini_string
        result = parse_ini_string("")
        assert result == {}

    def test_parse_ini_string_comments_only(self):
        from config_migrator import parse_ini_string
        result = parse_ini_string("; just a comment\n# another\n")
        assert result == {}

    def test_key_without_section_raises_error(self):
        """A key-value pair before any section header is an error."""
        from config_migrator import parse_ini_string, ConfigParseError
        with pytest.raises(ConfigParseError, match="outside.*section"):
            parse_ini_string("orphan_key = value\n")

    def test_duplicate_keys_last_wins(self):
        """If the same key appears twice in a section, last value wins."""
        from config_migrator import parse_ini_string
        content = "[s]\nk = first\nk = second\n"
        result = parse_ini_string(content)
        assert result["s"]["k"] == "second"

    def test_duplicate_sections_are_merged(self):
        """If the same section appears twice, keys are merged."""
        from config_migrator import parse_ini_string
        content = "[s]\na = 1\n[s]\nb = 2\n"
        result = parse_ini_string(content)
        assert result["s"]["a"] == "1"
        assert result["s"]["b"] == "2"

    def test_inline_comments_stripped(self):
        """Inline comments after values (with ; or #) should be stripped."""
        from config_migrator import parse_ini_string
        content = "[s]\nkey = value ; this is a comment\n"
        result = parse_ini_string(content)
        assert result["s"]["key"] == "value"

    def test_quoted_values_preserve_inline_comment_chars(self):
        """Values in quotes should preserve ; and # characters."""
        from config_migrator import parse_ini_string
        content = '[s]\nkey = "value ; not a comment"\n'
        result = parse_ini_string(content)
        assert result["s"]["key"] == "value ; not a comment"

    def test_coerce_types_returns_new_dict(self):
        """coerce_types should not modify the input dict."""
        from config_migrator import coerce_types
        original = {"s": {"k": "42"}}
        result = coerce_types(original)
        assert original["s"]["k"] == "42"
        assert result["s"]["k"] == 42

    def test_validate_schema_empty_schema(self):
        """An empty schema should pass for any config."""
        from config_migrator import validate_schema
        errors = validate_schema({"any": {"key": "val"}}, {})
        assert errors == []
