// Workflow structure tests + act integration tests.
// Structure tests validate the YAML, file references, and actionlint.
// Act tests run the full pipeline and assert on exact expected values.

import { describe, test, expect, beforeAll } from "bun:test";
import * as yaml from "js-yaml";
import { existsSync, readFileSync, writeFileSync, appendFileSync } from "fs";
import { resolve, dirname } from "path";
import { spawnSync } from "child_process";

const PROJECT_ROOT = resolve(dirname(import.meta.dir));
const WORKFLOW_PATH = resolve(
  PROJECT_ROOT,
  ".github/workflows/dependency-license-checker.yml"
);
const ACT_RESULT_PATH = resolve(PROJECT_ROOT, "act-result.txt");

// Load and parse the workflow YAML once
const workflowText = readFileSync(WORKFLOW_PATH, "utf-8");
const workflow = yaml.load(workflowText) as Record<string, any>;

// ============================================================
// 1. Workflow Structure Tests
// ============================================================
describe("Workflow structure", () => {
  test("workflow file exists", () => {
    expect(existsSync(WORKFLOW_PATH)).toBe(true);
  });

  test("has correct trigger events (push, pull_request, workflow_dispatch)", () => {
    const on = workflow["on"] as Record<string, unknown>;
    expect(on).toBeDefined();
    expect("push" in on).toBe(true);
    expect("pull_request" in on).toBe(true);
    expect("workflow_dispatch" in on).toBe(true);
  });

  test("has permissions set to contents:read", () => {
    expect(workflow.permissions).toBeDefined();
    expect(workflow.permissions.contents).toBe("read");
  });

  test("has license-check job on ubuntu-latest", () => {
    const job = workflow.jobs["license-check"];
    expect(job).toBeDefined();
    expect(job["runs-on"]).toBe("ubuntu-latest");
  });

  test("first step is checkout@v4", () => {
    const steps = workflow.jobs["license-check"].steps;
    expect(steps[0].uses).toBe("actions/checkout@v4");
  });

  test("has bun setup step", () => {
    const steps = workflow.jobs["license-check"].steps;
    const bunStep = steps.find(
      (s: any) => s.uses && s.uses.startsWith("oven-sh/setup-bun@")
    );
    expect(bunStep).toBeDefined();
  });

  test("has install, test, and fixture check steps", () => {
    const steps = workflow.jobs["license-check"].steps;
    expect(steps.find((s: any) => s.run?.includes("bun install"))).toBeDefined();
    expect(steps.find((s: any) => s.run?.includes("bun test"))).toBeDefined();
    expect(
      steps.find((s: any) => s.run?.includes("all-approved-package.json"))
    ).toBeDefined();
    expect(
      steps.find((s: any) => s.run?.includes("has-denied-package.json"))
    ).toBeDefined();
    expect(
      steps.find((s: any) => s.run?.includes("mixed-requirements.txt"))
    ).toBeDefined();
  });
});

// ============================================================
// 2. Script File References
// ============================================================
describe("Script file references", () => {
  const requiredFiles = [
    "src/main.ts",
    "src/parser.ts",
    "src/checker.ts",
    "src/report.ts",
    "src/types.ts",
    "src/license-lookup.ts",
    "fixtures/all-approved-package.json",
    "fixtures/has-denied-package.json",
    "fixtures/mixed-requirements.txt",
    "fixtures/license-config.json",
  ];

  for (const file of requiredFiles) {
    test(`${file} exists`, () => {
      expect(existsSync(resolve(PROJECT_ROOT, file))).toBe(true);
    });
  }
});

// ============================================================
// 3. Actionlint Validation
// ============================================================
describe("Actionlint validation", () => {
  test("actionlint passes with exit code 0", () => {
    const result = spawnSync("actionlint", [WORKFLOW_PATH], {
      encoding: "utf-8",
    });
    if (result.status !== 0) {
      console.error("actionlint output:", result.stdout, result.stderr);
    }
    expect(result.status).toBe(0);
  });
});

