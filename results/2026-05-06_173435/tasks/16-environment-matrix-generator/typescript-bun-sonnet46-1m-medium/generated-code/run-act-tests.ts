// Act test harness for the Environment Matrix Generator.
// Runs the GitHub Actions workflow via act and asserts on exact expected values.
// Usage: bun run run-act-tests.ts
// Output: act-result.txt (appended with each test case's output)

import { mkdtempSync, cpSync, writeFileSync, appendFileSync, existsSync } from "node:fs";
import { join, resolve } from "node:path";

const CWD = resolve(import.meta.dir);
const ACT_RESULT_FILE = join(CWD, "act-result.txt");

function log(msg: string) {
  console.log(msg);
}

function appendResult(content: string) {
  appendFileSync(ACT_RESULT_FILE, content + "\n");
}

function assert(condition: boolean, message: string) {
  if (!condition) {
    const err = `ASSERTION FAILED: ${message}`;
    appendResult(err);
    console.error(err);
    process.exit(1);
  }
}

// ── Workflow structure tests (run on host before act) ─────────────────────────

log("=== Workflow structure tests ===");

const WORKFLOW_PATH = join(CWD, ".github/workflows/environment-matrix-generator.yml");
assert(existsSync(WORKFLOW_PATH), "Workflow file exists");
log("✓ Workflow file exists");

const workflowContent = Bun.file(WORKFLOW_PATH).toString();

// Read synchronously
const wfText = (() => {
  const result = Bun.spawnSync(["cat", WORKFLOW_PATH]);
  return new TextDecoder().decode(result.stdout);
})();

assert(wfText.includes("push:"), "Workflow has push trigger");
log("✓ Workflow has push trigger");

assert(wfText.includes("pull_request:"), "Workflow has pull_request trigger");
log("✓ Workflow has pull_request trigger");

assert(wfText.includes("workflow_dispatch:"), "Workflow has workflow_dispatch trigger");
log("✓ Workflow has workflow_dispatch trigger");

assert(wfText.includes("jobs:"), "Workflow has jobs section");
log("✓ Workflow has jobs section");

assert(wfText.includes("bun test"), "Workflow runs bun test");
log("✓ Workflow runs bun test");

assert(wfText.includes("src/main.ts"), "Workflow references main script");
log("✓ Workflow references main script");

assert(existsSync(join(CWD, "src/main.ts")), "src/main.ts exists");
log("✓ src/main.ts exists");

assert(existsSync(join(CWD, "src/matrix-generator.ts")), "src/matrix-generator.ts exists");
log("✓ src/matrix-generator.ts exists");

// Run actionlint
const alResult = Bun.spawnSync(["actionlint", WORKFLOW_PATH]);
const alStderr = new TextDecoder().decode(alResult.stderr ?? new Uint8Array());
assert(alResult.exitCode === 0, `actionlint passes (exit ${alResult.exitCode}): ${alStderr}`);
log("✓ actionlint passes");

log("");

// ── Act test run ───────────────────────────────────────────────────────────────

// Initialize the act-result.txt file
writeFileSync(ACT_RESULT_FILE, `=== Act Test Results ===\nDate: ${new Date().toISOString()}\n\n`);

// Files to copy from the project root
const PROJECT_FILES = [
  "src",
  "fixtures",
  ".github",
];

// ── Test case 1: All fixtures (single act run covers all test cases) ──────────

log("=== Test case: Full workflow run (all fixtures) ===");
appendResult("=== TEST CASE: Full workflow run (all fixtures) ===");

// Create temp directory
const tmpDir = mkdtempSync("/tmp/matrix-gen-test-");
log(`Temp dir: ${tmpDir}`);

// Copy project files
for (const item of PROJECT_FILES) {
  const src = join(CWD, item);
  const dst = join(tmpDir, item);
  if (existsSync(src)) {
    cpSync(src, dst, { recursive: true });
  }
}

// Copy .actrc so act uses the correct container image
const actrcSrc = join(CWD, ".actrc");
if (existsSync(actrcSrc)) {
  cpSync(actrcSrc, join(tmpDir, ".actrc"));
}

// Initialize git repo
function git(args: string[], cwd: string): { exitCode: number; stdout: string; stderr: string } {
  const r = Bun.spawnSync(["git", ...args], { cwd });
  return {
    exitCode: r.exitCode ?? 1,
    stdout: new TextDecoder().decode(r.stdout ?? new Uint8Array()),
    stderr: new TextDecoder().decode(r.stderr ?? new Uint8Array()),
  };
}

git(["init"], tmpDir);
git(["config", "user.email", "test@test.com"], tmpDir);
git(["config", "user.name", "Test"], tmpDir);
git(["add", "-A"], tmpDir);
git(["commit", "-m", "test: add matrix generator"], tmpDir);

log("Running act push --rm (this may take 30-90 seconds)...");

