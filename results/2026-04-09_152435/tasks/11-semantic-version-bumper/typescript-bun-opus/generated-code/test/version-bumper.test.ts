// Test suite for the semantic version bumper.
// - Structural tests: validate the workflow YAML, actionlint, and file references.
// - Integration tests: run the full pipeline through act for each bump scenario.

import { describe, test, expect, beforeAll } from "bun:test";
import {
  mkdtempSync,
  cpSync,
  writeFileSync,
  readFileSync,
  existsSync,
  rmSync,
  mkdirSync,
  appendFileSync,
} from "fs";
import { join } from "path";
import { tmpdir } from "os";

// Resolve project root (one level up from test/)
const PROJECT_DIR = import.meta.dir.replace(/\/test$/, "");
const ACT_RESULT_FILE = join(PROJECT_DIR, "act-result.txt");
const WORKFLOW_PATH = join(
  PROJECT_DIR,
  ".github/workflows/semantic-version-bumper.yml",
);

// Clear act-result.txt at module load so it's fresh each run
writeFileSync(ACT_RESULT_FILE, "");

// ---------------------------------------------------------------------------
// Workflow Structure Tests
// ---------------------------------------------------------------------------

describe("Workflow Structure Tests", () => {
  let workflowContent: string;

  beforeAll(() => {
    workflowContent = readFileSync(WORKFLOW_PATH, "utf-8");
  });

  test("workflow file exists", () => {
    expect(existsSync(WORKFLOW_PATH)).toBe(true);
  });

  test("has push trigger", () => {
    expect(workflowContent).toContain("push:");
  });

  test("has pull_request trigger", () => {
    expect(workflowContent).toContain("pull_request:");
  });

  test("has workflow_dispatch trigger", () => {
    expect(workflowContent).toContain("workflow_dispatch:");
  });

  test("has jobs defined", () => {
    expect(workflowContent).toContain("jobs:");
  });

  test("uses actions/checkout@v4", () => {
    expect(workflowContent).toContain("actions/checkout@v4");
  });

  test("references src/main.ts which exists on disk", () => {
    expect(workflowContent).toContain("src/main.ts");
    expect(existsSync(join(PROJECT_DIR, "src/main.ts"))).toBe(true);
  });

  test("references src/version.ts exists", () => {
    expect(existsSync(join(PROJECT_DIR, "src/version.ts"))).toBe(true);
  });

  test("references src/commits.ts exists", () => {
    expect(existsSync(join(PROJECT_DIR, "src/commits.ts"))).toBe(true);
  });

  test("references src/changelog.ts exists", () => {
    expect(existsSync(join(PROJECT_DIR, "src/changelog.ts"))).toBe(true);
  });

  test("actionlint passes with exit code 0", () => {
    const result = Bun.spawnSync(["actionlint", WORKFLOW_PATH]);
    const stderr = result.stderr.toString();
    if (result.exitCode !== 0) {
      console.error("actionlint errors:", stderr);
    }
    expect(result.exitCode).toBe(0);
  });
});

// ---------------------------------------------------------------------------
// Helpers for act integration tests
// ---------------------------------------------------------------------------

/**
 * Set up a temporary git repository containing the project source files,
 * the GitHub Actions workflow, and a VERSION file. Then create conventional
 * commits so the version bumper has something to parse.
 */
function setupTestRepo(
  testName: string,
  commits: string[],
  initialVersion: string = "1.0.0",
): string {
  const tmpDir = mkdtempSync(join(tmpdir(), `svb-${testName}-`));

  // Copy source files
  cpSync(join(PROJECT_DIR, "src"), join(tmpDir, "src"), { recursive: true });

  // Copy workflow
  mkdirSync(join(tmpDir, ".github", "workflows"), { recursive: true });
  cpSync(WORKFLOW_PATH, join(tmpDir, ".github", "workflows", "semantic-version-bumper.yml"));

  // Copy .actrc so act uses the correct Docker image
  if (existsSync(join(PROJECT_DIR, ".actrc"))) {
    cpSync(join(PROJECT_DIR, ".actrc"), join(tmpDir, ".actrc"));
  }

  // Create VERSION file with the starting version
  writeFileSync(join(tmpDir, "VERSION"), initialVersion + "\n");

  // Initialise a git repository
  run(tmpDir, ["git", "init"]);
  run(tmpDir, ["git", "config", "user.email", "test@test.com"]);
  run(tmpDir, ["git", "config", "user.name", "Test"]);
  run(tmpDir, ["git", "add", "-A"]);
  run(tmpDir, ["git", "commit", "-m", "initial: project setup"]);

  // Create conventional commits that the bumper will read
  for (const msg of commits) {
    run(tmpDir, ["git", "commit", "--allow-empty", "-m", msg]);
  }

  return tmpDir;
}

