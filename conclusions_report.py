#!/usr/bin/env python3
"""Merged Conclusions generator for results.md.

Integrates the panel-of-judges consistency data (quality rankings,
Spearman correlations, reversals) with the benchmark speed/cost
aggregate table to produce ONE integrated Conclusions block focused on
tradeoffs between quality, speed, and cost.

Intentionally separate from `judge_consistency_report.py` — that file
is the judge-consistency DATA artefact (tables, rankings, per-judge
means). This file is purely about translating the cross-axis picture
into prose.

Contract:
    generate_conclusions(
        results_dir: Path,
        speed_cost_input: str | None,
        repo_root: Path | None = None,
    ) -> {
        "conclusions": entry | None,                # merged tradeoff prose
        "judge_consistency_summary": entry | None,  # Notes > JCS prose
    }

    Each entry: {"text", "cost_usd", "input_tokens", "output_tokens",
                 "model", "effort", "from_cache"}.

Calls are cached in `<results_dir>/conclusions-cache.json` keyed by
sha256(system_prompt + user_message) so a regen doesn't re-pay the
LLM bill when underlying data is unchanged.
"""
import hashlib
import json
import sys
from pathlib import Path

from judge_consistency_report import (
    SUMMARY_MODEL,
    SUMMARY_EFFORT,
    SUMMARY_MAX_BUDGET_USD,
    SUMMARY_TIMEOUT_S,
    JUDGE_CONSISTENCY_SUMMARY_SYSTEM_PROMPT,
    _read_context_excerpts,
    build_report,
)


# System prompt for the merged Conclusions block. Framed around the
# four decisions a reader of this benchmark makes when asking an agent
# to produce a GitHub Actions workflow: which model, what effort level,
# what context length, and whether to specify a scripting language.
MERGED_CONCLUSIONS_SYSTEM_PROMPT = """\
You are writing the Conclusions section of a benchmark report for an
executive audience. It renders in results.md directly after the
Scoring section.

READER CONTEXT (use this to scope the content):
The reader is about to ask an AI coding agent to write a GitHub
Actions workflow (including scripts and tests). They need to pick:

  1. Which model? (haiku-4-5, sonnet-4-6, opus-4-7 — denoted here as
     haiku45, sonnet46, opus47)
  2. What effort level? (medium, high, xhigh — opus47 only)
  3. What context length? (200k vs 1m — opus47 and sonnet46)
  4. Whether to specify a scripting language? If so, which one?
     (default lets the agent pick, typically Python. Explicit choices:
     bash, powershell, powershell-tool, typescript-bun.)

Different readers weigh cost, Tests Quality, Workflow Craft, and a
preferred scripting language differently; your prose must give them
the MAGNITUDES they need to make their own tradeoffs, not tell them
what to pick.

SOURCE DATA you will receive:
- The panel-of-judges consistency data (rankings of model, language,
  and language×model combinations; Spearman rank correlations;
  pair-wise reversals between judges).
- The benchmark aggregate table listing per (language, model+context+
  effort) combo: average duration in minutes, average cost in USD,
  total cost, and panel-mean Tests Quality + Workflow Craft (1-5).

OUTPUT FORMAT — emit EXACTLY this structure:

Anchor paragraph (1-2 short sentences): names the four decisions the
reader is making and mentions the mean-of-two-LLM-as-judge source of
quality numbers. ≤ 50 words. No bullets, no numbers yet. Sets framing.

Then a blank line. Then exactly **four bullets**, one per decision,
in this fixed order:

- **Model choice:** magnitudes the reader gets by moving between
  haiku45 / sonnet46 / opus47 on cost, duration, Tests Quality, and
  Workflow Craft. Cite one judge-agreement number if relevant.
- **Effort (opus47 only):** what medium → high and high → xhigh each
  add on cost and duration, and whether quality follows.
- **Context length (opus47, sonnet46):** where 1m buys measurable
  quality over 200k and where it doesn't.
- **Scripting language:** magnitudes from letting the agent choose
  (default → Python) vs specifying a language, and which language
  leads by model when specified.

Each bullet: ONE short sentence, followed by at most ONE short
follow-up only if needed. ≤ 45 words per bullet. At most 3 numbers
per bullet; prefer 2. Use en-dash `–` for ranges (`$0.45–$3.54`,
`4.7–16.5 min`, `Tests 2.0–4.5`).

Then a blank line. Then ONE closing sentence (≤ 25 words) flagging
that no single configuration dominates all axes and that the reader
should weigh the magnitudes above by their own preferences.

FORBIDDEN — imperatives. Do NOT tell the reader what to do. Banned
phrasings include "pair it with ...", "skip ... otherwise",
"use ...", "avoid ...", "don't pick ...", "choose ...", "pick ...",
"go with ...", "stick with ...", "reach for ...". Replace every
imperative with a descriptive observation of what the data shows:
"haiku45 lands X points below opus47 on both axes", NOT "choose
haiku45 if cost matters". The closing sentence may use "weigh these
magnitudes against your own priorities" — the ONE allowed second-
person phrasing — but must not name a recommendation.

FORBIDDEN — universal recommendations. Do NOT pick a "winner" on any
axis. The reader is the one picking; you supply magnitudes.

Examples of acceptable descriptive phrasing:
- "haiku45 runs $0.45–$0.49 per run at 2.0–2.6 panel-mean quality — a
  full point below opus47 and sonnet46 on both axes."
- "Medium → high on opus47 adds $0.5–$0.9/run for +0.3–0.8 Tests
  Quality, while high → xhigh adds another $0.3–$1.2/run with flat
  quality on 3 of 4 languages."
- "Specifying language over default moves Tests Quality by up to 0.7
  points; powershell and default tie on opus47-1m-high (both 4.2)."

STYLE RULES:
- Total length: 180-300 words across anchor + 4 bullets + closing.
- Plain English, executive audience. "Pareto" is fine without gloss.
- Use "language" (never "mode") for the scripting-language axis.
- Use "Workflow Craft" and "Tests Quality" verbatim as score names.
- No hedging filler ("it seems", "arguably", "one might argue").
- Do NOT emit any section heading, horizontal rule, or preamble. Start
  directly with the anchor paragraph.
- Cite judge support in a ≤ 8-word subclause (e.g. "both judges agree
  (ρ = +0.83)"). Max one correlation number per bullet.
- Scannable > eloquent. A reader skimming the four bold decision
  labels alone should pick up the shape of each tradeoff.
"""


