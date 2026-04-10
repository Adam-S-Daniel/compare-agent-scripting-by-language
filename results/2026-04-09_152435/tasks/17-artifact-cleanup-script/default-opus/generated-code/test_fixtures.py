"""
Test fixtures for artifact cleanup script.

Provides mock artifact data and policies for testing various retention scenarios.
"""

# Fixed "now" timestamp for deterministic age calculations
NOW_ISO = "2026-04-10T12:00:00+00:00"

# Basic set of artifacts spanning multiple workflows and dates
BASIC_ARTIFACTS = [
    {
        "name": "build-linux-latest",
        "size_mb": 50.0,
        "created_at": "2026-04-09T10:00:00+00:00",  # 1 day old
        "workflow_run_id": "wf-100"
    },
    {
        "name": "build-linux-old",
        "size_mb": 45.0,
        "created_at": "2026-03-25T10:00:00+00:00",  # 16 days old
        "workflow_run_id": "wf-100"
    },
    {
        "name": "build-windows-latest",
        "size_mb": 80.0,
        "created_at": "2026-04-08T10:00:00+00:00",  # 2 days old
        "workflow_run_id": "wf-200"
    },
    {
        "name": "build-windows-old",
        "size_mb": 75.0,
        "created_at": "2026-03-20T10:00:00+00:00",  # 21 days old
        "workflow_run_id": "wf-200"
    },
    {
        "name": "test-results-recent",
        "size_mb": 10.0,
        "created_at": "2026-04-10T08:00:00+00:00",  # 4 hours old
        "workflow_run_id": "wf-300"
    },
    {
        "name": "test-results-medium",
        "size_mb": 12.0,
        "created_at": "2026-04-03T10:00:00+00:00",  # 7 days old
        "workflow_run_id": "wf-300"
    },
    {
        "name": "test-results-ancient",
        "size_mb": 8.0,
        "created_at": "2026-03-01T10:00:00+00:00",  # 40 days old
        "workflow_run_id": "wf-300"
    },
]

# Test case 1: Max age policy (30 days) — should delete only test-results-ancient (40 days old)
MAX_AGE_CONFIG = {
    "artifacts": BASIC_ARTIFACTS,
    "policy": {"max_age_days": 30},
    "now": NOW_ISO,
}
# Expected: delete test-results-ancient (40 days), retain 6

# Test case 2: Keep latest 1 per workflow — keeps only newest per workflow_run_id
KEEP_LATEST_CONFIG = {
    "artifacts": BASIC_ARTIFACTS,
    "policy": {"keep_latest_n_per_workflow": 1},
    "now": NOW_ISO,
}
# Expected: delete build-linux-old (wf-100), build-windows-old (wf-200),
#           test-results-medium & test-results-ancient (wf-300). Retain 3.

# Test case 3: Max total size 150 MB — delete oldest until under 150
MAX_SIZE_CONFIG = {
    "artifacts": BASIC_ARTIFACTS,
    "policy": {"max_total_size_mb": 150},
    "now": NOW_ISO,
}
# Total: 50+45+80+75+10+12+8 = 280 MB. Need to drop 130 MB.
# Oldest first: test-results-ancient(8)=272, build-windows-old(75)=197,
#               build-linux-old(45)=152, test-results-medium(12)=140. Under 150.
# Expected: delete test-results-ancient, build-windows-old, build-linux-old, test-results-medium

# Test case 4: Combined policies
COMBINED_CONFIG = {
    "artifacts": BASIC_ARTIFACTS,
    "policy": {
        "max_age_days": 14,
        "keep_latest_n_per_workflow": 2,
        "max_total_size_mb": 200,
    },
    "now": NOW_ISO,
}
# max_age (14d): deletes build-windows-old(21d), test-results-ancient(40d), build-linux-old(16d)
# keep_latest_2: wf-300 has 3 artifacts -> deletes test-results-ancient (already marked)
# After age+keep: deleted={build-linux-old, build-windows-old, test-results-ancient}
# Remaining: build-linux-latest(50), build-windows-latest(80), test-results-recent(10), test-results-medium(12) = 152 MB
# 152 < 200, so no size deletions needed.
# Expected: delete build-linux-old, build-windows-old, test-results-ancient. Retain 4.

# Test case 5: Empty artifacts
EMPTY_CONFIG = {
    "artifacts": [],
    "policy": {"max_age_days": 30},
    "now": NOW_ISO,
}

# Test case 6: Invalid artifact (missing fields)
INVALID_MISSING_FIELD = {
    "artifacts": [{"name": "broken"}],
    "policy": {},
    "now": NOW_ISO,
}

# Test case 7: Dry run vs live mode
DRY_RUN_CONFIG = {
    "artifacts": BASIC_ARTIFACTS[:2],
    "policy": {"max_age_days": 7},
    "now": NOW_ISO,
}
# build-linux-old is 16 days old -> deleted
# build-linux-latest is 1 day old -> retained
