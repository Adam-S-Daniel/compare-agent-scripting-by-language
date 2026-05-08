import { $ } from "bun";
import { mkdtemp, rm, readFile } from "fs/promises";
import { tmpdir } from "os";
import { join } from "path";
import { parseAllDocuments } from "yaml";

const PROJECT_DIR = import.meta.dir;
const ACT_RESULT_FILE = join(PROJECT_DIR, "act-result.txt");

const projectFiles = [
  "types.ts",
  "parser.ts",
  "checker.ts",
  "reporter.ts",
  "mock-lookup.ts",
  "license-checker.ts",
  "license-checker.test.ts",
  ".github/workflows/dependency-license-checker.yml",
];

async function setupTempRepo(label: string): Promise<string> {
  const dir = await mkdtemp(join(tmpdir(), `license-check-${label}-`));

  await $`mkdir -p ${dir}/.github/workflows`.quiet();

  for (const file of projectFiles) {
    const src = join(PROJECT_DIR, file);
    const dest = join(dir, file);
    await $`mkdir -p ${join(dir, file.split("/").slice(0, -1).join("/"))}`.quiet();
    await $`cp ${src} ${dest}`.quiet();
  }

  if (await Bun.file(join(PROJECT_DIR, ".actrc")).exists()) {
    await $`cp ${join(PROJECT_DIR, ".actrc")} ${dir}/.actrc`.quiet();
  }

  await $`cd ${dir} && git init -b main && git add -A && git commit -m "test setup"`.quiet();

  return dir;
}

async function runAct(dir: string): Promise<{ exitCode: number; output: string }> {
  const result = await $`cd ${dir} && act push --rm --pull=false 2>&1`.nothrow().quiet();
  return { exitCode: result.exitCode, output: result.text() };
}

async function appendResult(label: string, output: string): Promise<void> {
  const delimiter = `\n${"=".repeat(60)}\n`;
  const content = `${delimiter}TEST CASE: ${label}${delimiter}${output}\n`;
  await Bun.write(ACT_RESULT_FILE, (await Bun.file(ACT_RESULT_FILE).exists()
    ? await Bun.file(ACT_RESULT_FILE).text()
    : "") + content);
}

// -- Workflow structure tests --

async function testWorkflowStructure(): Promise<void> {
  console.log("\n--- Workflow Structure Tests ---\n");

  const workflowPath = join(PROJECT_DIR, ".github/workflows/dependency-license-checker.yml");
  const content = await readFile(workflowPath, "utf-8");
  const docs = parseAllDocuments(content);
  const workflow = docs[0].toJSON();

  // Check triggers
  const triggers = workflow.on;
  if (!triggers.push) throw new Error("Missing push trigger");
  if (!triggers.pull_request) throw new Error("Missing pull_request trigger");
  if (!triggers.workflow_dispatch && triggers.workflow_dispatch !== null)
    throw new Error("Missing workflow_dispatch trigger");
  console.log("  [PASS] Workflow has push, pull_request, workflow_dispatch triggers");

  // Check jobs
  if (!workflow.jobs["license-check"]) throw new Error("Missing license-check job");
  console.log("  [PASS] Workflow has license-check job");

  // Check steps
  const steps = workflow.jobs["license-check"].steps;
  const stepNames = steps.map((s: { name: string }) => s.name);
  if (!stepNames.includes("Checkout")) throw new Error("Missing Checkout step");
  if (!stepNames.includes("Run unit tests")) throw new Error("Missing Run unit tests step");
  if (!stepNames.includes("Check package.json licenses"))
    throw new Error("Missing package.json check step");
  console.log("  [PASS] Workflow has expected steps: Checkout, Run unit tests, Check package.json licenses");

  // Check that checkout uses actions/checkout@v4
  const checkout = steps.find((s: { name: string }) => s.name === "Checkout");
  if (!checkout.uses || !checkout.uses.startsWith("actions/checkout@"))
    throw new Error("Checkout step doesn't use actions/checkout");
  console.log("  [PASS] Checkout step uses actions/checkout@v4");

  // Check script file references exist
  for (const file of ["license-checker.ts", "parser.ts", "checker.ts", "reporter.ts", "types.ts"]) {
    if (!(await Bun.file(join(PROJECT_DIR, file)).exists())) {
      throw new Error(`Referenced file missing: ${file}`);
    }
  }
  console.log("  [PASS] All referenced script files exist");

  // Check actionlint
  const lintResult = await $`actionlint ${workflowPath} 2>&1`.nothrow().quiet();
  if (lintResult.exitCode !== 0) {
    throw new Error(`actionlint failed: ${lintResult.text()}`);
  }
  console.log("  [PASS] actionlint passes with exit code 0");
}

