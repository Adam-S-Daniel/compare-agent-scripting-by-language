# Repository Rules

## No workflows in this repo

Do NOT create or modify files in `.github/workflows/` at the repository root.
The `.github/workflows/` directory is reserved for agent workspaces only — each
benchmark agent creates workflows inside its own isolated workspace directory
under `workspaces/`. The repo root must never contain GitHub Actions workflows.

## Only spawned agents fix their own YAML

If a benchmark agent produces a broken workflow YAML file, only that agent
(running inside its workspace via `runner.py`) is responsible for fixing it.
Do not manually fix, edit, or patch workflow files in `workspaces/` or
`results/*/generated-code/`. The whole point of the benchmark is to measure
what the agent produces autonomously.

## Benchmark workspace isolation

Each benchmark run creates isolated workspaces under `workspaces/<run-id>/`.
These are throwaway directories. Do not commit workspace contents to git.
The `results/` directory contains the archived outputs (metrics, generated code,
transcripts) and IS committed.

## runner.py is the harness, not a participant

`runner.py` orchestrates benchmark runs, collects metrics, and runs post-run
validation (actionlint, act). It must not modify the agent's code or fix errors
on the agent's behalf. Its role is observe and record, not intervene.
