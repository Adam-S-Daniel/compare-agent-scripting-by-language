// matrix-generator.test.ts
// Tests for the Environment Matrix Generator
// Uses red/green TDD: each test was written before its implementation.
// Act integration test runs the full workflow via act and validates exact values.

import { test, expect, describe, beforeAll } from "bun:test";
import { readFileSync, existsSync, appendFileSync, cpSync } from "fs";
import { mkdtempSync } from "fs";
import { join } from "path";
import { tmpdir } from "os";
import { spawnSync } from "child_process";
import { parse as parseYaml } from "yaml";

import { generateMatrix } from "./matrix-generator";

const PROJECT_DIR = process.cwd();
const WORKFLOW_PATH = join(PROJECT_DIR, ".github/workflows/environment-matrix-generator.yml");

// ─── Unit tests (TDD: written before implementation) ──────────────────────────

describe("generateMatrix - basic cartesian product", () => {
  test("2 OS x 2 node versions => 4 entries", () => {
    const result = generateMatrix({
      os: ["ubuntu-latest", "windows-latest"],
      languageVersions: { node: ["18", "20"] },
    });
    expect(result.matrix.include.length).toBe(4);
  });

  test("each entry has correct os field", () => {
    const result = generateMatrix({
      os: ["ubuntu-latest", "windows-latest"],
      languageVersions: { node: ["18"] },
    });
    const oses = result.matrix.include.map((e) => e.os);
    expect(oses).toContain("ubuntu-latest");
    expect(oses).toContain("windows-latest");
  });

  test("each entry has correct language version field", () => {
    const result = generateMatrix({
      os: ["ubuntu-latest"],
      languageVersions: { node: ["18", "20"] },
    });
    const nodes = result.matrix.include.map((e) => e.node);
    expect(nodes).toContain("18");
    expect(nodes).toContain("20");
  });

  test("multiple language version keys produce correct combinations", () => {
    const result = generateMatrix({
      os: ["ubuntu-latest"],
      languageVersions: { node: ["18"], python: ["3.11", "3.12"] },
    });
    // 1 OS x 1 node x 2 python = 2 entries
    expect(result.matrix.include.length).toBe(2);
  });
});

describe("generateMatrix - feature flags", () => {
  test("boolean feature flags expand the matrix", () => {
    const result = generateMatrix({
      os: ["ubuntu-latest"],
      languageVersions: { node: ["18"] },
      featureFlags: { experimental: [true, false] },
    });
    // 1 x 1 x 2 = 2 entries
    expect(result.matrix.include.length).toBe(2);
    const flags = result.matrix.include.map((e) => e.experimental);
    expect(flags).toContain(true);
    expect(flags).toContain(false);
  });

  test("multiple feature flags multiply correctly", () => {
    const result = generateMatrix({
      os: ["ubuntu-latest"],
      languageVersions: { node: ["18"] },
      featureFlags: { a: [true, false], b: [true, false] },
    });
    expect(result.matrix.include.length).toBe(4);
  });
});

describe("generateMatrix - exclude rules", () => {
  test("exclude removes matching entries", () => {
    const result = generateMatrix({
      os: ["ubuntu-latest", "windows-latest"],
      languageVersions: { node: ["18", "20"] },
      exclude: [{ os: "windows-latest", node: "18" }],
    });
    // 4 entries - 1 excluded = 3
    expect(result.matrix.include.length).toBe(3);
    const hasExcluded = result.matrix.include.some(
      (e) => e.os === "windows-latest" && e.node === "18"
    );
    expect(hasExcluded).toBe(false);
  });

  test("exclude with no match leaves matrix unchanged", () => {
    const result = generateMatrix({
      os: ["ubuntu-latest"],
      languageVersions: { node: ["18"] },
      exclude: [{ os: "windows-latest" }],
    });
    expect(result.matrix.include.length).toBe(1);
  });
});

