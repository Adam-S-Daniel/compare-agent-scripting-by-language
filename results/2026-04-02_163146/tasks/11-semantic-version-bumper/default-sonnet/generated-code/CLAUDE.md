# Semantic Version Bumper

Python implementation of a semantic version bumper using conventional commits.

## Files

- `semver_bumper.py` — main library (no external dependencies)
- `test_semver_bumper.py` — full pytest test suite
- `requirements.txt` — `pytest>=7.0`
- `fixtures/` — mock commit log files and sample version files
- `run_tests.sh` — convenience script to install pytest and run tests

## Running Tests

```bash
pip3 install pytest
python3 -m pytest test_semver_bumper.py -v
```

Or using uv:
```bash
uv pip install pytest --system
python3 -m pytest test_semver_bumper.py -v
```

## CLI Usage

```bash
# Bump version from commits piped via stdin
echo "feat: add new feature" | python3 semver_bumper.py package.json

# With a commits file
python3 semver_bumper.py package.json --commits-file fixtures/commits_minor.txt

# Include changelog output
python3 semver_bumper.py package.json --commits-file fixtures/commits_minor.txt --changelog
```

## TDD Approach

Tests were written first (red) in `test_semver_bumper.py`, then the minimum
implementation was added to `semver_bumper.py` to make each test pass (green).

Feature coverage:
1. `parse_version` — reads package.json or plain text version files
2. `determine_bump_type` — parses conventional commits (feat/fix/breaking → minor/patch/major)
3. `bump_version` — calculates next semver from current version + bump type
4. `update_version_file` — writes new version back to file in-place
5. `generate_changelog` — generates Markdown changelog entry grouped by type
6. `run_version_bump` — end-to-end pipeline combining all the above
