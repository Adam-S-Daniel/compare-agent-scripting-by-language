"""
Config File Migrator
====================

Reads INI configuration files, validates them against a JSON schema,
and outputs equivalent configurations in JSON and YAML formats.

Features:
  - Parses INI files with sections, key-value pairs, comments, multi-line values
  - Coerces string values to appropriate Python types (int, float, bool, None)
  - Validates config against a schema (required keys, expected types)
  - Outputs to JSON (pretty-printed) and YAML formats

Developed using red/green TDD: tests were written first, then this
implementation was written to make them pass.
"""

import json
import os
import re
from typing import Any, Optional

import yaml


# =============================================================================
# Custom exception for parse errors
# =============================================================================

class ConfigParseError(Exception):
    """Raised when the INI content cannot be parsed correctly."""
    pass


# =============================================================================
# INI Parsing
# =============================================================================

def parse_ini(filepath: str) -> dict[str, dict[str, str]]:
    """
    Parse an INI file from disk into a nested dict.

    Args:
        filepath: Path to the .ini file.

    Returns:
        Dict mapping section names to dicts of key-value string pairs.

    Raises:
        FileNotFoundError: If the file does not exist.
    """
    if not os.path.isfile(filepath):
        raise FileNotFoundError(f"Configuration file not found: {filepath}")

    with open(filepath, "r") as f:
        content = f.read()

    return parse_ini_string(content)


def parse_ini_string(content: str) -> dict[str, dict[str, str]]:
    """
    Parse INI-format content from a string into a nested dict.

    Handles:
      - [section] headers
      - key = value pairs (with or without spaces around =)
      - ; and # full-line comments
      - Inline comments after values (stripped unless value is quoted)
      - Multi-line values (continuation lines starting with whitespace)
      - Duplicate sections are merged; duplicate keys use last value

    Args:
        content: The INI file content as a string.

    Returns:
        Dict mapping section names to dicts of key-value string pairs.

    Raises:
        ConfigParseError: If a key-value pair appears before any section header.
    """
    result: dict[str, dict[str, str]] = {}
    current_section: Optional[str] = None
    current_key: Optional[str] = None

    # Regex patterns
    section_re = re.compile(r"^\[([^\]]+)\]\s*$")
    # Match key = value, key=value, etc.
    kv_re = re.compile(r"^([^=]+?)=(.*)$")

    for line in content.splitlines():
        # Check for full-line comments (leading ; or #, possibly indented)
        stripped = line.strip()
        if stripped == "" or stripped.startswith(";") or stripped.startswith("#"):
            continue

        # Check for continuation line (starts with whitespace, follows a key).
        # Only treat as continuation if the stripped content does NOT look
        # like a key=value pair — otherwise indented kv lines would be
        # swallowed into the previous value.
        if line[0:1] in (" ", "\t") and current_key is not None and current_section is not None:
            if not kv_re.match(stripped):
                # Append to the current multi-line value
                result[current_section][current_key] += "\n" + stripped
                continue

        # Check for section header
        m = section_re.match(stripped)
        if m:
            current_section = m.group(1).strip()
            current_key = None
            if current_section not in result:
                result[current_section] = {}
            continue

        # Check for key = value
        m = kv_re.match(stripped)
        if m:
            if current_section is None:
                raise ConfigParseError(
                    f"Key-value pair found outside of any section: '{stripped}'"
                )
            key = m.group(1).strip()
            value = m.group(2).strip()

            # Handle quoted values: preserve everything inside quotes
            value = _strip_inline_comment(value)

            current_key = key
            result[current_section][key] = value
            continue

        # If we get here, line is unparseable - skip it silently
        current_key = None

    return result


def _strip_inline_comment(value: str) -> str:
    """
    Remove inline comments from a value string.

    If the value is quoted (single or double), the quotes are removed
    and the content inside is preserved verbatim (including ; and #).
    Otherwise, everything after an unquoted ; or # is stripped.
    """
    # Check for quoted values
    if len(value) >= 2:
        if (value[0] == '"' and value[-1] == '"') or \
           (value[0] == "'" and value[-1] == "'"):
            # Return content inside quotes, stripping the quote chars
            return value[1:-1]

    # Strip inline comment: find first ; or # that's not inside quotes
    for i, ch in enumerate(value):
        if ch in (";", "#"):
            # Check it's preceded by whitespace (standard INI convention)
            if i > 0 and value[i - 1] in (" ", "\t"):
                return value[:i].rstrip()
    return value


# =============================================================================
# Type Coercion
# =============================================================================

# Boolean values recognized (case-insensitive)
_BOOL_TRUE = {"true", "yes", "on"}
_BOOL_FALSE = {"false", "no", "off"}
_NULL_VALUES = {"null", "none", ""}


def coerce_types(data: dict[str, dict[str, str]]) -> dict[str, dict[str, Any]]:
    """
    Create a new dict with string values coerced to native Python types.

    Coercion rules (applied in order):
      1. Empty string, "null", "none" -> None
      2. Boolean-like strings ("true", "false", "yes", "no", "on", "off") -> bool
      3. Integer strings (no leading zeros except for "-0") -> int
      4. Float strings -> float
      5. Everything else stays a string

    Leading-zero numbers like "007" are kept as strings to preserve
    semantics (e.g., zero-padded identifiers). IPs like "192.168.1.1"
    stay strings because they contain multiple dots.

    Args:
        data: Nested dict from parse_ini / parse_ini_string.

    Returns:
        New nested dict with coerced values. Original dict is not modified.
    """
    result = {}
    for section, kvs in data.items():
        result[section] = {}
        for key, value in kvs.items():
            result[section][key] = _coerce_value(value)
    return result


