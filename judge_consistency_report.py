#!/usr/bin/env python3
"""Post-judge-batch analysis: writes a markdown report summarising how
the panel of judges (Haiku 4.5, Gemini 3.1 Pro, and any others) agree
or disagree across tasks, languages, and model/effort configurations.

Usage:
    python3 judge_consistency_report.py results/2026-04-17_004319
    python3 judge_consistency_report.py results/<dir> -o results/<dir>/judge-consistency-data.md

Intended to run automatically at the end of `test_quality.py --llm-judge
--deliverable-judge`, but also invokable standalone whenever per-judge
cache files have accumulated. Reads every `test-quality-{short}.json`
and `deliverable-quality-{short}.json` under `<results_dir>/tasks/*/*/`
and emits grouped Haiku-vs-Gemini deltas plus disagreement hotspots.
"""
import argparse
import json
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo


# Dimensions emitted by each rubric. Ordering matters for display.
TEST_DIMS = ("coverage", "rigor", "design", "overall")
DELIV_DIMS = ("best_practices", "conciseness", "readability",
              "maintainability", "overall")

# Known language modes in the campaign, ordered by length-desc so the
# variant-subdir-name parser picks the longest prefix first (crucial
# so `powershell-tool` isn't mis-parsed as `powershell`).
_LANG_MODES = ("powershell-tool", "typescript-bun",
               "powershell", "default", "bash")


def _parse_variant_subdir(name: str) -> tuple[str, str]:
    """Return (mode, model_short_with_effort) from a variant subdir
    name like `bash-opus47-1m-high` or `default-sonnet-medium`."""
    for m in _LANG_MODES:
        if name.startswith(m + "-"):
            return m, name[len(m) + 1:]
    return "?", name


def _load_cache(path: Path) -> dict | None:
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text())
    except Exception:
        return None


def _collect(results_dir: Path) -> list[dict]:
    """Walk every variant subdir and emit one record per run containing
    the raw per-judge scores for both kinds (test + deliverable).

    Applies sibling `judge-audit-<kind>.json` verdicts so downstream
    rankings, Spearman correlations, and the JCS summary all see the
    audit-adjusted score pool — consistent with what Tiers / Comparison
    / LLM-as-Judge Scores tables render. Without this alignment, a
    judge's raw floor-hugging score would feed the rank correlations
    even though its rationale was factually wrong and the rest of the
    report already dropped it.

    Audit decisions:
    - `drop_both`  → omit that kind entirely for the record.
    - `drop_<j>`   → omit judge `j` from that kind's score map.
    - `keep_both`  → no change.
    - no audit file → no change (default behaviour unchanged).
    """
    tasks_dir = results_dir / "tasks"
    out: list[dict] = []
    for task in sorted(tasks_dir.iterdir()):
        if not task.is_dir():
            continue
        for variant in sorted(task.iterdir()):
            if not variant.is_dir():
                continue
            mode, model_suffix = _parse_variant_subdir(variant.name)
            rec = {
                "task_id": task.name,
                "mode": mode,
                "model_suffix": model_suffix,
                "variant_dir": str(variant),
                "tests_by_judge": {},
                "deliv_by_judge": {},
            }
            # Scan each per-judge cache file.
            for f in variant.glob("test-quality-*.json"):
                judge = f.stem.split("-", 2)[-1] if f.stem.count("-") >= 2 else f.stem
                if judge == "llm":  # legacy sonnet-only filename
                    judge = "sonnet-legacy"
                data = _load_cache(f)
                if data:
                    rec["tests_by_judge"][judge] = data
            for f in variant.glob("deliverable-quality-*.json"):
                judge = f.stem.split("-", 2)[-1] if f.stem.count("-") >= 2 else f.stem
                if judge == "llm":
                    judge = "sonnet-legacy"
                data = _load_cache(f)
                if data:
                    rec["deliv_by_judge"][judge] = data

            # Apply audit adjustments per kind.
            for kind, by_judge_key in (
                ("test-quality", "tests_by_judge"),
                ("deliverable-quality", "deliv_by_judge"),
            ):
                audit = _load_cache(variant / f"judge-audit-{kind}.json")
                if not audit:
                    continue
                decision = audit.get("panel_decision", "keep_both")
                if decision == "drop_both":
                    rec[by_judge_key] = {}
                elif decision.startswith("drop_"):
                    dropped = decision[len("drop_"):]
                    rec[by_judge_key].pop(dropped, None)

            if rec["tests_by_judge"] or rec["deliv_by_judge"]:
                out.append(rec)
    return out


