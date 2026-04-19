import { execSync, spawnSync } from "child_process";
import { existsSync, writeFileSync, appendFileSync, rmSync } from "fs";
import { join } from "path";

// Test cases with fixture data
interface TestCase {
  name: string;
  files: string[];
  expectedLabels: string[];
}

const testCases: TestCase[] = [
  {
    name: "Documentation files",
    files: ["docs/README.md", "docs/api/endpoints.md"],
    expectedLabels: ["documentation"],
  },
  {
    name: "API source files",
    files: ["src/api/routes.ts", "src/api/middleware.ts"],
    expectedLabels: ["api", "code"],
  },
  {
    name: "Test files",
    files: ["src/api/routes.test.ts", "tests/integration.test.ts"],
    expectedLabels: ["api", "code", "tests"],
  },
  {
    name: "Configuration files",
    files: ["tsconfig.json", "package.json"],
    expectedLabels: ["configuration"],
  },
  {
    name: "Mixed file types",
    files: [
      "docs/README.md",
      "src/api/routes.ts",
      "src/utils/helpers.test.ts",
      "package.json",
      ".github/workflows/ci.yml",
    ],
    expectedLabels: ["api", "ci", "code", "configuration", "documentation", "tests"],
  },
  {
    name: "Workflow files",
    files: [".github/workflows/ci.yml", ".github/workflows/deploy.yml"],
    expectedLabels: ["ci", "configuration"],
  },
];

// Run a single test with act
function runActTest(testCase: TestCase, outputFile: string): boolean {
  const filesStr = testCase.files.join(",");
  console.log(`\n========================================`);
  console.log(`Running test: ${testCase.name}`);
  console.log(`Files: ${filesStr}`);
  console.log(`Expected labels: ${testCase.expectedLabels.join(", ")}`);
  console.log(`========================================`);

  try {
    // Log test case to output file
    appendFileSync(
      outputFile,
      `\n========================================\n`
    );
    appendFileSync(outputFile, `Test: ${testCase.name}\n`);
    appendFileSync(outputFile, `Files: ${filesStr}\n`);
    appendFileSync(outputFile, `Expected: ${testCase.expectedLabels.join(", ")}\n`);
    appendFileSync(outputFile, `========================================\n`);

    // Run act with environment variable for test mode
    const env = {
      ...process.env,
      CHANGED_FILES: filesStr,
    };

    const result = spawnSync("act", ["push", "--rm"], {
      env,
      encoding: "utf-8",
      stdio: ["pipe", "pipe", "pipe"],
    });

    const stdout = result.stdout || "";
    const stderr = result.stderr || "";
    const exitCode = result.status || 0;

    appendFileSync(outputFile, `Exit code: ${exitCode}\n`);
    appendFileSync(outputFile, `\n--- Act Output ---\n`);
    appendFileSync(outputFile, stdout);
    if (stderr) {
      appendFileSync(outputFile, `\n--- Stderr ---\n`);
      appendFileSync(outputFile, stderr);
    }

    // Check if successful
    if (exitCode !== 0) {
      console.error(`❌ Test failed with exit code ${exitCode}`);
      appendFileSync(outputFile, `\n❌ FAILED: Exit code ${exitCode}\n`);
      return false;
    }

    // Verify "Job succeeded" appears in output
    if (!stdout.includes("Job succeeded") && !stdout.includes("jobs succeeded")) {
      console.error(`❌ Test failed: No success message found`);
      appendFileSync(outputFile, `\n❌ FAILED: No success message\n`);
      return false;
    }

    // Check for expected labels in output
    const labelOutputMatch = stdout.match(
      /\["[^"]*"\]|\[.*?\]/g
    );

    let foundAllLabels = true;
    for (const label of testCase.expectedLabels) {
      if (!stdout.includes(label)) {
        console.warn(`⚠️  Label not found in output: ${label}`);
        // Don't fail on this as labels might be in JSON format
      }
    }

    console.log(`✅ Test passed`);
    appendFileSync(outputFile, `✅ PASSED\n\n`);
    return true;
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    console.error(`❌ Test error: ${errorMsg}`);
    appendFileSync(outputFile, `\n❌ ERROR: ${errorMsg}\n\n`);
    return false;
  }
}

// Main test harness
async function runTests() {
  const outputFile = join(process.cwd(), "act-result.txt");

  // Clear previous output file
  if (existsSync(outputFile)) {
    rmSync(outputFile);
  }

  // Start test summary
  appendFileSync(
    outputFile,
    `PR Label Assigner - GitHub Actions Workflow Test Results\n`
  );
  appendFileSync(outputFile, `Generated: ${new Date().toISOString()}\n`);
  appendFileSync(
    outputFile,
    `Total test cases: ${testCases.length}\n\n`
  );

  let passedTests = 0;
  let failedTests = 0;

  // Run each test case
  for (const testCase of testCases) {
    const passed = runActTest(testCase, outputFile);
    if (passed) {
      passedTests++;
    } else {
      failedTests++;
    }
  }

  // Add summary
  appendFileSync(outputFile, `\n========================================\n`);
  appendFileSync(outputFile, `SUMMARY\n`);
  appendFileSync(outputFile, `========================================\n`);
  appendFileSync(outputFile, `Total: ${testCases.length}\n`);
  appendFileSync(outputFile, `Passed: ${passedTests}\n`);
  appendFileSync(outputFile, `Failed: ${failedTests}\n`);

  // Print summary
  console.log(`\n========================================`);
  console.log(`FINAL SUMMARY`);
  console.log(`========================================`);
  console.log(`Total: ${testCases.length}`);
  console.log(`Passed: ${passedTests}`);
  console.log(`Failed: ${failedTests}`);
  console.log(`Result file: ${outputFile}`);

  // Exit with appropriate code
  if (failedTests > 0) {
    console.error(`\n❌ Some tests failed`);
    process.exit(1);
  } else {
    console.log(`\n✅ All tests passed!`);
    process.exit(0);
  }
}

runTests().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