describe("generateMatrix - include rules", () => {
  test("include adds a new entry not in base matrix", () => {
    const result = generateMatrix({
      os: ["ubuntu-latest", "windows-latest"],
      languageVersions: { node: ["18"] },
      include: [{ os: "macos-latest", node: "18" }],
    });
    // 2 base + 1 new = 3
    expect(result.matrix.include.length).toBe(3);
    const hasMac = result.matrix.include.some((e) => e.os === "macos-latest");
    expect(hasMac).toBe(true);
  });

  test("include merges extra fields into existing matching entry", () => {
    const result = generateMatrix({
      os: ["ubuntu-latest"],
      languageVersions: { node: ["18"] },
      include: [{ os: "ubuntu-latest", node: "18", extra: "bonus" }],
    });
    // Still 1 entry, but with extra field merged
    expect(result.matrix.include.length).toBe(1);
    expect((result.matrix.include[0] as Record<string, unknown>).extra).toBe("bonus");
  });
});

describe("generateMatrix - strategy settings", () => {
  test("fail-fast defaults to true", () => {
    const result = generateMatrix({
      os: ["ubuntu-latest"],
      languageVersions: { node: ["18"] },
    });
    expect(result["fail-fast"]).toBe(true);
  });

  test("fail-fast=false is preserved", () => {
    const result = generateMatrix({
      os: ["ubuntu-latest"],
      languageVersions: { node: ["18"] },
      failFast: false,
    });
    expect(result["fail-fast"]).toBe(false);
  });

  test("maxParallel is included when specified", () => {
    const result = generateMatrix({
      os: ["ubuntu-latest"],
      languageVersions: { node: ["18", "20"] },
      maxParallel: 3,
    });
    expect(result["max-parallel"]).toBe(3);
  });

  test("maxParallel is omitted when not specified", () => {
    const result = generateMatrix({
      os: ["ubuntu-latest"],
      languageVersions: { node: ["18"] },
    });
    expect(result["max-parallel"]).toBeUndefined();
  });
});

describe("generateMatrix - size validation", () => {
  test("matrix exceeding maxSize throws meaningful error", () => {
    expect(() =>
      generateMatrix({
        os: ["ubuntu-latest", "windows-latest"],
        languageVersions: { node: ["18", "20"] },
        maxSize: 2,
      })
    ).toThrow(/exceeds maximum.*2/i);
  });

  test("matrix exactly at maxSize is accepted", () => {
    const result = generateMatrix({
      os: ["ubuntu-latest", "windows-latest"],
      languageVersions: { node: ["18"] },
      maxSize: 2,
    });
    expect(result.matrix.include.length).toBe(2);
  });

  test("default maxSize is 256", () => {
    // Build a matrix near the limit without failing
    const os = Array.from({ length: 16 }, (_, i) => `os-${i}`);
    const node = Array.from({ length: 16 }, (_, i) => `${i}`);
    const result = generateMatrix({ os, languageVersions: { node } });
    expect(result.matrix.include.length).toBe(256);
  });
});

// ─── Workflow structure tests ──────────────────────────────────────────────────

describe("workflow structure", () => {
  test("workflow file exists", () => {
    expect(existsSync(WORKFLOW_PATH)).toBe(true);
  });

  test("workflow has correct triggers", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    const wf = parseYaml(content) as Record<string, unknown>;
    const on = wf["on"] as Record<string, unknown>;
    expect(on).toHaveProperty("push");
    expect(on).toHaveProperty("workflow_dispatch");
  });

  test("workflow has generate-matrix job", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    const wf = parseYaml(content) as Record<string, unknown>;
    const jobs = wf.jobs as Record<string, unknown>;
    expect(jobs).toHaveProperty("generate-matrix");
  });

  test("workflow job has checkout step", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    const wf = parseYaml(content) as Record<string, unknown>;
    const jobs = wf.jobs as Record<string, unknown>;
    const job = jobs["generate-matrix"] as Record<string, unknown>;
    const steps = job.steps as Array<Record<string, unknown>>;
    const hasCheckout = steps.some((s) =>
      String(s.uses ?? "").startsWith("actions/checkout@")
    );
    expect(hasCheckout).toBe(true);
  });

  test("workflow references script file that exists", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("matrix-generator.ts");
    expect(existsSync(join(PROJECT_DIR, "matrix-generator.ts"))).toBe(true);
  });

  test("actionlint passes on workflow file", () => {
    const result = spawnSync("actionlint", [WORKFLOW_PATH], { encoding: "utf-8" });
    if (result.status !== 0) {
      console.error("actionlint output:", result.stdout + result.stderr);
    }
    expect(result.status).toBe(0);
  });
});