def _group_agg(records: list[dict], key_fn, kind: str,
               judges: list[str], dims: tuple[str, ...]) -> list[dict]:
    """Group records by key_fn, compute per-judge per-dim means, plus
    Δ(first-judge → every-other-judge) on the `overall` dim if ≥2 judges."""
    buckets: dict = defaultdict(list)
    for r in records:
        by_judge = r["tests_by_judge"] if kind == "test" else r["deliv_by_judge"]
        # Only include records where EVERY judge in `judges` has a score —
        # otherwise the gap calculation would mix partial panels.
        if not all(j in by_judge for j in judges):
            continue
        buckets[key_fn(r)].append(by_judge)

    rows = []
    for key in sorted(buckets):
        entries = buckets[key]
        row = {"group": key, "n": len(entries)}
        # Per-judge, per-dim mean.
        for j in judges:
            for d in dims:
                vals = [e[j].get(d) for e in entries
                        if isinstance(e.get(j, {}).get(d), (int, float))]
                if vals:
                    row[f"{j}_{d}"] = sum(vals) / len(vals)
        # Δ for overall: every judge past the first, relative to the first.
        anchor = judges[0]
        for j in judges[1:]:
            a = row.get(f"{anchor}_overall")
            b = row.get(f"{j}_overall")
            if a is not None and b is not None:
                row[f"delta_{j}_minus_{anchor}"] = b - a
        rows.append(row)
    return rows


def _md_group_table(rows: list[dict], group_label: str,
                    judges: list[str], kind: str) -> list[str]:
    """Render one Haiku-vs-Gemini overall-score table. Adds Δ column
    when exactly two judges are present (the common panel setup)."""
    if not rows:
        return [f"*(no complete-panel runs for {kind} yet)*", ""]
    header_cells = [group_label, "n"]
    for j in judges:
        header_cells.append(f"{j} ovr")
    if len(judges) == 2:
        header_cells.append(f"Δ({judges[1]}−{judges[0]})")
    header = "| " + " | ".join(header_cells) + " |"
    sep = "|" + "|".join("---" for _ in header_cells) + "|"
    lines = [header, sep]
    for r in rows:
        cells = [str(r["group"]), str(r["n"])]
        for j in judges:
            v = r.get(f"{j}_overall")
            cells.append(f"{v:.2f}" if v is not None else "—")
        if len(judges) == 2:
            d = r.get(f"delta_{judges[1]}_minus_{judges[0]}")
            cells.append(f"{d:+.2f}" if d is not None else "—")
        lines.append("| " + " | ".join(cells) + " |")
    lines.append("")
    return lines


def _disagreement_hotspots(records: list[dict], kind: str,
                           judges: list[str], threshold: float = 2.0,
                           limit: int = 25) -> list[dict]:
    """Return runs where judges disagree by ≥ threshold points on `overall`,
    sorted by absolute disagreement descending."""
    if len(judges) < 2:
        return []
    out = []
    for r in records:
        by_judge = r["tests_by_judge"] if kind == "test" else r["deliv_by_judge"]
        if not all(j in by_judge for j in judges):
            continue
        vals = [by_judge[j].get("overall") for j in judges]
        if any(not isinstance(v, (int, float)) for v in vals):
            continue
        span = max(vals) - min(vals)
        if span >= threshold:
            out.append({
                "task_id": r["task_id"],
                "mode": r["mode"],
                "model_suffix": r["model_suffix"],
                "span": span,
                "values": dict(zip(judges, vals)),
            })
    out.sort(key=lambda x: -x["span"])
    return out[:limit]


_EFFORTS = {"low", "medium", "high", "xhigh", "max"}


def _model_short_of(model_suffix: str) -> str:
    """Strip effort/CLI tags from a variant's model_suffix so
    opus47-1m-medium / opus47-1m-xhigh collapse to `opus47-1m`."""
    parts = model_suffix.split("-")
    keep = []
    for p in parts:
        if p in _EFFORTS or p.startswith("cli"):
            break
        keep.append(p)
    return "-".join(keep) if keep else model_suffix


def _rank_by(records: list[dict], kind: str, judges: list[str],
             key_fn) -> dict[str, list[tuple[str, float, int]]]:
    """Return {judge: [(group_key, mean_overall, n), ...]} sorted
    best-to-worst for an arbitrary grouping function.

    `key_fn(record)` must return a string (or None to skip that
    record). Examples:
      - lambda r: _model_short_of(r["model_suffix"])          # by model
      - lambda r: r["mode"]                                    # by language
      - lambda r: f"{r['mode']}/{_model_short_of(r['model_suffix'])}"
                                                               # combo
    """
    agg: dict[tuple[str, str], list[float]] = defaultdict(list)
    for r in records:
        k = key_fn(r)
        if not k:
            continue
        by_judge = r["tests_by_judge"] if kind == "test" else r["deliv_by_judge"]
        for j in judges:
            if j in by_judge:
                ovr = by_judge[j].get("overall")
                if isinstance(ovr, (int, float)):
                    agg[(j, k)].append(ovr)
    out: dict[str, list[tuple[str, float, int]]] = {}
    all_keys = sorted({k for (_, k) in agg.keys()})
    for j in judges:
        rows = []
        for k in all_keys:
            vals = agg.get((j, k), [])
            if vals:
                rows.append((k, sum(vals) / len(vals), len(vals)))
        rows.sort(key=lambda x: -x[1])
        out[j] = rows
    return out


