/**
 * Act test harness for the environment matrix generator.
 *
 * This script:
 *  1. Creates a temporary git repository containing all project files.
 *  2. Runs `act push --rm` against the workflow.
 *  3. Captures the full output and appends it to `act-result.txt`.
 *  4. Asserts that act exited with code 0.
 *  5. Parses the output and asserts on exact expected values from each fixture.
 *
 * Run with: bun run run-act-tests.ts
 */

import { execSync, spawnSync } from "child_process";
import { mkdtempSync, cpSync, writeFileSync, appendFileSync, existsSync, rmSync } from "fs";
import { join, resolve } from "path";
import { tmpdir } from "os";

// ── Configuration ──────────────────────────────────────────────────────────────

const PROJECT_DIR = resolve(__dirname);
const ACT_RESULT_FILE = join(PROJECT_DIR, "act-result.txt");

// Expected values per fixture that we'll assert in the act output.
// These are exact strings that must appear in the workflow stdout.
const EXPECTED_VALUES: Record<string, string[]> = {
  basic: [
    '"ubuntu-latest"',
    '"windows-latest"',
    '"18"',
    '"20"',
    '"fail-fast": true',
    "COMBINATION_COUNT: 4",
  ],
  "include-exclude": [
    '"fail-fast": false',
    '"max-parallel": 3',
    '"experimental": true',
    "COMBINATION_COUNT: 4",
  ],
  "size-exceeded": [
    "MATRIX_ERROR",
    "exceeds maximum",
  ],
};

// ── Helpers ────────────────────────────────────────────────────────────────────

function log(msg: string): void {
  console.log(msg);
}

function fail(msg: string): never {
  console.error(`FAIL: ${msg}`);
  process.exit(1);
}

/**
 * Copy all relevant project files into a destination directory so act has a
 * complete, self-contained repository to work from.
 */
function copyProjectFiles(destDir: string): void {
  const filesToCopy = [
    "matrix-generator.ts",
    "index.ts",
    "matrix-generator.test.ts",
    "workflow.test.ts",
    ".github",
    "fixtures",
    ".actrc",
  ];
  for (const file of filesToCopy) {
    const src = join(PROJECT_DIR, file);
    const dst = join(destDir, file);
    if (existsSync(src)) {
      cpSync(src, dst, { recursive: true });
    }
  }
}

/**
 * Initialise a git repo in dir, add all files, and create an initial commit.
 */
function initGitRepo(dir: string): void {
  const opts = { cwd: dir, stdio: "pipe" as const };
  execSync("git init", opts);
  execSync("git config user.email 'test@example.com'", opts);
  execSync("git config user.name 'Test'", opts);
  execSync("git add -A", opts);
  execSync("git commit -m 'test: initial commit for act run'", opts);
}

/**
 * Run `act push --rm` in dir, return { exitCode, output }.
 */
function runAct(dir: string): { exitCode: number; output: string } {
  log("  Running act push --rm ...");
  const result = spawnSync(
    "act",
    ["push", "--rm", "--pull=false"],
    {
      cwd: dir,
      encoding: "utf-8",
      timeout: 300_000, // 5 min max
    }
  );
  const output = (result.stdout ?? "") + (result.stderr ?? "");
  return { exitCode: result.status ?? 1, output };
}

// ── Main test runner ───────────────────────────────────────────────────────────

async function main(): Promise<void> {
  // Initialise (or truncate) act-result.txt
  writeFileSync(ACT_RESULT_FILE, `# act-result.txt — Environment Matrix Generator\n\n`);
  log("Starting act integration test...\n");

  // We run a single act invocation with all fixtures included.
  // The workflow processes all three fixtures in sequence, so one run is enough
  // to verify all expected values.
  const tmpDir = mkdtempSync(join(tmpdir(), "matrix-gen-act-"));
  log(`Temp directory: ${tmpDir}`);

  try {
    log("  Copying project files...");
    copyProjectFiles(tmpDir);

    log("  Initialising git repository...");
    initGitRepo(tmpDir);

    appendFileSync(
      ACT_RESULT_FILE,
      `\n${"=".repeat(60)}\n` +
      `TEST CASE: all-fixtures (single act run)\n` +
      `${"=".repeat(60)}\n`
    );

    const { exitCode, output } = runAct(tmpDir);

    appendFileSync(ACT_RESULT_FILE, output);
    appendFileSync(ACT_RESULT_FILE, `\nEXIT_CODE: ${exitCode}\n`);

    log(`  act exit code: ${exitCode}`);

    // ── Assert exit code 0 ───────────────────────────────────────────────────
    if (exitCode !== 0) {
      fail(
        `act exited with code ${exitCode}. Check act-result.txt for details.`
      );
    }

    // ── Assert "Job succeeded" appeared ──────────────────────────────────────
    if (!output.includes("Job succeeded")) {
      fail('Expected "Job succeeded" in act output but it was not found.');
    }
    log('  [PASS] "Job succeeded" found in output');

    // ── Assert fixture-specific expected values ───────────────────────────────
    for (const [fixture, expectedStrings] of Object.entries(EXPECTED_VALUES)) {
      log(`\n  Checking fixture: ${fixture}`);
      for (const expected of expectedStrings) {
        if (!output.includes(expected)) {
          fail(
            `Fixture '${fixture}': expected to find '${expected}' in act output but it was not present.\n` +
            `Check act-result.txt for the full output.`
          );
        }
        log(`    [PASS] found: ${JSON.stringify(expected)}`);
      }
    }

    log("\n✓ All assertions passed!");
    log(`act-result.txt written to: ${ACT_RESULT_FILE}`);
  } finally {
    // Clean up temp directory
    try {
      rmSync(tmpDir, { recursive: true, force: true });
    } catch {
      // Best-effort cleanup
    }
  }
}

main().catch((err) => {
  console.error("Unexpected error:", err);
  process.exit(1);
});
