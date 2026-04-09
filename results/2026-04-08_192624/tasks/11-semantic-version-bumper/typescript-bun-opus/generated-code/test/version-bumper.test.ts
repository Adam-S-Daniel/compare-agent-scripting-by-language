/**
 * Test harness for the Semantic Version Bumper.
 *
 * All functional tests run through the GitHub Actions workflow via `act`.
 * Each test case creates a temporary git repo with specific commits,
 * runs `act push --rm`, and asserts on the exact output.
 *
 * TDD approach: tests define the expected behavior (exact version output)
 * and the implementation must produce those exact values.
 */

import { describe, test, expect, beforeAll, afterAll } from "bun:test";
import {
  mkdtempSync,
  mkdirSync,
  writeFileSync,
  readFileSync,
  cpSync,
  existsSync,
  appendFileSync,
  rmSync,
} from "fs";
import { join, resolve } from "path";
import { spawnSync, execSync } from "child_process";
import { tmpdir } from "os";

// Paths relative to the project root
const PROJECT_DIR = resolve(import.meta.dir, "..");
const ACT_RESULT_FILE = join(PROJECT_DIR, "act-result.txt");
const WORKFLOW_PATH = join(
  PROJECT_DIR,
  ".github/workflows/semantic-version-bumper.yml",
);

// Source files to copy into each isolated test repo
const FILES_TO_COPY = [
  "src/version.ts",
  "src/commits.ts",
  "src/changelog.ts",
  "src/main.ts",
  "package.json",
  "tsconfig.json",
];

/** Defines a test case with input fixtures and expected output */
interface TestCase {
  name: string;
  startVersion: string;
  commits: string[];
  expectedVersion: string;
  expectedBump: string;
  expectedChangelogSections: string[];
}

// Test cases covering patch, minor, major, and mixed bump scenarios
const testCases: TestCase[] = [
  {
    name: "patch-bump",
    startVersion: "1.0.0",
    commits: [
      "fix: resolve null pointer exception",
      "fix: handle empty input gracefully",
    ],
    expectedVersion: "1.0.1",
    expectedBump: "patch",
    expectedChangelogSections: ["Bug Fixes"],
  },
  {
    name: "minor-bump",
    startVersion: "1.1.0",
    commits: [
      "feat: add search functionality",
      "fix: correct typo in error message",
    ],
    expectedVersion: "1.2.0",
    expectedBump: "minor",
    expectedChangelogSections: ["Features", "Bug Fixes"],
  },
  {
    name: "major-bump",
    startVersion: "2.0.0",
    commits: ["feat!: redesign API endpoints"],
    expectedVersion: "3.0.0",
    expectedBump: "major",
    expectedChangelogSections: ["Breaking Changes"],
  },
  {
    name: "mixed-with-breaking",
    startVersion: "1.0.0",
    commits: [
      "fix: minor bug fix",
      "feat: add new feature",
      "feat!: breaking API change",
    ],
    expectedVersion: "2.0.0",
    expectedBump: "major",
    expectedChangelogSections: ["Breaking Changes", "Features", "Bug Fixes"],
  },
];

/**
 * Set up an isolated git repo with source files and fixture commits.
 * Returns the path to the temporary directory.
 */