# Back-compat shim: existing callers reference this name. Keep it as a
# thin wrapper on _rank_by so the reshape didn't force an API break.
def _model_rankings_by_judge(records: list[dict], kind: str,
                             judges: list[str]) -> dict[str, list[tuple[str, float, int]]]:
    return _rank_by(records, kind, judges,
                    lambda r: _model_short_of(r["model_suffix"]))


def _ranking_agreement(rankings: dict[str, list[tuple[str, float, int]]],
                       judges: list[str]) -> dict:
    """Summarise how well the judges agree on model ordering.

    Reports Spearman-style rank correlation (implemented manually to
    avoid a scipy dep) plus explicit pair-wise reversals: pairs of
    models (A, B) where one judge ranks A > B and the other ranks B > A.
    Also tags reversals as "own-family favouring" when one judge's
    preferred model in the pair is that judge's own model family.
    """
    if len(judges) < 2:
        return {"correlation": None, "reversals": []}
    a, b = judges[0], judges[1]
    # Common model set.
    common = set(m for m, _, _ in rankings[a]) & set(m for m, _, _ in rankings[b])
    if len(common) < 2:
        return {"correlation": None, "reversals": []}

    rank_a = {m: i for i, (m, _, _) in enumerate(rankings[a]) if m in common}
    rank_b = {m: i for i, (m, _, _) in enumerate(rankings[b]) if m in common}

    # Spearman: 1 − 6·Σd² / (n·(n²−1))
    n = len(common)
    if n >= 2 and n * (n * n - 1) != 0:
        d2 = sum((rank_a[m] - rank_b[m]) ** 2 for m in common)
        rho = 1 - (6 * d2) / (n * (n * n - 1))
    else:
        rho = None

    # Find pair-wise reversals.
    reversals = []
    models = sorted(common)
    for i, m1 in enumerate(models):
        for m2 in models[i + 1:]:
            a_prefers = rank_a[m1] < rank_a[m2]  # m1 ranked higher under a
            b_prefers = rank_b[m1] < rank_b[m2]
            if a_prefers != b_prefers:
                # Determine if either judge's preferred model is its own
                # family — the self-preference signature.
                judge_prefers = {a: m1 if a_prefers else m2,
                                 b: m1 if b_prefers else m2}
                own_family_flag = None
                for j in (a, b):
                    # e.g. judge "haiku45" prefers model "haiku45" → self-preference.
                    if j.rstrip("0123456789") in judge_prefers[j].replace("-", ""):
                        own_family_flag = j
                        break
                reversals.append({
                    "pair": (m1, m2),
                    f"{a}_prefers": judge_prefers[a],
                    f"{b}_prefers": judge_prefers[b],
                    "own_family_judge": own_family_flag,
                })
    return {"correlation": rho, "reversals": reversals}


def _self_judgment_rows(records: list[dict], kind: str,
                        judges: list[str],
                        deviation_threshold: float = 1.0) -> tuple[list[dict], float | None]:
    """Flag self-judgment runs whose inter-judge delta deviates
    MATERIALLY from the usual inter-judge delta for this dataset.

    Heuristic for "self-judgment": substring match of judge short-name
    (stripped of trailing digits) against the model short that produced
    the run. `haiku45` judging `haiku45-...` is the clearest case.

    For the filter, we need exactly two judges in the panel so the
    "delta" is unambiguous. With more than two judges, we'd need to
    define which pair to compare — for now, skip the filter and emit
    every self-judgment row unchanged.

    Returns (rows, baseline_delta):
        rows: list of self-judgment rows that passed the filter, each
              with self_score, other_judge, other_score, row_delta,
              deviation (row_delta − baseline_delta). When baseline
              can't be computed (≠2 judges), all rows pass.
        baseline_delta: mean (second_judge − first_judge) on `overall`
              across ALL runs where both judges scored, or None if the
              panel doesn't have exactly two judges.
    """
    # Compute the baseline inter-judge delta when exactly two judges.
    baseline = None
    if len(judges) == 2:
        a, b = judges  # e.g. ("haiku45", "gemini31pro")
        deltas: list[float] = []
        for r in records:
            by_judge = r["tests_by_judge"] if kind == "test" else r["deliv_by_judge"]
            if a in by_judge and b in by_judge:
                va = by_judge[a].get("overall")
                vb = by_judge[b].get("overall")
                if isinstance(va, (int, float)) and isinstance(vb, (int, float)):
                    deltas.append(vb - va)
        if deltas:
            baseline = sum(deltas) / len(deltas)

    out: list[dict] = []
    for r in records:
        by_judge = r["tests_by_judge"] if kind == "test" else r["deliv_by_judge"]
        for j in judges:
            if j not in by_judge:
                continue
            self_score = by_judge[j].get("overall")
            if not isinstance(self_score, (int, float)):
                continue
            # Self-judgment detection — substring test.
            if j.rstrip("0123456789") not in r["model_suffix"].replace("-", ""):
                continue

            row = {
                "task_id": r["task_id"],
                "mode": r["mode"],
                "model_suffix": r["model_suffix"],
                "self_judge": j,
                "self_score": self_score,
            }

            # Try to pair with the other judge (for delta calculation).
            others = [o for o in judges if o != j]
            if len(others) == 1 and baseline is not None and others[0] in by_judge:
                other = others[0]
                other_score = by_judge[other].get("overall")
                if isinstance(other_score, (int, float)):
                    # Keep the sign convention consistent with _group_agg:
                    # delta = (second judge in `judges` order) − (first).
                    if j == judges[0]:
                        row_delta = other_score - self_score
                    else:
                        row_delta = self_score - other_score
                    deviation = row_delta - baseline
                    row.update({
                        "other_judge": other,
                        "other_score": other_score,
                        "row_delta": row_delta,
                        "deviation": deviation,
                    })
                    # Only include rows whose deviation exceeds the threshold.
                    # A self-inflating Haiku would deflate (Gemini − Haiku),
                    # giving negative deviation; a self-deflating Haiku
                    # would inflate it. Either direction is material.
                    if abs(deviation) < deviation_threshold:
                        continue
            else:
                # No comparable pair — keep the row with score only.
                pass
            out.append(row)
    return out, baseline


