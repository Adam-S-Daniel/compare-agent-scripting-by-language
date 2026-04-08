"""
migrate.py — CLI entry point for Config File Migrator.

Usage:
    python migrate.py <input.ini> [--out-dir <dir>]

Outputs:
    <input_stem>.json  and  <input_stem>.yaml  in the current directory
    (or --out-dir if specified).
"""
import argparse
import os
import sys

from config_migrator import ConfigMigrator


def main():
    parser = argparse.ArgumentParser(description="Migrate an INI config to JSON and YAML.")
    parser.add_argument("ini_file", help="Path to the input INI file")
    parser.add_argument(
        "--out-dir",
        default=".",
        help="Directory to write output files (default: current directory)",
    )
    args = parser.parse_args()

    stem = os.path.splitext(os.path.basename(args.ini_file))[0]
    json_path = os.path.join(args.out_dir, f"{stem}.json")
    yaml_path = os.path.join(args.out_dir, f"{stem}.yaml")

    migrator = ConfigMigrator(args.ini_file)
    try:
        migrator.parse()
    except FileNotFoundError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)

    os.makedirs(args.out_dir, exist_ok=True)
    migrator.to_json_file(json_path)
    migrator.to_yaml_file(yaml_path)

    print(f"Written: {json_path}")
    print(f"Written: {yaml_path}")


if __name__ == "__main__":
    main()
