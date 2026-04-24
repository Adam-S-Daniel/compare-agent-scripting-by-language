// Integration test suite — verifies workflow structure and runs act end-to-end.
// These tests are intentionally separate from unit.test.ts so the workflow can
// run only unit tests without recursive act invocations.

import { describe, it, expect, beforeAll } from "bun:test";
import {
  existsSync,
  readFileSync,
  writeFileSync,
  mkdirSync,
  rmSync,
  cpSync, // cpSync used below; rmSync handles .git removal separately
} from "fs";
import { execSync, spawnSync } from "child_process";
import { join, resolve } from "path";

const WORKFLOW_PATH = ".github/workflows/dependency-license-checker.yml";
const PROJECT_ROOT = resolve(import.meta.dir, "..");
const ACT_RESULT_PATH = join(PROJECT_ROOT, "act-result.txt");

// ──────────────────────────────────────────────────
// Workflow structure tests
// ──────────────────────────────────────────────────
describe("workflow structure", () => {
  it("workflow file exists", () => {
    expect(existsSync(join(PROJECT_ROOT, WORKFLOW_PATH))).toBe(true);
  });

  it("workflow references src/licenseChecker.ts (path exists)", () => {
    expect(existsSync(join(PROJECT_ROOT, "src/licenseChecker.ts"))).toBe(true);
    const content = readFileSync(join(PROJECT_ROOT, WORKFLOW_PATH), "utf-8");
    expect(content).toContain("src/licenseChecker.ts");
  });

  it("workflow references fixture files that exist", () => {
    const content = readFileSync(join(PROJECT_ROOT, WORKFLOW_PATH), "utf-8");
    for (const fixture of [
      "fixtures/package-all-approved.json",
      "fixtures/package-with-denied.json",
      "fixtures/package-with-unknown.json",
    ]) {
      expect(content).toContain(fixture);
      expect(existsSync(join(PROJECT_ROOT, fixture))).toBe(true);
    }
  });

  it("workflow has expected triggers", () => {
    const content = readFileSync(join(PROJECT_ROOT, WORKFLOW_PATH), "utf-8");
    expect(content).toContain("push:");
    expect(content).toContain("pull_request:");
    expect(content).toContain("workflow_dispatch:");
    expect(content).toContain("schedule:");
  });

  it("workflow has a license-check job", () => {
    const content = readFileSync(join(PROJECT_ROOT, WORKFLOW_PATH), "utf-8");
    expect(content).toContain("license-check:");
    expect(content).toContain("runs-on: ubuntu-latest");
  });

  it("workflow uses actions/checkout@v4", () => {
    const content = readFileSync(join(PROJECT_ROOT, WORKFLOW_PATH), "utf-8");
    expect(content).toContain("actions/checkout@v4");
  });

  it("actionlint passes with exit code 0", () => {
    const result = spawnSync("actionlint", [WORKFLOW_PATH], {
      cwd: PROJECT_ROOT,
    });
    expect(result.status).toBe(0);
  });
});

// ──────────────────────────────────────────────────
// Act end-to-end integration test
// Runs the workflow in a Docker container via act and asserts on exact output.
// ──────────────────────────────────────────────────
describe("act end-to-end", () => {
  let actOutput = "";
  let actExitCode = -1;

  beforeAll(() => {
    // Set up a temp git repo with the project files
    const tmpDir = `/tmp/license-checker-act-${Date.now()}`;
    mkdirSync(tmpDir, { recursive: true });

    try {
      // Copy project files, then remove .git (cpSync filter for ".git" would
      // accidentally exclude ".github" too, since it starts with ".git")
      cpSync(PROJECT_ROOT, tmpDir, { recursive: true });
      rmSync(join(tmpDir, ".git"), { recursive: true, force: true });
      rmSync(join(tmpDir, "node_modules"), { recursive: true, force: true });

      // Initialize a git repo so act has a valid context
      execSync("git init -q && git add -A && git commit -q -m 'test'", {
        cwd: tmpDir,
        env: {
          ...process.env,
          GIT_AUTHOR_NAME: "test",
          GIT_AUTHOR_EMAIL: "test@test.com",
          GIT_COMMITTER_NAME: "test",
          GIT_COMMITTER_EMAIL: "test@test.com",
        },
      });

      // Run act — capture stdout+stderr combined
      const result = spawnSync(
        "act",
        ["push", "--rm", "--pull=false"],
        {
          cwd: tmpDir,
          timeout: 120_000,
          maxBuffer: 10 * 1024 * 1024,
        }
      );

      actOutput =
        (result.stdout?.toString() ?? "") + (result.stderr?.toString() ?? "");
      actExitCode = result.status ?? -1;
    } finally {
      // Append output to act-result.txt (delimited so multiple test cases are clear)
      const delimiter = `\n${"=".repeat(60)}\n=== ACT TEST CASE: dependency-license-checker ===\n${"=".repeat(60)}\n`;
      writeFileSync(ACT_RESULT_PATH, delimiter + actOutput, { flag: "a" });

      // Clean up temp dir
      try {
        rmSync(tmpDir, { recursive: true, force: true });
      } catch {
        // best-effort cleanup
      }
    }
  }, 130_000);

  it("act exits with code 0", () => {
    expect(actExitCode).toBe(0);
  });

  it("job succeeded message is present", () => {
    expect(actOutput).toContain("Job succeeded");
  });

  // ── Fixture 1: all-approved ──────────────────────────────
  it("all-approved fixture: react is APPROVED", () => {
    expect(actOutput).toContain("react@18.2.0: MIT - APPROVED");
  });

  it("all-approved fixture: lodash is APPROVED", () => {
    expect(actOutput).toContain("lodash@4.17.21: MIT - APPROVED");
  });

  it("all-approved fixture: axios is APPROVED", () => {
    expect(actOutput).toContain("axios@1.4.0: MIT - APPROVED");
  });

  it("all-approved fixture: summary shows 3 approved", () => {
    expect(actOutput).toContain("SUMMARY: 3 approved, 0 denied, 0 unknown");
  });

  // ── Fixture 2: with-denied ───────────────────────────────
  it("with-denied fixture: gpl-pkg is DENIED", () => {
    expect(actOutput).toContain("gpl-pkg@1.0.0: GPL-3.0 - DENIED");
  });

  it("with-denied fixture: summary shows 1 approved, 1 denied", () => {
    expect(actOutput).toContain("SUMMARY: 1 approved, 1 denied, 0 unknown");
  });

  // ── Fixture 3: with-unknown ──────────────────────────────
  it("with-unknown fixture: unknown-pkg is UNKNOWN", () => {
    expect(actOutput).toContain("unknown-pkg@2.0.0: UNKNOWN - UNKNOWN");
  });

  it("with-unknown fixture: summary shows 1 approved, 1 unknown", () => {
    expect(actOutput).toContain("SUMMARY: 1 approved, 0 denied, 1 unknown");
  });

  // ── Unit tests ran inside container ─────────────────────
  it("all 16 unit tests pass inside the container", () => {
    expect(actOutput).toContain("16 pass");
    expect(actOutput).toContain("0 fail");
  });
});
