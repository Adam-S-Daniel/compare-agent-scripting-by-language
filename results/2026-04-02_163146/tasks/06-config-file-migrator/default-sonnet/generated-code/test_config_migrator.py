"""
Config File Migrator - TDD Test Suite
======================================
Red/Green TDD approach:
  1. Write a failing test
  2. Write minimum code to pass
  3. Refactor
  4. Repeat

Tests cover: INI parsing, schema validation, type coercion,
JSON/YAML output, edge cases (comments, multi-line values, etc.)
"""

import unittest
import json
import os
import tempfile
import textwrap

# The module under test — does not exist yet (RED phase)
from config_migrator import (
    parse_ini,
    validate_config,
    coerce_types,
    to_json,
    to_yaml,
    migrate_config,
    ConfigValidationError,
)


# ---------------------------------------------------------------------------
# Fixtures: reusable INI content strings
# ---------------------------------------------------------------------------

BASIC_INI = textwrap.dedent("""\
    [database]
    host = localhost
    port = 5432
    name = mydb
    ssl = true

    [server]
    host = 0.0.0.0
    port = 8080
    debug = false
    workers = 4
""")

INI_WITH_COMMENTS = textwrap.dedent("""\
    # Top-level comment
    ; Another comment style

    [app]
    # Inline meaning: the app name
    name = MyApp
    version = 1.2.3
""")

INI_WITH_MULTILINE = textwrap.dedent("""\
    [logging]
    message = This is a very long
        message that spans
        multiple lines
    level = info
""")

INI_MISSING_REQUIRED = textwrap.dedent("""\
    [database]
    host = localhost
""")

INI_WRONG_TYPE = textwrap.dedent("""\
    [database]
    host = localhost
    port = not_a_number
""")

INI_ALL_TYPES = textwrap.dedent("""\
    [types]
    str_val = hello
    int_val = 42
    float_val = 3.14
    bool_true = true
    bool_false = false
    bool_yes = yes
    bool_no = no
    bool_on = on
    bool_off = off
    none_val =
""")

# ---------------------------------------------------------------------------
# 1. INI Parsing Tests
# ---------------------------------------------------------------------------

class TestParseIni(unittest.TestCase):
    """Tests for parse_ini() — reads INI content and returns a plain dict."""

    def test_parse_basic_sections(self):
        """Basic INI with two sections is parsed into a dict of dicts."""
        result = parse_ini(BASIC_INI)
        self.assertIn("database", result)
        self.assertIn("server", result)

    def test_parse_key_values(self):
        """Keys and values within a section are correct strings."""
        result = parse_ini(BASIC_INI)
        self.assertEqual(result["database"]["host"], "localhost")
        self.assertEqual(result["database"]["port"], "5432")

    def test_parse_ignores_comments(self):
        """Comment lines (# and ;) are not included in the result."""
        result = parse_ini(INI_WITH_COMMENTS)
        self.assertIn("app", result)
        # Comments must not appear as keys
        self.assertNotIn("#", str(result.keys()))
        self.assertNotIn(";", str(result.keys()))

    def test_parse_multiline_values(self):
        """Multi-line values (continuation lines) are joined with newlines."""
        result = parse_ini(INI_WITH_MULTILINE)
        msg = result["logging"]["message"]
        # The continuation lines should be part of the value
        self.assertIn("multiple lines", msg)
        self.assertIn("spans", msg)

    def test_parse_from_file(self):
        """parse_ini can also accept a file path string."""
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".ini", delete=False
        ) as f:
            f.write(BASIC_INI)
            path = f.name
        try:
            result = parse_ini(path, from_file=True)
            self.assertIn("database", result)
        finally:
            os.unlink(path)

    def test_parse_empty_value(self):
        """Empty values are represented as empty strings."""
        result = parse_ini(INI_ALL_TYPES)
        self.assertEqual(result["types"]["none_val"], "")

    def test_parse_preserves_all_keys(self):
        """Every key in every section is present in the output."""
        result = parse_ini(BASIC_INI)
        self.assertEqual(
            set(result["database"].keys()),
            {"host", "port", "name", "ssl"},
        )


