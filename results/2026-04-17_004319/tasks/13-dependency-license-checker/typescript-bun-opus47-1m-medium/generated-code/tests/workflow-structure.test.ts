// Workflow structure tests — parse the YAML, check the shape is what
// downstream CI expects, and verify actionlint passes. Runs in the
// normal `bun test` pass and does not shell out to act.
import { describe, test, expect } from "bun:test";
import { readFileSync, existsSync } from "node:fs";
import { spawnSync } from "node:child_process";

const WORKFLOW = ".github/workflows/dependency-license-checker.yml";

function loadWorkflow(): string {
  return readFileSync(WORKFLOW, "utf8");
}

describe("workflow file", () => {
  test("exists at the expected path", () => {
    expect(existsSync(WORKFLOW)).toBe(true);
  });

  test("has required trigger events", () => {
    const text = loadWorkflow();
    expect(text).toMatch(/^on:/m);
    expect(text).toMatch(/push:/);
    expect(text).toMatch(/pull_request:/);
    expect(text).toMatch(/workflow_dispatch:/);
    expect(text).toMatch(/schedule:/);
  });

  test("references the checker script and fixtures", () => {
    const text = loadWorkflow();
    expect(text).toContain("src/cli.ts");
    expect(existsSync("src/cli.ts")).toBe(true);
    expect(existsSync("src/checker.ts")).toBe(true);
  });

  test("uses actions/checkout@v4 and setup-bun", () => {
    const text = loadWorkflow();
    expect(text).toContain("actions/checkout@v4");
    expect(text).toContain("oven-sh/setup-bun@v1");
  });

  test("declares permissions and env defaults", () => {
    const text = loadWorkflow();
    expect(text).toMatch(/permissions:/);
    expect(text).toMatch(/contents:\s*read/);
    expect(text).toMatch(/MANIFEST_PATH:/);
    expect(text).toMatch(/POLICY_PATH:/);
  });

  test("actionlint passes cleanly", () => {
    const res = spawnSync("actionlint", [WORKFLOW], { encoding: "utf8" });
    expect(res.status).toBe(0);
    expect(res.stdout + res.stderr).toBe("");
  });
});
