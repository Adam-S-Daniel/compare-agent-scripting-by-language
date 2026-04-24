// Structural assertions about the workflow YAML. No act, no docker.
// Kept separate from aggregator.test.ts so the CI `bun test aggregator.test.ts`
// path stays focused on the unit tests (these require actionlint on PATH).

import { describe, expect, test } from "bun:test";
import { existsSync, readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { join } from "node:path";

const ROOT = import.meta.dir;
const WF = join(ROOT, ".github/workflows/test-results-aggregator.yml");

describe("workflow structure", () => {
  test("file exists", () => {
    expect(existsSync(WF)).toBe(true);
  });

  test("actionlint passes", () => {
    const r = spawnSync("actionlint", [WF], { encoding: "utf8" });
    expect(r.stderr + r.stdout).toBe("");
    expect(r.status).toBe(0);
  });

  test("declares expected triggers, job, and steps", () => {
    const text = readFileSync(WF, "utf8");
    expect(text).toMatch(/^on:/m);
    expect(text).toMatch(/push:/);
    expect(text).toMatch(/pull_request:/);
    expect(text).toMatch(/workflow_dispatch:/);
    expect(text).toMatch(/schedule:/);
    expect(text).toMatch(/runs-on:\s*ubuntu-latest/);
    expect(text).toMatch(/actions\/checkout@v4/);
    expect(text).toMatch(/oven-sh\/setup-bun@v1/);
    expect(text).toMatch(/cli\.ts/);
    expect(text).toMatch(/bun test/);
  });

  test("referenced files exist", () => {
    for (const p of ["cli.ts", "aggregator.ts", "fixtures"]) {
      expect(existsSync(join(ROOT, p))).toBe(true);
    }
  });
});
