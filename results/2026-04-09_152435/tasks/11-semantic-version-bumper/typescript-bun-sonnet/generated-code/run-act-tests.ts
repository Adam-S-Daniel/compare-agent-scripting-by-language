/**
 * Act Test Harness for Semantic Version Bumper
 *
 * This script:
 * 1. Creates a temp git repo with all project files
 * 2. Runs `act push --rm` to execute the GitHub Actions workflow in Docker
 * 3. Saves the full output to act-result.txt
 * 4. Asserts on exit code, job success, and exact version output values
 *
 * Run: bun run run-act-tests.ts
 */

import * as fs from "fs";
import * as path from "path";
import * as os from "os";

const CWD = process.cwd();
const ACT_RESULT_FILE = path.join(CWD, "act-result.txt");

// ─── Helpers ──────────────────────────────────────────────────────────────────

function log(msg: string): void {
  console.log(msg);
}

function copyDirRecursive(src: string, dst: string): void {
  if (!fs.existsSync(dst)) {
    fs.mkdirSync(dst, { recursive: true });
  }
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    // Skip node_modules and .git when copying project files
    if (entry.name === "node_modules" || entry.name === ".git") continue;
    const srcPath = path.join(src, entry.name);
    const dstPath = path.join(dst, entry.name);
    if (entry.isDirectory()) {
      copyDirRecursive(srcPath, dstPath);
    } else {
      fs.copyFileSync(srcPath, dstPath);
    }
  }
}

function runCommand(cmd: string[], cwd: string): { exitCode: number; output: string } {
  const proc = Bun.spawnSync(cmd, {
    cwd,
    stdout: "pipe",
    stderr: "pipe",
  });
  const stdout = proc.stdout ? new TextDecoder().decode(proc.stdout) : "";
  const stderr = proc.stderr ? new TextDecoder().decode(proc.stderr) : "";
  return {
    exitCode: proc.exitCode ?? 1,
    output: stdout + stderr,
  };
}

function assert(condition: boolean, message: string): boolean {
  if (condition) {
    log(`  ✓ ${message}`);
    return true;
  } else {
    log(`  ✗ FAIL: ${message}`);
    return false;
  }
}

// ─── Setup Temp Git Repo ──────────────────────────────────────────────────────

log("=== Setting up temp git repo ===");

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "semver-act-"));
log(`Temp dir: ${tmpDir}`);

// Copy all project files into the temp directory
copyDirRecursive(CWD, tmpDir);

// Copy .actrc so act uses the right container image
const actrcSrc = path.join(CWD, ".actrc");
if (fs.existsSync(actrcSrc)) {
  fs.copyFileSync(actrcSrc, path.join(tmpDir, ".actrc"));
  log("Copied .actrc");
}

// Initialize git repo (act requires a git repo)
runCommand(["git", "init"], tmpDir);
runCommand(["git", "config", "user.email", "test@example.com"], tmpDir);
runCommand(["git", "config", "user.name", "Test Runner"], tmpDir);
runCommand(["git", "add", "-A"], tmpDir);
const commitResult = runCommand(["git", "commit", "-m", "ci: add semantic version bumper"], tmpDir);
log(`Git commit exit code: ${commitResult.exitCode}`);

// ─── Run act ──────────────────────────────────────────────────────────────────

log("\n=== Running act push --rm ===");
log("This takes 30-90 seconds for container startup + workflow execution...\n");

// --pull=false: use already-pulled container images, avoid slow pulls
// --rm: clean up container after run
const actResult = runCommand(["act", "push", "--rm", "--pull=false"], tmpDir);

const actOutput = actResult.output;
log(`act exit code: ${actResult.exitCode}`);

// ─── Save to act-result.txt ───────────────────────────────────────────────────

const delimiter = `\n${"=".repeat(80)}\n`;
const resultContent =
  `${delimiter}` +
  `ACT TEST RUN - Semantic Version Bumper\n` +
  `Timestamp: ${new Date().toISOString()}\n` +
  `Exit code: ${actResult.exitCode}\n` +
  `${delimiter}\n` +
  actOutput +
  `\n${delimiter}`;

fs.writeFileSync(ACT_RESULT_FILE, resultContent);
log(`\nAct output saved to: ${ACT_RESULT_FILE}`);

// Print act output for debugging
log("\n--- ACT OUTPUT ---");
log(actOutput.slice(0, 5000)); // First 5000 chars
if (actOutput.length > 5000) {
  log(`... (${actOutput.length - 5000} more chars, see act-result.txt)`);
}
log("--- END ACT OUTPUT ---\n");

// ─── Assertions ───────────────────────────────────────────────────────────────

log("=== Assertions ===");
let allPassed = true;

function check(condition: boolean, msg: string): void {
  if (!assert(condition, msg)) allPassed = false;
}

// 1. Act process exited with code 0
check(actResult.exitCode === 0, "act exited with code 0");

// 2. Job succeeded
check(actOutput.includes("Job succeeded"), 'Output contains "Job succeeded"');

// 3. Each test case passed with exact expected version
check(actOutput.includes("NEW_VERSION: 1.0.1"), "test-case-1: outputs exactly NEW_VERSION: 1.0.1");
check(actOutput.includes("NEW_VERSION: 1.1.0"), "test-case-2: outputs exactly NEW_VERSION: 1.1.0");
check(actOutput.includes("NEW_VERSION: 2.0.0"), "test-case-3: outputs exactly NEW_VERSION: 2.0.0");
check(actOutput.includes("NEW_VERSION: 1.3.0"), "test-case-4: outputs exactly NEW_VERSION: 1.3.0");

// 4. PASS markers present (workflow step-level pass messages)
check(actOutput.includes("PASS: test-case-1 patch bump"), "test-case-1: PASS marker present");
check(actOutput.includes("PASS: test-case-2 minor bump"), "test-case-2: PASS marker present");
check(actOutput.includes("PASS: test-case-3 major bump"), "test-case-3: PASS marker present");
check(actOutput.includes("PASS: test-case-4 mixed commits"), "test-case-4: PASS marker present");

// 5. Unit tests ran (bun test output)
check(actOutput.includes("pass") && actOutput.includes("bun test"), "Unit tests ran via bun test");

// 6. Version assertion in fixture verified (ASSERTION PASSED: X.Y.Z)
check(actOutput.includes("ASSERTION PASSED: 1.0.1"), "test-case-1: assertion passed");
check(actOutput.includes("ASSERTION PASSED: 1.1.0"), "test-case-2: assertion passed");
check(actOutput.includes("ASSERTION PASSED: 2.0.0"), "test-case-3: assertion passed");
check(actOutput.includes("ASSERTION PASSED: 1.3.0"), "test-case-4: assertion passed");

// ─── Cleanup ──────────────────────────────────────────────────────────────────

fs.rmSync(tmpDir, { recursive: true, force: true });
log(`\nCleaned up temp dir: ${tmpDir}`);

// ─── Final Result ─────────────────────────────────────────────────────────────

if (allPassed) {
  log("\n✓ ALL ACT TESTS PASSED");
  process.exit(0);
} else {
  log("\n✗ SOME ACT TESTS FAILED - check act-result.txt for details");
  process.exit(1);
}
