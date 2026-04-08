"""
Config File Migrator
====================
Reads INI-format configuration files, validates them against a schema,
and exports to JSON and YAML.

Design notes
------------
- We roll our own INI parser instead of using configparser so that we can
  support ALL of:
    * Both comment styles (# and ;), including trailing inline comments
    * Multi-line values (continuation lines indented with whitespace)
    * Quoted string stripping
    * Automatic type coercion (int, float, bool, None for empty)
- A two-phase workflow is enforced: parse() must be called before
  validate() or any export method, giving callers explicit control.
"""

import json
import re
from typing import Any

import yaml


class ValidationError(Exception):
    """Raised when the parsed config does not satisfy the schema."""


class ConfigMigrator:
    """Parse, validate, and export INI configuration files."""

    # Boolean truthy / falsy tokens (case-insensitive).
    _TRUE_VALUES  = {"true", "yes", "on", "1"}
    _FALSE_VALUES = {"false", "no", "off", "0"}

    def __init__(self, filepath: str, schema: dict | None = None):
        self._filepath = filepath
        self._schema   = schema
        self._data: dict[str, Any] | None = None  # set after parse()

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def parse(self) -> dict:
        """
        Parse the INI file and return the data as a nested dict.

        Raises FileNotFoundError if the file does not exist.
        Sets self._data so that validate() / to_json() / to_yaml() work.
        """
        try:
            with open(self._filepath, "r", encoding="utf-8") as fh:
                lines = fh.readlines()
        except FileNotFoundError:
            raise FileNotFoundError(f"Config file not found: {self._filepath}")

        self._data = self._parse_lines(lines)
        return self._data

    def validate(self) -> None:
        """
        Validate parsed data against self._schema.

        Raises RuntimeError if parse() has not been called yet.
        Raises ValidationError on any schema violation.
        """
        self._require_parsed()
        if self._schema is None:
            return  # nothing to validate

        for section, rules in self._schema.items():
            # Check the section exists.
            if section not in self._data:
                raise ValidationError(
                    f"Config is missing section '{section}'"
                )

            section_data = self._data[section]
            required_keys = rules.get("required", [])
            type_map      = rules.get("types", {})

            # Check required keys are present.
            for key in required_keys:
                if key not in section_data:
                    raise ValidationError(
                        f"[{section}] missing required key '{key}'"
                    )

            # Check types for keys that are present.
            for key, expected_type in type_map.items():
                if key not in section_data:
                    continue  # optional key — skip
                value = section_data[key]
                if value is None:
                    continue  # empty values are always acceptable
                if not isinstance(value, expected_type):
                    raise ValidationError(
                        f"[{section}] type error for key '{key}': "
                        f"expected {expected_type.__name__}, "
                        f"got {type(value).__name__} ({value!r})"
                    )

    def to_json(self, indent: int = 2) -> str:
        """Return the configuration as a pretty-printed JSON string."""
        self._require_parsed()
        return json.dumps(self._data, indent=indent)

    def to_json_file(self, path: str, indent: int = 2) -> None:
        """Write the configuration as JSON to *path*."""
        self._require_parsed()
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(self._data, fh, indent=indent)

    def to_yaml(self) -> str:
        """Return the configuration as a YAML string."""
        self._require_parsed()
        return yaml.dump(self._data, default_flow_style=False, sort_keys=False)

    def to_yaml_file(self, path: str) -> None:
        """Write the configuration as YAML to *path*."""
        self._require_parsed()
        with open(path, "w", encoding="utf-8") as fh:
            yaml.dump(self._data, fh, default_flow_style=False, sort_keys=False)

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _require_parsed(self) -> None:
        if self._data is None:
            raise RuntimeError(
                "You must call parse() before using this method."
            )

    def _parse_lines(self, lines: list[str]) -> dict:
        """
        Core INI parser.

        Algorithm:
        1. Iterate lines; skip blank lines and comment-only lines.
        2. Detect section headers: [section_name]
        3. Accumulate key=value pairs; detect continuation lines
           (those that start with whitespace) and append to the
           previous key's value list.
        4. After collecting raw strings, coerce each value.
        """
        data: dict[str, dict] = {}
        current_section: str | None = None
        # Track the *last* key so continuation lines can extend it.
        last_key: str | None = None
        # Raw accumulator: values start as a list of strings, later
        # collapsed into a scalar or left as a list.
        raw: dict[str, dict[str, list[str]]] = {}

        for line in lines:
            # Preserve original line for continuation detection before strip.
            is_continuation = line and line[0] in (" ", "\t") and current_section and last_key

            stripped = line.strip()

            # Skip blank lines.
            if not stripped:
                last_key = None  # blank line ends continuation context
                continue

            # Skip comment-only lines.
            if stripped.startswith(("#", ";")):
                continue

            # Section header.
            m = re.match(r"^\[([^\]]+)\]", stripped)
            if m:
                current_section = m.group(1).strip()
                data[current_section] = {}
                raw[current_section] = {}
                last_key = None
                continue

            # Continuation line (starts with whitespace, not blank, not comment).
            if is_continuation and last_key and not stripped.startswith(("#", ";")):
                raw[current_section][last_key].append(stripped)
                continue

            # Key=value line — must be inside a section.
            if "=" in stripped and current_section is not None:
                key, _, raw_val = stripped.partition("=")
                key = key.strip()
                # Strip trailing inline comments from the value.
                raw_val = self._strip_inline_comment(raw_val)
                raw_val = raw_val.strip()
                raw[current_section][key] = [raw_val] if raw_val else []
                last_key = key
                continue

        # --- Post-processing: collapse raw lists → coerced values ---
        for section, kv in raw.items():
            for key, parts in kv.items():
                if not parts:
                    # Empty value (key =)
                    data[section][key] = None
                elif len(parts) == 1:
                    data[section][key] = self._coerce(parts[0])
                else:
                    # Multi-line → list; coerce each element.
                    data[section][key] = [self._coerce(p) for p in parts]

        return data

    @staticmethod
    def _strip_inline_comment(value: str) -> str:
        """
        Remove trailing inline comments (; or #) from a value string.
        We only strip after whitespace so that # or ; inside quoted strings
        are (mostly) left alone — a simple heuristic sufficient for INI files.
        """
        # Match a semicolon or hash preceded by at least one space.
        m = re.search(r"\s+[;#].*$", value)
        if m:
            return value[: m.start()]
        return value

    def _coerce(self, value: str) -> Any:
        """
        Attempt to convert a raw string value to a Python native type.

        Order of precedence:
        1. Quoted string  → strip quotes, return as str.
        2. Boolean token  → True / False.
        3. Integer        → int.
        4. Float          → float.
        5. Fallback       → str (unchanged).
        """
        # Quoted strings.
        if (value.startswith('"') and value.endswith('"')) or \
           (value.startswith("'") and value.endswith("'")):
            return value[1:-1]

        lower = value.lower()

        # Boolean coercion.
        if lower in self._TRUE_VALUES:
            return True
        if lower in self._FALSE_VALUES:
            return False

        # Integer coercion.
        try:
            return int(value)
        except ValueError:
            pass

        # Float coercion.
        try:
            return float(value)
        except ValueError:
            pass

        # Return as string.
        return value
