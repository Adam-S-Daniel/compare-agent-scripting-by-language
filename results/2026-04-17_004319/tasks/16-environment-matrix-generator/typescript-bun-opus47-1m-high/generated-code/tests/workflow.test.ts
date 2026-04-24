// Workflow structure tests. These inspect the YAML file directly — NOT via
// act — so they catch regressions cheaply before we pay the cost of an act run.
//
// A separate test, act-harness.test.ts, runs the workflow end-to-end through
// `act push --rm` and asserts on the captured output.
import { describe, test, expect } from "bun:test";
import { readFileSync, existsSync, statSync } from "node:fs";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const ROOT = join(import.meta.dir, "..");
const WORKFLOW_PATH = join(ROOT, ".github/workflows/environment-matrix-generator.yml");

describe("workflow structure", () => {
  test("workflow file exists", () => {
    expect(existsSync(WORKFLOW_PATH)).toBe(true);
  });

  test("declares the required triggers", () => {
    const yaml = readFileSync(WORKFLOW_PATH, "utf8");
    expect(yaml).toMatch(/^on:/m);
    expect(yaml).toMatch(/^\s+push:/m);
    expect(yaml).toMatch(/^\s+pull_request:/m);
    expect(yaml).toMatch(/^\s+workflow_dispatch:/m);
  });

  test("defines both jobs with a dependency", () => {
    const yaml = readFileSync(WORKFLOW_PATH, "utf8");
    expect(yaml).toMatch(/^\s+unit-tests:/m);
    expect(yaml).toMatch(/^\s+generate-matrix:/m);
    expect(yaml).toMatch(/needs:\s*unit-tests/);
  });

  test("references script paths that actually exist", () => {
    const yaml = readFileSync(WORKFLOW_PATH, "utf8");
    const scriptRefs = [...yaml.matchAll(/bun run (src\/\S+)/g)].map((m) => m[1]!);
    const fixtureRefs = [...yaml.matchAll(/(fixtures\/\S+\.json)/g)].map((m) => m[1]!);
    expect(scriptRefs.length).toBeGreaterThan(0);
    expect(fixtureRefs.length).toBeGreaterThan(0);
    for (const ref of [...scriptRefs, ...fixtureRefs]) {
      expect(existsSync(join(ROOT, ref))).toBe(true);
    }
  });

  test("has minimal contents:read permissions (principle of least privilege)", () => {
    const yaml = readFileSync(WORKFLOW_PATH, "utf8");
    expect(yaml).toMatch(/^permissions:/m);
    expect(yaml).toMatch(/contents:\s*read/);
  });

  test("actionlint passes with exit 0", () => {
    // actionlint is a host-side tool — skip when unavailable (e.g. inside
    // the act container) so we don't fail CI for a missing linter.
    const which = spawnSync("which", ["actionlint"], { encoding: "utf8" });
    if (which.status !== 0) {
      console.log("actionlint not installed, skipping lint assertion");
      return;
    }
    const result = spawnSync("actionlint", [WORKFLOW_PATH], { encoding: "utf8" });
    if (result.status !== 0) {
      console.error("actionlint stdout:", result.stdout);
      console.error("actionlint stderr:", result.stderr);
    }
    expect(result.status).toBe(0);
  });
});

describe("fixtures", () => {
  test("every fixture is valid JSON", () => {
    const fixtures = ["basic.json", "with-exclude.json", "with-include.json", "too-big.json"];
    for (const f of fixtures) {
      const path = join(ROOT, "fixtures", f);
      expect(existsSync(path)).toBe(true);
      expect(() => JSON.parse(readFileSync(path, "utf8"))).not.toThrow();
    }
  });
});