# ---------------------------------------------------------------------------
# 2. Type Coercion Tests
# ---------------------------------------------------------------------------

class TestCoerceTypes(unittest.TestCase):
    """Tests for coerce_types() — converts string values to native types."""

    def setUp(self):
        self.raw = parse_ini(INI_ALL_TYPES)

    def test_coerce_integer(self):
        result = coerce_types(self.raw)
        self.assertIsInstance(result["types"]["int_val"], int)
        self.assertEqual(result["types"]["int_val"], 42)

    def test_coerce_float(self):
        result = coerce_types(self.raw)
        self.assertIsInstance(result["types"]["float_val"], float)
        self.assertAlmostEqual(result["types"]["float_val"], 3.14)

    def test_coerce_bool_true_variants(self):
        result = coerce_types(self.raw)
        self.assertIs(result["types"]["bool_true"], True)
        self.assertIs(result["types"]["bool_yes"], True)
        self.assertIs(result["types"]["bool_on"], True)

    def test_coerce_bool_false_variants(self):
        result = coerce_types(self.raw)
        self.assertIs(result["types"]["bool_false"], False)
        self.assertIs(result["types"]["bool_no"], False)
        self.assertIs(result["types"]["bool_off"], False)

    def test_coerce_none_for_empty(self):
        result = coerce_types(self.raw)
        self.assertIsNone(result["types"]["none_val"])

    def test_coerce_string_unchanged(self):
        result = coerce_types(self.raw)
        self.assertEqual(result["types"]["str_val"], "hello")

    def test_coerce_preserves_sections(self):
        result = coerce_types(self.raw)
        self.assertIn("types", result)


# ---------------------------------------------------------------------------
# 3. Schema Validation Tests
# ---------------------------------------------------------------------------

class TestValidateConfig(unittest.TestCase):
    """Tests for validate_config() — checks required keys and value types."""

    SCHEMA = {
        "database": {
            "required": ["host", "port"],
            "types": {"port": int, "ssl": bool},
        }
    }

    def test_valid_config_passes(self):
        """A config matching the schema raises no error."""
        config = {
            "database": {"host": "localhost", "port": 5432, "ssl": True}
        }
        # Should not raise
        validate_config(config, self.SCHEMA)

    def test_missing_required_key_raises(self):
        """Missing required key raises ConfigValidationError."""
        config = {"database": {"host": "localhost"}}  # missing 'port'
        with self.assertRaises(ConfigValidationError) as ctx:
            validate_config(config, self.SCHEMA)
        self.assertIn("port", str(ctx.exception))

    def test_missing_required_section_raises(self):
        """Missing required section raises ConfigValidationError."""
        config = {"server": {"host": "0.0.0.0"}}  # missing 'database'
        with self.assertRaises(ConfigValidationError) as ctx:
            validate_config(config, self.SCHEMA)
        self.assertIn("database", str(ctx.exception))

    def test_wrong_type_raises(self):
        """Value with wrong native type raises ConfigValidationError."""
        config = {
            "database": {"host": "localhost", "port": "not_a_number", "ssl": True}
        }
        with self.assertRaises(ConfigValidationError) as ctx:
            validate_config(config, self.SCHEMA)
        self.assertIn("port", str(ctx.exception))

    def test_extra_keys_allowed(self):
        """Extra keys beyond the schema are silently allowed."""
        config = {
            "database": {
                "host": "localhost",
                "port": 5432,
                "extra_key": "whatever",
            }
        }
        # Should not raise
        validate_config(config, self.SCHEMA)

    def test_validation_error_message_is_meaningful(self):
        """Error message mentions both section and key."""
        config = {"database": {"host": "localhost"}}
        with self.assertRaises(ConfigValidationError) as ctx:
            validate_config(config, self.SCHEMA)
        msg = str(ctx.exception)
        self.assertIn("database", msg)


