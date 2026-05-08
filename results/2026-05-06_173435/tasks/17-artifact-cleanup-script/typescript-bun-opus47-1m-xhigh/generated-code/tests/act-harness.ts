#!/usr/bin/env bun
// End-to-end act harness.
//
// For each scenario:
//   1. Materialize a temp git repo containing the project files + that
//      scenario's fixture data.
//   2. Run `act push --rm` against the repo, capturing stdout + stderr.
//   3. Append the captured output to act-result.txt with a clear delimiter.
//   4. Assert act exited 0, that every job reports "Job succeeded", and
//      that the captured output contains the exact expected substrings
//      defined for that scenario.
//
// The harness is deliberately self-contained — it can be invoked manually
// (`bun run tests/act-harness.ts`) and also doubles as a CI gate.
//
// IMPORTANT: each scenario triggers exactly one `act push` invocation; the
// harness ships with three scenarios so the total cost is exactly 3 act
// runs, matching the budget called out in the task spec.

import {
  copyFileSync,
  cpSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = resolve(__dirname, "..");
const RESULT_FILE = join(PROJECT_ROOT, "act-result.txt");

interface Scenario {
  name: string;
  description: string;
  artifacts: unknown[];
  config: Record<string, unknown>;
  expected: {
    substrings: string[];
    minJobsSucceeded: number;
  };
}

// Scenarios cover: APPLY mode with mixed evictions, DRY-RUN mode, and a
// no-op case where lenient policies retain everything.
const NOW_ISO = "2026-05-07T12:00:00.000Z";

const SCENARIOS: Scenario[] = [
  {
    name: "01-mixed-policies-apply",
    description:
      "All three policies active: max-age evicts very old, keep-latest-N trims surplus per workflow.",
    artifacts: [
      {
        id: "art-old-A",
        name: "build-output",
        sizeBytes: 1500,
        createdAt: "2026-02-01T00:00:00.000Z",
        workflowRunId: "wf-A",
      },
      {
        id: "art-mid-A",
        name: "build-output",
        sizeBytes: 1200,
        createdAt: "2026-04-20T00:00:00.000Z",
        workflowRunId: "wf-A",
      },
      {
        id: "art-new-A",
        name: "build-output",
        sizeBytes: 1100,
        createdAt: "2026-05-05T00:00:00.000Z",
        workflowRunId: "wf-A",
      },
      {
        id: "art-newest-A",
        name: "build-output",
        sizeBytes: 1300,
        createdAt: "2026-05-06T00:00:00.000Z",
        workflowRunId: "wf-A",
      },
      {
        id: "art-B-only",
        name: "test-results",
        sizeBytes: 800,
        createdAt: "2026-05-01T00:00:00.000Z",
        workflowRunId: "wf-B",
      },
    ],
    config: {
      input: "fixtures/artifacts.json",
      now: NOW_ISO,
      maxAgeDays: 30,
      maxTotalSizeBytes: 5000,
      keepLatestN: 2,
      dryRun: false,
    },
    expected: {
      // Stage 1 (max-age 30d, threshold 2026-04-07): evicts art-old-A.
      // Stage 2 (size cap 5000B, total 4400B remaining): no evictions.
      // Stage 3 (keep-latest-N=2 per workflow): wf-A trims to [newest, new] ->
      //   evicts art-mid-A. wf-B has 1 artifact, kept.
      // Final: 2 deleted (art-old-A + art-mid-A), 3 retained.
      substrings: [
        "MODE: APPLY",
        "total_artifacts=5",
        "retained_count=3",
        "deleted_count=2",
        "space_reclaimed_bytes=2700",
        "space_retained_bytes=3200",
        "reasons=max-age=1,keep-latest-n=1",
        "art-old-A",
        "art-mid-A",
      ],
      minJobsSucceeded: 2,
    },
  },
  {
    name: "02-dry-run-mode",
    description:
      "Same artifacts, dry-run flag flips header & verb without touching counts.",
    artifacts: [
      {
        id: "old-1",
        name: "build",
        sizeBytes: 500,
        createdAt: "2025-12-01T00:00:00.000Z",
        workflowRunId: "wf-X",
      },
      {
        id: "old-2",
        name: "build",
        sizeBytes: 600,
        createdAt: "2025-11-01T00:00:00.000Z",
        workflowRunId: "wf-X",
      },
      {
        id: "fresh-1",
        name: "build",
        sizeBytes: 700,
        createdAt: "2026-05-06T00:00:00.000Z",
        workflowRunId: "wf-X",
      },
    ],
    config: {
      input: "fixtures/artifacts.json",
      now: NOW_ISO,
      maxAgeDays: 30,
      dryRun: true,
    },
    expected: {
      // 2 artifacts older than 30 days -> both flagged for deletion.
      substrings: [
        "MODE: DRY-RUN",
        "would delete",
        "total_artifacts=3",
        "retained_count=1",
        "deleted_count=2",
        "space_reclaimed_bytes=1100",
        "space_retained_bytes=700",
        "reasons=max-age=2",
      ],
      minJobsSucceeded: 2,
    },
  },
  {
    name: "03-noop-everything-fits",
    description:
      "Lenient policies on a small fixture: nothing to delete, summary shows zero reclamation.",
    artifacts: [
      {
        id: "k1",
        name: "build",
        sizeBytes: 200,
        createdAt: "2026-05-05T00:00:00.000Z",
        workflowRunId: "wf-Z",
      },
      {
        id: "k2",
        name: "build",
        sizeBytes: 300,
        createdAt: "2026-05-04T00:00:00.000Z",
        workflowRunId: "wf-Z",
      },
    ],
    config: {
      input: "fixtures/artifacts.json",
      now: NOW_ISO,
      maxAgeDays: 365,
      maxTotalSizeBytes: 1000000,
      keepLatestN: 10,
      dryRun: false,
    },
    expected: {
      substrings: [
        "MODE: APPLY",
        "total_artifacts=2",
        "retained_count=2",
        "deleted_count=0",
        "space_reclaimed_bytes=0",
        "space_retained_bytes=500",
        "reasons=none",
      ],
      minJobsSucceeded: 2,
    },
  },
];

function copyProjectInto(target: string): void {
  // Files & dirs the workflow needs at runtime. We deliberately exclude
  // node_modules (act re-installs) and any prior act-result.txt.
  const files = [
    "package.json",
    "bun.lock",
    "tsconfig.json",
    ".actrc",
  ];
  for (const f of files) {
    const src = join(PROJECT_ROOT, f);
    if (existsSync(src)) copyFileSync(src, join(target, f));
  }
  const dirs = ["src", "tests", ".github"];
  for (const d of dirs) {
    cpSync(join(PROJECT_ROOT, d), join(target, d), { recursive: true });
  }
}

function writeFixturesInto(target: string, scenario: Scenario): void {
  const fixturesDir = join(target, "fixtures");
  mkdirSync(fixturesDir, { recursive: true });
  writeFileSync(
    join(fixturesDir, "artifacts.json"),
    JSON.stringify(scenario.artifacts, null, 2),
    "utf8",
  );
  writeFileSync(
    join(fixturesDir, "cleanup.config.json"),
    JSON.stringify(scenario.config, null, 2),
    "utf8",
  );
}

function gitInit(target: string): void {
  // act needs a git repo; minimal init + commit covers it.
  const run = (args: string[]): void => {
    const r = spawnSync("git", args, { cwd: target, encoding: "utf8" });
    if (r.status !== 0) {
      throw new Error(
        `git ${args.join(" ")} failed (status=${r.status}): ${r.stderr}`,
      );
    }
  };
  run(["init", "-q", "-b", "main"]);
  run(["config", "user.email", "harness@example.com"]);
  run(["config", "user.name", "harness"]);
  run(["add", "-A"]);
  run(["commit", "-q", "-m", "harness fixture"]);
}

function setupRepoForScenario(scenario: Scenario): string {
  const tmp = mkdtempSync(join(tmpdir(), `act-cleanup-${scenario.name}-`));
  copyProjectInto(tmp);
  writeFixturesInto(tmp, scenario);
  gitInit(tmp);
  return tmp;
}

function runAct(repoDir: string): {
  code: number;
  combined: string;
} {
  // --pull=false: the .actrc points to a locally-built image
  // (act-ubuntu-pwsh:latest) that has no upstream registry. Without this
  // flag, act's default forcePull=true makes the docker daemon try to pull
  // and fail with 'pull access denied'.
  const result = spawnSync("act", ["push", "--rm", "--pull=false"], {
    cwd: repoDir,
    encoding: "utf8",
    // 5 minute cap matches the workflow's own timeout-minutes.
    timeout: 5 * 60 * 1000,
    maxBuffer: 50 * 1024 * 1024,
  });
  const stdout = result.stdout ?? "";
  const stderr = result.stderr ?? "";
  return {
    code: result.status ?? -1,
    combined: stdout + (stderr ? `\n--- stderr ---\n${stderr}` : ""),
  };
}

function appendResult(name: string, code: number, output: string): void {
  const block = [
    `===== TEST CASE: ${name} =====`,
    output,
    `===== END: ${name} (act exit=${code}) =====`,
    "",
    "",
  ].join("\n");
  // Read existing, append, write — keeps the file atomic-ish on small sizes.
  const prior = existsSync(RESULT_FILE) ? readFileSync(RESULT_FILE, "utf8") : "";
  writeFileSync(RESULT_FILE, prior + block, "utf8");
}

function checkScenario(
  scenario: Scenario,
  code: number,
  output: string,
): string[] {
  const failures: string[] = [];
  if (code !== 0) {
    failures.push(`act exited with code ${code} (expected 0)`);
  }
  // act prints "Job succeeded" once per job. We need at least the configured
  // minimum number of "Job succeeded" lines.
  const matches = output.match(/Job succeeded/g) ?? [];
  if (matches.length < scenario.expected.minJobsSucceeded) {
    failures.push(
      `expected >= ${scenario.expected.minJobsSucceeded} 'Job succeeded' lines, got ${matches.length}`,
    );
  }
  for (const needle of scenario.expected.substrings) {
    if (!output.includes(needle)) {
      failures.push(`output missing expected substring: '${needle}'`);
    }
  }
  return failures;
}

async function main(): Promise<number> {
  // Reset result file so each harness invocation gets a clean record.
  writeFileSync(RESULT_FILE, "", "utf8");

  let passed = 0;
  let failed = 0;
  const failureSummary: string[] = [];

  for (const scenario of SCENARIOS) {
    console.log(`\n>>> scenario ${scenario.name}: ${scenario.description}`);
    let repo: string | undefined;
    try {
      repo = setupRepoForScenario(scenario);
      const { code, combined } = runAct(repo);
      appendResult(scenario.name, code, combined);
      const failures = checkScenario(scenario, code, combined);
      if (failures.length === 0) {
        console.log(`PASS ${scenario.name}`);
        passed += 1;
      } else {
        console.log(`FAIL ${scenario.name}`);
        for (const f of failures) console.log(`    - ${f}`);
        failureSummary.push(`${scenario.name}: ${failures.join("; ")}`);
        failed += 1;
      }
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      console.log(`ERROR ${scenario.name}: ${msg}`);
      failureSummary.push(`${scenario.name}: ${msg}`);
      failed += 1;
    } finally {
      if (repo) rmSync(repo, { recursive: true, force: true });
    }
  }

  console.log(`\nTotals: ${passed} passed, ${failed} failed.`);
  if (failed > 0) {
    console.log("Failure summary:");
    for (const line of failureSummary) console.log(`  - ${line}`);
    return 1;
  }
  return 0;
}

const code = await main();
process.exit(code);
