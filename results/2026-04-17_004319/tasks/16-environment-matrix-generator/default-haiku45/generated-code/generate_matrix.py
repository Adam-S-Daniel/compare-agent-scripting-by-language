#!/usr/bin/env python3
"""CLI for generating GitHub Actions build matrices.

Usage:
    python3 generate_matrix.py config.json
    python3 generate_matrix.py config.json --output matrix.json
"""
import argparse
import json
import sys
from pathlib import Path

from matrix_generator import MatrixConfig, MatrixGenerator, MatrixValidationError


def load_config(config_path: str) -> dict:
    """Load configuration from JSON file.

    Args:
        config_path: Path to configuration JSON file.

    Returns:
        Configuration dictionary.

    Raises:
        FileNotFoundError: If configuration file doesn't exist.
        json.JSONDecodeError: If JSON is invalid.
    """
    path = Path(config_path)
    if not path.exists():
        raise FileNotFoundError(f"Configuration file not found: {config_path}")

    with open(path) as f:
        return json.load(f)


def create_config_from_dict(data: dict) -> MatrixConfig:
    """Create MatrixConfig from dictionary.

    Args:
        data: Configuration dictionary.

    Returns:
        MatrixConfig instance.

    Raises:
        KeyError: If required fields are missing.
        TypeError: If field types are invalid.
    """
    return MatrixConfig(
        os_versions=data.get("os_versions", []),
        language_versions=data.get("language_versions", []),
        feature_flags=data.get("feature_flags", []),
        include=data.get("include", []),
        exclude=data.get("exclude", []),
        max_parallel=data.get("max_parallel"),
        fail_fast=data.get("fail_fast", True),
        max_size=data.get("max_size", 256),
    )


def main() -> int:
    """Main entry point.

    Returns:
        Exit code (0 for success, 1 for error).
    """
    parser = argparse.ArgumentParser(
        description="Generate GitHub Actions build matrix from configuration"
    )
    parser.add_argument(
        "config",
        help="Path to configuration JSON file",
    )
    parser.add_argument(
        "--output",
        "-o",
        help="Output file for matrix JSON (default: print to stdout)",
    )

    args = parser.parse_args()

    try:
        config_dict = load_config(args.config)
        config = create_config_from_dict(config_dict)
        generator = MatrixGenerator(config)
        matrix_json = generator.to_json()

        if args.output:
            output_path = Path(args.output)
            output_path.write_text(matrix_json)
            print(f"Matrix written to {args.output}")
        else:
            print(matrix_json)

        return 0

    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in configuration: {e}", file=sys.stderr)
        return 1
    except (KeyError, TypeError) as e:
        print(f"Error: Invalid configuration: {e}", file=sys.stderr)
        return 1
    except MatrixValidationError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