/** Small wrapper around Bun.spawnSync that throws on failure. */
function run(cwd: string, cmd: string[]): void {
  const r = Bun.spawnSync(cmd, { cwd, stderr: "pipe" });
  if (r.exitCode !== 0) {
    throw new Error(`Command failed (${cmd.join(" ")}): ${r.stderr.toString()}`);
  }
}

/** Run `act push --rm` in the given repo directory and return output + exit code. */
function runAct(repoDir: string): { exitCode: number; output: string } {
  const result = Bun.spawnSync(["act", "push", "--rm", "--pull=false"], {
    cwd: repoDir,
    env: { ...process.env },
    // 5-minute timeout per act run
    timeout: 300_000_000_000, // nanoseconds
  });
  const stdout = result.stdout.toString();
  const stderr = result.stderr.toString();
  return { exitCode: result.exitCode ?? 1, output: stdout + "\n" + stderr };
}

/** Append a delimited test-case section to act-result.txt. */
function appendResult(testCase: string, output: string): void {
  const sep = "=".repeat(60);
  const entry = `\n${sep}\nTEST CASE: ${testCase}\n${sep}\n${output}\n`;
  appendFileSync(ACT_RESULT_FILE, entry);
}

// ---------------------------------------------------------------------------
// Act Integration Tests — three scenarios, one act run each
// ---------------------------------------------------------------------------

describe("Act Integration Tests", () => {
  // ---- PATCH: fix commits bump 1.0.0 -> 1.0.1 ----
  test(
    "patch bump: fix commits bump 1.0.0 -> 1.0.1",
    () => {
      const repoDir = setupTestRepo("patch", [
        "fix: resolve null pointer in user lookup",
        "fix(api): handle timeout errors gracefully",
      ]);

      const { exitCode, output } = runAct(repoDir);
      appendResult("patch bump (1.0.0 -> 1.0.1)", output);

      // Job must succeed
      expect(exitCode).toBe(0);
      expect(output.toLowerCase()).toContain("succeeded");

      // Script must output the exact expected version
      expect(output).toContain("VERSION=1.0.1");
      expect(output).toContain("Bump type: patch");
      expect(output).toContain("New version: 1.0.1");

      rmSync(repoDir, { recursive: true, force: true });
    },
    300_000,
  );

  // ---- MINOR: feat commits bump 1.0.0 -> 1.1.0 ----
  test(
    "minor bump: feat commits bump 1.0.0 -> 1.1.0",
    () => {
      const repoDir = setupTestRepo("minor", [
        "feat: add dark mode support",
        "feat(ui): implement drag-and-drop file upload",
        "fix: correct CSS alignment on mobile",
      ]);

      const { exitCode, output } = runAct(repoDir);
      appendResult("minor bump (1.0.0 -> 1.1.0)", output);

      expect(exitCode).toBe(0);
      expect(output.toLowerCase()).toContain("succeeded");

      expect(output).toContain("VERSION=1.1.0");
      expect(output).toContain("Bump type: minor");
      expect(output).toContain("New version: 1.1.0");

      rmSync(repoDir, { recursive: true, force: true });
    },
    300_000,
  );

  // ---- MAJOR: breaking commit bumps 1.0.0 -> 2.0.0 ----
  test(
    "major bump: breaking commit bumps 1.0.0 -> 2.0.0",
    () => {
      const repoDir = setupTestRepo("major", [
        "feat!: redesign authentication API",
        "fix: patch XSS vulnerability in comments",
      ]);

      const { exitCode, output } = runAct(repoDir);
      appendResult("major bump (1.0.0 -> 2.0.0)", output);

      expect(exitCode).toBe(0);
      expect(output.toLowerCase()).toContain("succeeded");

      expect(output).toContain("VERSION=2.0.0");
      expect(output).toContain("Bump type: major");
      expect(output).toContain("New version: 2.0.0");

      rmSync(repoDir, { recursive: true, force: true });
    },
    300_000,
  );
});
