// Workflow structure tests — verify the GHA workflow file is valid and
// references all necessary script files and fixtures correctly.
// These run locally and inside the act container (both have the repo checked out).

import { describe, test, expect } from "bun:test";
import { existsSync, readFileSync } from "fs";
import { resolve, join } from "path";
import { spawnSync } from "child_process";

const ROOT = resolve(import.meta.dir, "..");
const WORKFLOW_PATH = join(ROOT, ".github/workflows/dependency-license-checker.yml");

describe("Workflow file", () => {
  test("workflow YAML file exists", () => {
    expect(existsSync(WORKFLOW_PATH)).toBe(true);
  });

  test("workflow contains push trigger", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("push:");
  });

  test("workflow contains pull_request trigger", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("pull_request:");
  });

  test("workflow contains workflow_dispatch trigger", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("workflow_dispatch:");
  });

  test("workflow uses actions/checkout@v4", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("actions/checkout@v4");
  });

  test("workflow installs Bun", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("oven-sh/setup-bun");
  });

  test("workflow runs bun test", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("bun test");
  });

  test("workflow references src/index.ts", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("src/index.ts");
  });

  test("workflow references sample-package.json fixture", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("fixtures/sample-package.json");
  });

  test("workflow references approved-package.json fixture", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("fixtures/approved-package.json");
  });

  test("workflow has a check-licenses job", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("check-licenses:");
  });
});

describe("Referenced files exist", () => {
  test("src/index.ts exists", () => {
    expect(existsSync(join(ROOT, "src/index.ts"))).toBe(true);
  });

  test("src/licenseChecker.ts exists", () => {
    expect(existsSync(join(ROOT, "src/licenseChecker.ts"))).toBe(true);
  });

  test("src/types.ts exists", () => {
    expect(existsSync(join(ROOT, "src/types.ts"))).toBe(true);
  });

  test("fixtures/sample-package.json exists", () => {
    expect(existsSync(join(ROOT, "fixtures/sample-package.json"))).toBe(true);
  });

  test("fixtures/approved-package.json exists", () => {
    expect(existsSync(join(ROOT, "fixtures/approved-package.json"))).toBe(true);
  });

  test("fixtures/license-config.json exists", () => {
    expect(existsSync(join(ROOT, "fixtures/license-config.json"))).toBe(true);
  });

  test("fixtures/mock-licenses.json exists", () => {
    expect(existsSync(join(ROOT, "fixtures/mock-licenses.json"))).toBe(true);
  });
});

describe("actionlint validation", () => {
  test("workflow passes actionlint with exit code 0", () => {
    // Run actionlint as a subprocess — exit code 0 means no errors.
    const result = spawnSync("actionlint", [WORKFLOW_PATH], {
      encoding: "utf-8",
    });
    if (result.error) {
      // actionlint not available — skip gracefully
      console.log("Warning: actionlint not found, skipping lint check");
      return;
    }
    if (result.status !== 0) {
      console.error("actionlint output:", result.stdout + result.stderr);
    }
    expect(result.status).toBe(0);
  });
});
