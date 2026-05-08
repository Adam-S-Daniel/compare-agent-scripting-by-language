// Test harness: runs all test cases through the GitHub Actions workflow via `act push`.
// Also includes workflow structure tests (YAML checks, actionlint, file existence).
//
// Usage: bun run run-act-tests.ts
// Output: act-result.txt in the current working directory

import * as fs from "fs";
import * as path from "path";
import * as os from "os";
import { execSync, spawnSync } from "child_process";

const PROJECT_ROOT = path.dirname(new URL(import.meta.url).pathname);
const ACT_RESULT_FILE = path.join(PROJECT_ROOT, "act-result.txt");
const WORKFLOW_FILE = path.join(PROJECT_ROOT, ".github/workflows/semantic-version-bumper.yml");

// Clear act-result.txt at the start
fs.writeFileSync(ACT_RESULT_FILE, "");

let passCount = 0;
let failCount = 0;

function pass(name: string): void {
  console.log(`  PASS: ${name}`);
  passCount++;
}

function fail(name: string, reason: string): never {
  console.error(`  FAIL: ${name} — ${reason}`);
  failCount++;
  throw new Error(`Assertion failed: ${name} — ${reason}`);
}

function assert(condition: boolean, name: string, reason: string): void {
  if (!condition) fail(name, reason);
  else pass(name);
}

function assertContains(haystack: string, needle: string, name: string): void {
  assert(haystack.includes(needle), name, `Expected to find: "${needle}"`);
}

function appendActResult(header: string, output: string): void {
  const divider = "=".repeat(70);
  fs.appendFileSync(
    ACT_RESULT_FILE,
    `\n${divider}\n${header}\n${divider}\n${output}\n`
  );
}

// ---------------------------------------------------------------------------
// SECTION 1: Workflow structure tests (no act needed, fast)
// ---------------------------------------------------------------------------

console.log("\n=== Workflow Structure Tests ===\n");

// 1a. Workflow file exists
assert(fs.existsSync(WORKFLOW_FILE), "workflow file exists", `${WORKFLOW_FILE} not found`);

const workflowContent = fs.readFileSync(WORKFLOW_FILE, "utf-8");

// 1b. Has push trigger
assertContains(workflowContent, "push:", "workflow has push trigger");

// 1c. Has pull_request trigger
assertContains(workflowContent, "pull_request:", "workflow has pull_request trigger");

// 1d. Has workflow_dispatch trigger
assertContains(workflowContent, "workflow_dispatch:", "workflow has workflow_dispatch trigger");

// 1e. Has test-and-bump job
assertContains(workflowContent, "test-and-bump:", "workflow has test-and-bump job");

// 1f. Uses actions/checkout@v4
assertContains(workflowContent, "actions/checkout@v4", "workflow uses actions/checkout@v4");

// 1g. Runs bun test
assertContains(workflowContent, "bun test", "workflow runs bun test");

// 1h. References correct script path
assertContains(workflowContent, "src/version-bumper.ts", "workflow references version-bumper.ts");

// 1i. References fixture files
assertContains(workflowContent, "fixtures/test-case-patch.json", "workflow references patch fixture");
assertContains(workflowContent, "fixtures/test-case-minor.json", "workflow references minor fixture");
assertContains(workflowContent, "fixtures/test-case-major.json", "workflow references major fixture");

// 1j. Script files actually exist
assert(
  fs.existsSync(path.join(PROJECT_ROOT, "src/version-bumper.ts")),
  "src/version-bumper.ts exists",
  "Script file not found"
);
assert(
  fs.existsSync(path.join(PROJECT_ROOT, "fixtures/test-case-patch.json")),
  "fixtures/test-case-patch.json exists",
  "Patch fixture not found"
);
assert(
  fs.existsSync(path.join(PROJECT_ROOT, "fixtures/test-case-minor.json")),
  "fixtures/test-case-minor.json exists",
  "Minor fixture not found"
);
assert(
  fs.existsSync(path.join(PROJECT_ROOT, "fixtures/test-case-major.json")),
  "fixtures/test-case-major.json exists",
  "Major fixture not found"
);

