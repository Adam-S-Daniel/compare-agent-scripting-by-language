#!/usr/bin/env bun
import { execSync } from "child_process";
import { writeFileSync, mkdirSync } from "fs";
import * as path from "path";

interface TestCase {
  name: string;
  setup: () => void;
  expectedInOutput: string[];
}

const testCases: TestCase[] = [
  {
    name: "Basic workflow execution",
    setup: () => {
      // Default setup - workflow will run with its test fixture
    },
    expectedInOutput: [
      "Run unit tests",
      "pass",
      "Validate workflow",
    ],
  },
];

function runActTest(): string {
  try {
    // Initialize git repo if not already
    try {
      execSync("git status", { cwd: process.cwd(), stdio: "ignore" });
    } catch {
      execSync("git init", { cwd: process.cwd(), stdio: "pipe" });
      execSync("git config user.email 'test@example.com'", {
        cwd: process.cwd(),
        stdio: "pipe",
      });
      execSync("git config user.name 'Test User'", {
        cwd: process.cwd(),
        stdio: "pipe",
      });
    }

    // Stage and commit all files
    execSync("git add -A", { cwd: process.cwd(), stdio: "pipe" });
    try {
      execSync("git commit -m 'test: artifact cleanup workflow'", {
        cwd: process.cwd(),
        stdio: "pipe",
      });
    } catch {
      // Might fail if nothing to commit
    }

    // Run act push with proper error handling
    console.log("Running act push...");
    const result = execSync("act push --rm 2>&1", {
      cwd: process.cwd(),
      stdio: "pipe",
      encoding: "utf-8",
      timeout: 120000,
    });

    return result;
  } catch (error) {
    if (error instanceof Error) {
      return error.message || String(error);
    }
    return String(error);
  }
}

function main() {
  console.log("=".repeat(60));
  console.log("ARTIFACT CLEANUP SCRIPT - ACT WORKFLOW TEST");
  console.log("=".repeat(60));

  const results: string[] = [];

  for (const testCase of testCases) {
    console.log(`\n[TEST] ${testCase.name}`);
    console.log("-".repeat(60));

    try {
      testCase.setup();
      const output = runActTest();

      // Check for expected strings
      let passed = true;
      const missingItems: string[] = [];

      for (const expected of testCase.expectedInOutput) {
        if (!output.includes(expected)) {
          passed = false;
          missingItems.push(expected);
        }
      }

      if (passed) {
        console.log(`✓ PASS: ${testCase.name}`);
        results.push(`✓ ${testCase.name}`);
      } else {
        console.log(`✗ FAIL: ${testCase.name}`);
        console.log(`  Missing in output: ${missingItems.join(", ")}`);
        results.push(`✗ ${testCase.name} - Missing: ${missingItems.join(", ")}`);
      }

      // Save full output
      const outputDir = "/tmp/act-output";
      try {
        mkdirSync(outputDir, { recursive: true });
      } catch {}

      const sanitizedName = testCase.name.replace(/[^a-z0-9]/gi, "_").toLowerCase();
      writeFileSync(
        path.join(outputDir, `${sanitizedName}.txt`),
        output
      );
    } catch (error) {
      console.log(`✗ ERROR: ${testCase.name}`);
      console.log(`  ${error}`);
      results.push(`✗ ${testCase.name} - Error: ${error}`);
    }
  }

  // Write summary to act-result.txt
  const summary = [
    "ARTIFACT CLEANUP SCRIPT - ACT TEST RESULTS",
    "=".repeat(60),
    new Date().toISOString(),
    "",
    "TEST RESULTS:",
    ...results,
    "",
    "=".repeat(60),
  ].join("\n");

  writeFileSync("act-result.txt", summary);
  console.log("\n" + "=".repeat(60));
  console.log("Results saved to act-result.txt");
  console.log("=".repeat(60));

  // Exit with appropriate code
  const hasFailed = results.some((r) => r.startsWith("✗"));
  process.exit(hasFailed ? 1 : 0);
}

main();