SUMMARY_MODEL = "claude-opus-4-7[1m]"
# `max` effort was costing ~$1 per Conclusions call and ~$0.30 per JCS
# call — untenable for every regen. `xhigh` keeps the same model and
# 1m context but caps reasoning depth, bringing typical calls to
# fractions of a dollar with no observable loss of output quality for
# these summary prompts.
SUMMARY_EFFORT = "xhigh"
SUMMARY_MAX_BUDGET_USD = 5.00
SUMMARY_TIMEOUT_S = 600  # max effort + 1M context can take several minutes

QUALITY_ANALYSIS_SYSTEM_PROMPT = """\
You are writing the Quality Analysis section of `judge-consistency-data.md`,
for an executive audience. This section renders above the ranking
tables and is the prose interpretation of those rankings.

SOURCE DATA: the panel-of-judges consistency report you'll be given
contains model / language / language×model rankings from two
independent LLM judges (Haiku and Gemini), Spearman rank correlations,
and any pair-wise reversals between judges.

OUTPUT FORMAT — emit EXACTLY this structure:

Paragraph 1 (2-3 sentences): the strongest conclusions the rankings
data supports — which model+effort tier produces the best code, which
scripting languages are the best fit for each model. Lead with the
most decision-useful point. NO icons or bullets in this paragraph.

Then a blank line, then 3-5 bullets — each an additional specific
conclusion backed by the data. Start each bullet with `- ` and a
short bolded topic, followed by a 1-2 sentence claim. Example topics:
"Top performer", "Best by language", "Effort tier",
"Workflow Craft ceiling", "Where rankings diverge".

For EACH conclusion, briefly name WHY the judging supports it — cite
the Spearman correlation, the absence of reversals on the relevant
pair, or the agreement on top/bottom positions. Keep the "why"
phrasing short (a subclause, not a sentence): "... (both judges agree
on this ordering, ρ = +0.90)".

STYLE RULES:
- Total length: 150-250 words across paragraph + bullets.
- Plain English; no academic vocabulary. Use "baseline", "average",
  "agreement".
- Use "language" (never "mode") for the scripting-language axis.
- FORBIDDEN: imperatives. Do NOT tell the reader what to do. Banned
  phrasings include "pair it with ...", "skip ... otherwise",
  "use ...", "avoid ...", "pick ...", "choose ...". Replace every
  imperative with a descriptive observation.
- No hedging filler. State what's supported by the data.
- Do NOT emit any section heading or preamble — start directly with
  the first paragraph.
- When referring to the judges, prefer "both judges" over naming them.
- Refer to the deliverable-quality axis as "Workflow Craft"
  (never "Deliverables Quality" or "Deliv Quality")."""


