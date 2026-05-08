// workflow.test.ts
// Tests that:
// 1. The workflow YAML has the correct structure (triggers, jobs, steps)
// 2. All files referenced by the workflow exist
// 3. actionlint passes
// 4. The workflow runs successfully via act (end-to-end integration tests)
//
// Each act-based test:
//   - Sets up a temp git repo with project files + fixture data
//   - Runs `act push --rm` and captures output
//   - Appends output to act-result.txt
//   - Asserts exact expected version values in the output

import { test, expect, describe, beforeAll, afterAll } from "bun:test";
import {
  mkdtempSync,
  rmSync,
  writeFileSync,
  mkdirSync,
  readFileSync,
  existsSync,
  copyFileSync,
} from "fs";
import { join, resolve, dirname } from "path";
import { tmpdir } from "os";
import { spawnSync } from "child_process";

const WORKFLOW_PATH = ".github/workflows/semantic-version-bumper.yml";
const PROJECT_ROOT = resolve(import.meta.dir);
const ACT_RESULT_FILE = join(PROJECT_ROOT, "act-result.txt");

// --- Workflow structure tests (no act needed) ---

describe("Workflow YAML structure", () => {
  let workflowContent: string;

  beforeAll(() => {
    workflowContent = readFileSync(join(PROJECT_ROOT, WORKFLOW_PATH), "utf-8");
  });

  test("workflow file exists", () => {
    expect(existsSync(join(PROJECT_ROOT, WORKFLOW_PATH))).toBe(true);
  });

  test("has push trigger", () => {
    expect(workflowContent).toContain("push:");
  });

  test("has pull_request trigger", () => {
    expect(workflowContent).toContain("pull_request");
  });

  test("has workflow_dispatch trigger", () => {
    expect(workflowContent).toContain("workflow_dispatch");
  });

  test("has bump-version job", () => {
    expect(workflowContent).toContain("bump-version:");
  });

  test("uses actions/checkout@v4", () => {
    expect(workflowContent).toContain("actions/checkout@v4");
  });

  test("installs Bun", () => {
    expect(workflowContent).toContain("bun.sh/install");
  });

  test("runs bumper.ts", () => {
    expect(workflowContent).toContain("bumper.ts");
  });

  test("has contents: write permission", () => {
    expect(workflowContent).toContain("contents: write");
  });
});

describe("Referenced files exist", () => {
  test("bumper.ts exists", () => {
    expect(existsSync(join(PROJECT_ROOT, "bumper.ts"))).toBe(true);
  });

  test("fixtures/commits-patch.txt exists", () => {
    expect(existsSync(join(PROJECT_ROOT, "fixtures/commits-patch.txt"))).toBe(true);
  });

  test("fixtures/commits-minor.txt exists", () => {
    expect(existsSync(join(PROJECT_ROOT, "fixtures/commits-minor.txt"))).toBe(true);
  });

  test("fixtures/commits-major.txt exists", () => {
    expect(existsSync(join(PROJECT_ROOT, "fixtures/commits-major.txt"))).toBe(true);
  });

  test("fixtures/commits-mixed.txt exists", () => {
    expect(existsSync(join(PROJECT_ROOT, "fixtures/commits-mixed.txt"))).toBe(true);
  });
});

describe("actionlint validation", () => {
  test("workflow passes actionlint with exit code 0", () => {
    const result = spawnSync("actionlint", [WORKFLOW_PATH], {
      cwd: PROJECT_ROOT,
      encoding: "utf-8",
    });
    if (result.status !== 0) {
      console.error("actionlint output:", result.stdout, result.stderr);
    }
    expect(result.status).toBe(0);
  });
});

// --- Act integration tests ---

// Helper: create a temp git repo with project files + given fixtures
function setupTestRepo(opts: {
  version: string;
  commitsFixture: string; // path to fixture file relative to PROJECT_ROOT
  versionFile?: "version.txt" | "package.json";
}): string {
  const tmpDir = mkdtempSync(join(tmpdir(), "semver-act-"));

  // Copy core project files
  for (const f of ["bumper.ts"]) {
    copyFileSync(join(PROJECT_ROOT, f), join(tmpDir, f));
  }

  // Copy workflow
  mkdirSync(join(tmpDir, ".github/workflows"), { recursive: true });
  copyFileSync(
    join(PROJECT_ROOT, WORKFLOW_PATH),
    join(tmpDir, WORKFLOW_PATH)
  );

  // Write .actrc: use local image, disable force-pull
  writeFileSync(join(tmpDir, ".actrc"), "-P ubuntu-latest=act-ubuntu-pwsh:latest\n--pull=false\n");

  // Write version file
  const versionFile = opts.versionFile ?? "version.txt";
  if (versionFile === "package.json") {
    writeFileSync(
      join(tmpDir, "package.json"),
      JSON.stringify({ name: "test-pkg", version: opts.version }, null, 2) + "\n"
    );
  } else {
    writeFileSync(join(tmpDir, "version.txt"), opts.version + "\n");
  }

  // Copy commits fixture as commits.txt
  copyFileSync(join(PROJECT_ROOT, opts.commitsFixture), join(tmpDir, "commits.txt"));

  // Initialize git repo and commit everything
  const gitOpts = { cwd: tmpDir, encoding: "utf-8" as const };
  spawnSync("git", ["init"], gitOpts);
  spawnSync("git", ["config", "user.email", "test@test.com"], gitOpts);
  spawnSync("git", ["config", "user.name", "Test"], gitOpts);
  spawnSync("git", ["add", "-A"], gitOpts);
  spawnSync("git", ["commit", "-m", "test: initial commit"], gitOpts);

  return tmpDir;
}