def _call_cached(cache_path: Path, cache: dict, name: str,
                 system_prompt: str, user_message: str) -> dict | None:
    """Single LLM call with disk caching keyed by hash(sys+user)."""
    key = hashlib.sha256(
        (system_prompt + "\n\n" + user_message).encode()
    ).hexdigest()
    cached = cache.get(name)
    if cached and cached.get("hash") == key and cached.get("text"):
        return {**cached, "from_cache": True}
    try:
        from llm_providers import get_provider
        provider = get_provider("claude-cli")
    except Exception as e:
        print(f"  Conclusions [{name}]: provider unavailable: {e}",
              file=sys.stderr)
        return None
    try:
        resp = provider.judge(
            system_prompt, user_message,
            model=SUMMARY_MODEL, effort=SUMMARY_EFFORT,
            max_budget_usd=SUMMARY_MAX_BUDGET_USD,
            timeout_s=SUMMARY_TIMEOUT_S,
        )
    except TypeError:
        resp = provider.judge(system_prompt, user_message,
                              model=SUMMARY_MODEL)
    if not resp or not resp.get("text"):
        return None
    entry = {
        "hash": key,
        "text": resp["text"].strip(),
        "cost_usd": round(resp.get("cost_usd", 0), 4),
        "input_tokens": resp.get("input_tokens", 0),
        "output_tokens": resp.get("output_tokens", 0),
        "model": SUMMARY_MODEL,
        "effort": SUMMARY_EFFORT,
    }
    cache[name] = dict(entry)
    cache_path.write_text(json.dumps(cache, indent=2))
    return {**entry, "from_cache": False}


def _load_cache(cache_path: Path) -> dict:
    if not cache_path.exists():
        return {}
    try:
        return json.loads(cache_path.read_text())
    except Exception:
        return {}


def generate_conclusions_from_inputs(
    cache_path: Path,
    data_md: str,
    speed_cost_input: str | None,
    repo_root: Path,
) -> dict:
    """Lower-level: run both Opus-max prompts with explicit inputs and
    a specific cache path. Useful for the combined-report path where
    the data MD and cache location differ from a single run directory.

    Returns {"conclusions": entry | None,
             "judge_consistency_summary": entry | None}.
    """
    cache = _load_cache(cache_path)
    context = _read_context_excerpts(repo_root)
    out: dict = {"conclusions": None, "judge_consistency_summary": None}

    # The merged Conclusions LLM prose is disabled for every caller
    # (per-run and combined). Report consumers rely on the aggregate
    # tables plus the Judge Consistency Summary below instead.
    _ = speed_cost_input  # kept in the signature for call-site compat.

    if data_md:
        jcs_user = (
            "CONTEXT:\n\n" + context + "\n\n---\n\n"
            + "JUDGE CONSISTENCY DATA (rankings, Spearman correlations, "
            + "reversals across model / language / language×model axes):\n\n"
            + data_md
        )
        out["judge_consistency_summary"] = _call_cached(
            cache_path, cache, "judge_consistency_summary",
            JUDGE_CONSISTENCY_SUMMARY_SYSTEM_PROMPT, jcs_user)

    return out


def generate_conclusions(results_dir: Path,
                         speed_cost_input: str | None = None,
                         repo_root: Path | None = None) -> dict:
    """Per-run-directory wrapper: builds the judge-consistency data MD
    for `results_dir` and runs both prompts with the shared cache file
    (`<results_dir>/conclusions-cache.json`)."""
    if repo_root is None:
        repo_root = Path(__file__).parent.resolve()
    cache_path = results_dir / "conclusions-cache.json"
    data_md = build_report(results_dir, repo_root=repo_root)
    return generate_conclusions_from_inputs(
        cache_path=cache_path,
        data_md=data_md,
        speed_cost_input=speed_cost_input,
        repo_root=repo_root,
    )