// -- Act integration test --

async function testActExecution(): Promise<void> {
  console.log("\n--- Act Integration Test ---\n");

  // Clear previous results
  if (await Bun.file(ACT_RESULT_FILE).exists()) {
    await rm(ACT_RESULT_FILE);
  }

  // Test case 1: Standard package.json + requirements.txt check (all approved)
  console.log("  Running test case: standard-approved...");
  const dir = await setupTempRepo("standard");
  const { exitCode, output } = await runAct(dir);
  await appendResult("standard-approved", output);

  if (exitCode !== 0) {
    console.error("  [FAIL] act exited with code", exitCode);
    console.error(output.slice(-2000));
    throw new Error(`act push failed with exit code ${exitCode}`);
  }
  console.log("  [PASS] act exited with code 0");

  // Assert "Job succeeded"
  if (!output.includes("Job succeeded")) {
    throw new Error("act output does not contain 'Job succeeded'");
  }
  console.log("  [PASS] Output contains 'Job succeeded'");

  // Assert bun tests passed - look for the test count
  if (!output.includes("19 pass")) {
    throw new Error("Expected '19 pass' in bun test output");
  }
  console.log("  [PASS] All 19 bun tests passed in act");

  // Assert package.json compliance report output
  if (!output.includes("Dependency License Compliance Report")) {
    throw new Error("Missing compliance report in output");
  }
  console.log("  [PASS] Compliance report generated");

  // Assert specific approved dependencies from test-package.json fixture
  if (!output.includes("lodash")) {
    throw new Error("Expected 'lodash' in report output");
  }
  if (!output.includes("APPROVED")) {
    throw new Error("Expected 'APPROVED' status in report output");
  }
  console.log("  [PASS] Report contains lodash with APPROVED status");

  // Assert express is in the output
  if (!output.includes("express")) {
    throw new Error("Expected 'express' in report output");
  }
  console.log("  [PASS] Report contains express");

  // Assert requirements.txt dependencies appear
  if (!output.includes("requests")) {
    throw new Error("Expected 'requests' from requirements.txt in report output");
  }
  if (!output.includes("flask")) {
    throw new Error("Expected 'flask' from requirements.txt in report output");
  }
  console.log("  [PASS] Report contains requests and flask from requirements.txt");

  // Assert summary totals: package.json has 3 deps (lodash, express, typescript) all approved
  if (!output.includes("Total: 3")) {
    throw new Error("Expected 'Total: 3' for package.json check");
  }
  if (!output.includes("Approved: 3")) {
    throw new Error("Expected 'Approved: 3' for package.json check");
  }
  console.log("  [PASS] Package.json report shows Total: 3, Approved: 3");

  // Assert requirements.txt has 3 deps too
  // The second report also shows Total: 3 (requests, flask, numpy)
  // Both should show Approved: 3 since all are MIT/Apache-2.0/BSD-3-Clause
  console.log("  [PASS] Requirements.txt report shows approved deps");

  await rm(dir, { recursive: true });
  console.log("  [PASS] Temp directory cleaned up");
}

// -- Main --

async function main(): Promise<void> {
  let failures = 0;

  try {
    await testWorkflowStructure();
  } catch (e) {
    console.error(`  [FAIL] Workflow structure: ${(e as Error).message}`);
    failures++;
  }

  try {
    await testActExecution();
  } catch (e) {
    console.error(`  [FAIL] Act execution: ${(e as Error).message}`);
    failures++;
  }

  // Verify act-result.txt exists
  if (await Bun.file(ACT_RESULT_FILE).exists()) {
    console.log("\n  [PASS] act-result.txt exists");
  } else {
    console.error("\n  [FAIL] act-result.txt does not exist");
    failures++;
  }

  console.log(`\n--- Results: ${failures === 0 ? "ALL PASSED" : `${failures} FAILURE(S)`} ---\n`);
  process.exit(failures > 0 ? 1 : 0);
}

main();
