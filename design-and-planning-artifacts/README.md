# Design and Planning Artifacts

Historical documents from the design and evolution of the benchmark. These are not used at runtime but provide context for understanding design decisions.

| File | Description |
|------|-------------|
| [PLAN-v3-gha.md](PLAN-v3-gha.md) | Original design plan for v3 (GHA workflows). Describes scope changes from v2, task redesign, implementation phases. |
| [STATUS.md](STATUS.md) | v2 benchmark status snapshot from 2026-04-08. Documents v1→v2 changes, completion state, and known issues. |
| [language-mode-insights.md](language-mode-insights.md) | Deep analysis of v1 results: why different language modes cost different amounts, with transcript examples. |
| [write-more-iterate-less.md](write-more-iterate-less.md) | v1 analysis of Opus vs Sonnet coding strategies. Opus takes many small steps; Sonnet front-loads large artifacts. |
| [analysis.ipynb](analysis.ipynb) | Jupyter notebook with v1/v2 data analysis and visualizations. |
| [syntax-check.sh](syntax-check.sh) | Bash version of the PostToolUse syntax hook. Superseded by `hooks/syntax-check.py` (Python version used in v3). |
