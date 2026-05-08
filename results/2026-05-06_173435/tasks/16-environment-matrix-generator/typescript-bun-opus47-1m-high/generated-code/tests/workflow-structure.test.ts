// Workflow-structure tests:
// - YAML parses to the expected shape (triggers, jobs, steps).
// - The script paths the workflow references actually exist.
// - actionlint exits 0 against the workflow file.

import { describe, expect, test } from "bun:test";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

const PROJECT_ROOT = join(import.meta.dir, "..");
const WORKFLOW_PATH = join(
  PROJECT_ROOT,
  ".github",
  "workflows",
  "environment-matrix-generator.yml",
);

// Tiny YAML reader: we don't depend on a yaml library. Instead we sniff
// the workflow text for the structural facts we care about.
function readWorkflow(): string {
  return readFileSync(WORKFLOW_PATH, "utf8");
}

describe("workflow file structure", () => {
  test("workflow file exists at the expected path", () => {
    expect(existsSync(WORKFLOW_PATH)).toBe(true);
  });

  test("declares push, pull_request, workflow_dispatch and schedule triggers", () => {
    const text = readWorkflow();
    expect(text).toMatch(/^on:/m);
    expect(text).toMatch(/^\s+push:/m);
    expect(text).toMatch(/^\s+pull_request:/m);
    expect(text).toMatch(/^\s+workflow_dispatch:/m);
    expect(text).toMatch(/^\s+schedule:/m);
  });

  test("declares minimal contents:read permission", () => {
    const text = readWorkflow();
    expect(text).toMatch(/^permissions:/m);
    expect(text).toMatch(/contents:\s*read/);
  });

  test("declares both jobs (unit-tests + generate-matrix)", () => {
    const text = readWorkflow();
    expect(text).toMatch(/^\s+unit-tests:/m);
    expect(text).toMatch(/^\s+generate-matrix:/m);
    // generate-matrix depends on unit-tests
    expect(text).toMatch(/needs:\s*unit-tests/);
  });

  test("uses actions/checkout@v4", () => {
    const text = readWorkflow();
    expect(text).toMatch(/uses:\s*actions\/checkout@v4/);
  });

  test("references files that actually exist on disk", () => {
    // The script path the workflow runs:
    expect(existsSync(join(PROJECT_ROOT, "src", "cli.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_ROOT, "src", "matrix.ts"))).toBe(true);
    // The fixture path it reads:
    expect(existsSync(join(PROJECT_ROOT, "fixtures", "config.json"))).toBe(true);
    // The unit test files it runs:
    expect(existsSync(join(PROJECT_ROOT, "tests", "matrix.test.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_ROOT, "tests", "cli.test.ts"))).toBe(true);
    // Workflow references these paths:
    const text = readWorkflow();
    expect(text).toContain("src/cli.ts");
    expect(text).toContain("fixtures/config.json");
  });

  test("actionlint passes cleanly", () => {
    const proc = Bun.spawnSync({
      cmd: ["actionlint", WORKFLOW_PATH],
      stdout: "pipe",
      stderr: "pipe",
    });
    const out =
      new TextDecoder().decode(proc.stdout) +
      new TextDecoder().decode(proc.stderr);
    expect(proc.exitCode).toBe(0);
    expect(out).toBe("");
  });
});
