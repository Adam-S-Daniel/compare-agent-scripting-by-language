/**
 * Test harness for the Environment Matrix Generator.
 *
 * Tests are structured in two groups:
 * 1. Workflow structure tests (YAML parsing, actionlint, file references)
 * 2. Integration tests via `act` (runs the full workflow in Docker)
 *
 * All test cases execute through the GitHub Actions workflow via `act`.
 */

import { describe, test, expect, beforeAll } from "bun:test";
import { readFileSync, existsSync, mkdirSync, writeFileSync, cpSync, rmSync } from "fs";
import { execSync } from "child_process";
import { join } from "path";
import YAML from "./yaml-parser";

const PROJECT_DIR = import.meta.dir;
const WORKFLOW_PATH = join(PROJECT_DIR, ".github/workflows/environment-matrix-generator.yml");
const ACT_RESULT_PATH = join(PROJECT_DIR, "act-result.txt");

// --- Workflow Structure Tests ---

describe("Workflow structure tests", () => {
  let workflow: any;

  beforeAll(() => {
    const raw = readFileSync(WORKFLOW_PATH, "utf-8");
    workflow = YAML.parse(raw);
  });

  test("workflow file exists", () => {
    expect(existsSync(WORKFLOW_PATH)).toBe(true);
  });

  test("has correct trigger events", () => {
    expect(workflow.on).toBeDefined();
    expect(workflow.on.push).toBeDefined();
    expect(workflow.on.pull_request).toBeDefined();
    expect(workflow.on.workflow_dispatch).toBeDefined();
  });

  test("has generate-matrix job", () => {
    expect(workflow.jobs).toBeDefined();
    expect(workflow.jobs["generate-matrix"]).toBeDefined();
  });

  test("job runs on ubuntu-latest", () => {
    expect(workflow.jobs["generate-matrix"]["runs-on"]).toBe("ubuntu-latest");
  });

  test("uses actions/checkout@v4", () => {
    const steps = workflow.jobs["generate-matrix"].steps;
    const checkoutStep = steps.find((s: any) => s.uses === "actions/checkout@v4");
    expect(checkoutStep).toBeDefined();
  });

  test("references matrix-generator.ts script", () => {
    const steps = workflow.jobs["generate-matrix"].steps;
    const scriptSteps = steps.filter((s: any) =>
      s.run && s.run.includes("matrix-generator.ts")
    );
    expect(scriptSteps.length).toBeGreaterThan(0);
  });

  test("references fixture files that exist", () => {
    const steps = workflow.jobs["generate-matrix"].steps;
    const fixtureRefs = ["fixtures/basic.json", "fixtures/with-excludes.json",
      "fixtures/with-includes.json", "fixtures/too-large.json"];
    for (const fixture of fixtureRefs) {
      expect(existsSync(join(PROJECT_DIR, fixture))).toBe(true);
    }
  });

  test("has permissions configured", () => {
    expect(workflow.permissions).toBeDefined();
    expect(workflow.permissions.contents).toBe("read");
  });

  test("actionlint passes", () => {
    const result = execSync(`actionlint ${WORKFLOW_PATH} 2>&1`, {
      encoding: "utf-8",
    });
    // actionlint returns empty string on success
    expect(result.trim()).toBe("");
  });
});

// --- Act Integration Tests ---

describe("Act integration tests", () => {
  let actOutput: string = "";

  beforeAll(() => {
    // Set up a temporary git repo with all project files, run act
    const tmpDir = join(PROJECT_DIR, ".tmp-act-repo");

    // Clean up any previous run
    if (existsSync(tmpDir)) {
      rmSync(tmpDir, { recursive: true, force: true });
    }
    mkdirSync(tmpDir, { recursive: true });

    // Copy project files to temp dir
    const filesToCopy = [
      "matrix-generator.ts",
      ".actrc",
    ];
    for (const f of filesToCopy) {
      const src = join(PROJECT_DIR, f);
      if (existsSync(src)) {
        cpSync(src, join(tmpDir, f), { recursive: true });
      }
    }

    // Copy directories
    cpSync(join(PROJECT_DIR, "fixtures"), join(tmpDir, "fixtures"), { recursive: true });
    cpSync(join(PROJECT_DIR, ".github"), join(tmpDir, ".github"), { recursive: true });

    // Initialize git repo (act requires it)
    execSync("git init && git add -A && git commit -m 'init'", {
      cwd: tmpDir,
      encoding: "utf-8",
      stdio: "pipe",
    });

    // Run act
    try {
      actOutput = execSync("act push --rm --pull=false 2>&1", {
        cwd: tmpDir,
        encoding: "utf-8",
        timeout: 180000, // 3 minute timeout
        stdio: "pipe",
      });
    } catch (err: any) {
      // act may exit non-zero but still produce output we can analyze
      actOutput = err.stdout || err.stderr || err.message || "";
    }

    // Write act output to act-result.txt
    writeFileSync(ACT_RESULT_PATH, `=== ACT RUN OUTPUT ===\n${actOutput}\n=== END ACT RUN ===\n`);

    // Clean up temp dir
    rmSync(tmpDir, { recursive: true, force: true });
  }, 200000); // 200 second timeout for beforeAll

  test("act-result.txt was created", () => {
    expect(existsSync(ACT_RESULT_PATH)).toBe(true);
  });

  test("act exited successfully (job succeeded)", () => {
    expect(actOutput).toContain("Job succeeded");
  });

  // --- Basic matrix test ---
  test("basic matrix: produces 6 combinations (2 OS x 3 versions)", () => {
    expect(actOutput).toContain('"total-jobs": 6');
  });

  test("basic matrix: contains ubuntu-latest", () => {
    expect(actOutput).toContain('"os": "ubuntu-latest"');
  });

  test("basic matrix: contains windows-latest", () => {
    expect(actOutput).toContain('"os": "windows-latest"');
  });

  test("basic matrix: fail-fast is false", () => {
    expect(actOutput).toContain('"fail-fast": false');
  });

  // --- Excludes test ---
  test("excludes matrix: produces 7 combinations (9 - 2 excluded)", () => {
    expect(actOutput).toContain('"total-jobs": 7');
  });

  test("excludes matrix: max-parallel is 4", () => {
    expect(actOutput).toContain('"max-parallel": 4');
  });

  // --- Includes test ---
  test("includes matrix: adds experimental flag to matching combo", () => {
    expect(actOutput).toContain('"experimental": "true"');
  });

  test("includes matrix: adds macos-latest as new combination", () => {
    expect(actOutput).toContain('"os": "macos-latest"');
  });

  test("includes matrix: produces 3 total jobs (2 original + 1 new)", () => {
    // 2 from cartesian (ubuntu x [18,20]), include extends one and adds one new = 3
    expect(actOutput).toContain('"total-jobs": 3');
  });

  // --- Too-large test ---
  test("too-large matrix: correctly rejects oversized matrix", () => {
    expect(actOutput).toContain("PASS: Correctly rejected oversized matrix");
  });

  test("too-large matrix: shows error about exceeding max size", () => {
    expect(actOutput).toContain("exceeds maximum allowed size of 10");
  });

  // --- Stdin test ---
  test("stdin test: produces 1 combination", () => {
    expect(actOutput).toContain('"total-jobs": 1');
  });
});
