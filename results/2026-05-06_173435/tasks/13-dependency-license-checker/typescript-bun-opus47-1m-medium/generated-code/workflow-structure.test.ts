// Structural assertions about the GitHub Actions workflow itself: triggers,
// referenced script paths, and `actionlint` cleanliness. These run as part of
// `bun test` so they are also exercised through the workflow's own test step.
import { describe, expect, test } from "bun:test";
import { readFileSync, existsSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { join } from "node:path";

const wfPath = join(import.meta.dir, ".github/workflows/dependency-license-checker.yml");

function getWorkflowText(): string {
  return readFileSync(wfPath, "utf8");
}

describe("workflow structure", () => {
  test("file exists", () => {
    expect(existsSync(wfPath)).toBe(true);
  });

  test("declares the expected triggers", () => {
    const text = getWorkflowText();
    for (const trigger of ["push:", "pull_request:", "workflow_dispatch:", "schedule:"]) {
      expect(text).toContain(trigger);
    }
  });

  test("uses pinned actions/checkout", () => {
    expect(getWorkflowText()).toMatch(/uses:\s*actions\/checkout@v4/);
  });

  test("references script and config files that exist", () => {
    const text = getWorkflowText();
    expect(text).toContain("checker.ts");
    expect(text).toContain("license-config.json");
    expect(existsSync(join(import.meta.dir, "checker.ts"))).toBe(true);
    expect(existsSync(join(import.meta.dir, "license-config.json"))).toBe(true);
  });

  test("declares minimal permissions", () => {
    expect(getWorkflowText()).toMatch(/permissions:\s*\n\s*contents:\s*read/);
  });

  test("has a single job that runs the unit tests and the CLI", () => {
    const text = getWorkflowText();
    expect(text).toContain("bun test");
    expect(text).toContain("bun run checker.ts");
  });

  test("actionlint passes cleanly", () => {
    const r = spawnSync("actionlint", [wfPath], { encoding: "utf8" });
    expect(r.status).toBe(0);
    expect(r.stdout + r.stderr).toBe("");
  });
});
