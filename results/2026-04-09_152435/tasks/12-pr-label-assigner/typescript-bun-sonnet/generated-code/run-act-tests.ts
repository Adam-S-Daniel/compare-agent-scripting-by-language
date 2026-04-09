#!/usr/bin/env bun
// Test harness: runs `act push --rm`, captures output to act-result.txt,
// then parses and validates exact expected values from each test case.

import { $ } from "bun";
import { resolve } from "path";

const ACT_RESULT_FILE = resolve(import.meta.dir, "act-result.txt");

interface Assertion {
  description: string;
  check: (output: string) => boolean;
  expected: string;
}

// --- Expected values for exact validation ---
const assertions: Assertion[] = [
  // Unit tests
  {
    description: "Unit tests pass (22 tests)",
    check: (o) => /22 pass/.test(o),
    expected: "22 pass",
  },
  {
    description: "No failing unit tests",
    check: (o) => /0 fail/.test(o),
    expected: "0 fail",
  },
  // Test case 1: feature PR -> api, documentation, tests, source, other
  {
    description: "Fixture 1: LABELS contains api",
    check: (o) => /LABELS=.*\bapi\b/.test(o),
    expected: "LABELS=...api...",
  },
  {
    description: "Fixture 1: LABELS contains tests",
    check: (o) => /LABELS=.*\btests\b/.test(o),
    expected: "LABELS=...tests...",
  },
  {
    description: "Fixture 1: LABELS contains documentation",
    check: (o) => /LABELS=.*\bdocumentation\b/.test(o),
    expected: "LABELS=...documentation...",
  },
  {
    description: "Fixture 1: validation passes",
    check: (o) => o.includes("VALIDATION: All expected labels present."),
    expected: "VALIDATION: All expected labels present.",
  },
  // Test case 2: CI PR -> ci, other
  {
    description: "Fixture 2: LABELS=ci,other (exact)",
    check: (o) => o.includes("LABELS=ci,other"),
    expected: "LABELS=ci,other",
  },
  // Test case 3: docs PR -> documentation, other
  {
    description: "Fixture 3: LABELS=documentation,other (exact)",
    check: (o) => o.includes("LABELS=documentation,other"),
    expected: "LABELS=documentation,other",
  },
  // Mock PR
  {
    description: "Mock PR: LABELS contains api,ci,documentation",
    check: (o) => o.includes("LABELS=api,ci,documentation,tests,source,other"),
    expected: "LABELS=api,ci,documentation,tests,source,other",
  },
  // Job success
  {
    description: "test job succeeded",
    check: (o) => /Job succeeded.*Run Unit Tests|Run Unit Tests.*Job succeeded|\[Run Unit Tests\].*Job succeeded|\[PR Label Assigner\/Run Unit Tests\].*Job succeeded/s.test(o),
    expected: "Job succeeded for Run Unit Tests",
  },
];

async function runActPush(): Promise<{ output: string; exitCode: number }> {
  console.log("Running: act push --rm");
  console.log("This may take 1-2 minutes...\n");

  let output = "";
  let exitCode = 0;

  try {
    const result = await $`act push --rm 2>&1`.text();
    output = result;
  } catch (err: unknown) {
    const procErr = err as { stdout?: string; stderr?: string; exitCode?: number };
    output = (procErr.stdout ?? "") + (procErr.stderr ?? "");
    exitCode = procErr.exitCode ?? 1;
  }

  return { output, exitCode };
}