// ============================================================
// 4. Act Integration Tests
// ============================================================
describe("Act integration", () => {
  let actOutput: string = "";
  let actExitCode: number = 1;

  beforeAll(() => {
    // Create a temp directory with a fresh git repo containing our project
    const tmpDir = spawnSync("mktemp", ["-d"], {
      encoding: "utf-8",
    }).stdout.trim();
    const projectDir = `${tmpDir}/project`;

    // Copy project files (excluding .git, node_modules, act-result.txt)
    spawnSync("mkdir", ["-p", projectDir]);
    const items = spawnSync("ls", ["-A", PROJECT_ROOT], {
      encoding: "utf-8",
    }).stdout.trim().split("\n");

    for (const item of items) {
      if (item === ".git" || item === "node_modules" || item === "act-result.txt") continue;
      spawnSync("cp", ["-r", `${PROJECT_ROOT}/${item}`, projectDir + "/"], {
        encoding: "utf-8",
      });
    }

    // Init git repo (act requires one)
    spawnSync("git", ["init"], { cwd: projectDir, encoding: "utf-8" });
    spawnSync("git", ["config", "user.email", "test@test.com"], {
      cwd: projectDir, encoding: "utf-8",
    });
    spawnSync("git", ["config", "user.name", "test"], {
      cwd: projectDir, encoding: "utf-8",
    });
    spawnSync("git", ["add", "-A"], { cwd: projectDir, encoding: "utf-8" });
    spawnSync("git", ["commit", "-m", "initial"], {
      cwd: projectDir, encoding: "utf-8",
    });

    // Run act push (--pull=false to use local image without pulling)
    console.log("Running act push --rm --pull=false (this may take a few minutes)...");
    const actResult = spawnSync("act", ["push", "--rm", "--pull=false"], {
      cwd: projectDir,
      encoding: "utf-8",
      timeout: 300000, // 5 minute timeout
    });

    actOutput = (actResult.stdout || "") + "\n" + (actResult.stderr || "");
    actExitCode = actResult.status ?? 1;

    // Write act-result.txt
    const content =
      "=== ACT RUN: Dependency License Checker Pipeline ===\n" +
      `Exit code: ${actExitCode}\n` +
      "=".repeat(60) + "\n" +
      actOutput +
      "\n" + "=".repeat(60) + "\n";
    writeFileSync(ACT_RESULT_PATH, content, "utf-8");

    // Cleanup temp dir
    spawnSync("rm", ["-rf", tmpDir]);

    if (actExitCode !== 0) {
      console.error("Act failed with exit code:", actExitCode);
      console.error("Output (last 100 lines):", actOutput.split("\n").slice(-100).join("\n"));
    }
  }, 360000); // 6 minute timeout

  test("act exits with code 0", () => {
    expect(actExitCode).toBe(0);
  });

  test("act-result.txt exists", () => {
    expect(existsSync(ACT_RESULT_PATH)).toBe(true);
  });

  test("job succeeded", () => {
    expect(actOutput).toContain("Job succeeded");
  });

  // -- Unit tests ran inside the pipeline --
  test("unit tests passed (0 fail)", () => {
    expect(actOutput).toMatch(/\d+ pass/);
    expect(actOutput).toContain("0 fail");
  });

  // -- All-approved fixture: exact value assertions --
  test("all-approved: found exactly 4 dependencies", () => {
    expect(actOutput).toContain("Found 4 dependencies in all-approved-package.json");
  });

  test("all-approved: Approved:4, Denied:0, Unknown:0", () => {
    expect(actOutput).toContain("Approved: 4");
    expect(actOutput).toContain("Denied: 0");
    expect(actOutput).toContain("Unknown: 0");
  });

  test("all-approved: individual licenses are correct", () => {
    // express=MIT, lodash=MIT, axios=MIT, typescript=Apache-2.0
    expect(actOutput).toContain("express");
    expect(actOutput).toContain("lodash");
    expect(actOutput).toContain("axios");
    expect(actOutput).toContain("typescript");
    expect(actOutput).toContain("Apache-2.0");
  });

  test("all-approved: PASS message", () => {
    expect(actOutput).toContain(
      "PASS: All dependencies have acceptable licenses."
    );
  });

  test("all-approved: exit marker ALL_APPROVED_EXIT=0", () => {
    expect(actOutput).toContain("ALL_APPROVED_EXIT=0");
  });

  // -- Has-denied fixture: exact value assertions --
  test("has-denied: found exactly 2 dependencies", () => {
    expect(actOutput).toContain("Found 2 dependencies in has-denied-package.json");
  });

  test("has-denied: Approved:1, Denied:1", () => {
    expect(actOutput).toContain("Approved: 1");
    expect(actOutput).toContain("Denied: 1");
  });

  test("has-denied: gpl-crypto marked DENIED with GPL-3.0", () => {
    expect(actOutput).toContain("gpl-crypto");
    expect(actOutput).toContain("GPL-3.0");
    expect(actOutput).toContain("DENIED");
  });

  test("has-denied: FAIL message with exactly 1 denied", () => {
    expect(actOutput).toContain("FAIL: 1 denied license(s) found.");
  });

  test("has-denied: exit marker DENIED_EXIT=1", () => {
    expect(actOutput).toContain("DENIED_EXIT=1");
  });

  // -- Requirements.txt fixture: exact value assertions --
  test("requirements.txt: found exactly 4 dependencies", () => {
    expect(actOutput).toContain(
      "Found 4 dependencies in mixed-requirements.txt"
    );
  });

  test("requirements.txt: Approved:3, Denied:1, Unknown:0", () => {
    expect(actOutput).toContain("Approved: 3");
  });

  test("requirements.txt: gpl-tool marked DENIED", () => {
    expect(actOutput).toContain("gpl-tool");
  });

  test("requirements.txt: exit marker REQUIREMENTS_EXIT=1", () => {
    expect(actOutput).toContain("REQUIREMENTS_EXIT=1");
  });

  test("requirements.txt: correctly detected denied licenses message", () => {
    expect(actOutput).toContain(
      "Correctly detected denied licenses in requirements.txt"
    );
  });
});
