/**
 * Act Test Harness for PR Label Assigner
 *
 * Runs each test case through GitHub Actions via `act` and asserts:
 *   1. act exits with code 0
 *   2. Every job shows "Job succeeded"
 *   3. The LABELS_OUTPUT matches the expected value exactly
 *   4. Workflow structure is valid (triggers, steps, actionlint)
 *
 * All output is saved to act-result.txt.
 */

import { spawnSync } from "child_process";
import { writeFileSync, appendFileSync, existsSync, unlinkSync, readFileSync } from "fs";

interface TestCase {
  name: string;
  changedFiles: string;
  expectedLabelsSet: Set<string>;
}

const TEST_CASES: TestCase[] = [
  {
    name: "docs-only",
    changedFiles: "docs/getting-started.md,docs/api/reference.md",
    expectedLabelsSet: new Set(["documentation"]),
  },
  {
    name: "api-files",
    changedFiles: "src/api/users.ts,src/api/products.ts",
    expectedLabelsSet: new Set(["api", "source"]),
  },
  {
    name: "test-files",
    // src/api/users.test.ts: tests+api+source; src/components/Button.spec.tsx: tests+source+frontend
    changedFiles: "src/api/users.test.ts,src/components/Button.spec.tsx",
    expectedLabelsSet: new Set(["tests", "api", "source", "frontend"]),
  },
  {
    name: "mixed-pr",
    changedFiles: "docs/getting-started.md,src/api/users.ts,src/api/users.test.ts,.github/workflows/ci.yml",
    expectedLabelsSet: new Set(["tests", "ci/cd", "api", "source", "documentation"]),
  },
  {
    name: "security-auth",
    changedFiles: "src/api/auth/login.ts,src/api/auth/middleware.ts",
    expectedLabelsSet: new Set(["security", "api", "source"]),
  },
  {
    name: "cicd-only",
    changedFiles: ".github/workflows/ci.yml,.github/dependabot.yml",
    expectedLabelsSet: new Set(["ci/cd"]),
  },
  {
    name: "infrastructure",
    changedFiles: "terraform/main.tf,terraform/variables.tf,infra/k8s/deploy.yaml",
    expectedLabelsSet: new Set(["infrastructure"]),
  },
  {
    name: "full-stack-pr",
    changedFiles: "src/api/auth/login.ts,src/components/LoginForm.tsx,src/components/LoginForm.test.tsx,docs/auth.md",
    expectedLabelsSet: new Set(["security", "tests", "api", "source", "frontend", "documentation"]),
  },
];

const RESULT_FILE = "act-result.txt";
const WORKFLOW_FILE = ".github/workflows/pr-label-assigner.yml";
const PROJECT_DIR = process.cwd();

// Initialize result file
if (existsSync(RESULT_FILE)) unlinkSync(RESULT_FILE);
writeFileSync(RESULT_FILE, `PR Label Assigner - Act Test Results\nDate: ${new Date().toISOString()}\n\n`);

function log(text: string) {
  appendFileSync(RESULT_FILE, text + "\n");
  console.log(text);
}

function runAct(changedFiles: string, testCaseName: string): { exitCode: number; output: string } {
  log(`\n${"=".repeat(60)}`);
  log(`TEST CASE: ${testCaseName}`);
  log(`CHANGED_FILES: ${changedFiles}`);
  log("=".repeat(60));

  const actArgs = [
    "workflow_dispatch",
    "--rm",
    "-W", WORKFLOW_FILE,
    "--input", `changed_files=${changedFiles}`,
    "--input", `test_case=${testCaseName}`,
  ];

  log(`Running: act ${actArgs.join(" ")}`);

  const result = spawnSync("act", actArgs, {
    cwd: PROJECT_DIR,
    encoding: "utf-8",
    timeout: 300_000,
    maxBuffer: 10 * 1024 * 1024,
  });

  const output = (result.stdout || "") + (result.stderr || "");
  log(output);

  return { exitCode: result.status ?? 1, output };
}

function parseLabelsFromOutput(output: string): Set<string> {
  // Find the LABELS_OUTPUT line emitted by the workflow step
  const match = output.match(/LABELS_OUTPUT=([^\r\n]*)/);
  if (!match) return new Set();
  return new Set(
    match[1].split(",").map((l) => l.trim()).filter((l) => l.length > 0)
  );
}