JUDGE_CONSISTENCY_SUMMARY_SYSTEM_PROMPT = """\
You are summarising a cross-judge consistency check for a benchmark
report, as a short subsection under Notes.

CONTEXT — what the panel-of-judges is for in this benchmark:

- Identifying which configurations produce better code is the GOAL, so
  the judges DROPPING scores on a weaker model's output is desirable
  signal, not bias.
- What matters is whether the judges AGREE on the relative ordering
  (rankings) of configurations. Absolute-score differences between
  judges are expected calibration differences, not bias.
- Self-preference bias = when a judge elevates its own model family's
  RELATIVE rank vs what another judge says. NOT "rates own family
  higher in absolute terms".

Health verdict should be based on three criteria:
1. Directional agreement on model / language / language×model rankings.
2. Consistency within each judge across tasks/languages.
3. No pair-wise ranking reversals that favour a judge's own model.

OUTPUT FORMAT — emit EXACTLY this structure, nothing else:

Line 1: a bolded paragraph (1–3 sentences) that starts with 🟢 / 🟡 /
🔴 — your overall health verdict. Wrap the whole paragraph in `**…**`.
No bullet, no label. Example: `**🟢 The panel is doing its job:** …`

Then a blank line, then exactly three bullets in order:

- 👀 **Where to look closer:** (one to two sentences, naming specific
  disagreements worth a human spot-check; name task/language/model
  combos concretely)
- 🤓 **Surprise finding:** (one sentence that contradicts the setup's
  expectation; or write "None — panel behaved as expected" and stop)
- ℹ️ **Recommended next step:** (one sentence with a concrete
  actionable follow-up)

Do NOT include a "What we can trust" bullet — that content lives in
the Conclusions > Quality section above.

STYLE RULES:
- Total length: 100–180 words.
- Plain English, executive audience. No academic vocabulary.
- Use **"language"** (never "mode").
- When attributing a divergence between two judges, identify whose
  scoring moved relative to its own baseline. Note floor/ceiling
  effects explicitly if relevant.
- Say "own-model" or "own model family" rather than "same company".
- Do NOT emit any section heading — start directly with the bolded
  paragraph on line 1.
- No jargon shorthand without an inline definition. Scores run 1–5,
  so the most extreme disagreement is a 4-point gap (one judge 1, the
  other 5). If you surface such rows, introduce them with plain
  language the first time — e.g. "the widest disagreements (a judge
  scoring 1 vs 5, a 4-point gap on a 1–5 scale): …". Do NOT invent
  shorthand names like "Span-N", "Δ-N", or any abbreviation that a
  reader would have to decode. Prefer concrete numbers over coined
  terms every time.
- Any specific run you cite should be identified by task name (or
  task id + short name), language, and model — the same triple the
  Per-Run table uses. Example: "11-semantic-version-bumper / bash /
  sonnet46-1m-medium"."""


def _read_context_excerpts(repo_root: Path) -> str:
    """Collect concise, prompt-friendly context about the benchmark.

    Includes the two judge rubrics (which define what the scores mean),
    a compact summary of the experiment setup, and the list of tasks
    so the summarising LLM can reference them by name.
    """
    pieces: list[str] = []

    # Judge rubrics — the clearest signal for what each score represents.
    try:
        from test_quality import JUDGE_SYSTEM_PROMPT, DELIVERABLE_JUDGE_SYSTEM_PROMPT
        pieces.append("## Tests Quality judge rubric\n\n" + JUDGE_SYSTEM_PROMPT.strip())
        pieces.append("## Deliverable Quality judge rubric\n\n" +
                      DELIVERABLE_JUDGE_SYSTEM_PROMPT.strip())
    except Exception:
        pass

    # Task IDs and names from runner.TASKS — gives the LLM the human-
    # readable task descriptions it can quote when relevant.
    try:
        from runner import TASKS
        tasks_text = "## Benchmark tasks\n\n"
        for t in TASKS:
            tasks_text += f"- {t['id']}: {t.get('name', '')} — {t.get('category', '')}\n"
        pieces.append(tasks_text)
    except Exception:
        pass

    # High-level setup reminder.
    pieces.append(
        "## Experiment setup\n\n"
        "- Axes: language mode (default/python, powershell, powershell-tool, "
        "bash, typescript-bun) × model+context+effort (opus47-1m @ medium/"
        "high/xhigh, opus47-200k @ medium, sonnet46-1m @ medium, sonnet "
        "@ 200k medium, haiku45 @ 200k) × CLI version (2.1.112 / 2.1.114).\n"
        "- Judges: Haiku 4.5 (intra-family, shares training with models "
        "under test) + Gemini 3.1 Pro (cross-family, zero self-judgment "
        "since no Gemini-produced runs exist in this dataset).\n"
        "- Self-judgment rows exist only for Haiku (the 35 haiku45 runs)."
    )
    return "\n\n".join(pieces)


