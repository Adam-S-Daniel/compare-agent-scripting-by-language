"""
Config File Migrator
====================
Reads INI configuration files, validates them against a schema,
performs type coercion, and outputs JSON and YAML equivalents.

Design decisions:
- Uses stdlib only: configparser (INI), json, io — no external deps.
- Custom YAML serialiser handles the subset needed for config files.
- Type coercion: empty string → None, integers, floats, booleans.
- Multi-line values: handled by configparser's built-in continuation
  line support (lines indented with whitespace continue the previous value).
"""

import configparser
import json
import io
import os
from typing import Any


# ---------------------------------------------------------------------------
# Public exception
# ---------------------------------------------------------------------------

class ConfigValidationError(Exception):
    """Raised when a config dict fails schema validation."""


# ---------------------------------------------------------------------------
# 1. INI Parsing
# ---------------------------------------------------------------------------

def parse_ini(source: str, *, from_file: bool = False) -> dict:
    """
    Parse an INI-format source into a plain dict of dicts.

    Args:
        source:    INI content string, OR a file path (when from_file=True).
        from_file: If True, treat source as a filesystem path.

    Returns:
        {section_name: {key: value_string, ...}, ...}
        All values are raw strings at this stage; call coerce_types() after.

    Multi-line values:
        configparser supports continuation lines natively: any line that
        starts with whitespace is appended to the previous key's value.

    Comments:
        Both '#' and ';' line-comment styles are stripped by configparser.
    """
    parser = configparser.RawConfigParser(
        # Allow empty values (key with no '=') — treat as empty string
        allow_no_value=False,
        # Keep original key casing; by default configparser lower-cases keys
        # We preserve case so round-trips are faithful.
        strict=True,
    )
    # configparser lower-cases option names by default; disable that:
    parser.optionxform = str  # identity → preserve original casing

    if from_file:
        parser.read(source, encoding="utf-8")
    else:
        if not source or not source.strip():
            return {}
        parser.read_file(io.StringIO(source))

    result: dict = {}
    for section in parser.sections():
        result[section] = {}
        for key, value in parser.items(section):
            # Continuation lines are already merged by configparser;
            # strip leading/trailing whitespace from each logical line.
            if value is None:
                value = ""
            result[section][key] = value.strip()

    return result


# ---------------------------------------------------------------------------
# 2. Type Coercion
# ---------------------------------------------------------------------------

# Strings that map to boolean True / False
_BOOL_TRUE  = {"true", "yes", "on", "1"}
_BOOL_FALSE = {"false", "no", "off", "0"}


def _coerce_value(value: str) -> Any:
    """
    Convert a single string value to its most appropriate Python type.

    Precedence:
      1. Empty string → None
      2. Known boolean literals → bool
      3. Integer literal → int
      4. Floating-point literal → float
      5. Anything else → str (unchanged)

    Version strings like '1.2.3' remain as str because they cannot be
    parsed as a single number.
    """
    if value == "":
        return None

    lower = value.lower()

    if lower in _BOOL_TRUE:
        return True
    if lower in _BOOL_FALSE:
        return False

    # Try integer first (no decimal point, no exponent)
    try:
        return int(value)
    except ValueError:
        pass

    # Try float
    try:
        return float(value)
    except ValueError:
        pass

    # Keep as string
    return value


def coerce_types(config: dict) -> dict:
    """
    Return a new config dict with all string values coerced to native types.

    Does not mutate the input.
    """
    return {
        section: {key: _coerce_value(val) for key, val in keys.items()}
        for section, keys in config.items()
    }


# ---------------------------------------------------------------------------
# 3. Schema Validation
# ---------------------------------------------------------------------------

def validate_config(config: dict, schema: dict) -> None:
    """
    Validate config against schema.  Raises ConfigValidationError on failure.

    Schema format::

        {
            "section_name": {
                "required": ["key1", "key2"],   # keys that MUST be present
                "types":    {"key1": int, ...},  # expected Python types
            },
            ...
        }

    Rules:
    - Every section listed in the schema must be present in config.
    - Every key in 'required' must be present in the section.
    - Every key in 'types' must have the correct Python type if present.
    - Extra sections/keys not in the schema are silently ignored.
    """
    for section, rules in schema.items():
        if section not in config:
            raise ConfigValidationError(
                f"Missing required section: [{section}]"
            )

        section_data = config[section]

        for key in rules.get("required", []):
            if key not in section_data:
                raise ConfigValidationError(
                    f"Missing required key '{key}' in section [{section}]"
                )

        for key, expected_type in rules.get("types", {}).items():
            if key not in section_data:
                continue  # optional key not present — OK
            actual = section_data[key]
            # bool is a subclass of int in Python, so check bool explicitly
            if expected_type is int and isinstance(actual, bool):
                raise ConfigValidationError(
                    f"Key '{key}' in [{section}] expected {expected_type.__name__}, "
                    f"got bool"
                )
            if not isinstance(actual, expected_type):
                raise ConfigValidationError(
                    f"Key '{key}' in [{section}] expected {expected_type.__name__}, "
                    f"got {type(actual).__name__} ({actual!r})"
                )


# ---------------------------------------------------------------------------
# 4. JSON Output
# ---------------------------------------------------------------------------

