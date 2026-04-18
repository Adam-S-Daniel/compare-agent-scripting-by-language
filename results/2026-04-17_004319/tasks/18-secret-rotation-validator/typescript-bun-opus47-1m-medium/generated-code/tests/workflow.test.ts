// Workflow structure tests. Pure static checks — no act invocation.
// These guard the YAML shape so the CI pipeline doesn't silently drift.
import { describe, expect, test } from "bun:test";
import { readFileSync, existsSync } from "node:fs";
import { execSync } from "node:child_process";
import { parse } from "yaml";

const WF_PATH = ".github/workflows/secret-rotation-validator.yml";

function loadWorkflow(): any {
  return parse(readFileSync(WF_PATH, "utf8"));
}

describe("workflow YAML structure", () => {
  const wf = loadWorkflow();

  test("declares the expected triggers", () => {
    // YAML parses bare `on:` as key "on" — but `on: true` is a YAML gotcha.
    // Our workflow uses the block form so this comes back as an object.
    const on = wf.on ?? wf[true];
    expect(Object.keys(on).sort()).toEqual(
      ["pull_request", "push", "schedule", "workflow_dispatch"].sort(),
    );
  });

  test("schedule trigger runs daily", () => {
    const on = wf.on ?? wf[true];
    expect(on.schedule[0].cron).toBe("0 8 * * *");
  });

  test("has a 'validate' job on ubuntu-latest", () => {
    expect(wf.jobs.validate).toBeDefined();
    expect(wf.jobs.validate["runs-on"]).toBe("ubuntu-latest");
  });

  test("job steps reference our script and fixtures", () => {
    const steps = wf.jobs.validate.steps as Array<any>;
    const joined = JSON.stringify(steps);
    expect(joined).toContain("actions/checkout@v4");
    expect(joined).toContain("src/cli.ts");
    expect(joined).toContain("src/validator.test.ts");
  });

  test("script and fixtures referenced by workflow exist on disk", () => {
    expect(existsSync("src/cli.ts")).toBe(true);
    expect(existsSync("src/validator.ts")).toBe(true);
    expect(existsSync("src/validator.test.ts")).toBe(true);
    expect(existsSync("fixtures/mixed.json")).toBe(true);
  });

  test("declares read-only default permissions", () => {
    expect(wf.permissions.contents).toBe("read");
  });
});

describe("actionlint", () => {
  test("passes with no findings", () => {
    const out = execSync(`actionlint ${WF_PATH}`, { stdio: ["ignore", "pipe", "pipe"] });
    expect(out.toString()).toBe("");
  });
});
