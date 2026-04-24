// Test harness: validates workflow structure, runs act, and asserts exact output values.
// ALL test cases run through GitHub Actions via `act` as required.
import { execSync, spawnSync } from "child_process";
import { existsSync, mkdtempSync, rmSync, writeFileSync, readFileSync, appendFileSync } from "fs";
import { join, resolve } from "path";
import { tmpdir } from "os";
import * as path from "path";

const PROJECT_ROOT = resolve(import.meta.dir);
const ACT_RESULT_FILE = join(PROJECT_ROOT, "act-result.txt");
const WORKFLOW_PATH = join(PROJECT_ROOT, ".github/workflows/pr-label-assigner.yml");
const ACTRC_PATH = join(PROJECT_ROOT, ".actrc");

// Clear result file at start
writeFileSync(ACT_RESULT_FILE, "");

let totalPassed = 0;
let totalFailed = 0;

function assert(condition: boolean, message: string): void {
  if (!condition) {
    console.error(`  FAIL: ${message}`);
    totalFailed++;
  } else {
    console.log(`  PASS: ${message}`);
    totalPassed++;
  }
}

function appendResult(content: string): void {
  appendFileSync(ACT_RESULT_FILE, content + "\n");
}

// ─── Workflow structure tests ─────────────────────────────────────────────────
console.log("\n=== Workflow Structure Tests ===");

// Verify workflow file exists
assert(existsSync(WORKFLOW_PATH), "workflow file exists at .github/workflows/pr-label-assigner.yml");

// Verify referenced script files exist
assert(existsSync(join(PROJECT_ROOT, "src/labeler.ts")), "src/labeler.ts exists");
assert(existsSync(join(PROJECT_ROOT, "src/labeler.test.ts")), "src/labeler.test.ts exists");
assert(existsSync(join(PROJECT_ROOT, "src/main.ts")), "src/main.ts exists");
assert(existsSync(join(PROJECT_ROOT, "fixtures/config.json")), "fixtures/config.json exists");
assert(existsSync(join(PROJECT_ROOT, "fixtures/changed-files.txt")), "fixtures/changed-files.txt exists");
assert(existsSync(join(PROJECT_ROOT, "fixtures/test-case-api-only.txt")), "fixtures/test-case-api-only.txt exists");
assert(existsSync(join(PROJECT_ROOT, "fixtures/test-case-docs-only.txt")), "fixtures/test-case-docs-only.txt exists");

// Parse workflow YAML by reading content and checking for expected structure
const workflowContent = readFileSync(WORKFLOW_PATH, "utf-8");

assert(workflowContent.includes("on:"), "workflow has trigger events");
assert(workflowContent.includes("push:"), "workflow triggers on push");
assert(workflowContent.includes("pull_request:"), "workflow triggers on pull_request");
assert(workflowContent.includes("workflow_dispatch:"), "workflow triggers on workflow_dispatch");
assert(workflowContent.includes("jobs:"), "workflow has jobs section");
assert(workflowContent.includes("actions/checkout@v4"), "workflow uses actions/checkout@v4");
assert(workflowContent.includes("oven-sh/setup-bun"), "workflow installs Bun");
assert(workflowContent.includes("bun test"), "workflow runs bun test");
assert(workflowContent.includes("bun run src/main.ts"), "workflow runs main script");
assert(workflowContent.includes("fixtures/changed-files.txt"), "workflow references default fixture");
assert(workflowContent.includes("fixtures/test-case-api-only.txt"), "workflow references api-only fixture");
assert(workflowContent.includes("fixtures/test-case-docs-only.txt"), "workflow references docs-only fixture");

// Verify actionlint passes
console.log("\n  Running actionlint...");
const actionlintResult = spawnSync("actionlint", [WORKFLOW_PATH], { encoding: "utf-8" });
assert(actionlintResult.status === 0, `actionlint passes (exit code 0)`);
if (actionlintResult.stdout) console.log("  actionlint stdout:", actionlintResult.stdout);
if (actionlintResult.stderr) console.log("  actionlint stderr:", actionlintResult.stderr);

