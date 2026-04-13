# Task 14: Docker Image Tag Generator (Archived)

**Status:** Archived after v4 (run 2026-04-09_152435)

## Task Definition

- **ID:** `14-docker-image-tag-generator`
- **Name:** Docker Image Tag Generator
- **Category:** GitHub Actions / CI/CD
- **Description:** Given git context (branch name, commit SHA, tags, PR number — all provided as mock inputs), generate appropriate Docker image tags following common conventions: latest for main, pr-{number} for PRs, v{semver} for tags, {branch}-{short-sha} for feature branches. Handle tag sanitization (lowercase, no special chars). Output the tag list.

## Benchmark History

- **v1** (2026-04-02_163146): Included. Standalone script, no GHA workflow.
- **v2** (2026-04-07_225702): Included. Standalone script, no GHA workflow.
- **v3** (2026-04-08_192624): Included. Added GHA workflow + act execution.
- **v4** (2026-04-09_152435): Included. Final run before archival.

## Results

Results for all runs that included this task are preserved in their original
locations and remain part of the generated reports:

- `results/2026-04-09_152435/tasks/14-docker-image-tag-generator/` (v4)
- `results/2026-04-08_192624/tasks/14-docker-image-tag-generator/` (v3)
- `results/2026-04-07_225702/tasks/14-docker-image-tag-generator/` (v2)
- `results/2026-04-02_163146/tasks/14-docker-image-tag-generator/` (v1)

## Rationale for Removal

Task 14 was removed because it is redundant with Task 16 (Environment Matrix
Generator). A quantitative analysis of v4 results across all 8 model/mode
combinations found:

- **TQ (test quality) scores:** Average difference of only 0.38 points (on a
  1-5 scale) across all combos. 5 of 8 combos had identical scores. All diffs
  were within 1 point.
- **Cost profiles:** Spearman rank correlation rho = +0.143 (weakly correlated
  but not contradictory).
- **Duration profiles:** Spearman rank correlation rho = +0.476 (moderately
  correlated — the same combos tend to be fast/slow for both tasks).
- **Model preference:** Both favor Sonnet over Opus.
- **Combined redundancy score:** 0.781 (highest of any pair), using
  0.5*TQ_sim + 0.25*cost_sim + 0.25*dur_sim.

Both tasks are "generate structured output from configuration/inputs" problems.
Keeping Task 16 provides equivalent signal for benchmark comparisons.
