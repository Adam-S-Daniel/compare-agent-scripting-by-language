// Workflow structure tests: parse the YAML and assert expected shape, plus run actionlint.
import { describe, expect, test } from "bun:test";
import { spawnSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";

const WF_PATH = ".github/workflows/test-results-aggregator.yml";

// Cheap YAML structural checks — we look for required substrings rather than
// pulling in a YAML parser. actionlint is the authoritative validator.
const yaml = readFileSync(WF_PATH, "utf8");

describe("workflow structure", () => {
  test("file exists", () => {
    expect(existsSync(WF_PATH)).toBe(true);
  });

  test("declares push, pull_request, workflow_dispatch triggers", () => {
    expect(yaml).toMatch(/on:\s*[\s\S]*push:/);
    expect(yaml).toMatch(/pull_request:/);
    expect(yaml).toMatch(/workflow_dispatch:/);
  });

  test("checks out the repo and installs bun", () => {
    expect(yaml).toContain("actions/checkout@v4");
    expect(yaml).toMatch(/Install Bun/);
  });

  test("references the cli script path that exists on disk", () => {
    expect(yaml).toContain("src/cli.ts");
    expect(existsSync("src/cli.ts")).toBe(true);
  });

  test("uploads summary.md artifact", () => {
    expect(yaml).toContain("actions/upload-artifact@v4");
    expect(yaml).toContain("summary.md");
  });

  test("declares contents:read permissions", () => {
    expect(yaml).toMatch(/permissions:\s*\n\s*contents:\s*read/);
  });

  test("actionlint passes", () => {
    const r = spawnSync("actionlint", [WF_PATH], { encoding: "utf8" });
    if (r.status !== 0) {
      console.error("actionlint stdout:", r.stdout);
      console.error("actionlint stderr:", r.stderr);
    }
    expect(r.status).toBe(0);
  });
});
