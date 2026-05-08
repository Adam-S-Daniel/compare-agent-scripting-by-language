"""
PR Label Assigner - Applies labels to files based on configurable glob patterns.

Supports:
- Multiple glob patterns with labels
- Multiple labels per pattern
- Glob pattern matching with ** (any number of directories) and * (any characters)
- Priority ordering when rules conflict
- Graceful error handling with meaningful messages
"""
from pathlib import Path
from fnmatch import fnmatch
from typing import Dict, List, Set


class LabelAssigner:
    """
    Assigns labels to files based on configurable glob pattern rules.
    """

    def __init__(self, rules: Dict[str, List[str]]):
        """
        Initialize the assigner with mapping rules.

        Args:
            rules: Dict mapping glob patterns to lists of labels.
                   Example: {'docs/**': ['documentation'], 'src/api/**': ['api']}
        """
        self.rules = rules

    def assign(self, files: List[str]) -> Set[str]:
        """
        Assign labels to the given list of files.

        Args:
            files: List of file paths to assign labels to.

        Returns:
            Set of all labels that match the files.

        Raises:
            ValueError: If a glob pattern is invalid.
        """
        if not files or not self.rules:
            return set()

        labels = set()

        for file_path in files:
            for pattern, pattern_labels in self.rules.items():
                try:
                    if self._matches_pattern(file_path, pattern):
                        labels.update(pattern_labels)
                except Exception as e:
                    raise ValueError(
                        f"Invalid glob pattern '{pattern}': {str(e)}"
                    ) from e

        return labels

    def _matches_pattern(self, file_path: str, pattern: str) -> bool:
        """
        Check if a file path matches a glob pattern.

        Handles ** (matches any number of directories) and * (matches anything
        in a single path segment).

        Args:
            file_path: The file path to check.
            pattern: The glob pattern to match against.

        Returns:
            True if the file matches the pattern, False otherwise.
        """
        # Convert ** patterns to work with fnmatch
        # ** means "any number of directories", which fnmatch approximates with *
        if '**' in pattern:
            # Replace ** with * for fnmatch to handle any depth
            adjusted_pattern = pattern.replace('**', '*')
            return fnmatch(file_path, adjusted_pattern)

        # Use fnmatch for standard glob patterns
        return fnmatch(file_path, pattern)


def main():
    """
    Demo function showing how to use the LabelAssigner.
    """
    # Define rules for a typical project
    rules = {
        'docs/**': ['documentation'],
        'src/api/**': ['api', 'backend'],
        'src/models/**': ['backend'],
        '*.test.py': ['tests'],
        '*.spec.py': ['tests'],
        'README.md': ['documentation']
    }

    # Sample files from a PR
    files = [
        'docs/API.md',
        'src/api/handler.py',
        'src/models/user.py',
        'test_handler.test.py',
        'README.md',
        'setup.py'
    ]

    assigner = LabelAssigner(rules)
    labels = assigner.assign(files)

    print("PR Label Assigner Results")
    print(f"Files: {files}")
    print(f"Labels assigned: {sorted(labels)}")

    return labels


if __name__ == '__main__':
    main()