# ---------------------------------------------------------------------------
# 4. JSON Output Tests
# ---------------------------------------------------------------------------

class TestToJson(unittest.TestCase):
    """Tests for to_json() — serialises the config dict to a JSON string."""

    def test_json_is_valid(self):
        """Output is valid JSON that can be re-parsed."""
        config = {"database": {"host": "localhost", "port": 5432}}
        output = to_json(config)
        parsed = json.loads(output)
        self.assertEqual(parsed["database"]["port"], 5432)

    def test_json_is_pretty_printed(self):
        """Output is indented (pretty-printed) for readability."""
        config = {"database": {"host": "localhost"}}
        output = to_json(config)
        self.assertIn("\n", output)

    def test_json_preserves_types(self):
        """Native int/float/bool/None survive the round-trip."""
        config = {"s": {"i": 1, "f": 1.5, "b": True, "n": None}}
        output = to_json(config)
        parsed = json.loads(output)
        self.assertIsInstance(parsed["s"]["i"], int)
        self.assertIsInstance(parsed["s"]["f"], float)
        self.assertIsInstance(parsed["s"]["b"], bool)
        self.assertIsNone(parsed["s"]["n"])

    def test_json_handles_multiline_string(self):
        """Multi-line string values are serialised correctly."""
        config = {"logging": {"msg": "line1\nline2\nline3"}}
        output = to_json(config)
        parsed = json.loads(output)
        self.assertIn("\n", parsed["logging"]["msg"])


# ---------------------------------------------------------------------------
# 5. YAML Output Tests
# ---------------------------------------------------------------------------

class TestToYaml(unittest.TestCase):
    """Tests for to_yaml() — serialises the config dict to a YAML string."""

    def test_yaml_contains_section_key(self):
        """Section names appear as top-level YAML keys."""
        config = {"database": {"host": "localhost", "port": 5432}}
        output = to_yaml(config)
        self.assertIn("database:", output)

    def test_yaml_contains_values(self):
        """Key-value pairs appear in the YAML output."""
        config = {"database": {"host": "localhost", "port": 5432}}
        output = to_yaml(config)
        self.assertIn("host: localhost", output)

    def test_yaml_bool_representation(self):
        """Booleans are written as 'true'/'false' (lowercase YAML standard)."""
        config = {"app": {"debug": True, "verbose": False}}
        output = to_yaml(config)
        self.assertIn("true", output.lower())
        self.assertIn("false", output.lower())

    def test_yaml_null_representation(self):
        """None values are written as 'null' in YAML."""
        config = {"app": {"val": None}}
        output = to_yaml(config)
        self.assertIn("null", output)

    def test_yaml_integer_representation(self):
        """Integers are written without quotes."""
        config = {"server": {"port": 8080}}
        output = to_yaml(config)
        self.assertIn("port: 8080", output)

    def test_yaml_multiline_string(self):
        """Multi-line strings are handled (block scalar or quoted)."""
        config = {"logging": {"msg": "line1\nline2"}}
        output = to_yaml(config)
        # Must contain the text content somewhere
        self.assertIn("line1", output)
        self.assertIn("line2", output)


# ---------------------------------------------------------------------------
# 6. End-to-End / Integration Tests
# ---------------------------------------------------------------------------

