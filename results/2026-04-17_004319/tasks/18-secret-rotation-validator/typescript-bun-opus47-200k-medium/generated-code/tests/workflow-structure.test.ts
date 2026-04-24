// Workflow structure tests: parse the YAML, assert triggers/jobs/steps,
// that referenced script paths exist, and that actionlint is happy.
import { describe, test, expect } from "bun:test";
import { existsSync, readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";

// Minimal YAML-ish extraction without a dependency — for the bits we care about
// we can rely on `bun install`-ed parser, but to avoid adding deps we do a
// small regex scan. Richer structural validation is delegated to actionlint.
const WORKFLOW = ".github/workflows/secret-rotation-validator.yml";

describe("workflow file", () => {
  const text = readFileSync(WORKFLOW, "utf8");

  test("uses expected triggers", () => {
    expect(text).toMatch(/^on:/m);
    expect(text).toContain("push:");
    expect(text).toContain("pull_request:");
    expect(text).toContain("workflow_dispatch:");
    expect(text).toContain("schedule:");
  });

  test("pins actions/checkout@v4 and setup-bun", () => {
    expect(text).toContain("actions/checkout@v4");
    expect(text).toContain("oven-sh/setup-bun@v2");
  });

  test("references files that exist", () => {
    // Anything the workflow invokes must be present in the repo.
    expect(existsSync("src/cli.ts")).toBe(true);
    expect(existsSync("src/validator.ts")).toBe(true);
    expect(existsSync("src/report.ts")).toBe(true);
    expect(existsSync("scripts/assert-report.ts")).toBe(true);
    expect(existsSync("fixtures/secrets.json")).toBe(true);
    expect(text).toContain("src/cli.ts");
    expect(text).toContain("scripts/assert-report.ts");
    expect(text).toContain("fixtures/secrets.json");
  });

  test("declares contents:read permissions", () => {
    expect(text).toMatch(/permissions:\s*\n\s*contents:\s*read/);
  });

  test("has a validate job with bun test step", () => {
    expect(text).toContain("validate:");
    expect(text).toContain("bun test");
  });
});

describe("actionlint", () => {
  test("passes cleanly (skipped if actionlint not installed)", () => {
    const r = spawnSync("actionlint", [WORKFLOW], { encoding: "utf8" });
    // `spawnSync` returns a populated `error` field (and status=null) when the
    // binary is missing. Skip the assertion in environments without actionlint
    // (e.g. the act container) but enforce it locally.
    if (r.error && (r.error as NodeJS.ErrnoException).code === "ENOENT") {
      console.warn("actionlint not available, skipping");
      return;
    }
    if (r.status !== 0) {
      console.error("actionlint stdout:", r.stdout);
      console.error("actionlint stderr:", r.stderr);
    }
    expect(r.status).toBe(0);
  });
});
