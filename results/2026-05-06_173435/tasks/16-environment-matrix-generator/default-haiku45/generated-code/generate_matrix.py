#!/usr/bin/env python3
"""CLI for generating GitHub Actions build matrix from configuration."""
import argparse
import json
import sys
from pathlib import Path

from matrix_generator import MatrixConfig, MatrixGenerator, MatrixValidationError


def main():
    """Parse arguments and generate matrix."""
    parser = argparse.ArgumentParser(
        description="Generate GitHub Actions build matrix from configuration"
    )
    parser.add_argument(
        "--config",
        type=str,
        required=True,
        help="Path to JSON configuration file",
    )
    parser.add_argument(
        "--output",
        type=str,
        help="Path to output JSON file (default: stdout)",
    )

    args = parser.parse_args()

    try:
        # Load config from file
        config_path = Path(args.config)
        if not config_path.exists():
            print(f"Error: Config file not found: {config_path}", file=sys.stderr)
            return 1

        with open(config_path) as f:
            config_data = json.load(f)

        # Create config object
        config = MatrixConfig(**config_data)

        # Generate matrix
        generator = MatrixGenerator(config)
        matrix = generator.generate()

        # Output result
        output_json = json.dumps(matrix, indent=2)

        if args.output:
            output_path = Path(args.output)
            output_path.parent.mkdir(parents=True, exist_ok=True)
            with open(output_path, "w") as f:
                f.write(output_json)
                f.write("\n")
            print(f"Matrix written to {output_path}")
        else:
            print(output_json)

        return 0

    except MatrixValidationError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in config file: {e}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