function runStructureTests(): boolean {
  log(`\n${"=".repeat(60)}`);
  log("WORKFLOW STRUCTURE TESTS");
  log("=".repeat(60));

  let allPassed = true;

  function check(condition: boolean, desc: string) {
    log(`[${condition ? "PASS" : "FAIL"}] ${desc}`);
    if (!condition) allPassed = false;
  }

  // File existence checks
  check(existsSync(WORKFLOW_FILE), `Workflow file exists: ${WORKFLOW_FILE}`);
  check(existsSync("src/index.ts"), "Script file exists: src/index.ts");
  check(existsSync("src/labeler.ts"), "Labeler module exists: src/labeler.ts");
  check(existsSync("src/labeler.test.ts"), "Test file exists: src/labeler.test.ts");
  check(existsSync("package.json"), "package.json exists");

  // actionlint validation
  const lintResult = spawnSync("actionlint", [WORKFLOW_FILE], {
    cwd: PROJECT_DIR,
    encoding: "utf-8",
  });
  const lintPassed = lintResult.status === 0;
  check(lintPassed, `actionlint validation passes (exit code: ${lintResult.status})`);
  if (lintResult.stdout?.trim()) log(`  actionlint stdout: ${lintResult.stdout.trim()}`);
  if (lintResult.stderr?.trim()) log(`  actionlint stderr: ${lintResult.stderr.trim()}`);

  // Workflow content checks
  const workflowText = readFileSync(WORKFLOW_FILE, "utf-8");
  check(workflowText.includes("push:"), "Workflow has push trigger");
  check(workflowText.includes("pull_request:"), "Workflow has pull_request trigger");
  check(workflowText.includes("workflow_dispatch:"), "Workflow has workflow_dispatch trigger");
  check(workflowText.includes("actions/checkout@v4"), "Workflow uses actions/checkout@v4");
  check(workflowText.includes("oven-sh/setup-bun"), "Workflow sets up Bun (oven-sh/setup-bun)");
  check(workflowText.includes("bun test"), "Workflow runs bun test");
  check(workflowText.includes("bun run src/index.ts"), "Workflow runs bun run src/index.ts");
  check(workflowText.includes("LABELS_OUTPUT"), "Workflow captures LABELS_OUTPUT");

  return allPassed;
}

function main() {
  log("Starting PR Label Assigner Act Test Suite");
  log(`Working directory: ${PROJECT_DIR}`);
  log(`Timestamp: ${new Date().toISOString()}`);

  // Workflow structure tests
  const structurePassed = runStructureTests();

  // Act integration tests
  let actPassCount = 0;
  let actFailCount = 0;
  const failures: string[] = [];

  for (const tc of TEST_CASES) {
    const { exitCode, output } = runAct(tc.changedFiles, tc.name);

    log(`\n--- Assertions for: ${tc.name} ---`);

    const exitOk = exitCode === 0;
    log(`[${exitOk ? "PASS" : "FAIL"}] act exit code = 0 (got ${exitCode})`);

    const jobOk = output.includes("Job succeeded");
    log(`[${jobOk ? "PASS" : "FAIL"}] Job succeeded`);

    const actualLabels = parseLabelsFromOutput(output);
    const labelsMatch =
      actualLabels.size === tc.expectedLabelsSet.size &&
      [...tc.expectedLabelsSet].every((l) => actualLabels.has(l));

    log(`[${labelsMatch ? "PASS" : "FAIL"}] Labels match expected`);
    log(`  Expected: {${[...tc.expectedLabelsSet].sort().join(", ")}}`);
    log(`  Got:      {${[...actualLabels].sort().join(", ")}}`);

    if (exitOk && jobOk && labelsMatch) {
      actPassCount++;
    } else {
      actFailCount++;
      failures.push(tc.name);
    }
  }

  // Final summary
  log(`\n${"=".repeat(60)}`);
  log("FINAL SUMMARY");
  log("=".repeat(60));
  log(`Structure tests: ${structurePassed ? "PASS" : "FAIL"}`);
  log(`Act integration tests: ${actPassCount}/${TEST_CASES.length} passed`);
  if (failures.length > 0) {
    log(`Failed cases: ${failures.join(", ")}`);
  }
  log(`Results written to: ${RESULT_FILE}`);

  const overallPass = structurePassed && actFailCount === 0;
  log(`\nOVERALL: ${overallPass ? "PASS" : "FAIL"}`);

  process.exit(overallPass ? 0 : 1);
}

main();
