"""Config file migrator: INI → JSON/YAML with schema validation and type coercion.

Parses INI files (sections, comments, multi-line values, quoted values,
inline comments), validates against a schema (required keys, types),
coerces values, and outputs JSON or YAML.
"""

import json
import os
import re
from collections import OrderedDict

import yaml


class MigrationError(Exception):
    """Raised for any config migration failure (missing file, validation, etc.)."""
    pass


# ── Parsing ───────────────────────────────────────────────────────────────────

def parse_ini(path: str) -> dict:
    """Parse an INI file into a nested dict of {section: {key: raw_string_value}}.

    Handles:
      - Sections in [brackets]
      - Comments: lines starting with ; or #
      - Inline comments: text after unquoted ; or #
      - Continuation lines (leading whitespace = multi-line value)
      - Key = value and key : value delimiters
      - Quoted values (surrounding single/double quotes stripped)
      - Whitespace trimming around keys and values
    """
    if not os.path.isfile(path):
        raise MigrationError(f"Config file not found: {path}")

    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    config: dict[str, dict[str, str]] = OrderedDict()
    current_section = None
    current_key = None

    for line in lines:
        raw = line.rstrip("\n\r")

        # Blank line — ends any multi-line continuation
        if raw.strip() == "":
            current_key = None
            continue

        # Full-line comments
        stripped = raw.strip()
        if stripped.startswith(";") or stripped.startswith("#"):
            current_key = None
            continue

        # Continuation line: starts with whitespace while we have an active key,
        # but only if it doesn't look like a key=value or key:value pair itself
        if current_key and raw[0] in (" ", "\t"):
            if not re.match(r"^\s*[^=:]+\s*[=:]\s*", raw):
                cont_value = raw.strip()
                config[current_section][current_key] += "\n" + cont_value
                continue

        # Section header
        m = re.match(r"^\s*\[([^\]]+)\]\s*$", raw)
        if m:
            current_section = m.group(1).strip()
            if current_section not in config:
                config[current_section] = OrderedDict()
            current_key = None
            continue

        # Key-value pair (= or : as delimiter)
        m = re.match(r"^\s*([^=:]+?)\s*[=:]\s*(.*?)\s*$", raw)
        if m and current_section is not None:
            key = m.group(1).strip()
            value = m.group(2).strip()

            # Strip inline comments — but only if the ; or # is not inside quotes
            value = _strip_inline_comment(value)

            # Strip surrounding quotes
            value = _strip_quotes(value)

            config[current_section][key] = value
            current_key = key
            continue

        # Unrecognized line — skip silently
        current_key = None

    return dict(config)


def _strip_inline_comment(value: str) -> str:
    """Remove inline comments (; or #) that are not inside quotes."""
    in_single = False
    in_double = False
    for i, ch in enumerate(value):
        if ch == "'" and not in_double:
            in_single = not in_single
        elif ch == '"' and not in_single:
            in_double = not in_double
        elif ch in (";", "#") and not in_single and not in_double:
            # Check there's a space before the comment char (standard INI convention)
            if i > 0 and value[i - 1] == " ":
                return value[:i].rstrip()
    return value


def _strip_quotes(value: str) -> str:
    """Strip matching surrounding single or double quotes from a value."""
    if len(value) >= 2:
        if (value[0] == "'" and value[-1] == "'") or \
           (value[0] == '"' and value[-1] == '"'):
            return value[1:-1]
    return value


# ── Validation & type coercion ────────────────────────────────────────────────

# Truthy/falsy string variants for boolean coercion
_BOOL_TRUE = {"true", "yes", "on", "1"}
_BOOL_FALSE = {"false", "no", "off", "0"}


def validate(config: dict, schema: dict | None = None) -> dict:
    """Validate config against a schema and coerce types.

    Schema format:
        {
            "section_name": {
                "key": {"type": "string"|"integer"|"float"|"boolean", "required": bool}
            }
        }

    If schema is None, auto-coerce all values (detect ints, floats, bools).
    Keys/sections not in the schema are kept with auto-coercion.
    """
    if schema is None:
        return _auto_coerce_all(config)

    result = OrderedDict()

    # First, check that all required sections exist
    for section_name, keys_schema in schema.items():
        has_any_required = any(
            spec.get("required", False) for spec in keys_schema.values()
        )
        if has_any_required and section_name not in config:
            raise MigrationError(
                f"Missing required section: [{section_name}]"
            )

    # Process each section in config
    for section_name, section_data in config.items():
        section_schema = schema.get(section_name, {})
        result[section_name] = OrderedDict()

        # Check required keys are present
        for key, spec in section_schema.items():
            if spec.get("required", False) and key not in section_data:
                raise MigrationError(
                    f"Missing required key '{key}' in [{section_name}]"
                )

        # Coerce each value
        for key, raw_value in section_data.items():
            if key in section_schema:
                expected_type = section_schema[key].get("type", "string")
                result[section_name][key] = _coerce(
                    raw_value, expected_type, section_name, key
                )
            else:
                # Key not in schema — auto-coerce
                result[section_name][key] = _auto_coerce_value(raw_value)

    return dict(result)


