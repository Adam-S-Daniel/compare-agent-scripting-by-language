#!/usr/bin/env bun
// Act test harness: sets up a temp git repo, runs act push, captures output,
// and asserts on exact expected values.
// Saves all output to act-result.txt in the current working directory.

import { mkdirSync, cpSync, writeFileSync, appendFileSync, existsSync } from "fs";
import { join } from "path";
import { spawnSync } from "child_process";
import { tmpdir } from "os";

const ROOT = join(import.meta.dir);
const ACT_RESULT_FILE = join(ROOT, "act-result.txt");

// Clear or create the act-result.txt file
writeFileSync(ACT_RESULT_FILE, "");

interface TestCase {
  name: string;
  fixtures: string[];
  expectedInOutput: string[];
  expectJobSucceeded: boolean;
}

// Test cases with exact expected values
const TEST_CASES: TestCase[] = [
  {
    name: "basic-aggregation",
    fixtures: ["matrix-linux.xml", "matrix-windows.xml", "unit-tests.json"],
    expectedInOutput: [
      "Test Results Summary",
      "Passed",
      "Failed",
      "Flaky Tests",
      // With all 3 fixtures: login fails with bad creds is flaky (fail linux, pass windows)
      "login fails with bad creds",
      // pass/fail counts — derived from known fixture data
      "17",  // total passed across all 3 fixtures
    ],
    expectJobSucceeded: true,
  },
];

function runActTest(tc: TestCase): { passed: boolean; output: string } {
  const tmpDir = join(tmpdir(), `act-test-${Date.now()}`);
  mkdirSync(tmpDir, { recursive: true });

  // Copy all project files to the temp dir — exclude .git dir but keep .github
  cpSync(ROOT, tmpDir, {
    recursive: true,
    filter: (src) => {
      if (src.includes("node_modules")) return false;
      // Exclude .git directory but allow .github
      const rel = src.slice(ROOT.length);
      if (/[/\\]\.git([/\\]|$)/.test(rel)) return false;
      return true;
    },
  });

  // Initialize git repo
  const git = (args: string[]) =>
    spawnSync("git", args, { cwd: tmpDir, encoding: "utf-8" });

  git(["init"]);
  git(["config", "user.email", "test@example.com"]);
  git(["config", "user.name", "Test"]);
  git(["add", "-A"]);
  git(["commit", "-m", "test: add project files"]);

  // Run act with --pull=false to use locally cached image
  const actResult = spawnSync(
    "act",
    ["push", "--rm", "--pull=false", "-W", ".github/workflows/test-results-aggregator.yml"],
    {
      cwd: tmpDir,
      encoding: "utf-8",
      timeout: 300_000, // 5 minutes
    }
  );

  const output = (actResult.stdout ?? "") + (actResult.stderr ?? "");
  return { passed: actResult.status === 0, output };
}

let overallPassed = true;

for (const tc of TEST_CASES) {
  const delimiter = `\n${"=".repeat(60)}\nTEST CASE: ${tc.name}\n${"=".repeat(60)}\n`;
  appendFileSync(ACT_RESULT_FILE, delimiter);

  console.log(`\nRunning test case: ${tc.name}`);

  const { passed, output } = runActTest(tc);

  appendFileSync(ACT_RESULT_FILE, output);

  // Assert exit code
  if (!passed) {
    const msg = `FAIL [${tc.name}]: act exited non-zero\n`;
    appendFileSync(ACT_RESULT_FILE, msg);
    console.error(msg);
    overallPassed = false;
  } else {
    console.log(`  act exit code: 0 ✓`);
  }

  // Assert Job succeeded appears in output
  if (tc.expectJobSucceeded) {
    if (!output.includes("Job succeeded")) {
      const msg = `FAIL [${tc.name}]: "Job succeeded" not found in output\n`;
      appendFileSync(ACT_RESULT_FILE, msg);
      console.error(msg);
      overallPassed = false;
    } else {
      console.log(`  "Job succeeded" found ✓`);
    }
  }

  // Assert exact expected values
  for (const expected of tc.expectedInOutput) {
    if (!output.includes(expected)) {
      const msg = `FAIL [${tc.name}]: expected "${expected}" in output\n`;
      appendFileSync(ACT_RESULT_FILE, msg);
      console.error(msg);
      overallPassed = false;
    } else {
      console.log(`  found "${expected}" ✓`);
    }
  }
}

const finalMsg = `\n${"=".repeat(60)}\nOVERALL: ${overallPassed ? "PASSED" : "FAILED"}\n${"=".repeat(60)}\n`;
appendFileSync(ACT_RESULT_FILE, finalMsg);
console.log(finalMsg);

if (!overallPassed) {
  process.exit(1);
}
