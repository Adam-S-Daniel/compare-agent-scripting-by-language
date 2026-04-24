// Test harness: runs act for each test case, asserts expected values, writes act-result.txt

import { execSync } from "child_process";
import * as fs from "fs";
import * as path from "path";
import * as yaml from "js-yaml";

const WORKSPACE = import.meta.dir;
const RESULT_FILE = path.join(WORKSPACE, "act-result.txt");
const WORKFLOW_PATH = ".github/workflows/artifact-cleanup-script.yml";

interface TestCase {
  name: string;
  assertions: Array<(output: string) => void>;
}

function runAct(label: string): string {
  console.log(`\nRunning act for: ${label}`);
  try {
    const output = execSync("act push --rm --pull=false -W .github/workflows/artifact-cleanup-script.yml", {
      cwd: WORKSPACE,
      timeout: 120_000,
      encoding: "utf8",
    });
    return output;
  } catch (err: unknown) {
    const e = err as { stdout?: string; stderr?: string; message: string };
    const combined = (e.stdout ?? "") + "\n" + (e.stderr ?? "") + "\n" + e.message;
    return combined;
  }
}

function assert(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(`ASSERTION FAILED: ${message}`);
  }
}

// --- Workflow structure tests (no act needed) ---

function testWorkflowStructure(): void {
  console.log("\n=== Workflow Structure Tests ===");

  const workflowFile = path.join(WORKSPACE, WORKFLOW_PATH);
  assert(fs.existsSync(workflowFile), `Workflow file exists at ${WORKFLOW_PATH}`);
  console.log("PASS: workflow file exists");

  const content = fs.readFileSync(workflowFile, "utf8");
  const wf = yaml.load(content) as Record<string, unknown>;

  const on = wf["on"] as Record<string, unknown>;
  assert(on !== undefined, "workflow has triggers");
  assert("push" in on, "workflow triggers on push");
  assert("pull_request" in on, "workflow triggers on pull_request");
  assert("schedule" in on, "workflow has schedule trigger");
  assert("workflow_dispatch" in on, "workflow has workflow_dispatch trigger");
  console.log("PASS: all required triggers present");

  const jobs = wf["jobs"] as Record<string, unknown>;
  assert(jobs !== undefined, "workflow has jobs");
  assert("test" in jobs, "workflow has 'test' job");
  console.log("PASS: expected jobs present");

  const testJob = jobs["test"] as Record<string, unknown>;
  const steps = testJob["steps"] as Array<Record<string, unknown>>;
  const stepNames = steps.map((s) => s["name"] as string);
  assert(stepNames.some((n) => n?.includes("Checkout")), "workflow has checkout step");
  assert(stepNames.some((n) => n?.includes("Bun")), "workflow has Bun setup step");
  assert(stepNames.some((n) => n?.toLowerCase().includes("test")), "workflow has test step");
  console.log("PASS: expected steps present");

  const scriptFile = path.join(WORKSPACE, "artifact-cleanup.ts");
  assert(fs.existsSync(scriptFile), "script file artifact-cleanup.ts exists");
  console.log("PASS: referenced script file exists");

  // Verify actionlint passes
  try {
    execSync(`actionlint ${workflowFile}`, { encoding: "utf8" });
    console.log("PASS: actionlint validation passed");
  } catch {
    throw new Error("FAIL: actionlint reported errors");
  }
}

// --- Act test cases ---

const testCases: TestCase[] = [
  {
    name: "main-push-workflow",
    assertions: [
      (out) => {
        assert(
          out.includes("Job succeeded") || out.includes("job succeeded") || out.includes("success"),
          "Job succeeded"
        );
        assert(out.includes("bun test") || out.includes("pass"), "Tests ran");
        assert(out.includes("SUMMARY_JSON="), "Script outputs SUMMARY_JSON");
        assert(out.includes("totalArtifacts"), "Summary includes totalArtifacts");
        assert(out.includes("DRY RUN"), "Script runs in dry-run mode");
        assert(out.includes("PASS: SUMMARY_JSON present"), "Verification step confirms SUMMARY_JSON");
        assert(out.includes("PASS: totalArtifacts present"), "Verification step confirms totalArtifacts");
        assert(out.includes("PASS: dry-run mode indicated"), "Verification step confirms dry-run");
      },
    ],
  },
];

async function main(): Promise<void> {
  let allPassed = true;
  const resultLines: string[] = [];

  // Structure tests (no act)
  try {
    testWorkflowStructure();
    resultLines.push("=== Workflow Structure Tests: PASSED ===\n");
  } catch (err) {
    allPassed = false;
    resultLines.push(`=== Workflow Structure Tests: FAILED ===\n${(err as Error).message}\n`);
    console.error("Structure test failed:", (err as Error).message);
  }

  // Act-based tests
  const actOutput = runAct(testCases[0].name);

  for (const tc of testCases) {
    const delim = `\n${"=".repeat(60)}\nTEST CASE: ${tc.name}\n${"=".repeat(60)}\n`;
    resultLines.push(delim);
    resultLines.push(actOutput);

    let casePassed = true;
    for (const assertion of tc.assertions) {
      try {
        assertion(actOutput);
      } catch (err) {
        casePassed = false;
        allPassed = false;
        const msg = `ASSERTION FAILED in '${tc.name}': ${(err as Error).message}`;
        console.error(msg);
        resultLines.push(`\n${msg}\n`);
      }
    }
    resultLines.push(`\nTEST CASE ${tc.name}: ${casePassed ? "PASSED" : "FAILED"}\n`);
    console.log(`Test case '${tc.name}': ${casePassed ? "PASSED" : "FAILED"}`);
  }

  // Write act-result.txt
  fs.writeFileSync(RESULT_FILE, resultLines.join(""));
  console.log(`\nResults written to ${RESULT_FILE}`);

  if (allPassed) {
    console.log("\nAll tests PASSED");
    process.exit(0);
  } else {
    console.error("\nSome tests FAILED");
    process.exit(1);
  }
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
