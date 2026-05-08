// Workflow-structure tests: validate the YAML at .github/workflows/semantic-version-bumper.yml
// without running it. These run alongside the unit tests via `bun test`.

import { describe, expect, test } from "bun:test";
import { existsSync, readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const WORKFLOW = resolve(ROOT, ".github/workflows/semantic-version-bumper.yml");

describe("workflow file", () => {
  test("exists at the canonical path", () => {
    expect(existsSync(WORKFLOW)).toBe(true);
  });

  test("declares the expected triggers (push, pull_request, workflow_dispatch)", () => {
    const text = readFileSync(WORKFLOW, "utf8");
    expect(text).toMatch(/^on:/m);
    expect(text).toContain("push:");
    expect(text).toContain("pull_request:");
    expect(text).toContain("workflow_dispatch:");
  });

  test("declares a 'bump' job that uses actions/checkout@v4", () => {
    const text = readFileSync(WORKFLOW, "utf8");
    expect(text).toContain("bump:");
    expect(text).toContain("actions/checkout@v4");
  });

  test("references the script path that actually exists", () => {
    const text = readFileSync(WORKFLOW, "utf8");
    expect(text).toContain("src/cli.ts");
    expect(existsSync(resolve(ROOT, "src/cli.ts"))).toBe(true);
  });

  test("references fixtures that actually exist", () => {
    const text = readFileSync(WORKFLOW, "utf8");
    // The workflow uses fixtures/commits-${FIXTURE}.txt — verify all named fixtures exist.
    for (const name of ["feat", "fix", "breaking", "none"]) {
      expect(existsSync(resolve(ROOT, `fixtures/commits-${name}.txt`))).toBe(true);
    }
    expect(text).toContain("fixtures/commits-${FIXTURE}.txt");
  });

  test("declares a permissions block", () => {
    const text = readFileSync(WORKFLOW, "utf8");
    expect(text).toMatch(/^permissions:/m);
  });

  test("passes actionlint", () => {
    const result = spawnSync("actionlint", [WORKFLOW], {
      encoding: "utf8",
    });
    if (result.status !== 0) {
      console.error("actionlint stdout:", result.stdout);
      console.error("actionlint stderr:", result.stderr);
    }
    expect(result.status).toBe(0);
  });
});
