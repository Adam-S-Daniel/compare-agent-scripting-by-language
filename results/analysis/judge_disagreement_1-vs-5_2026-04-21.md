# Judge disagreement: Haiku 1 vs Gemini 5 — follow-up review

*Date: 2026-04-21. Source report: [`results_2026-04-17_004319__2026-04-09_152435.md`](../results_2026-04-17_004319__2026-04-09_152435.md).*

The Judge Consistency Summary flagged three rows where Haiku 4.5 rated a
run `1/5` and Gemini 3.1 Pro rated the same run `5/5` — the maximum
possible cross-judge gap on the 1–5 scale. It recommended a human
review to decide whether Gemini's ceiling is hiding real defects Haiku
caught. This file is that review.

## Verdict

**Gemini was right on all three.** Haiku's `1`s are rooted in
specific, verifiable factual claims that are false. In each case
Haiku asserted that a required file was missing from the submission;
in each case that file is present under `generated-code/` and `act`
ran the workflow end-to-end to completion (`🏁 Job succeeded`).

| Run | Axis | Haiku | Gemini | Haiku's central claim | Verifiable? |
|-----|------|-------|--------|-----------------------|-------------|
| 14-docker-image-tag-generator / default / opus46-200k | Tests Quality | 1 | 5 | "Workflow YAML is not provided in submission" | **False** — `generated-code/.github/workflows/docker-image-tag-generator.yml` exists (229 lines). |
| 11-semantic-version-bumper / bash / sonnet46-200k | Workflow Craft | 1 | 5 | "Missing `tests/version_bumper.bats` — workflow fails on `act` execution" | **False** — the `.bats` file is present and `act` completed successfully with `🏁 Job succeeded`. |
| 12-pr-label-assigner / default / sonnet46-200k | Workflow Craft | 1 | 5 | "Workflow references non-existent `test_label_assigner.py` and `test_fixtures/` — will fail on execution" | **False** — both exist; `act` completed with all four labelling cases succeeding. |

## Evidence per run

### 14-docker-image-tag-generator / default / opus46-200k (Tests Quality)

Haiku's summary: *"References workflow file `.github/workflows/docker-image-tag-generator.yml` that is not provided in submission, making ~60% of tests unable to run."* It also claims the `PASS:` strings the tests assert on *"don't exist anywhere in the provided code."*

Workspace listing shows both file existence and where the strings come from:

```
generated-code/
  docker_tag_generator.py          (4.4 KB)
  run_tests.py                     (9.9 KB)
  .github/workflows/docker-image-tag-generator.yml   (229 lines)
```

The workflow emits `PASS:` lines directly (grep finds eight occurrences: `echo "PASS: latest tag present"` at line 84, `echo "PASS: sha tag present"` at lines 89/107/130/153/183, etc.) plus the summary line `echo "SUCCESS - All 9 test cases passed."` at line 229. The `act-result.txt` tail confirms end-to-end success:

```
[Docker Image Tag Generator/test] | SUCCESS - All 9 test cases passed.
[Docker Image Tag Generator/test] ✅  Success - Main All tests passed
[Docker Image Tag Generator/test] 🏁  Job succeeded
```

17 `PASS:` markers emitted across the 9 test cases. Haiku's `coverage=1, rigor=2, design=2, overall=1` verdict is grounded in files Haiku thought were absent.

### 11-semantic-version-bumper / bash / sonnet46-200k (Workflow Craft)

Haiku: *"Critical failure: missing `tests/version_bumper.bats`. Workflow references `bats tests/version_bumper.bats` but file not provided—workflow fails on `act` execution. … Workflow will fail at 'Run bats unit tests' step. Not shippable."*

Workspace listing:

```
generated-code/
  bump-version.sh
  run_act_tests.sh
  tests/version_bumper.bats   ← claimed missing
  fixtures/commits_{major,minor,patch,mixed,breaking_mixed}.txt
  .github/workflows/semantic-version-bumper.yml
```

`act-result.txt` tail:

```
[Semantic Version Bumper/Test Semantic Version Bumper] ✅  Success - Main Show generated changelog sample
[Semantic Version Bumper/Test Semantic Version Bumper] ⭐ Run Complete job
[Semantic Version Bumper/Test Semantic Version Bumper] 🏁  Job succeeded
```

Gemini separately noted the submission uses `set -euo pipefail` and regex-based parsing with no heavy external deps — accurate observations about code Haiku dismissed.

### 12-pr-label-assigner / default / sonnet46-200k (Workflow Craft)

Haiku: *"CRITICAL FAILURES: Workflow references non-existent `test_label_assigner.py` and `test_fixtures/` dirs; will fail on execution. Missing required `act-result.txt` artifact output. No actionlint validation step. No external test harness. Workflow would not run as-is."*

Workspace listing:

```
generated-code/
  label_assigner.py
  test_label_assigner.py          ← claimed missing
  run_tests.py                    ← external harness Haiku said was absent
  test_fixtures/case{1,2,3,4}/    ← claimed missing
  act-result.txt                  ← claimed absent
  .github/workflows/pr-label-assigner.yml
```

`act-result.txt` tail:

```
[PR Label Assigner/label-assigner] ✅ Success - Main Case 3: priority ordering (backend before api)
[PR Label Assigner/label-assigner] ✅ Success - Main Case 4: no matches → NONE
[PR Label Assigner/label-assigner] 🏁  Job succeeded
```

Every missing-file claim is contradicted by a visible file in the same directory Haiku was asked to judge. The one fair observation — "No actionlint validation step" — is a preference, not a critical failure, and doesn't warrant a floor score.

## What's going on with Haiku

Three span-4 runs, three missing-file hallucinations. A plausible mechanism: Haiku's prompt presented file paths relative to the task's root, but Haiku appears to have searched for them at literal paths like `.github/workflows/...` rather than under the per-run `generated-code/` subtree. Once it assumed a file was missing, the rest of its verdict cascaded — assertions were dismissed as unverifiable, requirements marked as unmet, the overall score floored. This is consistent with Haiku's broader floor-compressing pattern noted in the Judge Consistency Summary.

## Implications for the benchmark

- **Panel-mean score is still the right aggregate.** Gemini alone also has calibration issues (it tends toward 5 where 4 would be defensible); Haiku alone is obviously unusable on these three. The mean survives one bad read from either side.
- **Flagging span-4 rows is working.** The three rows the JCS surfaced are exactly the ones worth spot-checking; no other eyeball-worthy reversals were missed in the pooled data we reviewed.
- **Next mitigation.** If we can bound how often Haiku claims a present file is missing, we can either:
  - Add a pre-scoring sanity step: before asking the judge, verify file existence claims in its rationale against the workspace, and re-prompt when those claims mismatch.
  - Or drop Haiku's score when its rationale makes a testable factual claim that the workspace contradicts.

Either mitigation is cheaper than adding a third judge for adjudication, which was the JCS summary's original recommendation.