def _coerce(value: str, type_name: str, section: str, key: str):
    """Coerce a string value to the given type, raising MigrationError on failure."""
    if type_name == "string":
        return value

    if type_name == "integer":
        try:
            return int(value)
        except (ValueError, TypeError):
            raise MigrationError(
                f"cannot convert '{key}' in [{section}] to integer: '{value}'"
            )

    if type_name == "float":
        try:
            return float(value)
        except (ValueError, TypeError):
            raise MigrationError(
                f"cannot convert '{key}' in [{section}] to float: '{value}'"
            )

    if type_name == "boolean":
        lower = value.strip().lower()
        if lower in _BOOL_TRUE:
            return True
        if lower in _BOOL_FALSE:
            return False
        raise MigrationError(
            f"cannot convert '{key}' in [{section}] to boolean: '{value}'"
        )

    raise MigrationError(f"Unknown type '{type_name}' for '{key}' in [{section}]")


def _auto_coerce_value(value: str):
    """Best-effort coercion: try int, then float, then bool, else keep string."""
    # Integer?
    try:
        return int(value)
    except (ValueError, TypeError):
        pass

    # Float?
    try:
        return float(value)
    except (ValueError, TypeError):
        pass

    # Boolean?
    lower = value.strip().lower()
    if lower in _BOOL_TRUE:
        return True
    if lower in _BOOL_FALSE:
        return False

    return value


def _auto_coerce_all(config: dict) -> dict:
    """Auto-coerce every value in every section."""
    result = OrderedDict()
    for section, data in config.items():
        result[section] = OrderedDict()
        for key, value in data.items():
            result[section][key] = _auto_coerce_value(value)
    return dict(result)


# ── Output ────────────────────────────────────────────────────────────────────

def to_json(config: dict, indent: int = 2) -> str:
    """Serialize config dict to a pretty-printed JSON string."""
    return json.dumps(config, indent=indent, ensure_ascii=False)


def to_yaml(config: dict) -> str:
    """Serialize config dict to a YAML string.

    Uses default_flow_style=False for block-style output.
    Converts OrderedDicts to plain dicts for clean YAML output.
    """
    return yaml.dump(
        _to_plain_dict(config),
        default_flow_style=False,
        allow_unicode=True,
        sort_keys=False,
    )


def _to_plain_dict(obj):
    """Recursively convert OrderedDicts to plain dicts."""
    if isinstance(obj, dict):
        return {k: _to_plain_dict(v) for k, v in obj.items()}
    return obj


# ── CLI entry point ──────────────────────────────────────────────────────────

def main():
    """Simple CLI: config_migrator.py <input.ini> [schema.json] [--json] [--yaml]."""
    import argparse

    parser = argparse.ArgumentParser(
        description="Migrate INI config to JSON/YAML with optional schema validation."
    )
    parser.add_argument("input", help="Path to INI config file")
    parser.add_argument("--schema", help="Path to JSON schema file", default=None)
    parser.add_argument("--json", dest="output_json", action="store_true",
                        help="Output JSON to stdout")
    parser.add_argument("--yaml", dest="output_yaml", action="store_true",
                        help="Output YAML to stdout")
    parser.add_argument("--json-out", help="Write JSON to file")
    parser.add_argument("--yaml-out", help="Write YAML to file")

    args = parser.parse_args()

    # Default: output both if neither specified
    if not args.output_json and not args.output_yaml and \
       not args.json_out and not args.yaml_out:
        args.output_json = True
        args.output_yaml = True

    try:
        config = parse_ini(args.input)

        schema = None
        if args.schema:
            with open(args.schema, "r") as f:
                schema = json.load(f)

        validated = validate(config, schema)

        if args.output_json or args.json_out:
            json_str = to_json(validated)
            if args.output_json:
                print("=== JSON ===")
                print(json_str)
            if args.json_out:
                with open(args.json_out, "w") as f:
                    f.write(json_str)

        if args.output_yaml or args.yaml_out:
            yaml_str = to_yaml(validated)
            if args.output_yaml:
                print("=== YAML ===")
                print(yaml_str)
            if args.yaml_out:
                with open(args.yaml_out, "w") as f:
                    f.write(yaml_str)

    except MigrationError as e:
        print(f"Error: {e}", file=__import__("sys").stderr)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
