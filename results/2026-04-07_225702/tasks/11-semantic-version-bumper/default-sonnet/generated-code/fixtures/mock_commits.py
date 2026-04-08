"""
Mock commit log fixtures for use in tests and manual demos.

Each COMMITS_* list represents a realistic git log snapshot.
"""

# A release containing only bug fixes → patch bump
COMMITS_PATCH = [
    "fix: correct null pointer in user service",
    "fix(auth): handle expired token edge case",
    "fix: trim whitespace from input fields",
]

# A feature release → minor bump
COMMITS_MINOR = [
    "feat: add dark mode support",
    "feat(search): implement fuzzy search",
    "fix: correct sidebar alignment",
    "docs: update README with new screenshots",
    "chore: upgrade dependencies",
]

# A breaking API change → major bump
COMMITS_MAJOR_BANG = [
    "feat!: redesign REST API surface\n\nBREAKING CHANGE: /v1 endpoints removed, migrate to /v2",
    "feat: add GraphQL endpoint",
    "fix: resolve race condition in queue processor",
]

# Breaking change signalled via footer, not bang
COMMITS_MAJOR_FOOTER = [
    "refactor: extract auth module\n\nBREAKING CHANGE: AuthService constructor signature changed",
    "feat: support OAuth2 PKCE flow",
    "fix: correct CORS header on preflight",
]

# No conventional commits at all → no bump
COMMITS_NO_BUMP = [
    "chore: update CI pipeline",
    "docs: fix typo in contributing guide",
    "style: run prettier across codebase",
    "test: increase unit test coverage for utils",
]

# Mixed bag with chores, docs, and one fix
COMMITS_MIXED = [
    "fix(logging): avoid duplicate log entries",
    "chore: pin Node version in .nvmrc",
    "docs: add ADR-007 for caching strategy",
    "perf: lazy-load heavy dependencies",
    "ci: switch from CircleCI to GitHub Actions",
]
