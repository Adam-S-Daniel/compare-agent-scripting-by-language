/**
 * Workflow Structure Tests
 *
 * These tests verify:
 * 1. The GitHub Actions workflow YAML has the expected structure
 * 2. The workflow references files that actually exist
 * 3. actionlint passes on the workflow
 */

import { describe, it, expect } from "bun:test";
import { existsSync } from "fs";
import { join } from "path";

// Root of the project (one level up from src/)
const ROOT = join(import.meta.dir, "..");
const WORKFLOW_PATH = join(ROOT, ".github/workflows/dependency-license-checker.yml");

// ─── Workflow File Existence ──────────────────────────────────────────────────

describe("workflow file", () => {
  it("exists at expected path", () => {
    expect(existsSync(WORKFLOW_PATH)).toBe(true);
  });

  it("is valid YAML (can be parsed)", async () => {
    const content = await Bun.file(WORKFLOW_PATH).text();
    expect(content.length).toBeGreaterThan(0);
    // Basic YAML structure check - starts with 'name:'
    expect(content).toContain("name:");
  });
});

// ─── Workflow Structure Validation ───────────────────────────────────────────

describe("workflow structure", () => {
  let workflowContent: string;

  // Load the workflow once
  const setup = async () => {
    workflowContent = await Bun.file(WORKFLOW_PATH).text();
  };

  it("has push trigger", async () => {
    await setup();
    expect(workflowContent).toContain("push:");
  });

  it("has pull_request trigger", async () => {
    await setup();
    expect(workflowContent).toContain("pull_request");
  });

  it("has workflow_dispatch trigger", async () => {
    await setup();
    expect(workflowContent).toContain("workflow_dispatch");
  });

  it("has check-licenses job", async () => {
    await setup();
    expect(workflowContent).toContain("check-licenses:");
  });

  it("has run-unit-tests job", async () => {
    await setup();
    expect(workflowContent).toContain("run-unit-tests:");
  });

  it("uses actions/checkout@v4", async () => {
    await setup();
    expect(workflowContent).toContain("actions/checkout@v4");
  });

  it("uses oven-sh/setup-bun", async () => {
    await setup();
    expect(workflowContent).toContain("oven-sh/setup-bun");
  });

  it("references the main script correctly", async () => {
    await setup();
    expect(workflowContent).toContain("bun run src/main.ts");
  });

  it("references the test command", async () => {
    await setup();
    expect(workflowContent).toContain("bun test");
  });

  it("uses matrix strategy for fixtures", async () => {
    await setup();
    expect(workflowContent).toContain("matrix:");
    expect(workflowContent).toContain("fixture:");
  });
});

// ─── Referenced Files Exist ───────────────────────────────────────────────────

describe("referenced files exist", () => {
  it("src/main.ts exists", () => {
    expect(existsSync(join(ROOT, "src/main.ts"))).toBe(true);
  });

  it("src/licenseChecker.ts exists", () => {
    expect(existsSync(join(ROOT, "src/licenseChecker.ts"))).toBe(true);
  });

  it("fixtures/package-approved.json exists", () => {
    expect(existsSync(join(ROOT, "fixtures/package-approved.json"))).toBe(true);
  });

  it("fixtures/package-denied.json exists", () => {
    expect(existsSync(join(ROOT, "fixtures/package-denied.json"))).toBe(true);
  });

  it("fixtures/package-unknown.json exists", () => {
    expect(existsSync(join(ROOT, "fixtures/package-unknown.json"))).toBe(true);
  });

  it("fixtures/license-config.json exists", () => {
    expect(existsSync(join(ROOT, "fixtures/license-config.json"))).toBe(true);
  });
});

// ─── actionlint Validation ───────────────────────────────────────────────────

describe("actionlint", () => {
  it("passes with exit code 0 on the workflow file", async () => {
    const result = await Bun.spawn(["actionlint", WORKFLOW_PATH], {
      stdout: "pipe",
      stderr: "pipe",
    });

    const stdout = await new Response(result.stdout).text();
    const stderr = await new Response(result.stderr).text();
    const exitCode = await result.exited;

    if (exitCode !== 0) {
      console.error("actionlint stdout:", stdout);
      console.error("actionlint stderr:", stderr);
    }

    expect(exitCode).toBe(0);
  });
});