// ─── Act integration tests ────────────────────────────────────────────────────
console.log("\n=== Act Integration Tests ===");

// Known expected outputs for each fixture (exact values to assert)
const testCases = [
  {
    name: "Full run: unit tests + all fixtures",
    // The workflow runs all tests in one job; we assert key outputs
    expectedLabels: {
      // default fixture: docs/README.md, src/api/users.ts, src/utils.test.ts, README.md
      "default": "documentation,tests,api,frontend",
      // api-only fixture: src/api/auth.ts, src/api/users.ts
      "api-only": "api,frontend",
      // docs-only fixture: docs/guide/intro.md, docs/api-reference.md, CHANGELOG.md
      "docs-only": "documentation",
    },
    expectedStrings: [
      "19 pass",           // all unit tests pass
      "0 fail",
      "ASSIGNED_LABELS=documentation,tests,api,frontend", // default fixture
      "ASSIGNED_LABELS=api,frontend",                      // api-only fixture
      "ASSIGNED_LABELS=documentation",                     // docs-only fixture
    ],
  },
];

// Set up a temp git repo with all project files, run act, capture output
function runActTest(testCase: typeof testCases[0]): boolean {
  const tmpDir = mkdtempSync(join(tmpdir(), "pr-label-test-"));
  console.log(`  Temp dir: ${tmpDir}`);

  try {
    // Copy project files into temp repo
    execSync(`cp -r ${PROJECT_ROOT}/src ${tmpDir}/`, { stdio: "pipe" });
    execSync(`cp -r ${PROJECT_ROOT}/fixtures ${tmpDir}/`, { stdio: "pipe" });
    execSync(`cp -r ${PROJECT_ROOT}/.github ${tmpDir}/`, { stdio: "pipe" });
    if (existsSync(ACTRC_PATH)) {
      execSync(`cp ${ACTRC_PATH} ${tmpDir}/.actrc`, { stdio: "pipe" });
    }

    // Initialize git repo (act requires a git repo)
    execSync("git init", { cwd: tmpDir, stdio: "pipe" });
    execSync("git config user.email 'test@test.com'", { cwd: tmpDir, stdio: "pipe" });
    execSync("git config user.name 'Test'", { cwd: tmpDir, stdio: "pipe" });
    execSync("git add -A", { cwd: tmpDir, stdio: "pipe" });
    execSync("git commit -m 'test'", { cwd: tmpDir, stdio: "pipe" });

    // Run act
    console.log("  Running act push --rm ...");
    const actResult = spawnSync(
      "act",
      ["push", "--rm", "--pull=false"],
      {
        cwd: tmpDir,
        encoding: "utf-8",
        timeout: 300000, // 5 minutes
      }
    );

    const output = (actResult.stdout || "") + (actResult.stderr || "");
    const delimiter = `\n${"=".repeat(60)}\nTEST CASE: ${testCase.name}\n${"=".repeat(60)}\n`;
    appendResult(delimiter);
    appendResult(output);

    console.log(`  Act exit code: ${actResult.status}`);
    assert(actResult.status === 0, `act exited with code 0`);

    // Assert "Job succeeded"
    assert(
      output.includes("Job succeeded"),
      `act output contains "Job succeeded"`
    );

    // Assert all expected strings appear in output
    for (const expected of testCase.expectedStrings) {
      assert(
        output.includes(expected),
        `output contains: ${expected}`
      );
    }

    return actResult.status === 0;
  } finally {
    try { rmSync(tmpDir, { recursive: true }); } catch {}
  }
}

// Run the single act test (covers all fixtures in one workflow execution)
runActTest(testCases[0]);

// ─── Summary ─────────────────────────────────────────────────────────────────
console.log(`\n=== Results: ${totalPassed} passed, ${totalFailed} failed ===`);
appendResult(`\n=== Final: ${totalPassed} passed, ${totalFailed} failed ===\n`);

if (totalFailed > 0) {
  console.error("Some tests failed.");
  process.exit(1);
} else {
  console.log("All tests passed.");
}
