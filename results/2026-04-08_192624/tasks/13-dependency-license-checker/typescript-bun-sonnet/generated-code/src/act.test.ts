/**
 * Act Integration Tests
 *
 * Runs the GitHub Actions workflow through `act` (nektos/act) in Docker.
 * Each test case:
 * 1. Sets up a temp git repo with all project files
 * 2. Runs `act push --rm` and captures output
 * 3. Asserts exit code 0
 * 4. Asserts exact expected values in the output
 * 5. Saves all output to act-result.txt
 */

import { describe, it, expect } from "bun:test";
import { mkdtempSync, cpSync, writeFileSync, appendFileSync, existsSync } from "fs";
import { join } from "path";
import { tmpdir } from "os";

const ROOT = join(import.meta.dir, "..");
const ACT_RESULT_FILE = join(ROOT, "act-result.txt");

// Docker can be slow - 5 minute timeout per test
const TIMEOUT_MS = 300_000;

// Initialize act-result.txt at module load
writeFileSync(ACT_RESULT_FILE, `# Act Test Results\nGenerated: ${new Date().toISOString()}\n\n`);

/**
 * Set up a temporary git repo with the project files, then run `act push --rm`.
 * Returns the captured output and exit code.
 */
async function runActInTempRepo(
  testName: string,
  opts: { job?: string } = {}
): Promise<{ stdout: string; exitCode: number }> {
  // Create a temp directory for the isolated git repo
  const tempDir = mkdtempSync(join(tmpdir(), "license-checker-act-"));

  // Copy all project files into the temp repo
  cpSync(ROOT, tempDir, {
    recursive: true,
    filter: (src) => {
      // Skip .git to avoid copying git history; we'll init fresh
      if (src.includes("/.git/")) return false;
      // Skip act-result.txt to avoid circular inclusion
      if (src.endsWith("act-result.txt")) return false;
      return true;
    },
  });

  // Initialize a fresh git repo (act needs a valid git repo)
  const gitInit = Bun.spawnSync(["git", "init"], { cwd: tempDir });
  if (gitInit.exitCode !== 0) {
    throw new Error(`git init failed: ${gitInit.stderr}`);
  }

  Bun.spawnSync(["git", "config", "user.email", "test@test.com"], { cwd: tempDir });
  Bun.spawnSync(["git", "config", "user.name", "Test"], { cwd: tempDir });

  const gitAdd = Bun.spawnSync(["git", "add", "-A"], { cwd: tempDir });
  if (gitAdd.exitCode !== 0) {
    throw new Error(`git add failed: ${gitAdd.stderr}`);
  }

  const gitCommit = Bun.spawnSync(["git", "commit", "-m", "test: add project files"], {
    cwd: tempDir,
  });
  if (gitCommit.exitCode !== 0) {
    throw new Error(`git commit failed: ${gitCommit.stderr}`);
  }

  // Build the act command
  const actArgs = ["act", "push", "--rm", "--no-cache-server"];
  if (opts.job) {
    actArgs.push("--job", opts.job);
  }

  console.log(`\n[${testName}] Running: ${actArgs.join(" ")} in ${tempDir}`);

  // Pass the parent environment but remove GITHUB_TOKEN so act uses its
  // local action cache instead of trying to authenticate to GitHub
  const env = { ...process.env };
  delete env.GITHUB_TOKEN;

  const proc = Bun.spawn(actArgs, {
    cwd: tempDir,
    stdout: "pipe",
    stderr: "pipe",
    env,
  });

  const [stdoutText, stderrText, exitCode] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
    proc.exited,
  ]);

  const combined = stdoutText + stderrText;

  // Append to act-result.txt
  const delimiter = `\n${"=".repeat(60)}\n`;
  appendFileSync(
    ACT_RESULT_FILE,
    `${delimiter}TEST CASE: ${testName}\nExit Code: ${exitCode}\n${delimiter}\n${combined}\n`
  );

  return { stdout: combined, exitCode };
}

// ─── Act Tests ────────────────────────────────────────────────────────────────

describe("act workflow execution", () => {
  it(
    "unit tests job runs successfully and all tests pass",
    async () => {
      const { stdout, exitCode } = await runActInTempRepo("unit-tests-job", {
        job: "run-unit-tests",
      });

      console.log("Act output (unit tests):\n", stdout.slice(-3000));

      // Assert exit code 0
      expect(exitCode).toBe(0);

      // Assert job succeeded
      expect(stdout).toContain("Job succeeded");

      // Assert tests passed - look for "16 pass"
      expect(stdout).toContain("16 pass");

      // Assert zero failures
      expect(stdout).toContain("0 fail");

      // Assert all tests passed message
      expect(stdout).toContain("All tests passed!");
    },
    TIMEOUT_MS
  );

  it(
    "check-licenses job: approved=COMPLIANT:true, denied=COMPLIANT:false, all RESULT:PASS",
    async () => {
      const { stdout, exitCode } = await runActInTempRepo("check-licenses-all-fixtures", {
        job: "check-licenses",
      });

      console.log("Act output (check-licenses):\n", stdout.slice(-4000));

      // All matrix jobs must exit with code 0
      expect(exitCode).toBe(0);

      // All 3 matrix jobs must show "Job succeeded"
      const jobSucceededCount = (stdout.match(/Job succeeded/g) || []).length;
      expect(jobSucceededCount).toBeGreaterThanOrEqual(3);

      // Approved fixture: must show COMPLIANT: true
      expect(stdout).toContain("COMPLIANT: true");

      // Denied and unknown fixtures: must show COMPLIANT: false
      expect(stdout).toContain("COMPLIANT: false");

      // Denied fixture must show GPL-3.0 as denied
      expect(stdout).toContain("GPL-3.0");
      expect(stdout).toContain("denied");

      // All verification steps must pass
      expect(stdout).toContain("RESULT: PASS");

      // Approved packages must show MIT license
      expect(stdout).toContain("MIT");
    },
    TIMEOUT_MS
  );
});

// ─── Verify act-result.txt is created ────────────────────────────────────────

describe("act-result.txt artifact", () => {
  it("act-result.txt file exists", () => {
    expect(existsSync(ACT_RESULT_FILE)).toBe(true);
  });

  it("act-result.txt contains test case output", async () => {
    const content = await Bun.file(ACT_RESULT_FILE).text();
    // After the act tests run, the file should contain substantial output
    expect(content).toContain("TEST CASE:");
    expect(content).toContain("Act Test Results");
  });
});
