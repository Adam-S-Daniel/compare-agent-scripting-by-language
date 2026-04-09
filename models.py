# ---------------------------------------------------------------------------
# Model definitions and token pricing — SINGLE SOURCE OF TRUTH
# ---------------------------------------------------------------------------
# Every file in this repo that needs model IDs or token costs imports from
# here.  There is no other place these values are defined.
#
# TO UPDATE: check https://docs.anthropic.com/en/docs/about-claude/models
# and https://www.anthropic.com/pricing for current prices.  Update the
# values below, then run:
#     python3 generate_results.py --all
# to regenerate all reports with the new rates.
# ---------------------------------------------------------------------------

MODELS = {
    "opus": "claude-opus-4-6",
    "sonnet": "claude-sonnet-4-6",
}

# All costs in USD per million tokens.
COST_PER_MTOK = {
    "claude-opus-4-6":   {"input": 15.0, "output": 75.0, "cache_read": 1.5, "cache_write": 18.75},
    "claude-sonnet-4-6": {"input": 3.0,  "output": 15.0, "cache_read": 0.3, "cache_write": 3.75},
}
