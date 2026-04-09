#!/usr/bin/env bun
// Test harness: validates the workflow structure and runs each test case
// through act, asserting exact expected values in the output.

import { execSync } from "child_process";
import {
  mkdtempSync,
  mkdirSync,
  cpSync,
  writeFileSync,
  appendFileSync,
  readFileSync,
  existsSync,
} from "fs";
import { join, resolve } from "path";
import { tmpdir } from "os";

// ── Paths ───────────────────────────────────────────────────────────
const PROJECT_DIR = resolve(import.meta.dir);
const RESULT_FILE = join(PROJECT_DIR, "act-result.txt");
const WORKFLOW_PATH = join(
  PROJECT_DIR,
  ".github/workflows/artifact-cleanup-script.yml"
);

// ── Counters ────────────────────────────────────────────────────────
let passed = 0;
let failed = 0;

function assert(condition: boolean, message: string): void {
  if (condition) {
    console.log(`  ✅ PASS: ${message}`);
    passed++;
  } else {
    console.error(`  ❌ FAIL: ${message}`);
    failed++;
  }
}

// ── Initialize result file ──────────────────────────────────────────
writeFileSync(
  RESULT_FILE,
  "=== Artifact Cleanup Script — Act Test Results ===\n\n"
);

// =====================================================================
// PART 1: WORKFLOW STRUCTURE TESTS
// =====================================================================
console.log("\n═══ Workflow Structure Tests ═══\n");

const yamlContent = readFileSync(WORKFLOW_PATH, "utf-8");

// Check triggers
assert(yamlContent.includes("push:"), "Workflow has push trigger");
assert(yamlContent.includes("pull_request:"), "Workflow has pull_request trigger");
assert(yamlContent.includes("workflow_dispatch:"), "Workflow has workflow_dispatch trigger");
assert(yamlContent.includes("schedule:"), "Workflow has schedule trigger");
assert(yamlContent.includes("cron:"), "Workflow has cron schedule");

// Check jobs and steps
assert(yamlContent.includes("test-and-run:"), "Workflow has test-and-run job");
assert(yamlContent.includes("actions/checkout@v4"), "Workflow uses actions/checkout@v4");
assert(yamlContent.includes("oven-sh/setup-bun@v2"), "Workflow uses oven-sh/setup-bun@v2");
assert(yamlContent.includes("bun test"), "Workflow runs bun test");
assert(yamlContent.includes("bun run src/main.ts"), "Workflow runs the cleanup script");

// Verify referenced files exist
assert(existsSync(join(PROJECT_DIR, "src/main.ts")), "src/main.ts exists");
assert(existsSync(join(PROJECT_DIR, "src/cleanup.ts")), "src/cleanup.ts exists");
assert(existsSync(join(PROJECT_DIR, "src/cleanup.test.ts")), "src/cleanup.test.ts exists");
assert(existsSync(join(PROJECT_DIR, "input.json")), "input.json exists");

// actionlint validation
try {
  execSync(`actionlint ${WORKFLOW_PATH}`, { encoding: "utf-8" });
  assert(true, "actionlint passes with exit code 0");
} catch {
  assert(false, "actionlint passes with exit code 0");
}

appendFileSync(
  RESULT_FILE,
  `=== Workflow Structure Tests ===\nPassed: ${passed}, Failed: ${failed}\n\n`
);

// =====================================================================
// PART 2: ACT TEST CASES
// =====================================================================

interface TestCase {
  name: string;
  input: object;
  assertions: (output: string) => void;
}

