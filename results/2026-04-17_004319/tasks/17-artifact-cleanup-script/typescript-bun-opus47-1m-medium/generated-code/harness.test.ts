// Workflow structure tests — instant checks that don't need `act`.
// The end-to-end `act` runs are orchestrated by run-act.ts and append their
// output to act-result.txt.
import { describe, test, expect } from "bun:test";
import { readFileSync, existsSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { parse as parseYaml } from "yaml";

const WORKFLOW = ".github/workflows/artifact-cleanup-script.yml";

describe("workflow structure", () => {
  test("workflow file exists and is valid YAML", () => {
    const raw = readFileSync(WORKFLOW, "utf8");
    const doc = parseYaml(raw);
    expect(doc).toBeTruthy();
    expect(doc.name).toBe("artifact-cleanup-script");
  });

  test("declares expected triggers", () => {
    const doc = parseYaml(readFileSync(WORKFLOW, "utf8"));
    // YAML `on:` → depending on parser it may surface as key "on" or true.
    const on = doc.on ?? doc[true];
    expect(on).toBeTruthy();
    expect("push" in on).toBe(true);
    expect("pull_request" in on).toBe(true);
    expect("workflow_dispatch" in on).toBe(true);
    expect("schedule" in on).toBe(true);
  });

  test("has test and cleanup jobs with dependency", () => {
    const doc = parseYaml(readFileSync(WORKFLOW, "utf8"));
    expect(doc.jobs.test).toBeTruthy();
    expect(doc.jobs.cleanup).toBeTruthy();
    expect(doc.jobs.cleanup.needs).toBe("test");
  });

  test("references real script and fixture files", () => {
    const raw = readFileSync(WORKFLOW, "utf8");
    expect(raw).toContain("cleanup.ts");
    expect(raw).toContain("fixtures/artifacts.json");
    expect(raw).toContain("fixtures/policy.json");
    expect(existsSync("cleanup.ts")).toBe(true);
    expect(existsSync("fixtures/artifacts.json")).toBe(true);
    expect(existsSync("fixtures/policy.json")).toBe(true);
  });

  test("actionlint passes", () => {
    const r = spawnSync("actionlint", [WORKFLOW], { encoding: "utf8" });
    if (r.status !== 0) {
      console.error(r.stdout, r.stderr);
    }
    expect(r.status).toBe(0);
  });
});

describe("act-result.txt assertions", () => {
  // These assertions run after run-act.ts has been executed. They parse the
  // captured act output and assert on EXACT expected values per case.
  test("act-result.txt exists (run ./run-act.ts first)", () => {
    expect(existsSync("act-result.txt")).toBe(true);
  });

  test("each case: act exit 0 and Job succeeded lines present", () => {
    if (!existsSync("act-result.txt")) return;
    const txt = readFileSync("act-result.txt", "utf8");
    const cases = ["CASE:max-age", "CASE:keep-latest", "CASE:size-budget"];
    for (const c of cases) {
      expect(txt).toContain(c);
      expect(txt).toContain(`${c} ACT_EXIT=0`);
    }
    // Each run has two jobs (test, cleanup) → at least 6 "Job succeeded".
    const succeededCount = (txt.match(/Job succeeded/g) ?? []).length;
    expect(succeededCount).toBeGreaterThanOrEqual(6);
  });

  test("max-age case: expected numeric output", () => {
    if (!existsSync("act-result.txt")) return;
    const txt = readFileSync("act-result.txt", "utf8");
    // 2 artifacts, 1 aged out (b, 200 bytes).
    const section = sliceCase(txt, "CASE:max-age");
    expect(section).toContain("Total artifacts: 2");
    expect(section).toContain("Deleted: 1");
    expect(section).toContain("Retained: 1");
    expect(section).toContain("Bytes reclaimed: 200");
    expect(section).toContain("DRY-RUN");
  });

  test("keep-latest case: expected numeric output", () => {
    if (!existsSync("act-result.txt")) return;
    const txt = readFileSync("act-result.txt", "utf8");
    // 4 artifacts in w1 (ages 1,2,3,4 days, 100B each), keepLatestPerWorkflow=2
    // → delete the 2 oldest (200B).
    const section = sliceCase(txt, "CASE:keep-latest");
    expect(section).toContain("Total artifacts: 4");
    expect(section).toContain("Deleted: 2");
    expect(section).toContain("Retained: 2");
    expect(section).toContain("Bytes reclaimed: 200");
  });

  test("size-budget case: expected numeric output", () => {
    if (!existsSync("act-result.txt")) return;
    const txt = readFileSync("act-result.txt", "utf8");
    // 3 artifacts * 500B = 1500, budget 1000 → delete oldest 500B.
    const section = sliceCase(txt, "CASE:size-budget");
    expect(section).toContain("Total artifacts: 3");
    expect(section).toContain("Deleted: 1");
    expect(section).toContain("Retained: 2");
    expect(section).toContain("Bytes reclaimed: 500");
  });
});

function sliceCase(txt: string, marker: string): string {
  const start = txt.indexOf(marker);
  if (start === -1) return "";
  const rest = txt.slice(start);
  const nextCase = rest.slice(marker.length).search(/CASE:/);
  return nextCase === -1 ? rest : rest.slice(0, marker.length + nextCase);
}