def _coerce_value(value: str) -> Any:
    """Coerce a single string value to its most appropriate Python type."""
    # Null / empty
    if value.lower() in _NULL_VALUES:
        return None

    # Boolean
    if value.lower() in _BOOL_TRUE:
        return True
    if value.lower() in _BOOL_FALSE:
        return False

    # Integer: must not have leading zeros (except "0" itself or negative like "-0")
    # This prevents "007" from being coerced to 7.
    if re.match(r"^-?(?:0|[1-9]\d*)$", value):
        return int(value)

    # Float: standard decimal notation, no leading zeros in integer part
    # Must have exactly one dot, and be a valid float.
    # This prevents "192.168.1.1" from matching.
    if re.match(r"^-?(?:0|[1-9]\d*)\.\d+$", value):
        return float(value)

    # Everything else: keep as string
    return value


# =============================================================================
# Schema Validation
# =============================================================================

# Map schema type names to Python type checks
_TYPE_CHECKS = {
    "string": lambda v: isinstance(v, str),
    "integer": lambda v: isinstance(v, int) and not isinstance(v, bool),
    "float": lambda v: isinstance(v, (int, float)) and not isinstance(v, bool),
    "number": lambda v: isinstance(v, (int, float)) and not isinstance(v, bool),
    "boolean": lambda v: isinstance(v, bool),
}


def validate_schema(
    data: dict[str, dict[str, Any]],
    schema: dict[str, Any],
) -> list[str]:
    """
    Validate config data against a schema.

    Schema format (JSON):
      {
        "section_name": {
          "required": ["key1", "key2"],
          "types": {
            "key1": "string",
            "key2": "integer",
            "key3": "boolean"
          }
        }
      }

    Supported type names: "string", "integer", "float", "number", "boolean".
    Extra keys not mentioned in the schema are allowed (open-world assumption).
    Extra sections not in the schema are also allowed.

    Args:
        data: The config data (after coercion).
        schema: The schema dict.

    Returns:
        List of error message strings. Empty list means valid.
    """
    errors = []

    for section_name, section_schema in schema.items():
        required_keys = section_schema.get("required", [])
        type_specs = section_schema.get("types", {})

        # Check if section exists
        if section_name not in data:
            errors.append(
                f"Missing required section: [{section_name}]"
            )
            # Can't check keys if section is missing
            continue

        section_data = data[section_name]

        # Check required keys
        for key in required_keys:
            if key not in section_data:
                errors.append(
                    f"[{section_name}] Missing required key: '{key}'"
                )

        # Check types for keys that exist and have a type spec
        for key, expected_type in type_specs.items():
            if key not in section_data:
                continue  # Missing keys are caught by required check
            value = section_data[key]
            if value is None:
                continue  # None is acceptable for any type (null override)
            checker = _TYPE_CHECKS.get(expected_type)
            if checker and not checker(value):
                errors.append(
                    f"[{section_name}] Key '{key}' expected type "
                    f"'{expected_type}', got {type(value).__name__}: {value!r}"
                )

    return errors


# =============================================================================
# Output: JSON
# =============================================================================

def to_json(data: dict[str, Any], output_path: Optional[str] = None) -> str:
    """
    Convert config data to a pretty-printed JSON string.

    Args:
        data: The config data dict.
        output_path: Optional file path to write the JSON to.

    Returns:
        The JSON string.
    """
    json_str = json.dumps(data, indent=4, sort_keys=False)

    if output_path:
        with open(output_path, "w") as f:
            f.write(json_str)

    return json_str


# =============================================================================
# Output: YAML
# =============================================================================

def to_yaml(data: dict[str, Any], output_path: Optional[str] = None) -> str:
    """
    Convert config data to a YAML string.

    Args:
        data: The config data dict.
        output_path: Optional file path to write the YAML to.

    Returns:
        The YAML string.
    """
    yaml_str = yaml.dump(data, default_flow_style=False, sort_keys=False)

    if output_path:
        with open(output_path, "w") as f:
            f.write(yaml_str)

    return yaml_str


# =============================================================================
# CLI entry point
# =============================================================================

def main():
    """
    Command-line interface for config file migration.

    Usage:
        python config_migrator.py <input.ini> [--schema schema.json]
                                               [--json output.json]
                                               [--yaml output.yaml]
    """
    import argparse

    parser = argparse.ArgumentParser(
        description="Migrate INI configuration files to JSON/YAML"
    )
    parser.add_argument("input", help="Path to the INI configuration file")
    parser.add_argument("--schema", help="Path to a JSON schema for validation")
    parser.add_argument("--json", dest="json_out", help="Output path for JSON")
    parser.add_argument("--yaml", dest="yaml_out", help="Output path for YAML")
    args = parser.parse_args()

    # Parse
    try:
        raw = parse_ini(args.input)
    except FileNotFoundError as e:
        print(f"Error: {e}")
        return 1
    except ConfigParseError as e:
        print(f"Parse error: {e}")
        return 1

    # Coerce types
    data = coerce_types(raw)

    # Validate against schema if provided
    if args.schema:
        try:
            with open(args.schema) as f:
                schema = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError) as e:
            print(f"Schema error: {e}")
            return 1

        errors = validate_schema(data, schema)
        if errors:
            print("Validation errors:")
            for err in errors:
                print(f"  - {err}")
            return 1
        print("Schema validation passed.")

    # Output JSON
    if args.json_out:
        to_json(data, output_path=args.json_out)
        print(f"JSON written to: {args.json_out}")
    else:
        print("\n--- JSON ---")
        print(to_json(data))

    # Output YAML
    if args.yaml_out:
        to_yaml(data, output_path=args.yaml_out)
        print(f"YAML written to: {args.yaml_out}")
    else:
        print("\n--- YAML ---")
        print(to_yaml(data))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