const testCases: TestCase[] = [
  // ── Test 1: Max Age Policy ───────────────────────────────────────
  {
    name: "max-age-policy",
    input: {
      artifacts: [
        { name: "recent-build", sizeBytes: 104857600, createdAt: "2026-04-01T00:00:00Z", workflowRunId: "run-100" },
        { name: "old-build", sizeBytes: 209715200, createdAt: "2026-03-01T00:00:00Z", workflowRunId: "run-90" },
        { name: "ancient-build", sizeBytes: 314572800, createdAt: "2026-02-01T00:00:00Z", workflowRunId: "run-50" },
      ],
      policy: { maxAgeDays: 30 },
      referenceDate: "2026-04-09T00:00:00Z",
    },
    assertions(output: string) {
      assert(output.includes("Mode: EXECUTE"), "Mode is EXECUTE");
      assert(output.includes("Artifacts to delete: 2"), "Deletes exactly 2 artifacts");
      assert(output.includes("Artifacts to retain: 1"), "Retains exactly 1 artifact");
      assert(output.includes("Space reclaimed: 500.0 MB"), "Reclaims exactly 500.0 MB");
      assert(output.includes("Space retained: 100.0 MB"), "Retains exactly 100.0 MB");
      assert(output.includes("old-build"), "old-build listed for deletion");
      assert(output.includes("ancient-build"), "ancient-build listed for deletion");
      assert(output.includes("[reason: max_age]"), "Reason is max_age");
    },
  },

  // ── Test 2: Keep-Latest-N Policy ─────────────────────────────────
  {
    name: "keep-latest-n-policy",
    input: {
      artifacts: [
        { name: "build-3", sizeBytes: 104857600, createdAt: "2026-04-03T00:00:00Z", workflowRunId: "build" },
        { name: "build-2", sizeBytes: 104857600, createdAt: "2026-04-02T00:00:00Z", workflowRunId: "build" },
        { name: "build-1", sizeBytes: 104857600, createdAt: "2026-04-01T00:00:00Z", workflowRunId: "build" },
        { name: "test-2", sizeBytes: 104857600, createdAt: "2026-04-03T00:00:00Z", workflowRunId: "test" },
        { name: "test-1", sizeBytes: 104857600, createdAt: "2026-04-01T00:00:00Z", workflowRunId: "test" },
      ],
      policy: { keepLatestN: 1 },
      referenceDate: "2026-04-09T00:00:00Z",
    },
    assertions(output: string) {
      assert(output.includes("Artifacts to delete: 3"), "Deletes exactly 3 artifacts");
      assert(output.includes("Artifacts to retain: 2"), "Retains exactly 2 artifacts");
      assert(output.includes("Space reclaimed: 300.0 MB"), "Reclaims exactly 300.0 MB");
      assert(output.includes("Space retained: 200.0 MB"), "Retains exactly 200.0 MB");
      assert(output.includes("[reason: keep_latest_n]"), "Reason is keep_latest_n");
    },
  },

  // ── Test 3: Max Total Size Policy ────────────────────────────────
  {
    name: "max-total-size-policy",
    input: {
      artifacts: [
        { name: "newest", sizeBytes: 209715200, createdAt: "2026-04-08T00:00:00Z", workflowRunId: "run-1" },
        { name: "middle", sizeBytes: 157286400, createdAt: "2026-04-06T00:00:00Z", workflowRunId: "run-2" },
        { name: "older", sizeBytes: 262144000, createdAt: "2026-04-04T00:00:00Z", workflowRunId: "run-3" },
        { name: "oldest", sizeBytes: 314572800, createdAt: "2026-04-02T00:00:00Z", workflowRunId: "run-4" },
      ],
      policy: { maxTotalSizeBytes: 524288000 },
      referenceDate: "2026-04-09T00:00:00Z",
    },
    assertions(output: string) {
      assert(output.includes("Artifacts to delete: 2"), "Deletes exactly 2 artifacts");
      assert(output.includes("Artifacts to retain: 2"), "Retains exactly 2 artifacts");
      assert(output.includes("Space reclaimed: 550.0 MB"), "Reclaims exactly 550.0 MB");
      assert(output.includes("Space retained: 350.0 MB"), "Retains exactly 350.0 MB");
      assert(output.includes("[reason: max_total_size]"), "Reason is max_total_size");
      assert(output.includes("oldest"), "oldest artifact listed for deletion");
      assert(output.includes("older"), "older artifact listed for deletion");
    },
  },

  // ── Test 4: Combined Policies + Dry-Run ──────────────────────────
  {
    name: "combined-dry-run",
    input: {
      artifacts: [
        { name: "build-new", sizeBytes: 104857600, createdAt: "2026-04-08T00:00:00Z", workflowRunId: "build" },
        { name: "build-old", sizeBytes: 209715200, createdAt: "2026-02-01T00:00:00Z", workflowRunId: "build" },
        { name: "test-new", sizeBytes: 157286400, createdAt: "2026-04-07T00:00:00Z", workflowRunId: "test" },
        { name: "test-old", sizeBytes: 314572800, createdAt: "2026-03-01T00:00:00Z", workflowRunId: "test" },
      ],
      policy: { maxAgeDays: 30, keepLatestN: 1, dryRun: true },
      referenceDate: "2026-04-09T00:00:00Z",
    },
    assertions(output: string) {
      assert(output.includes("Mode: DRY-RUN"), "Mode is DRY-RUN");
      assert(output.includes("Artifacts to delete: 2"), "Deletes exactly 2 artifacts");
      assert(output.includes("Artifacts to retain: 2"), "Retains exactly 2 artifacts");
      assert(output.includes("Space reclaimed: 500.0 MB"), "Reclaims exactly 500.0 MB");
      assert(output.includes("Space retained: 250.0 MB"), "Retains exactly 250.0 MB");
      assert(output.includes("build-old"), "build-old listed for deletion");
      assert(output.includes("test-old"), "test-old listed for deletion");
    },
  },
];

