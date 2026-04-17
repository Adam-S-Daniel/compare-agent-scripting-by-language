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
    "opus47-1m": "claude-opus-4-7[1m]",
    "opus46-1m": "claude-opus-4-6[1m]",
}

# All costs in USD per million tokens.
# `[1m]` variants use the 1M-context beta. Under 200k tokens of input, standard
# rates apply; above 200k, Anthropic bills at a 2x input / 1.5x output multiplier.
# These are assumption fields — the CLI's reported `total_cost_usd` is the
# authoritative per-run cost and is what appears in results.md.
COST_PER_MTOK = {
    "claude-opus-4-6":       {"input": 15.0, "output": 75.0,  "cache_read": 1.5, "cache_write": 18.75},
    "claude-opus-4-7":       {"input": 15.0, "output": 75.0,  "cache_read": 1.5, "cache_write": 18.75},
    "claude-opus-4-6[1m]":   {"input": 15.0, "output": 75.0,  "cache_read": 1.5, "cache_write": 18.75},
    "claude-opus-4-7[1m]":   {"input": 15.0, "output": 75.0,  "cache_read": 1.5, "cache_write": 18.75},
    "claude-sonnet-4-6":     {"input": 3.0,  "output": 15.0,  "cache_read": 0.3, "cache_write": 3.75},
}
