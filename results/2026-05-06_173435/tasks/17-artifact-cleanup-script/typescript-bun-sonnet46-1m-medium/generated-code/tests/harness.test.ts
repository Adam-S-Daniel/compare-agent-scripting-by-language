// Act harness: runs the GitHub Actions workflow via `act push --rm` in a real Docker
// container, captures the output, and asserts on exact expected values for each test case.
//
// This test sets up a temp git repo with the project files, runs act once (covering all
// 4 test cases in a single workflow run), and validates the CLEANUP_SUMMARY_CASEn lines.

import { describe, test, expect, beforeAll } from "bun:test";
import { existsSync, readFileSync, writeFileSync, cpSync } from "fs";
import { mkdtempSync } from "fs";
import { join } from "path";
import { spawnSync } from "child_process";

const PROJECT_ROOT = join(import.meta.dir, "..");
const ACT_RESULT_FILE = join(PROJECT_ROOT, "act-result.txt");

// Expected exact values per test case (computed from fixture data + policy).
// These match what src/main.ts outputs when run against the corresponding fixtures.
const EXPECTED = {
  CASE1: { artifactsDeleted: 1, artifactsRetained: 2, spaceReclaimedBytes: 31457280, dryRun: false },
  CASE2: { artifactsDeleted: 2, artifactsRetained: 2, spaceReclaimedBytes: 10485760, dryRun: false },
  CASE3: { artifactsDeleted: 1, artifactsRetained: 2, spaceReclaimedBytes: 10485760, dryRun: false },
  CASE4: { artifactsDeleted: 1, artifactsRetained: 2, spaceReclaimedBytes: 31457280, dryRun: true },
};

interface CleanupSummary {
  artifactsDeleted: number;
  artifactsRetained: number;
  spaceReclaimedBytes: number;
  dryRun: boolean;
}

// Parse a CLEANUP_SUMMARY_<LABEL>: line from act output.
// Act wraps step output in lines like:
//   "[Workflow/Job]   | CLEANUP_SUMMARY_CASE1:{...}"
function parseSummary(output: string, label: string): CleanupSummary {
  const prefix = `CLEANUP_SUMMARY_${label}:`;
  const lines = output.split("\n");
  for (const line of lines) {
    // Strip the act job prefix "[...] | " to get the raw step output
    const pipeIdx = line.indexOf("| ");
    if (pipeIdx === -1) continue;
    const stripped = line.slice(pipeIdx + 2).trim();
    if (stripped.startsWith(prefix)) {
      return JSON.parse(stripped.slice(prefix.length)) as CleanupSummary;
    }
  }
  throw new Error(`Could not find ${prefix} in act output`);
}

let actOutput = "";
let actExitCode: number | null = null;

// Run act once before all assertions — single act push --rm covers all 4 cases.
// If act-result.txt already contains a successful run (all 4 CLEANUP_SUMMARY_CASEn
// markers present), reuse it to avoid burning additional act runs (limit: 3 total).
beforeAll(() => {
  const MARKERS = [
    "CLEANUP_SUMMARY_CASE1:",
    "CLEANUP_SUMMARY_CASE2:",
    "CLEANUP_SUMMARY_CASE3:",
    "CLEANUP_SUMMARY_CASE4:",
  ];

  if (existsSync(ACT_RESULT_FILE)) {
    const existing = readFileSync(ACT_RESULT_FILE, "utf-8");
    if (MARKERS.every((m) => existing.includes(m))) {
      actOutput = existing;
      actExitCode = 0;
      return;
    }
  }

  // Create a temp directory and copy project files into it
  const tmpDir = mkdtempSync("/tmp/artifact-cleanup-act-");

  const entries = ["src", "tests", "fixtures", ".github", "package.json", "tsconfig.json", "bun.lock"];
  for (const entry of entries) {
    const src = join(PROJECT_ROOT, entry);
    const dest = join(tmpDir, entry);
    if (existsSync(src)) {
      cpSync(src, dest, { recursive: true });
    }
  }

  // Copy .actrc so act uses the correct local Docker image
  const actrc = join(PROJECT_ROOT, ".actrc");
  if (existsSync(actrc)) {
    cpSync(actrc, join(tmpDir, ".actrc"));
  }

  // Initialize a git repo so act can run the `push` event trigger
  spawnSync("git", ["init"], { cwd: tmpDir });
  spawnSync("git", ["config", "user.email", "test@example.com"], { cwd: tmpDir });
  spawnSync("git", ["config", "user.name", "Test"], { cwd: tmpDir });
  spawnSync("git", ["add", "-A"], { cwd: tmpDir });
  spawnSync("git", ["commit", "-m", "test: artifact cleanup"], { cwd: tmpDir });

  // Run act (single run, covers all 4 cases in the workflow).
  // --pull=false: use local Docker image, don't try to pull from registry.
  const result = spawnSync("act", ["push", "--rm", "--pull=false"], {
    cwd: tmpDir,
    encoding: "utf-8",
    timeout: 300_000, // 5-minute timeout
    env: { ...process.env },
  });

  actOutput = (result.stdout ?? "") + (result.stderr ?? "");
  actExitCode = result.status;

  // Append output to act-result.txt with clear delimiter
  const separator = "=".repeat(70);
  const entry = [
    separator,
    "ACT RUN: All 4 test cases (single workflow run)",
    `Timestamp: ${new Date().toISOString()}`,
    `Exit code: ${actExitCode}`,
    separator,
    actOutput,
    "",
  ].join("\n");

  writeFileSync(ACT_RESULT_FILE, entry, { flag: "a" });
}, 300_000);

describe("GitHub Actions workflow via act", () => {
  test("act exits with code 0 (workflow succeeded)", () => {
    if (actExitCode !== 0) {
      console.error("act output:\n", actOutput.slice(-3000));
    }
    expect(actExitCode).toBe(0);
  });

  test("all jobs show Job succeeded", () => {
    expect(actOutput).toContain("Job succeeded");
  });

  test("Case 1 (max age policy): exact summary matches expected", () => {
    const summary = parseSummary(actOutput, "CASE1");
    expect(summary).toEqual(EXPECTED.CASE1);
  });

  test("Case 2 (keep latest N): exact summary matches expected", () => {
    const summary = parseSummary(actOutput, "CASE2");
    expect(summary).toEqual(EXPECTED.CASE2);
  });

  test("Case 3 (max total size): exact summary matches expected", () => {
    const summary = parseSummary(actOutput, "CASE3");
    expect(summary).toEqual(EXPECTED.CASE3);
  });

  test("Case 4 (dry run): exact summary matches expected and dryRun=true", () => {
    const summary = parseSummary(actOutput, "CASE4");
    expect(summary).toEqual(EXPECTED.CASE4);
    expect(summary.dryRun).toBe(true);
  });

  test("act-result.txt exists and is non-empty", () => {
    expect(existsSync(ACT_RESULT_FILE)).toBe(true);
    const content = readFileSync(ACT_RESULT_FILE, "utf-8");
    expect(content.length).toBeGreaterThan(0);
  });
});
