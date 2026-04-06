# Mock commit log fixtures for testing the semantic version bumper.
# Each fixture is a list of conventional commit message strings.

# Patch-only commits (fix: prefix)
PATCH_COMMITS = [
    "fix: correct off-by-one error in pagination",
    "fix: handle null pointer in user lookup",
    "fix(auth): resolve token expiration check",
]

# Minor (feature) commits
MINOR_COMMITS = [
    "feat: add user profile endpoint",
    "feat(search): implement full-text search",
]

# Major (breaking change) commits — BREAKING CHANGE footer or ! suffix
MAJOR_COMMITS = [
    "feat!: redesign authentication flow",
    "fix!: change error response format",
    "refactor!: rename User to Account across the codebase",
]

# Breaking change in the commit body/footer
MAJOR_COMMITS_FOOTER = [
    "feat: overhaul config format\n\nBREAKING CHANGE: config files must be migrated to v2 schema",
    "fix: update API response\n\nBREAKING CHANGE: removed deprecated fields from response",
]

# Mixed commits — the highest bump type wins
MIXED_PATCH_AND_MINOR = [
    "fix: typo in error message",
    "feat: add CSV export option",
    "fix(db): close connection on error",
]

MIXED_WITH_BREAKING = [
    "fix: minor typo",
    "feat: new dashboard widget",
    "feat!: remove legacy API endpoints",
]

# Non-conventional commits (should be ignored or treated as patch)
NON_CONVENTIONAL = [
    "updated readme",
    "WIP: experimenting with new layout",
    "Merge branch 'develop' into main",
]

# Empty commit list
EMPTY_COMMITS = []

# Commits with scopes
SCOPED_COMMITS = [
    "feat(api): add rate limiting",
    "fix(ui): button alignment on mobile",
    "feat(api): add batch endpoint",
    "fix(db): connection pool exhaustion",
]