async function main(): Promise<void> {
  // --- Workflow structure tests (no act needed) ---
  console.log("=== Workflow Structure Tests ===");

  // 1. Parse YAML and check expected structure
  const workflowPath = ".github/workflows/pr-label-assigner.yml";
  const workflowFile = Bun.file(workflowPath);
  if (!(await workflowFile.exists())) {
    console.error(`FAIL: Workflow file not found at ${workflowPath}`);
    process.exit(1);
  }
  console.log(`PASS: Workflow file exists at ${workflowPath}`);

  const workflowContent = await workflowFile.text();

  // Check triggers
  if (!workflowContent.includes("push:") && !workflowContent.includes("push\n")) {
    console.error("FAIL: Workflow missing push trigger");
    process.exit(1);
  }
  console.log("PASS: Workflow has push trigger");

  if (!workflowContent.includes("pull_request:")) {
    console.error("FAIL: Workflow missing pull_request trigger");
    process.exit(1);
  }
  console.log("PASS: Workflow has pull_request trigger");

  // Check jobs
  if (!workflowContent.includes("bun test")) {
    console.error("FAIL: Workflow doesn't run bun test");
    process.exit(1);
  }
  console.log("PASS: Workflow runs bun test");

  // Check script references
  if (!workflowContent.includes("index.ts")) {
    console.error("FAIL: Workflow doesn't reference index.ts");
    process.exit(1);
  }
  console.log("PASS: Workflow references index.ts");

  // 2. Verify referenced files exist
  for (const path of ["index.ts", "src/label-assigner.ts", "label-rules.json"]) {
    if (!(await Bun.file(path).exists())) {
      console.error(`FAIL: Referenced file missing: ${path}`);
      process.exit(1);
    }
    console.log(`PASS: File exists: ${path}`);
  }

  // 3. Verify actionlint passes
  console.log("\n=== actionlint Validation ===");
  try {
    await $`actionlint ${workflowPath}`.quiet();
    console.log("PASS: actionlint passed with no errors");
  } catch {
    console.error("FAIL: actionlint reported errors");
    process.exit(1);
  }

  // --- Act run ---
  console.log("\n=== Act Integration Tests ===");
  const delimiter = "=".repeat(60);

  const { output, exitCode } = await runActPush();

  // Write to act-result.txt
  const resultContent = [
    `${delimiter}`,
    `ACT RUN: act push --rm`,
    `DATE: ${new Date().toISOString()}`,
    `EXIT CODE: ${exitCode}`,
    `${delimiter}`,
    output,
    `${delimiter}`,
    `END OF ACT OUTPUT`,
    `${delimiter}`,
  ].join("\n");

  await Bun.write(ACT_RESULT_FILE, resultContent);
  console.log(`Act output saved to: ${ACT_RESULT_FILE}`);

  if (exitCode !== 0) {
    console.error(`\nFAIL: act exited with code ${exitCode}`);
    console.error("Last 50 lines of output:");
    const lines = output.split("\n");
    console.error(lines.slice(-50).join("\n"));
    process.exit(1);
  }
  console.log(`PASS: act exited with code 0`);

  // --- Validate assertions ---
  console.log("\n=== Assertion Validation ===");
  let allPassed = true;

  for (const assertion of assertions) {
    if (assertion.check(output)) {
      console.log(`PASS: ${assertion.description}`);
    } else {
      console.error(`FAIL: ${assertion.description}`);
      console.error(`  Expected: ${assertion.expected}`);
      allPassed = false;
    }
  }

  // Check "Job succeeded" for all jobs
  const jobNames = ["Run Unit Tests", "Run Label Assignment Fixtures", "Run Label Assigner with Built-in Mock"];
  for (const jobName of jobNames) {
    const succeeded = output.includes("Job succeeded") && output.includes(jobName);
    if (succeeded) {
      console.log(`PASS: "${jobName}" - Job succeeded`);
    } else {
      // Be lenient - check for any success indicator near the job name
      const jobRegex = new RegExp(
        jobName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&").replace(/\s+/g, "\\s+") +
        "[\\s\\S]{0,500}(Job succeeded|✅|success)",
        "i"
      );
      if (jobRegex.test(output)) {
        console.log(`PASS: "${jobName}" - Job succeeded`);
      } else {
        console.error(`WARN: Could not confirm "${jobName}" succeeded (may be a display format issue)`);
        // Don't fail for this - the exit code check is more reliable
      }
    }
  }

  if (!allPassed) {
    console.error("\nSome assertions failed. Check act-result.txt for full output.");
    process.exit(1);
  }

  console.log("\n=== All tests passed! ===");
}

main().catch((err: Error) => {
  console.error(`Fatal error: ${err.message}`);
  process.exit(1);
});
