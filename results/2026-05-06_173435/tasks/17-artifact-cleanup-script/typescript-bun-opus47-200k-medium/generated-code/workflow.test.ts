// End-to-end workflow tests: every assertion runs through `act`.
//
// For each test case we:
//   1. Set up a temp git repo with project files + the case's fixture data.
//   2. Run `act push --rm` with the appropriate variables.
//   3. Append the act output (clearly delimited) to act-result.txt.
//   4. Assert exit 0, "Job succeeded", and exact expected summary values.
//
// Also includes structural tests against the YAML and an actionlint check.

import { describe, test, expect, beforeAll, afterAll } from "bun:test";
import { mkdtempSync, rmSync, mkdirSync, cpSync, writeFileSync, appendFileSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";

const PROJECT_ROOT = resolve(import.meta.dir);
const ACT_RESULT_FILE = join(PROJECT_ROOT, "act-result.txt");
const WORKFLOW_PATH = join(PROJECT_ROOT, ".github/workflows/artifact-cleanup-script.yml");

// Fixed "now" so date-based assertions are reproducible regardless of when tests run.
const NOW_ISO = "2026-05-08T00:00:00Z";

interface ActRun {
  exitCode: number;
  stdout: string;
  stderr: string;
}

// Lazy-init a single act run per test case. Fresh worktree, fixture file, and vars per call.
function runAct(
  caseName: string,
  fixture: unknown,
  vars: Record<string, string>,
): ActRun {
  const work = mkdtempSync(join(tmpdir(), "act-cleanup-"));
  // Copy project files. We only need the cleanup source, package files, workflow, and fixtures dir.
  for (const f of ["cleanup.ts", "package.json", "tsconfig.json"]) {
    cpSync(join(PROJECT_ROOT, f), join(work, f));
  }
  // Use the default catthehacker image (ample tooling for setup-bun); skip the
  // workspace-level .actrc which pins to act-ubuntu-pwsh:latest (not built here).
  mkdirSync(join(work, ".github/workflows"), { recursive: true });
  cpSync(WORKFLOW_PATH, join(work, ".github/workflows/artifact-cleanup-script.yml"));
  // Copy unit tests so the workflow's `bun test` step has tests to run.
  cpSync(join(PROJECT_ROOT, "cleanup.test.ts"), join(work, "cleanup.test.ts"));
  // Write the case-specific fixture
  mkdirSync(join(work, "fixtures"), { recursive: true });
  writeFileSync(join(work, "fixtures/artifacts.json"), JSON.stringify(fixture, null, 2));
  // Init git repo so act push works
  spawnSync("git", ["init", "-q", "-b", "main"], { cwd: work });
  spawnSync("git", ["config", "user.email", "t@t"], { cwd: work });
  spawnSync("git", ["config", "user.name", "t"], { cwd: work });
  spawnSync("git", ["add", "-A"], { cwd: work });
  spawnSync("git", ["commit", "-q", "-m", "init"], { cwd: work });

  const varsArgs: string[] = [];
  for (const [k, v] of Object.entries(vars)) {
    varsArgs.push("--var", `${k}=${v}`);
  }
  const result = spawnSync("act", ["push", "--rm", "--pull=false", ...varsArgs], {
    cwd: work,
    encoding: "utf-8",
    timeout: 300_000,
  });
  rmSync(work, { recursive: true, force: true });

  const out = result.stdout ?? "";
  const err = result.stderr ?? "";
  appendFileSync(
    ACT_RESULT_FILE,
    `\n========== TEST CASE: ${caseName} ==========\n` +
      `EXIT: ${result.status}\nVARS: ${JSON.stringify(vars)}\n` +
      `--- STDOUT ---\n${out}\n--- STDERR ---\n${err}\n`,
  );
  return { exitCode: result.status ?? -1, stdout: out, stderr: err };
}

const FIXTURE = [
  { name: "build-old-1", sizeBytes: 1000, createdAt: "2025-01-01T00:00:00Z", workflowRunId: "wf-101" },
  { name: "build-recent-1", sizeBytes: 2000, createdAt: "2026-05-01T00:00:00Z", workflowRunId: "wf-200" },
  { name: "build-recent-2", sizeBytes: 2000, createdAt: "2026-05-02T00:00:00Z", workflowRunId: "wf-200" },
  { name: "build-recent-3", sizeBytes: 2000, createdAt: "2026-05-03T00:00:00Z", workflowRunId: "wf-200" },
  { name: "logs-1", sizeBytes: 500, createdAt: "2026-05-04T00:00:00Z", workflowRunId: "wf-300" },
];

describe("workflow structure", () => {
  test("YAML has expected triggers/jobs/steps", async () => {
    const t = await Bun.file(WORKFLOW_PATH).text();
    expect(t).toContain("name: Artifact Cleanup");
    expect(t).toContain("on:");
    expect(t).toMatch(/^\s*push:/m);
    expect(t).toMatch(/^\s*pull_request:/m);
    expect(t).toMatch(/^\s*workflow_dispatch:/m);
    expect(t).toMatch(/^\s*schedule:/m);
    expect(t).toMatch(/^\s+cleanup:/m);
    expect(t).toContain("actions/checkout@v4");
    expect(t).toMatch(/oven-sh\/setup-bun@/);
    expect(t).toContain("cleanup.ts");
    expect(t).toContain("bun test");
  });

  test("workflow references files that exist", () => {
    expect(existsSync(join(PROJECT_ROOT, "cleanup.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_ROOT, "fixtures/artifacts.json"))).toBe(true);
    expect(existsSync(join(PROJECT_ROOT, "package.json"))).toBe(true);
  });

  test("actionlint passes", () => {
    const r = spawnSync("actionlint", [WORKFLOW_PATH], { encoding: "utf-8" });
    if (r.status !== 0) {
      console.error("actionlint stdout:", r.stdout);
      console.error("actionlint stderr:", r.stderr);
    }
    expect(r.status).toBe(0);
  });
});

describe("act end-to-end", () => {
  beforeAll(() => {
    // Reset the act-result file at start of the run.
    writeFileSync(ACT_RESULT_FILE, `act-result.txt — generated ${new Date().toISOString()}\n`);
  });

  test(
    "case-1 dry-run with all policies (age + keep-2 + 5000 size cap)",
    () => {
      const r = runAct("case-1-dry-run", FIXTURE, {
        ARTIFACTS_FILE: "fixtures/artifacts.json",
        MAX_AGE_DAYS: "30",
        MAX_TOTAL_BYTES: "5000",
        KEEP_LATEST: "2",
        NOW_OVERRIDE: NOW_ISO,
      });
      expect(r.exitCode).toBe(0);
      expect(r.stdout).toContain("Job succeeded");
      expect(r.stdout).toContain("DRY RUN");
      // build-old-1 deleted by age, build-recent-1 deleted by keep-latest
      expect(r.stdout).toContain("Total artifacts: 5");
      expect(r.stdout).toContain("To delete:       2");
      expect(r.stdout).toContain("To retain:       3");
      expect(r.stdout).toContain("Bytes reclaimed: 3000");
      expect(r.stdout).toContain("Bytes retained:  4500");
      expect(r.stdout).toContain("build-old-1");
      expect(r.stdout).toContain("reason=age");
      expect(r.stdout).toContain("build-recent-1");
      expect(r.stdout).toContain("reason=keep-latest");
    },
    300_000,
  );

  test(
    "case-2 no deletions when policies are slack",
    () => {
      const r = runAct("case-2-no-deletions", FIXTURE, {
        ARTIFACTS_FILE: "fixtures/artifacts.json",
        MAX_AGE_DAYS: "1000",
        MAX_TOTAL_BYTES: "100000",
        KEEP_LATEST: "10",
        NOW_OVERRIDE: NOW_ISO,
      });
      expect(r.exitCode).toBe(0);
      expect(r.stdout).toContain("Job succeeded");
      expect(r.stdout).toContain("Total artifacts: 5");
      expect(r.stdout).toContain("To delete:       0");
      expect(r.stdout).toContain("To retain:       5");
      expect(r.stdout).toContain("Bytes reclaimed: 0");
      expect(r.stdout).toContain("Bytes retained:  7500");
    },
    300_000,
  );

  test(
    "case-3 strict policies trigger size cap deletions",
    () => {
      const r = runAct("case-3-size-cap", FIXTURE, {
        ARTIFACTS_FILE: "fixtures/artifacts.json",
        MAX_AGE_DAYS: "10",
        MAX_TOTAL_BYTES: "2000",
        KEEP_LATEST: "10",
        NOW_OVERRIDE: NOW_ISO,
      });
      expect(r.exitCode).toBe(0);
      expect(r.stdout).toContain("Job succeeded");
      // build-old-1 by age. Then size cap drops oldest survivors:
      //   recent-1 (7d, 2000) -> 4500 still > 2000
      //   recent-2 (6d, 2000) -> 2500 still > 2000
      //   recent-3 (5d, 2000) -> 500 ≤ 2000  ✓
      // logs-1 (4d, 500) survives. 4 deleted, 1 retained.
      expect(r.stdout).toContain("Total artifacts: 5");
      expect(r.stdout).toContain("To delete:       4");
      expect(r.stdout).toContain("To retain:       1");
      expect(r.stdout).toContain("Bytes reclaimed: 7000");
      expect(r.stdout).toContain("Bytes retained:  500");
    },
    300_000,
  );
});