// Helper: run act push in tmpDir, append output to act-result.txt, return {exitCode, output}
function runAct(tmpDir: string, label: string): { exitCode: number; output: string } {
  const delimiter = `\n${"=".repeat(60)}\nTEST CASE: ${label}\n${"=".repeat(60)}\n`;

  const result = spawnSync("act", ["push", "--rm"], {
    cwd: tmpDir,
    encoding: "utf-8",
    timeout: 300_000, // 5 min max
  });

  const output = [result.stdout ?? "", result.stderr ?? ""].join("\n");

  // Append to act-result.txt
  const entry = delimiter + output + "\n";
  const existing = existsSync(ACT_RESULT_FILE)
    ? readFileSync(ACT_RESULT_FILE, "utf-8")
    : "";
  writeFileSync(ACT_RESULT_FILE, existing + entry);

  return { exitCode: result.status ?? 1, output };
}

// Cleanup temp dirs after tests
const tempDirs: string[] = [];
afterAll(() => {
  for (const d of tempDirs) {
    rmSync(d, { recursive: true, force: true });
  }
});

describe("Act integration: workflow execution", () => {
  // Test 1: patch bump — fix commits on version 1.0.0 → 1.0.1
  test("patch bump: fix commits 1.0.0 -> 1.0.1", () => {
    const tmpDir = setupTestRepo({
      version: "1.0.0",
      commitsFixture: "fixtures/commits-patch.txt",
    });
    tempDirs.push(tmpDir);

    const { exitCode, output } = runAct(tmpDir, "patch-bump: 1.0.0 -> 1.0.1");

    expect(exitCode).toBe(0);
    expect(output).toContain("Job succeeded");
    expect(output).toContain("NEW_VERSION=1.0.1");
    expect(output).toContain("OLD_VERSION=1.0.0");
  }, 300_000);

  // Test 2: minor bump — feat commits on version 1.1.0 → 1.2.0
  test("minor bump: feat commits 1.1.0 -> 1.2.0", () => {
    const tmpDir = setupTestRepo({
      version: "1.1.0",
      commitsFixture: "fixtures/commits-minor.txt",
    });
    tempDirs.push(tmpDir);

    const { exitCode, output } = runAct(tmpDir, "minor-bump: 1.1.0 -> 1.2.0");

    expect(exitCode).toBe(0);
    expect(output).toContain("Job succeeded");
    expect(output).toContain("NEW_VERSION=1.2.0");
    expect(output).toContain("OLD_VERSION=1.1.0");
  }, 300_000);

  // Test 3: major bump — breaking commit on version 2.0.0 → 3.0.0
  test("major bump: breaking commit 2.0.0 -> 3.0.0", () => {
    const tmpDir = setupTestRepo({
      version: "2.0.0",
      commitsFixture: "fixtures/commits-major.txt",
    });
    tempDirs.push(tmpDir);

    const { exitCode, output } = runAct(tmpDir, "major-bump: 2.0.0 -> 3.0.0");

    expect(exitCode).toBe(0);
    expect(output).toContain("Job succeeded");
    expect(output).toContain("NEW_VERSION=3.0.0");
    expect(output).toContain("OLD_VERSION=2.0.0");
  }, 300_000);

  // Test 4: mixed commits (feat+fix) on version 1.0.0 → 1.1.0 via package.json
  test("mixed commits with package.json: 1.0.0 -> 1.1.0", () => {
    const tmpDir = setupTestRepo({
      version: "1.0.0",
      commitsFixture: "fixtures/commits-mixed.txt",
      versionFile: "package.json",
    });
    tempDirs.push(tmpDir);

    const { exitCode, output } = runAct(tmpDir, "mixed-bump (pkg.json): 1.0.0 -> 1.1.0");

    expect(exitCode).toBe(0);
    expect(output).toContain("Job succeeded");
    expect(output).toContain("NEW_VERSION=1.1.0");
    expect(output).toContain("OLD_VERSION=1.0.0");
  }, 300_000);
});
