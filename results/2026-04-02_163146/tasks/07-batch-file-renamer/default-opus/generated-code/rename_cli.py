#!/usr/bin/env python3
"""
Command-line interface for the batch file renamer.

Usage:
    python rename_cli.py <directory> <pattern> <replacement> [--preview] [--undo-script <path>]

Examples:
    # Preview what would change
    python rename_cli.py ./photos "IMG_(\\d+)" "photo_\\1" --preview

    # Execute renames and save undo script
    python rename_cli.py ./photos "IMG_(\\d+)" "photo_\\1" --undo-script undo.sh

    # Just rename, no undo script
    python rename_cli.py ./photos "\\.jpeg$" ".jpg"
"""

import argparse
import sys

from renamer import BatchRenamer, RenameConflictError


def main():
    parser = argparse.ArgumentParser(
        description="Batch rename files using regex patterns."
    )
    parser.add_argument("directory", help="Directory containing files to rename")
    parser.add_argument("pattern", help="Regex pattern to match in filenames")
    parser.add_argument("replacement", help="Replacement string (supports \\1, \\2 groups)")
    parser.add_argument(
        "--preview", action="store_true",
        help="Show what would change without renaming anything"
    )
    parser.add_argument(
        "--undo-script", metavar="PATH",
        help="Write an undo shell script to the given path"
    )
    args = parser.parse_args()

    renamer = BatchRenamer()

    try:
        # Scan the directory
        files = renamer.scan_directory(args.directory)

        if args.preview:
            # Preview mode: just show what would happen
            lines = renamer.preview(files, args.pattern, args.replacement)
            if not lines:
                print("No files match the pattern.")
            else:
                print(f"Preview ({len(lines)} files would be renamed):")
                for line in lines:
                    print(f"  {line}")
            return 0

        # Plan and execute
        plan = renamer.plan_renames(files, args.pattern, args.replacement)

        if not plan:
            print("No files match the pattern. Nothing to do.")
            return 0

        # Show what will happen
        print(f"Renaming {len(plan)} files:")
        for old, new in plan:
            print(f"  {old} -> {new}")

        # Save undo script if requested
        if args.undo_script:
            renamer.write_undo_script(plan, args.undo_script, args.directory)
            print(f"\nUndo script written to: {args.undo_script}")

        # Execute
        count = renamer.execute(args.directory, plan)
        print(f"\nDone. {count} files renamed.")
        return 0

    except RenameConflictError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1
    except OSError as e:
        print(f"Error renaming file: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