// 1k. actionlint passes
console.log("\n  Running actionlint...");
const actionlintResult = spawnSync("actionlint", [WORKFLOW_FILE], {
  encoding: "utf-8",
  cwd: PROJECT_ROOT,
});
assert(actionlintResult.status === 0, "actionlint passes", actionlintResult.stdout + actionlintResult.stderr);

appendActResult("WORKFLOW STRUCTURE TESTS", "All workflow structure tests passed.");

// ---------------------------------------------------------------------------
// SECTION 2: act end-to-end test (one act push run covers all 3 fixtures)
// ---------------------------------------------------------------------------

console.log("\n=== Act End-to-End Tests ===\n");

// Build test data: what each step should output
interface ActTestCase {
  stepName: string;
  expectedVersion: string;
}

const actTestCases: ActTestCase[] = [
  {
    stepName: "Run version bumper (patch fixture)",
    expectedVersion: "1.0.1",
  },
  {
    stepName: "Run version bumper (minor fixture)",
    expectedVersion: "1.1.0",
  },
  {
    stepName: "Run version bumper (major fixture)",
    expectedVersion: "2.0.0",
  },
];

// Set up a temp git repo with all project files
function setupTempRepo(): string {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "ver-bump-act-"));

  // Directories to copy
  const dirs = ["src", "fixtures", ".github"];
  for (const dir of dirs) {
    copyDirSync(path.join(PROJECT_ROOT, dir), path.join(tmpDir, dir));
  }

  // Files to copy
  const files = ["package.json", ".actrc"];
  for (const file of files) {
    const src = path.join(PROJECT_ROOT, file);
    if (fs.existsSync(src)) {
      fs.copyFileSync(src, path.join(tmpDir, file));
    }
  }

  // Init git repo
  execSync(
    "git init && " +
      "git config user.email 'test@test.com' && " +
      "git config user.name 'Test' && " +
      "git add -A && " +
      "git commit -m 'test: initial commit'",
    { cwd: tmpDir, stdio: "pipe" }
  );

  return tmpDir;
}

function copyDirSync(src: string, dest: string): void {
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);
    if (entry.isDirectory()) {
      copyDirSync(srcPath, destPath);
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

console.log("  Setting up temp git repo...");
const tmpRepo = setupTempRepo();
console.log(`  Temp repo: ${tmpRepo}`);

console.log("  Running act push --rm (this takes 30-90 seconds)...");

const actResult = spawnSync("act", ["push", "--rm", "--pull=false"], {
  cwd: tmpRepo,
  encoding: "utf-8",
  timeout: 300_000, // 5 minutes
});

const actOutput = (actResult.stdout ?? "") + (actResult.stderr ?? "");

appendActResult(
  "ACT PUSH RUN — all three fixture test cases",
  actOutput
);

// Assert act exit code 0
assert(
  actResult.status === 0,
  "act push exits with code 0",
  `act exited with ${actResult.status}. Output:\n${actOutput.slice(-2000)}`
);

// Assert "Job succeeded"
assertContains(actOutput, "Job succeeded", "act reports Job succeeded");

// Assert exact expected versions for each test case
for (const tc of actTestCases) {
  assertContains(
    actOutput,
    `New version: ${tc.expectedVersion}`,
    `${tc.stepName} outputs "New version: ${tc.expectedVersion}"`
  );
}

// Clean up temp dir
fs.rmSync(tmpRepo, { recursive: true, force: true });

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------

console.log(`\n=== Results: ${passCount} passed, ${failCount} failed ===\n`);
console.log(`act-result.txt written to: ${ACT_RESULT_FILE}`);

if (failCount > 0) {
  process.exit(1);
}