function setupTestRepo(tc: TestCase): string {
  const tmpDir = mkdtempSync(join(tmpdir(), `svb-${tc.name}-`));

  // Create directory structure
  mkdirSync(join(tmpDir, "src"), { recursive: true });
  mkdirSync(join(tmpDir, ".github", "workflows"), { recursive: true });

  // Copy source files
  for (const file of FILES_TO_COPY) {
    const srcPath = join(PROJECT_DIR, file);
    if (existsSync(srcPath)) {
      cpSync(srcPath, join(tmpDir, file));
    }
  }

  // Copy workflow
  cpSync(
    WORKFLOW_PATH,
    join(tmpDir, ".github/workflows/semantic-version-bumper.yml"),
  );

  // Create VERSION file with the starting version
  writeFileSync(join(tmpDir, "VERSION"), tc.startVersion + "\n");

  // Initialize git repo on 'main' branch
  execSync("git init -b main", { cwd: tmpDir, stdio: "pipe" });
  execSync('git config user.name "test"', { cwd: tmpDir, stdio: "pipe" });
  execSync('git config user.email "test@test.com"', {
    cwd: tmpDir,
    stdio: "pipe",
  });
  execSync("git add -A", { cwd: tmpDir, stdio: "pipe" });
  execSync('git commit -m "initial commit"', { cwd: tmpDir, stdio: "pipe" });

  // Add fixture commits (conventional commit messages)
  for (const msg of tc.commits) {
    // Escape double quotes in commit messages
    const escaped = msg.replace(/"/g, '\\"');
    execSync(`git commit --allow-empty -m "${escaped}"`, {
      cwd: tmpDir,
      stdio: "pipe",
    });
  }

  return tmpDir;
}

/**
 * Run `act push --rm` in the given directory and capture all output.
 * Returns exit code and combined stdout+stderr.
 */
function runAct(dir: string): { exitCode: number; output: string } {
  const result = spawnSync(
    "act",
    ["push", "--rm", "-P", "ubuntu-latest=catthehacker/ubuntu:act-latest"],
    {
      cwd: dir,
      encoding: "utf-8",
      timeout: 300000, // 5 minutes
      env: { ...process.env },
    },
  );

  const output = (result.stdout || "") + "\n" + (result.stderr || "");
  return { exitCode: result.status ?? 1, output };
}

// Initialize the act-result.txt file before all tests
beforeAll(() => {
  writeFileSync(
    ACT_RESULT_FILE,
    "=== Semantic Version Bumper - Act Test Results ===\n",
  );
});

// ─── Workflow Structure Tests ─────────────────────────────────────────────────

describe("Workflow Structure Tests", () => {
  test("workflow file exists", () => {
    expect(existsSync(WORKFLOW_PATH)).toBe(true);
  });

  test("workflow has correct triggers (push, pull_request, workflow_dispatch)", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    // Verify all three trigger types are present
    expect(content).toContain("push:");
    expect(content).toContain("pull_request:");
    expect(content).toContain("workflow_dispatch:");
    // Verify branch filters
    expect(content).toContain("branches:");
  });

  test("workflow has correct job structure", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("jobs:");
    expect(content).toContain("bump-version:");
    expect(content).toContain("runs-on: ubuntu-latest");
    expect(content).toContain("actions/checkout@v4");
    expect(content).toContain("fetch-depth: 0");
  });

  test("workflow has permissions defined", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("permissions:");
    expect(content).toContain("contents: read");
  });

  test("workflow references script files that exist", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    // The workflow should reference our main script
    expect(content).toContain("src/main.ts");
    // Verify the referenced file actually exists
    expect(existsSync(join(PROJECT_DIR, "src/main.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_DIR, "src/version.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_DIR, "src/commits.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_DIR, "src/changelog.ts"))).toBe(true);
  });

  test("workflow installs Bun runtime", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("Install Bun");
    expect(content).toContain("bun.sh/install");
  });

  test("actionlint passes with exit code 0", () => {
    const result = spawnSync("actionlint", [WORKFLOW_PATH], {
      encoding: "utf-8",
    });
    if (result.status !== 0) {
      console.error("actionlint output:", result.stdout, result.stderr);
    }
    expect(result.status).toBe(0);
  });
});

// ─── Act Pipeline Tests ──────────────────────────────────────────────────────

describe("Act Pipeline Tests", () => {
  const tempDirs: string[] = [];

  afterAll(() => {
    // Clean up temporary directories
    for (const dir of tempDirs) {
      try {
        rmSync(dir, { recursive: true, force: true });
      } catch {
        // Ignore cleanup errors
      }
    }
  });

  for (const tc of testCases) {
    test(
      `${tc.name}: version ${tc.startVersion} -> ${tc.expectedVersion} (${tc.expectedBump} bump)`,
      () => {
        // Red phase: these assertions define our exact expected output
        const dir = setupTestRepo(tc);
        tempDirs.push(dir);

        const { exitCode, output } = runAct(dir);

        // Append output to act-result.txt for archival
        appendFileSync(
          ACT_RESULT_FILE,
          `\n${"=".repeat(60)}\n` +
            `Test Case: ${tc.name}\n` +
            `Start Version: ${tc.startVersion}\n` +
            `Expected Version: ${tc.expectedVersion}\n` +
            `Expected Bump: ${tc.expectedBump}\n` +
            `${"=".repeat(60)}\n` +
            output +
            "\n",
        );

        // Assert act exited successfully
        expect(exitCode).toBe(0);

        // Assert the job completed successfully
        expect(output).toContain("Job succeeded");

        // Assert EXACT expected version output (machine-readable line)
        expect(output).toContain(`NEW_VERSION=${tc.expectedVersion}`);

        // Assert the starting version was correctly read
        expect(output).toContain(
          `Current version: ${tc.startVersion}`,
        );

        // Assert the correct bump type was determined
        expect(output).toContain(`Bump type: ${tc.expectedBump}`);

        // Assert the new version was calculated correctly
        expect(output).toContain(`New version: ${tc.expectedVersion}`);

        // Assert changelog sections appear for this bump type
        for (const section of tc.expectedChangelogSections) {
          expect(output).toContain(`### ${section}`);
        }

        // Assert the changelog header contains the exact new version
        expect(output).toContain(`## [${tc.expectedVersion}]`);
      },
      300000, // 5 minute timeout per test case
    );
  }
});
