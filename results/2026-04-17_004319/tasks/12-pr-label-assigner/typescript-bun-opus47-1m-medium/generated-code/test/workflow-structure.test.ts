import { describe, expect, test } from "bun:test";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { parse } from "yaml";

const WF = join(import.meta.dir, "../.github/workflows/pr-label-assigner.yml");

describe("workflow structure", () => {
  test("workflow file exists", () => {
    expect(existsSync(WF)).toBe(true);
  });

  test("actionlint passes", () => {
    const r = spawnSync("actionlint", [WF], { encoding: "utf8" });
    if (r.status !== 0) console.error(r.stdout, r.stderr);
    expect(r.status).toBe(0);
  });

  test("workflow has expected triggers and jobs", () => {
    const doc = parse(readFileSync(WF, "utf8")) as any;
    expect(doc.name).toBe("PR Label Assigner");
    // `on` may parse as true (YAML 1.1 quirk) or "on"; handle both
    const triggers = doc.on ?? doc[true];
    expect(triggers).toBeDefined();
    expect("push" in triggers || triggers.push !== undefined).toBe(true);
    expect(doc.jobs["unit-tests"]).toBeDefined();
    expect(doc.jobs["assign-labels"]).toBeDefined();
    expect(doc.jobs["assign-labels"].needs).toBe("unit-tests");
  });

  test("workflow references existing script paths", () => {
    const text = readFileSync(WF, "utf8");
    expect(text).toContain("src/cli.ts");
    expect(text).toContain("fixtures/rules.json");
    expect(existsSync(join(import.meta.dir, "../src/cli.ts"))).toBe(true);
    expect(existsSync(join(import.meta.dir, "../fixtures/rules.json"))).toBe(true);
  });
});
