// Act integration test harness
// Sets up a temp git repo, runs `act push --rm`, asserts on exact expected output,
// and saves all output to act-result.txt.

import { execSync, spawnSync } from "child_process";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";

const PROJECT_DIR = __dirname;
const ACT_RESULT_FILE = path.join(PROJECT_DIR, "act-result.txt");

// Files to copy into the temp git repo
const FILES_TO_COPY = [
  "artifact-cleanup.ts",
  "artifact-cleanup.test.ts",
  "fixtures/workflow-test-artifacts.json",
  "fixtures/workflow-test-policy.json",
  ".github/workflows/artifact-cleanup-script.yml",
  ".actrc",
];

interface TestCase {
  name: string;
  // Strings that must appear in act output for the test to pass
  expectedStrings: string[];
}

const TEST_CASES: TestCase[] = [
  {
    name: "push-event-dry-run-fixture",
    expectedStrings: [
      // Unit tests passed
      "30 pass",
      // Dry-run step output
      "[DRY RUN]",
      "Artifacts to delete: 1",
      "Artifacts to keep: 4",
      "Space to reclaim: 100.00 MB",
      "artifact-A",
      // Live run step output
      "Artifacts to delete: 1",
      "artifact-A",
      // Job success
      "Job succeeded",
    ],
  },
];

function copyFileToDir(src: string, destDir: string): void {
  const destPath = path.join(destDir, src);
  const destParent = path.dirname(destPath);
  if (!fs.existsSync(destParent)) {
    fs.mkdirSync(destParent, { recursive: true });
  }
  fs.copyFileSync(path.join(PROJECT_DIR, src), destPath);
}

function runTestCase(tc: TestCase): { passed: boolean; output: string } {
  console.log(`\n=== Running test case: ${tc.name} ===`);

  // Set up isolated temp directory with a fresh git repo
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "artifact-cleanup-act-"));
  console.log(`  Temp dir: ${tmpDir}`);

  try {
    // Copy all project files into temp dir
    for (const file of FILES_TO_COPY) {
      const src = path.join(PROJECT_DIR, file);
      if (fs.existsSync(src)) {
        copyFileToDir(file, tmpDir);
      }
    }

    // Initialize git repo
    execSync("git init", { cwd: tmpDir, stdio: "pipe" });
    execSync("git config user.email 'test@example.com'", { cwd: tmpDir, stdio: "pipe" });
    execSync("git config user.name 'Test'", { cwd: tmpDir, stdio: "pipe" });
    execSync("git add -A", { cwd: tmpDir, stdio: "pipe" });
    execSync('git commit -m "test: initial commit"', { cwd: tmpDir, stdio: "pipe" });

    console.log("  Running act push --rm ...");
    const result = spawnSync("act", ["push", "--rm"], {
      cwd: tmpDir,
      timeout: 300_000, // 5 minute timeout
      encoding: "utf-8",
    });

    const stdout = result.stdout ?? "";
    const stderr = result.stderr ?? "";
    const combined = `STDOUT:\n${stdout}\n\nSTDERR:\n${stderr}`;

    const exitCode = result.status ?? 1;
    console.log(`  Exit code: ${exitCode}`);

    // Check expected strings
    let allPassed = true;
    for (const expected of tc.expectedStrings) {
      const found = stdout.includes(expected) || stderr.includes(expected);
      if (!found) {
        console.error(`  FAIL: expected string not found: "${expected}"`);
        allPassed = false;
      } else {
        console.log(`  OK: found "${expected}"`);
      }
    }

    if (exitCode !== 0) {
      console.error(`  FAIL: act exited with code ${exitCode}`);
      allPassed = false;
    }

    return { passed: allPassed && exitCode === 0, output: combined };
  } finally {
    // Clean up temp dir
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
}

async function main(): Promise<void> {
  console.log("=== Artifact Cleanup Act Test Harness ===");
  console.log(`Project dir: ${PROJECT_DIR}`);

  // Clear/create act-result.txt
  fs.writeFileSync(ACT_RESULT_FILE, "");

  let allPassed = true;

  for (const tc of TEST_CASES) {
    const separator = `\n${"=".repeat(60)}\nTEST CASE: ${tc.name}\n${"=".repeat(60)}\n`;
    fs.appendFileSync(ACT_RESULT_FILE, separator);

    const { passed, output } = runTestCase(tc);
    fs.appendFileSync(ACT_RESULT_FILE, output);

    const resultLine = `\nRESULT: ${passed ? "PASSED" : "FAILED"}\n`;
    fs.appendFileSync(ACT_RESULT_FILE, resultLine);

    if (!passed) {
      allPassed = false;
      console.error(`\nTest case FAILED: ${tc.name}`);
    } else {
      console.log(`\nTest case PASSED: ${tc.name}`);
    }
  }

  console.log(`\nAll output saved to: ${ACT_RESULT_FILE}`);

  if (!allPassed) {
    console.error("\nSome test cases FAILED.");
    process.exit(1);
  }

  console.log("\nAll test cases PASSED.");
}

main().catch((e) => {
  console.error("Fatal error:", e);
  process.exit(1);
});