def to_json(config: dict, indent: int = 2) -> str:
    """
    Serialise config dict to a pretty-printed JSON string.

    Multi-line string values are included verbatim (JSON escapes newlines).
    All native Python types (int, float, bool, None) are preserved.
    """
    return json.dumps(config, indent=indent, ensure_ascii=False)


# ---------------------------------------------------------------------------
# 5. YAML Output (stdlib-only serialiser)
# ---------------------------------------------------------------------------

def _yaml_scalar(value: Any, indent: int) -> str:
    """
    Render a Python scalar (not a dict) as a YAML value string.

    - None    → 'null'
    - True    → 'true'  (lowercase, per YAML 1.1/1.2 spec)
    - False   → 'false'
    - int/float → unquoted number
    - str with newlines → block scalar (literal '|')
    - str without newlines → bare value (quoting if necessary)
    """
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    # String
    text = str(value)
    if "\n" in text:
        # Use YAML literal block scalar: lines indented by (indent+2)
        block_indent = " " * (indent + 2)
        body = "\n".join(block_indent + line for line in text.split("\n"))
        return "|\n" + body
    # Bare string — quote if it looks like a YAML special value or is empty
    _yaml_specials = {
        "true", "false", "null", "yes", "no", "on", "off", "~",
        "True", "False", "Null", "Yes", "No", "On", "Off",
    }
    needs_quoting = (
        not text
        or text.lower() in {s.lower() for s in _yaml_specials}
        or text[0] in "#&*!|>'\"%@`"
        or ":" in text
    )
    if needs_quoting:
        # Use double-quoted scalar with escaped special chars
        escaped = text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
        return f'"{escaped}"'
    return text


def _yaml_dict(data: dict, indent: int) -> list:
    """Recursively render a dict as YAML lines."""
    lines = []
    prefix = " " * indent
    for key, value in data.items():
        if isinstance(value, dict):
            lines.append(f"{prefix}{key}:")
            lines.extend(_yaml_dict(value, indent + 2))
        else:
            scalar = _yaml_scalar(value, indent)
            if scalar.startswith("|\n"):
                # Block scalar — key on its own line, then the block
                lines.append(f"{prefix}{key}: {scalar}")
            else:
                lines.append(f"{prefix}{key}: {scalar}")
    return lines


def to_yaml(config: dict) -> str:
    """
    Serialise config dict to a YAML string (stdlib-only implementation).

    Top-level keys (sections) map to YAML mapping keys.
    Nested values are indented two spaces per level.
    """
    lines: list = []
    for section, section_data in config.items():
        lines.append(f"{section}:")
        lines.extend(_yaml_dict(section_data, indent=2))
        lines.append("")  # blank line between sections
    return "\n".join(lines).rstrip() + "\n"


# ---------------------------------------------------------------------------
# 6. Top-Level Pipeline
# ---------------------------------------------------------------------------

def migrate_config(
    source: str,
    schema: dict,
    *,
    from_file: bool = False,
    json_output_path: str | None = None,
    yaml_output_path: str | None = None,
) -> dict:
    """
    Full pipeline: parse → coerce → validate → serialise.

    Args:
        source:           INI content string or file path.
        schema:           Validation schema (see validate_config()).
        from_file:        If True, source is a filesystem path.
        json_output_path: Optional path to write the JSON output.
        yaml_output_path: Optional path to write the YAML output.

    Returns:
        {"json": "<json string>", "yaml": "<yaml string>"}

    Raises:
        ConfigValidationError: if the config fails schema validation.
        FileNotFoundError:     if from_file=True and the path doesn't exist.
    """
    # Step 1: Parse
    raw = parse_ini(source, from_file=from_file)

    # Step 2: Coerce all string values to native Python types
    config = coerce_types(raw)

    # Step 3: Validate against schema
    validate_config(config, schema)

    # Step 4: Serialise
    json_str = to_json(config)
    yaml_str = to_yaml(config)

    # Step 5: Optionally write to files
    if json_output_path:
        os.makedirs(os.path.dirname(os.path.abspath(json_output_path)), exist_ok=True)
        with open(json_output_path, "w", encoding="utf-8") as f:
            f.write(json_str)

    if yaml_output_path:
        os.makedirs(os.path.dirname(os.path.abspath(yaml_output_path)), exist_ok=True)
        with open(yaml_output_path, "w", encoding="utf-8") as f:
            f.write(yaml_str)

    return {"json": json_str, "yaml": yaml_str}


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import sys
    import argparse

    parser = argparse.ArgumentParser(
        description="Migrate an INI config to JSON and/or YAML."
    )
    parser.add_argument("ini_file", help="Path to the INI configuration file.")
    parser.add_argument("--json-out", help="Path to write the JSON output.")
    parser.add_argument("--yaml-out", help="Path to write the YAML output.")
    args = parser.parse_args()

    # No schema validation in CLI mode — user-facing migration tool
    try:
        result = migrate_config(
            args.ini_file,
            schema={},
            from_file=True,
            json_output_path=args.json_out,
            yaml_output_path=args.yaml_out,
        )
        if not args.json_out and not args.yaml_out:
            print("=== JSON ===")
            print(result["json"])
            print("\n=== YAML ===")
            print(result["yaml"])
    except ConfigValidationError as e:
        print(f"Validation error: {e}", file=sys.stderr)
        sys.exit(1)
    except FileNotFoundError as e:
        print(f"File not found: {e}", file=sys.stderr)
        sys.exit(1)