def _generate_quality_analysis(data_body_md: str,
                               cache_location: Path,
                               repo_root: Path) -> dict | None:
    """Generate the prose Quality Analysis that renders INLINE in
    `judge-consistency-data.md` (above the ranking tables). Cached so
    regens don't re-pay the LLM bill.

    `cache_location`: if a directory, the cache file is
    `<dir>/conclusions-cache.json`. If a file path ending `.json`, it
    is used as-is (combined-report path)."""
    import hashlib
    if cache_location.suffix == ".json":
        cache_path = cache_location
    else:
        cache_path = cache_location / "conclusions-cache.json"
    cache: dict = {}
    if cache_path.exists():
        try:
            cache = json.loads(cache_path.read_text())
        except Exception:
            cache = {}

    context = _read_context_excerpts(repo_root)
    user_message = (
        "CONTEXT:\n\n" + context + "\n\n---\n\n"
        + "JUDGE CONSISTENCY DATA (rankings, Spearman correlations, "
        + "reversals across model / language / language×model axes):\n\n"
        + data_body_md
    )
    key = hashlib.sha256(
        (QUALITY_ANALYSIS_SYSTEM_PROMPT + "\n\n" + user_message).encode()
    ).hexdigest()
    cached = cache.get("quality_analysis")
    if cached and cached.get("hash") == key and cached.get("text"):
        return {**cached, "from_cache": True}
    try:
        from llm_providers import get_provider
        provider = get_provider("claude-cli")
    except Exception as e:
        print(f"  Quality analysis: provider unavailable: {e}",
              file=sys.stderr)
        return None
    try:
        resp = provider.judge(
            QUALITY_ANALYSIS_SYSTEM_PROMPT, user_message,
            model=SUMMARY_MODEL, effort=SUMMARY_EFFORT,
            max_budget_usd=SUMMARY_MAX_BUDGET_USD,
            timeout_s=SUMMARY_TIMEOUT_S,
        )
    except TypeError:
        resp = provider.judge(QUALITY_ANALYSIS_SYSTEM_PROMPT, user_message,
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
    cache["quality_analysis"] = dict(entry)
    cache_path.write_text(json.dumps(cache, indent=2))
    return {**entry, "from_cache": False}


def _build_body(records: list[dict], judges: list[str]) -> str:
    """Produce the tabular body (campaign/task/mode/model breakdowns,
    hotspots, self-judgment flags). Exactly the content that used to
    sit under the Generated/Source/Judges-present preamble — now
    separated so `_generate_summary` can feed it to the LLM."""
    lines: list[str] = []

    # ── Campaign-wide summary ──
    lines.append("## Campaign summary")
    lines.append("")
    for kind, label in (("test", "Tests Quality"), ("deliv", "Workflow Craft")):
        rows = _group_agg(records, lambda _r: "all", kind, judges,
                          TEST_DIMS if kind == "test" else DELIV_DIMS)
        lines.append(f"### {label}")
        lines.append("")
        lines.extend(_md_group_table(rows, "Scope", judges, kind))

    # ── By task ──
    lines.append("## By task")
    lines.append("")
    for kind, label in (("test", "Tests Quality"), ("deliv", "Workflow Craft")):
        rows = _group_agg(records, lambda r: r["task_id"], kind, judges,
                          TEST_DIMS if kind == "test" else DELIV_DIMS)
        lines.append(f"### {label}")
        lines.append("")
        lines.extend(_md_group_table(rows, "Task", judges, kind))

    # ── By language mode ──
    lines.append("## By language mode")
    lines.append("")
    for kind, label in (("test", "Tests Quality"), ("deliv", "Workflow Craft")):
        rows = _group_agg(records, lambda r: r["mode"], kind, judges,
                          TEST_DIMS if kind == "test" else DELIV_DIMS)
        lines.append(f"### {label}")
        lines.append("")
        lines.extend(_md_group_table(rows, "Mode", judges, kind))

    # ── By model + effort (the `model_suffix` captured from subdir name) ──
    lines.append("## By model + effort")
    lines.append("")
    for kind, label in (("test", "Tests Quality"), ("deliv", "Workflow Craft")):
        rows = _group_agg(records, lambda r: r["model_suffix"], kind, judges,
                          TEST_DIMS if kind == "test" else DELIV_DIMS)
        lines.append(f"### {label}")
        lines.append("")
        lines.extend(_md_group_table(rows, "Model-Effort", judges, kind))

    # ── Disagreement hotspots ──
    lines.append("## Disagreement hotspots (panel span ≥ 2 on overall)")
    lines.append("")
    for kind, label in (("test", "Tests Quality"), ("deliv", "Workflow Craft")):
        hs = _disagreement_hotspots(records, kind, judges)
        lines.append(f"### {label}")
        lines.append("")
        if not hs:
            lines.append("*(no hotspots found at threshold 2.0)*")
            lines.append("")
            continue
        hdr_cells = ["Task", "Mode", "Model", "Span"] + [f"{j} ovr" for j in judges]
        lines.append("| " + " | ".join(hdr_cells) + " |")
        lines.append("|" + "|".join("---" for _ in hdr_cells) + "|")
        for h in hs:
            cells = [h["task_id"][:30], h["mode"], h["model_suffix"],
                     f"{h['span']:.1f}"]
            for j in judges:
                v = h["values"].get(j)
                cells.append(f"{v:.1f}" if isinstance(v, (int, float)) else "—")
            lines.append("| " + " | ".join(cells) + " |")
        lines.append("")

    # ── Rankings by judge across three axes (the primary health signal) ──
    # Model, language, and language×model rankings let us check that
    # agreement isn't coming from one axis dominating the picture.
    def _emit_ranking_axis(axis_label: str, axis_col: str, key_fn) -> None:
        lines.append(f"## {axis_label} rankings by judge")
        lines.append("")
        lines.append(f"*Agreement on {axis_label.lower()} ordering tells us "
                     "the panel agrees on which configurations produce "
                     "better output on this axis. Absolute-score differences "
                     "between judges are expected (different grading scales) "
                     "and are not a bias concern.*")
        lines.append("")
        for kind, kind_label in (("test", "Tests Quality"),
                                 ("deliv", "Workflow Craft")):
            rankings = _rank_by(records, kind, judges, key_fn)
            agreement = _ranking_agreement(rankings, judges)
            lines.append(f"### {kind_label}")
            lines.append("")
            all_keys = set()
            for j in judges:
                for m, _, _ in rankings[j]:
                    all_keys.add(m)
            per_key: dict[str, dict[str, tuple[int, float, int]]] = {}
            for j in judges:
                for i, (m, mean_s, n) in enumerate(rankings[j]):
                    per_key.setdefault(m, {})[j] = (i + 1, mean_s, n)
            hdr = [axis_col] + [f"{j} rank (mean, n)" for j in judges]
            lines.append("| " + " | ".join(hdr) + " |")
            lines.append("|" + "|".join("---" for _ in hdr) + "|")
            ordered = sorted(all_keys,
                             key=lambda m: per_key.get(m, {}).get(
                                 judges[0], (999, 0, 0))[0])
            for m in ordered:
                cells = [m]
                for j in judges:
                    r = per_key.get(m, {}).get(j)
                    cells.append(f"{r[0]} ({r[1]:.2f}, n={r[2]})" if r else "—")
                lines.append("| " + " | ".join(cells) + " |")
            lines.append("")
            if agreement["correlation"] is not None:
                lines.append(f"*Spearman rank correlation between {judges[0]} "
                             f"and {judges[1]}: **{agreement['correlation']:+.2f}**. "
                             "(+1.0 = judges agree perfectly on ordering; "
                             "0 = no correlation; -1.0 = reversed.)*")
                lines.append("")
            if agreement["reversals"]:
                lines.append(f"**Pair-wise reversals** (where the two judges "
                             f"disagree on which {axis_label.lower()} is "
                             "better):")
                lines.append("")
                a, b = judges[0], judges[1]
                lines.append(f"| Pair | {a} prefers | {b} prefers | Own-family signal? |")
                lines.append("|---|---|---|---|")
                for rev in agreement["reversals"]:
                    own = rev["own_family_judge"] or "—"
                    flag = f"⚠️ {own}" if own != "—" else "—"
                    lines.append(f"| {rev['pair'][0]} vs {rev['pair'][1]} | "
                                 f"{rev[f'{a}_prefers']} | "
                                 f"{rev[f'{b}_prefers']} | {flag} |")
                lines.append("")
            else:
                lines.append(f"*No pair-wise reversals — both judges agree "
                             f"on every {axis_label.lower()}-vs-"
                             f"{axis_label.lower()} ordering.*")
                lines.append("")

    _emit_ranking_axis("Model", "Model",
                       lambda r: _model_short_of(r["model_suffix"]))
    _emit_ranking_axis("Language", "Language",
                       lambda r: r["mode"])
    _emit_ranking_axis("Language×Model", "Language / Model",
                       lambda r: f"{r['mode']} / {_model_short_of(r['model_suffix'])}")

    # ── Legacy per-run self-judgment inspection (secondary; kept for
    # manual cross-check but the ranking-agreement table above is the
    # primary bias signal) ──
    lines.append("## Per-run self-judgment rows (reference)")
    lines.append("")
    lines.append("*Rows where a judge evaluated output from its own model "
                 "family. These individual runs are kept as a sanity "
                 "check — the actual bias test is the pair-wise ranking "
                 "reversals in the table above. Filtered to rows whose "
                 "inter-judge delta differs from the baseline delta by "
                 "≥1.0 point; such rows are plausibly interesting but "
                 "don't by themselves indicate bias (absolute-score "
                 "differences between judges are expected).*")
    lines.append("")
    for kind, label in (("test", "Tests Quality"), ("deliv", "Workflow Craft")):
        sj, baseline = _self_judgment_rows(records, kind, judges)
        lines.append(f"### {label}")
        lines.append("")
        if baseline is not None:
            if len(judges) == 2:
                sign = "−"
                lines.append(f"*Baseline delta ({judges[1]} {sign} "
                             f"{judges[0]}) across the whole dataset: "
                             f"**{baseline:+.2f}**.*")
                lines.append("")
        if not sj:
            lines.append("*(no self-judgment rows exceed the 1.0-point "
                         "deviation threshold — judges agree about "
                         "in-family output roughly as much as about "
                         "out-of-family output)*")
            lines.append("")
            continue
        # Always render the full pair table; unpaired rows (missing the
        # other judge's score) get "—" in those columns so mixed states
        # don't split into two disjoint tables.
        lines.append("| Task | Mode | Model | Self judge | Self score | "
                     "Other judge | Other score | Row Δ | Deviation |")
        lines.append("|---|---|---|---|---|---|---|---|---|")
        for s in sj:
            other_j = s.get("other_judge", "—")
            other_s = (f"{s['other_score']:.1f}"
                       if isinstance(s.get("other_score"), (int, float)) else "—")
            row_d = (f"{s['row_delta']:+.1f}"
                     if isinstance(s.get("row_delta"), (int, float)) else "—")
            dev = (f"{s['deviation']:+.1f}"
                   if isinstance(s.get("deviation"), (int, float)) else "—")
            lines.append(
                f"| {s['task_id'][:30]} | {s['mode']} | "
                f"{s['model_suffix']} | {s['self_judge']} | "
                f"{s['self_score']:.1f} | {other_j} | {other_s} | "
                f"{row_d} | {dev} |"
            )
        lines.append("")

    return "\n".join(lines) + "\n"


def build_report(results_dir: Path | list[Path],
                 repo_root: Path | None = None,
                 cache_dir: Path | None = None) -> str:
    """Assemble the data report: `Notes` preamble + tabular body.

    Accepts either a single results_dir or a list. Multiple dirs pool
    their records so the combined report's judge-consistency analysis
    sees every run in the campaign at once.

    `cache_dir`: where to write the Quality-Analysis LLM cache entry
    (`conclusions-cache.json`). Defaults to the single input dir; for
    a multi-dir call, the caller should pass an explicit location
    (e.g. next to the combined output MD) so the cache is shared.

    The merged LLM Conclusions + Judge Consistency Summary live in
    results.md (assembled via `conclusions_report.generate_conclusions`).
    This file carries the rankings-focused Quality Analysis above the
    data tables plus the raw per-judge rankings themselves."""
    dirs = results_dir if isinstance(results_dir, list) else [results_dir]
    records: list[dict] = []
    for d in dirs:
        records.extend(_collect(d))
    if not records:
        return ("# Judge Consistency Data\n\n"
                "*No per-judge cache files found.*\n")

    # Discover which judges are present by scanning a sample of records.
    judge_set: set[str] = set()
    for r in records:
        judge_set.update(r["tests_by_judge"].keys())
        judge_set.update(r["deliv_by_judge"].keys())
    preferred_order = ["haiku45", "gemini31pro"]
    judges = [j for j in preferred_order if j in judge_set] + \
             sorted(j for j in judge_set if j not in preferred_order)

    if repo_root is None:
        repo_root = Path(__file__).parent.resolve()

    body = _build_body(records, judges)

    # LLM-generated Quality Analysis — renders inline above the data
    # tables. Cached on disk so regens are cheap.
    qa_cache_dir = cache_dir or dirs[0]
    qa_entry = _generate_quality_analysis(body, qa_cache_dir, repo_root)

    et = ZoneInfo("America/New_York")
    now = datetime.now(et).strftime("%Y-%m-%d %I:%M:%S %p ET")

    lines: list[str] = []
    lines.append("# Judge Consistency Data")
    lines.append("")
    lines.append("*Raw panel-of-judges data plus a rankings-focused "
                 "Quality Analysis. Backs the merged Conclusions and "
                 "Judge Consistency Summary in the corresponding "
                 "[`results.md`](results.md).*")
    lines.append("")

    # ── Notes (generation metadata + score conventions) ──
    lines.append("## Notes")
    lines.append("")
    lines.append(f"- **Generated:** {now}")
    source_label = ", ".join(f"`{d}`" for d in dirs)
    lines.append(f"- **Source:** {source_label}")
    lines.append(f"- **Judges present:** {', '.join(judges)}")
    lines.append("- **Score conventions:** Scores shown are the `overall` "
                 "dimension from each judge (1-5). Δ column is the second "
                 "judge minus the first; positive = second judge is more "
                 "generous.")
    lines.append("")

    # ── Quality Analysis (LLM-generated prose over rankings) ──
    if qa_entry and qa_entry.get("text"):
        lines.append("## Quality Analysis")
        lines.append("")
        lines.append(qa_entry["text"])
        lines.append("")
        lines.append(
            "*Provenance:* "
            f"`{qa_entry.get('model', '?')}` at effort "
            f"`{qa_entry.get('effort', '?')}` via Claude CLI"
            f"{' (from cache)' if qa_entry.get('from_cache') else ''}; "
            f"{qa_entry.get('input_tokens', 0)} in / "
            f"{qa_entry.get('output_tokens', 0)} out tokens, "
            f"${qa_entry.get('cost_usd', 0):.4f}. "
            "Prompt: [`QUALITY_ANALYSIS_SYSTEM_PROMPT`]"
            "(../../judge_consistency_report.py)."
        )
        lines.append("")

    # ── Body (tables) ──
    lines.append(body)
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate a cross-judge consistency markdown report.")
    parser.add_argument("results_dir",
                        help="Path to a results/ subdirectory containing "
                             "tasks/*/*/ variant subdirs with per-judge "
                             "cache files.")
    parser.add_argument("-o", "--output",
                        help="Output markdown path (default: "
                             "<results_dir>/judge-consistency-data.md)")
    args = parser.parse_args()

    results_dir = Path(args.results_dir).resolve()
    if not (results_dir / "tasks").is_dir():
        print(f"Error: {results_dir} has no tasks/ subdirectory", file=sys.stderr)
        return 1

    out_path = Path(args.output) if args.output else results_dir / "judge-consistency-data.md"
    md = build_report(results_dir)
    out_path.write_text(md)
    print(f"Wrote {out_path}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