const actProc = Bun.spawnSync(
  ["act", "push", "--rm", "--pull=false"],
  {
    cwd: tmpDir,
    timeout: 600_000, // 10 minutes
  }
);

const actStdout = new TextDecoder().decode(actProc.stdout ?? new Uint8Array());
const actStderr = new TextDecoder().decode(actProc.stderr ?? new Uint8Array());
const actOutput = actStdout + actStderr;

appendResult(`--- act stdout ---\n${actStdout}`);
appendResult(`--- act stderr ---\n${actStderr}`);
appendResult(`--- act exit code: ${actProc.exitCode} ---`);

log(`Act exit code: ${actProc.exitCode}`);
if (actProc.exitCode !== 0) {
  log("Act output (last 100 lines):");
  const lines = actOutput.split("\n");
  log(lines.slice(-100).join("\n"));
}

// ── Assertions on act output ─────────────────────────────────────────────────

assert(actProc.exitCode === 0, `act exited with code 0 (got ${actProc.exitCode})`);
log("✓ act exited with code 0");

// Every job must succeed
assert(
  actOutput.includes("Job succeeded"),
  "act output contains 'Job succeeded'"
);
log("✓ at least one job succeeded");

// Check that the test job succeeded (look for success markers)
const testJobSucceeded =
  actOutput.includes("Run unit tests") &&
  (actOutput.includes("Job succeeded") || actOutput.includes("✅"));
assert(testJobSucceeded, "test job succeeded");
log("✓ test job succeeded");

// ── Assert exact expected values for each fixture ────────────────────────────

// Helper: extract the MATRIX_RESULT output for a named fixture
function extractMatrixResult(output: string, name: string): Record<string, unknown> | null {
  const prefix = `MATRIX_RESULT[${name}]:`;
  const lines = output.split("\n");
  for (const line of lines) {
    const idx = line.indexOf(prefix);
    if (idx !== -1) {
      const jsonPart = line.slice(idx + prefix.length).trim();
      // Extract JSON — it may be prefixed with ANSI codes or pipe characters
      const jsonStart = jsonPart.indexOf("{");
      if (jsonStart !== -1) {
        try {
          return JSON.parse(jsonPart.slice(jsonStart));
        } catch {
          // try stripping trailing non-JSON
        }
      }
    }
  }
  return null;
}

// Test case: basic fixture → 4 combinations
const basicResult = extractMatrixResult(actOutput, "basic");
assert(basicResult !== null, "basic matrix result found in act output");
log("✓ basic matrix result found in act output");
assert(
  (basicResult as any).totalCombinations === 4,
  `basic totalCombinations === 4 (got ${(basicResult as any)?.totalCombinations})`
);
log(`✓ basic totalCombinations = 4`);
assert(
  (basicResult as any).effectiveCombinations === 4,
  `basic effectiveCombinations === 4 (got ${(basicResult as any)?.effectiveCombinations})`
);
log(`✓ basic effectiveCombinations = 4`);

// Test case: with-excludes → 3 effective combinations
const excludesResult = extractMatrixResult(actOutput, "with-excludes");
assert(excludesResult !== null, "with-excludes matrix result found in act output");
log("✓ with-excludes matrix result found in act output");
assert(
  (excludesResult as any).effectiveCombinations === 3,
  `with-excludes effectiveCombinations === 3 (got ${(excludesResult as any)?.effectiveCombinations})`
);
log(`✓ with-excludes effectiveCombinations = 3`);

// Test case: with-includes → 2 effective combinations
const includesResult = extractMatrixResult(actOutput, "with-includes");
assert(includesResult !== null, "with-includes matrix result found in act output");
log("✓ with-includes matrix result found in act output");
assert(
  (includesResult as any).effectiveCombinations === 2,
  `with-includes effectiveCombinations === 2 (got ${(includesResult as any)?.effectiveCombinations})`
);
log(`✓ with-includes effectiveCombinations = 2`);

// Test case: max-parallel → max-parallel=2, fail-fast=false
const maxParallelResult = extractMatrixResult(actOutput, "max-parallel");
assert(maxParallelResult !== null, "max-parallel matrix result found in act output");
log("✓ max-parallel matrix result found in act output");
assert(
  (maxParallelResult as any)["max-parallel"] === 2,
  `max-parallel['max-parallel'] === 2 (got ${(maxParallelResult as any)?.["max-parallel"]})`
);
log(`✓ max-parallel['max-parallel'] = 2`);
assert(
  (maxParallelResult as any)["fail-fast"] === false,
  `max-parallel['fail-fast'] === false (got ${(maxParallelResult as any)?.["fail-fast"]})`
);
log(`✓ max-parallel['fail-fast'] = false`);

// All assertions passed
appendResult("\n=== ALL ASSERTIONS PASSED ===");
log("\n✓ ALL ACT TEST ASSERTIONS PASSED");
log(`Results written to: ${ACT_RESULT_FILE}`);