/**
 * Set up a temporary git repo with the project files and a specific
 * fixture's input.json, then run act push --rm and return stdout+stderr.
 */
function runActTestCase(tc: TestCase): { output: string; exitCode: number } {
  const dir = mkdtempSync(join(tmpdir(), `act-${tc.name}-`));

  // Copy project files
  cpSync(join(PROJECT_DIR, "src"), join(dir, "src"), { recursive: true });
  mkdirSync(join(dir, ".github/workflows"), { recursive: true });
  cpSync(WORKFLOW_PATH, join(dir, ".github/workflows/artifact-cleanup-script.yml"));
  cpSync(join(PROJECT_DIR, "package.json"), join(dir, "package.json"));
  cpSync(join(PROJECT_DIR, "tsconfig.json"), join(dir, "tsconfig.json"));

  // Write the test-case-specific fixture
  writeFileSync(join(dir, "input.json"), JSON.stringify(tc.input, null, 2));

  // Initialize git repo (checkout action needs it)
  execSync(
    `cd "${dir}" && git init -b main && git config user.email "test@test.com" && git config user.name "Test" && git add -A && git commit -m "test setup"`,
    { stdio: "pipe" }
  );

  // Run act
  let output = "";
  let exitCode = 0;
  try {
    output = execSync(
      `cd "${dir}" && act push --rm -P ubuntu-latest=catthehacker/ubuntu:act-latest 2>&1`,
      { encoding: "utf-8", timeout: 300_000, maxBuffer: 10 * 1024 * 1024 }
    );
  } catch (err: unknown) {
    const execErr = err as { status?: number; stdout?: string; stderr?: string; output?: string[] };
    exitCode = execErr.status ?? 1;
    output = (execErr.stdout ?? "") + (execErr.stderr ?? "");
  }

  return { output, exitCode };
}

// ── Run each test case ──────────────────────────────────────────────
for (const tc of testCases) {
  console.log(`\n═══ Act Test: ${tc.name} ═══\n`);
  appendFileSync(RESULT_FILE, `\n${"=".repeat(60)}\n=== Act Test: ${tc.name} ===\n${"=".repeat(60)}\n`);

  const { output, exitCode } = runActTestCase(tc);
  appendFileSync(RESULT_FILE, output + "\n");

  // Common assertions
  assert(exitCode === 0, `act exited with code 0 (got ${exitCode})`);
  assert(output.includes("Job succeeded"), "Job succeeded");
  assert(output.includes("0 fail"), "All bun tests passed (0 fail)");

  // Test-case-specific assertions
  tc.assertions(output);
}

// ── Final report ────────────────────────────────────────────────────
const total = passed + failed;
const summary = `\n${"=".repeat(60)}\n=== Final Results: ${passed}/${total} passed, ${failed} failed ===\n${"=".repeat(60)}\n`;
console.log(summary);
appendFileSync(RESULT_FILE, summary);

if (failed > 0) {
  process.exit(1);
}
