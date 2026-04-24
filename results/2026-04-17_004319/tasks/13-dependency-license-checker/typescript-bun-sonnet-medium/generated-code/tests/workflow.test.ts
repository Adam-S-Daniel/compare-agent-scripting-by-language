// Workflow structure and act execution tests.
// These tests verify the GHA workflow file is valid and runs correctly via act.

import { describe, it, expect } from "bun:test";
import { existsSync, readFileSync, writeFileSync, mkdirSync, cpSync, rmSync } from "fs";
import { execSync } from "child_process";
import { join } from "path";
import { tmpdir } from "os";

const WORKSPACE = process.cwd();
const WORKFLOW_FILE = join(WORKSPACE, ".github/workflows/dependency-license-checker.yml");
const ACT_RESULT_FILE = join(WORKSPACE, "act-result.txt");

// --- Workflow structure tests ---

describe("workflow file structure", () => {
  it("workflow file exists", () => {
    expect(existsSync(WORKFLOW_FILE)).toBe(true);
  });

  it("has push trigger", () => {
    const content = readFileSync(WORKFLOW_FILE, "utf-8");
    expect(content).toContain("push:");
  });

  it("has pull_request trigger", () => {
    const content = readFileSync(WORKFLOW_FILE, "utf-8");
    expect(content).toContain("pull_request");
  });

  it("has jobs section", () => {
    const content = readFileSync(WORKFLOW_FILE, "utf-8");
    expect(content).toContain("jobs:");
  });

  it("has license-check job", () => {
    const content = readFileSync(WORKFLOW_FILE, "utf-8");
    expect(content).toContain("license-check:");
  });

  it("uses actions/checkout@v4", () => {
    const content = readFileSync(WORKFLOW_FILE, "utf-8");
    expect(content).toContain("actions/checkout@v4");
  });

  it("references unit test step", () => {
    const content = readFileSync(WORKFLOW_FILE, "utf-8");
    expect(content).toContain("checker.test.ts");
  });

  it("references license compliance check", () => {
    const content = readFileSync(WORKFLOW_FILE, "utf-8");
    expect(content).toContain("fixtures/license-config.json");
    expect(content).toContain("fixtures/package.json");
  });
});

// --- Referenced file existence tests ---

describe("workflow referenced files exist", () => {
  it("src/index.ts exists", () => {
    expect(existsSync(join(WORKSPACE, "src/index.ts"))).toBe(true);
  });

  it("tests/checker.test.ts exists", () => {
    expect(existsSync(join(WORKSPACE, "tests/checker.test.ts"))).toBe(true);
  });

  it("fixtures/license-config.json exists", () => {
    expect(existsSync(join(WORKSPACE, "fixtures/license-config.json"))).toBe(true);
  });

  it("fixtures/package.json exists", () => {
    expect(existsSync(join(WORKSPACE, "fixtures/package.json"))).toBe(true);
  });
});

// --- actionlint validation ---

describe("actionlint validation", () => {
  it("workflow passes actionlint", () => {
    const result = execSync(`actionlint "${WORKFLOW_FILE}"`, {
      encoding: "utf-8",
      stdio: ["pipe", "pipe", "pipe"],
    });
    // If actionlint exits 0 (no error thrown), it passed
    expect(result).toBeDefined();
  });
});

// --- Act execution tests ---

function setupTempRepo(): string {
  const tmpDir = join(tmpdir(), `license-checker-test-${Date.now()}`);
  mkdirSync(tmpDir, { recursive: true });

  // Copy all project files into the temp repo
  for (const item of ["src", "tests", "fixtures", ".github", "package.json"]) {
    const src = join(WORKSPACE, item);
    const dst = join(tmpDir, item);
    if (existsSync(src)) {
      cpSync(src, dst, { recursive: true });
    }
  }

  // Also copy .actrc so act uses the correct container image
  const actrc = join(WORKSPACE, ".actrc");
  if (existsSync(actrc)) {
    cpSync(actrc, join(tmpDir, ".actrc"));
  }

  // Initialize git repo
  execSync("git init", { cwd: tmpDir, stdio: "pipe" });
  execSync("git config user.email 'test@test.com'", { cwd: tmpDir, stdio: "pipe" });
  execSync("git config user.name 'Test'", { cwd: tmpDir, stdio: "pipe" });
  execSync("git add -A", { cwd: tmpDir, stdio: "pipe" });
  execSync("git commit -m 'test'", { cwd: tmpDir, stdio: "pipe" });

  return tmpDir;
}

describe("act execution", () => {
  it("workflow runs successfully via act and produces expected output", () => {
    const tmpDir = setupTempRepo();

    let output = "";
    let exitCode = 0;

    try {
      output = execSync("act push --rm --pull=false 2>&1", {
        cwd: tmpDir,
        encoding: "utf-8",
        timeout: 300000, // 5 minutes
        maxBuffer: 10 * 1024 * 1024,
      });
    } catch (e: unknown) {
      if (e && typeof e === "object" && "stdout" in e) {
        output = String((e as { stdout: unknown }).stdout || "");
        const stderr = "stderr" in e ? String((e as { stderr: unknown }).stderr || "") : "";
        output = output + stderr;
      }
      exitCode = e && typeof e === "object" && "status" in e ? Number((e as { status: unknown }).status) : 1;
    }

    // Write to act-result.txt (required artifact)
    const delimiter = "\n=== ACT RUN: standard fixture test ===\n";
    const resultEntry = delimiter + output + "\n=== END ACT RUN ===\n";
    writeFileSync(ACT_RESULT_FILE, resultEntry, "utf-8");

    // Assert act exited 0
    expect(exitCode).toBe(0);

    // Assert job succeeded
    expect(output).toContain("Job succeeded");

    // Assert exact expected values in report output
    expect(output).toContain("lodash@4.17.21: MIT (approved)");
    expect(output).toContain("express@4.18.2: MIT (approved)");
    expect(output).toContain("gpl-lib@1.0.0: GPL-3.0 (denied)");
    expect(output).toContain("unknown-pkg@2.0.0: UNKNOWN (unknown)");
    expect(output).toContain("react@18.0.0: MIT (approved)");
    expect(output).toContain("Approved: 4");
    expect(output).toContain("Denied: 1");
    expect(output).toContain("Unknown: 1");
    expect(output).toContain("Status: FAILED");

    // Cleanup
    try {
      rmSync(tmpDir, { recursive: true, force: true });
    } catch {
      // ignore cleanup errors
    }
  }, 360000); // 6 minute timeout for this test
});
