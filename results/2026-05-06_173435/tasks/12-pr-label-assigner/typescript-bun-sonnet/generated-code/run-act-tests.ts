// Act Test Harness for PR Label Assigner
// Sets up a temp git repo with project files, runs `act push --rm`,
// captures output to act-result.txt, and asserts on exact expected values.

import { execSync, spawnSync } from "child_process";
import { mkdtempSync, cpSync, writeFileSync, appendFileSync, existsSync, mkdirSync } from "fs";
import { join } from "path";
import { tmpdir } from "os";

const PROJECT_DIR = import.meta.dir;
const RESULT_FILE = join(PROJECT_DIR, "act-result.txt");

function log(msg: string): void {
  console.log(msg);
}

function divider(label: string): string {
  return `\n${"=".repeat(60)}\n${label}\n${"=".repeat(60)}\n`;
}

function appendResult(content: string): void {
  appendFileSync(RESULT_FILE, content, "utf8");
}

function setupTempRepo(): string {
  const tmpDir = mkdtempSync(join(tmpdir(), "pr-label-assigner-act-"));

  // Copy all project files into the temp repo
  const filesToCopy = [
    "label-assigner.ts",
    "label-assigner.test.ts",
    "run-act-tests.ts",
    "package.json",
    "bun.lock",
    ".actrc",
  ];

  for (const file of filesToCopy) {
    const src = join(PROJECT_DIR, file);
    if (existsSync(src)) {
      cpSync(src, join(tmpDir, file));
    }
  }

  // Copy .github/workflows directory
  const workflowsSrc = join(PROJECT_DIR, ".github");
  if (existsSync(workflowsSrc)) {
    cpSync(workflowsSrc, join(tmpDir, ".github"), { recursive: true });
  }

  // Copy node_modules (bun installs them)
  const nodeModulesSrc = join(PROJECT_DIR, "node_modules");
  if (existsSync(nodeModulesSrc)) {
    cpSync(nodeModulesSrc, join(tmpDir, "node_modules"), { recursive: true });
  }

  // Initialize git repo
  execSync("git init", { cwd: tmpDir, stdio: "pipe" });
  execSync("git config user.email 'test@test.com'", { cwd: tmpDir, stdio: "pipe" });
  execSync("git config user.name 'Test'", { cwd: tmpDir, stdio: "pipe" });
  execSync("git add -A", { cwd: tmpDir, stdio: "pipe" });
  execSync("git commit -m 'test: initial commit for act run'", { cwd: tmpDir, stdio: "pipe" });

  return tmpDir;
}

interface TestCase {
  name: string;
  expectedStrings: string[];
  expectedJobSuccess: boolean;
}

const TEST_CASES: TestCase[] = [
  {
    name: "full-test-suite",
    // These exact strings must appear in bun test + demo output from the workflow
    expectedStrings: [
      "[FIXTURE:docs-only] LABELS: documentation",
      "[FIXTURE:mixed-docs-api] LABELS: api,documentation",
      "[FIXTURE:test-files] LABELS: tests",
      "[FIXTURE:multi-label-single-file] LABELS: api,tests",
      "[FIXTURE:no-match] LABELS: (none)",
      "[FIXTURE:ci-files] LABELS: ci/cd",
      // bun test summary (space-padded format: " 23 pass")
      " 23 pass",
      " 0 fail",
      "Job succeeded",
    ],
    expectedJobSuccess: true,
  },
];

let allPassed = true;

// Clear result file from previous runs
writeFileSync(RESULT_FILE, "", "utf8");

log("Starting act test harness...");
log(`Results will be saved to: ${RESULT_FILE}`);

for (const testCase of TEST_CASES) {
  log(`\nRunning test case: ${testCase.name}`);
  appendResult(divider(`TEST CASE: ${testCase.name}`));

  const tmpDir = setupTempRepo();
  log(`Temp repo: ${tmpDir}`);

  const result = spawnSync(
    "act",
    ["push", "--rm", "--pull=false"],
    {
      cwd: tmpDir,
      encoding: "utf8",
      timeout: 300_000, // 5 minutes
    }
  );

  const combinedOutput = (result.stdout ?? "") + (result.stderr ?? "");
  appendResult(combinedOutput);

  const exitCode = result.status ?? 1;
  log(`act exit code: ${exitCode}`);

  // Assert: act exited with code 0
  if (exitCode !== 0) {
    log(`FAIL: act exited with code ${exitCode} for test case '${testCase.name}'`);
    allPassed = false;
  } else {
    log(`PASS: act exited with code 0`);
  }

  // Assert: each expected string appears in output
  for (const expected of testCase.expectedStrings) {
    if (combinedOutput.includes(expected)) {
      log(`PASS: output contains '${expected}'`);
    } else {
      log(`FAIL: output missing '${expected}'`);
      allPassed = false;
    }
  }

  appendResult(`\n[EXIT CODE: ${exitCode}]\n`);
}

appendResult(divider("SUMMARY"));
appendResult(`All assertions passed: ${allPassed}\n`);

log(`\nResults saved to: ${RESULT_FILE}`);

if (!allPassed) {
  log("\nSome assertions FAILED. Check act-result.txt for details.");
  process.exit(1);
} else {
  log("\nAll assertions PASSED.");
}