class TestMigrateConfig(unittest.TestCase):
    """Tests for migrate_config() — the top-level pipeline function."""

    SCHEMA = {
        "database": {
            "required": ["host", "port"],
            "types": {"port": int},
        },
        "server": {
            "required": ["host", "port"],
            "types": {"port": int, "workers": int},
        },
    }

    def test_migrate_returns_both_formats(self):
        """migrate_config returns a dict with 'json' and 'yaml' keys."""
        result = migrate_config(BASIC_INI, self.SCHEMA)
        self.assertIn("json", result)
        self.assertIn("yaml", result)

    def test_migrate_json_is_valid(self):
        """JSON output from full migration is valid and has correct values."""
        result = migrate_config(BASIC_INI, self.SCHEMA)
        parsed = json.loads(result["json"])
        self.assertEqual(parsed["database"]["host"], "localhost")
        self.assertEqual(parsed["database"]["port"], 5432)  # coerced to int
        self.assertIsInstance(parsed["database"]["port"], int)

    def test_migrate_yaml_contains_sections(self):
        """YAML output from full migration contains section headers."""
        result = migrate_config(BASIC_INI, self.SCHEMA)
        self.assertIn("database:", result["yaml"])
        self.assertIn("server:", result["yaml"])

    def test_migrate_raises_on_invalid_config(self):
        """Migration raises ConfigValidationError for invalid configs."""
        with self.assertRaises(ConfigValidationError):
            migrate_config(INI_MISSING_REQUIRED, self.SCHEMA)

    def test_migrate_to_files(self):
        """migrate_config can write output to JSON and YAML files."""
        with tempfile.TemporaryDirectory() as tmpdir:
            json_path = os.path.join(tmpdir, "config.json")
            yaml_path = os.path.join(tmpdir, "config.yaml")
            migrate_config(
                BASIC_INI,
                self.SCHEMA,
                json_output_path=json_path,
                yaml_output_path=yaml_path,
            )
            self.assertTrue(os.path.exists(json_path))
            self.assertTrue(os.path.exists(yaml_path))
            with open(json_path) as f:
                data = json.load(f)
            self.assertIn("database", data)


# ---------------------------------------------------------------------------
# 7. Edge-Case Tests
# ---------------------------------------------------------------------------

class TestEdgeCases(unittest.TestCase):
    """Tests for tricky INI edge cases."""

    def test_empty_ini(self):
        """An empty INI string parses to an empty dict (no sections)."""
        result = parse_ini("")
        self.assertEqual(result, {})

    def test_ini_with_only_comments(self):
        """An INI with only comments parses to an empty dict."""
        result = parse_ini("# just a comment\n; another comment\n")
        self.assertEqual(result, {})

    def test_version_string_stays_string(self):
        """Version strings like '1.2.3' are not mangled into a number."""
        result = parse_ini(INI_WITH_COMMENTS)
        coerced = coerce_types(result)
        self.assertEqual(coerced["app"]["version"], "1.2.3")

    def test_port_coerced_across_sections(self):
        """Port values in multiple sections are each coerced to int."""
        result = parse_ini(BASIC_INI)
        coerced = coerce_types(result)
        self.assertIsInstance(coerced["database"]["port"], int)
        self.assertIsInstance(coerced["server"]["port"], int)

    def test_bool_ssl_coerced(self):
        """'true'/'false' strings become Python booleans."""
        result = parse_ini(BASIC_INI)
        coerced = coerce_types(result)
        self.assertIs(coerced["database"]["ssl"], True)
        self.assertIs(coerced["server"]["debug"], False)

    def test_parse_ini_with_equals_in_value(self):
        """Values containing '=' characters are handled correctly."""
        ini = "[app]\nconnection = user=admin;pass=secret\n"
        result = parse_ini(ini)
        self.assertIn("=", result["app"]["connection"])

    def test_parse_ini_with_spaces_around_equals(self):
        """Spaces around '=' delimiter are stripped (no leading whitespace on key)."""
        # Note: a line starting with whitespace is a continuation line in INI format.
        # Here the key has trailing spaces and the value has surrounding spaces.
        ini = "[app]\nkey1  =  value1  \n"
        result = parse_ini(ini)
        self.assertEqual(result["app"]["key1"], "value1")


if __name__ == "__main__":
    unittest.main(verbosity=2)
