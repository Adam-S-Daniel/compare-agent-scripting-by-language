// Structural tests for the GitHub Actions workflow.
// These run every time `bun test` runs so mistakes are caught
// before we spend seconds on an `act push` cycle.

import { describe, test, expect } from "bun:test";
import { existsSync, readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { join } from "node:path";

const repoRoot = new URL("..", import.meta.url).pathname;
const wfPath = join(repoRoot, ".github/workflows/dependency-license-checker.yml");

describe("workflow file", () => {
  test("exists at the expected path", () => {
    expect(existsSync(wfPath)).toBe(true);
  });

  // A tiny, purpose-built YAML reader: grab top-level keys and job
  // step names as strings. Full YAML parsing isn't needed for these
  // structural checks, and Bun has no YAML parser in its standard lib.
  const yaml = readFileSync(wfPath, "utf8");

  test("declares all expected trigger events", () => {
    // The `on:` block should mention each of these trigger keys.
    for (const trig of ["push:", "pull_request:", "schedule:", "workflow_dispatch:"]) {
      expect(yaml).toContain(trig);
    }
  });

  test("declares read-only permissions", () => {
    expect(yaml).toMatch(/permissions:\s*\n\s*contents:\s*read/);
  });

  test("uses actions/checkout@v4", () => {
    expect(yaml).toContain("actions/checkout@v4");
  });

  test("references the CLI script path that exists", () => {
    expect(yaml).toContain("src/cli.ts");
    expect(existsSync(join(repoRoot, "src/cli.ts"))).toBe(true);
  });

  test("references fixture paths that exist", () => {
    for (const f of ["fixtures/package.json", "fixtures/policy.json", "fixtures/licenses.json"]) {
      expect(yaml).toContain(f);
      expect(existsSync(join(repoRoot, f))).toBe(true);
    }
  });

  test("declares a check-licenses job on ubuntu-latest", () => {
    expect(yaml).toContain("check-licenses:");
    expect(yaml).toContain("runs-on: ubuntu-latest");
  });

  test("actionlint passes cleanly", () => {
    const result = spawnSync("actionlint", [wfPath], { encoding: "utf8" });
    // If actionlint isn't on PATH (e.g. running outside the dev env),
    // skip rather than fail — act harness covers this too.
    if (result.error && (result.error as NodeJS.ErrnoException).code === "ENOENT") {
      console.warn("actionlint not on PATH; skipping structural actionlint assertion");
      return;
    }
    expect(result.status).toBe(0);
    expect(result.stdout + result.stderr).toBe("");
  });
});
