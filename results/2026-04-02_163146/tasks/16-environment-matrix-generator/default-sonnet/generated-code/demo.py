#!/usr/bin/env python3
"""
Demo: GitHub Actions build matrix generator.

Run this to see example output for typical configurations.
"""
import json
from matrix_generator import generate_matrix, MatrixTooLargeError, InvalidConfigError


def section(title: str) -> None:
    print(f"\n{'='*60}")
    print(f"  {title}")
    print('='*60)


def show(config: dict, label: str, **kwargs) -> None:
    print(f"\n-- {label} --")
    try:
        result = generate_matrix(config, **kwargs)
        print(json.dumps(result, indent=2))
        print(f"  [{len(result['matrix'])} combinations]")
    except (MatrixTooLargeError, InvalidConfigError) as exc:
        print(f"  ERROR: {exc}")


# 1. Basic cross-product
section("1. Basic cross-product (2 OS × 2 Python = 4 combinations)")
show(
    {
        "os": ["ubuntu-latest", "windows-latest"],
        "python-version": ["3.10", "3.11"],
    },
    "2×2 matrix",
)

# 2. Three axes
section("2. Three axes (2 × 2 × 2 = 8 combinations)")
show(
    {
        "os": ["ubuntu-latest", "windows-latest"],
        "python-version": ["3.10", "3.11"],
        "feature-flags": ["flag-a", "flag-b"],
    },
    "2×2×2 matrix",
)

# 3. Exclude rule
section("3. Exclude rule: remove windows + Python 3.10")
show(
    {
        "os": ["ubuntu-latest", "windows-latest"],
        "python-version": ["3.10", "3.11"],
        "exclude": [{"os": "windows-latest", "python-version": "3.10"}],
    },
    "4 base − 1 excluded = 3",
)

# 4. Partial exclude
section("4. Partial exclude: remove all windows combinations")
show(
    {
        "os": ["ubuntu-latest", "windows-latest"],
        "python-version": ["3.10", "3.11"],
        "exclude": [{"os": "windows-latest"}],
    },
    "4 base − 2 excluded = 2",
)

# 5. Include appends new combination
section("5. Include: append a new combination")
show(
    {
        "os": ["ubuntu-latest", "macos-latest"],
        "python-version": ["3.10", "3.11"],
        "include": [
            {"os": "windows-latest", "python-version": "3.12", "feature-flags": "flag-c"}
        ],
    },
    "4 base + 1 included = 5",
)

# 6. Include extends existing combination
section("6. Include: extend existing combination with extra key")
show(
    {
        "os": ["ubuntu-latest"],
        "python-version": ["3.10", "3.11"],
        "include": [
            {"os": "ubuntu-latest", "python-version": "3.10", "extra-tag": "canary"},
        ],
    },
    "1 combo gets extra-tag merged in",
)

# 7. max-parallel and fail-fast
section("7. max-parallel and fail-fast options")
show(
    {
        "os": ["ubuntu-latest", "windows-latest"],
        "python-version": ["3.10", "3.11"],
        "max-parallel": 2,
        "fail-fast": False,
    },
    "top-level strategy options",
)

# 8. Matrix size limit exceeded
section("8. Matrix size validation (default 256 limit)")
show(
    {
        "os": [str(i) for i in range(6)],
        "a": [str(i) for i in range(6)],
        "b": [str(i) for i in range(6)],
        "c": [str(i) for i in range(6)],
    },
    "6^4=1296 > 256 → error",
)

# 9. Custom max-size
section("9. Custom max_size=3 with 5 combinations → error")
show(
    {"os": [str(i) for i in range(5)]},
    "5 combos > max_size=3 → error",
    max_size=3,
)

# 10. Error: empty config
section("10. Error cases")
show({}, "empty config")
show({"os": []}, "empty axis")
show({"include": [{"os": "ubuntu"}], "max-parallel": 2}, "only reserved keys")

print("\nDone.")