// ─── Act integration test ─────────────────────────────────────────────────────

describe("act integration", () => {
  let actOutput = "";
  let actExitCode = -1;

  beforeAll(async () => {
    // Create an isolated temp git repo with all project files
    const tmpDir = mkdtempSync(join(tmpdir(), "matrix-act-"));

    // Copy everything except .git and node_modules.
    // Use a regex that matches /.git/ or ends with /.git so .github is NOT excluded.
    cpSync(PROJECT_DIR, tmpDir, {
      recursive: true,
      filter: (src) =>
        !/\/\.git(\/|$)/.test(src) && !src.includes("/node_modules"),
    });

    // Initialize git repo and commit
    spawnSync("git", ["init"], { cwd: tmpDir });
    spawnSync("git", ["config", "user.email", "test@test.com"], { cwd: tmpDir });
    spawnSync("git", ["config", "user.name", "Test"], { cwd: tmpDir });
    spawnSync("git", ["add", "-A"], { cwd: tmpDir });
    spawnSync("git", ["commit", "-m", "test"], { cwd: tmpDir });

    // Run act push --rm --pull=false (image is local-only, not on Docker Hub)
    console.log(`Running act in ${tmpDir} ...`);
    const actResult = spawnSync("act", ["push", "--rm", "--pull=false"], {
      cwd: tmpDir,
      encoding: "utf-8",
      timeout: 300_000,
      maxBuffer: 20 * 1024 * 1024,
    });

    actOutput = (actResult.stdout ?? "") + (actResult.stderr ?? "");
    actExitCode = actResult.status ?? -1;

    // Save output to act-result.txt (required artifact)
    const delimiter = "=".repeat(70);
    appendFileSync(
      join(PROJECT_DIR, "act-result.txt"),
      `${delimiter}\nACT INTEGRATION TEST — environment-matrix-generator\nExit code: ${actExitCode}\n${delimiter}\n${actOutput}\n${delimiter}\n\n`
    );

    console.log(`act exited with code ${actExitCode}`);
    if (actExitCode !== 0) {
      console.error("act output (last 3000 chars):\n", actOutput.slice(-3000));
    }
  }, 330_000);

  test("act exited with code 0", () => {
    expect(actExitCode).toBe(0);
  });

  test("job succeeded", () => {
    expect(actOutput).toContain("Job succeeded");
  });

  test("basic matrix: 4 entries", () => {
    expect(actOutput).toContain("MATRIX_ASSERT_BASIC_COUNT=4");
  });

  test("basic matrix: fail-fast=false", () => {
    expect(actOutput).toContain("MATRIX_ASSERT_BASIC_FAILFAST=false");
  });

  test("feature flags matrix: 2 entries", () => {
    expect(actOutput).toContain("MATRIX_ASSERT_FLAGS_COUNT=2");
  });

  test("exclude rules matrix: 3 entries", () => {
    expect(actOutput).toContain("MATRIX_ASSERT_EXCLUDES_COUNT=3");
  });

  test("include rules matrix: 3 entries", () => {
    expect(actOutput).toContain("MATRIX_ASSERT_INCLUDES_COUNT=3");
  });

  test("max-parallel setting: value=3", () => {
    expect(actOutput).toContain("MATRIX_ASSERT_MAXPARALLEL=3");
  });

  test("max-size validation: error on overflow", () => {
    expect(actOutput).toContain("MATRIX_ASSERT_MAXSIZE_ERROR=PASS");
  });
});
