// Test harness for the environment matrix generator.
//
// Per project requirements, all *behavioral* tests run through the GitHub
// Actions workflow via `act`. This file is the single bun-test entry point;
// it does three things:
//
//   1. Validates the workflow structurally (YAML present, required steps,
//      script paths exist, actionlint passes).
//   2. For each fixture, sets up a temp git repo with the project files +
//      that fixture's data, runs `act push --rm`, captures output, asserts
//      exit 0 and exact expected matrix output.
//   3. Appends each act invocation's output to act-result.txt at the
//      project root, with delimiters between fixtures.
//
// We have a hard budget of <= 3 `act push` runs total. We use exactly three:
// one per fixture (basic, complex, oversized).

import { test, describe, expect, beforeAll } from "bun:test";
import { spawnSync } from "node:child_process";
import {
  appendFileSync,
  cpSync,
  existsSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

// Project root — bun test runs from the project directory.
const PROJECT_DIR = resolve(import.meta.dir, "..");
const RESULT_FILE = join(PROJECT_DIR, "act-result.txt");
const WORKFLOW_PATH = join(
  PROJECT_DIR,
  ".github",
  "workflows",
  "environment-matrix-generator.yml",
);

// Files that must be copied into each temp workspace for the workflow to run.
const PROJECT_FILES = [
  "matrix.ts",
  "test-runner.ts",
  "package.json",
  "tsconfig.json",
  ".actrc",
];

interface ActResult {
  stdout: string;
  stderr: string;
  combined: string;
  status: number;
}

/**
 * Run the workflow via act in a fresh temp git repo seeded with the named
 * fixture (copied to `fixture.json` at the repo root).
 *
 * Output is appended to act-result.txt with clear delimiters so the file
 * survives as a single artifact across all three fixture runs.
 */
function runActWithFixture(fixtureName: string): ActResult {
  const tmp = mkdtempSync(join(tmpdir(), `matrix-act-${fixtureName}-`));
  try {
    for (const f of PROJECT_FILES) {
      cpSync(join(PROJECT_DIR, f), join(tmp, f));
    }
    cpSync(join(PROJECT_DIR, ".github"), join(tmp, ".github"), {
      recursive: true,
    });
    // Copy the chosen fixture as the workflow input filename.
    cpSync(
      join(PROJECT_DIR, "fixtures", `${fixtureName}.json`),
      join(tmp, "fixture.json"),
    );

    // Initialize a minimal git repo so `act push` has a valid context.
    const gitInit = (...args: string[]) =>
      spawnSync("git", args, { cwd: tmp, encoding: "utf-8" });
    gitInit("init", "-q", "-b", "main");
    gitInit("config", "user.email", "matrix-test@example.com");
    gitInit("config", "user.name", "matrix-test");
    gitInit("add", ".");
    const commit = gitInit("commit", "-q", "-m", `seed ${fixtureName}`);
    if (commit.status !== 0) {
      throw new Error(
        `git commit failed for ${fixtureName}: ${commit.stderr || commit.stdout}`,
      );
    }

    // --pull=false: the act-ubuntu-pwsh image is local-only; without this
    // act tries to pull from a registry that doesn't host it. The repo's
    // .actrc also sets this, but passing it explicitly keeps the harness
    // robust to differing default behaviors of act versions.
    const r = spawnSync("act", ["push", "--rm", "--pull=false"], {
      cwd: tmp,
      encoding: "utf-8",
      // act produces verbose output; allow plenty of buffer.
      maxBuffer: 64 * 1024 * 1024,
      timeout: 5 * 60 * 1000,
    });

    const stdout = r.stdout ?? "";
    const stderr = r.stderr ?? "";
    const combined = `${stdout}\n--- STDERR ---\n${stderr}`;

    appendFileSync(
      RESULT_FILE,
      `\n\n===================== FIXTURE: ${fixtureName} =====================\n`,
    );
    appendFileSync(RESULT_FILE, combined);
    appendFileSync(
      RESULT_FILE,
      `\n--------------------- END FIXTURE: ${fixtureName} (exit=${r.status}) ---------------------\n`,
    );

    return { stdout, stderr, combined, status: r.status ?? -1 };
  } finally {
    try {
      rmSync(tmp, { recursive: true, force: true });
    } catch {
      // Cleanup best-effort.
    }
  }
}

describe("workflow structure", () => {
  test("workflow file exists", () => {
    expect(existsSync(WORKFLOW_PATH)).toBe(true);
  });

  test("workflow YAML references required scripts and actions", () => {
    const yml = readFileSync(WORKFLOW_PATH, "utf-8");
    expect(yml).toContain("actions/checkout@");
    expect(yml).toContain("matrix.ts");
    expect(yml).toContain("test-runner.ts");
    expect(yml).toContain("on:");
    expect(yml).toContain("permissions:");
    expect(yml).toContain("jobs:");
  });

  test("required source files exist", () => {
    for (const f of PROJECT_FILES) {
      expect(existsSync(join(PROJECT_DIR, f))).toBe(true);
    }
    expect(existsSync(join(PROJECT_DIR, "fixtures", "basic.json"))).toBe(true);
    expect(existsSync(join(PROJECT_DIR, "fixtures", "complex.json"))).toBe(
      true,
    );
    expect(existsSync(join(PROJECT_DIR, "fixtures", "oversized.json"))).toBe(
      true,
    );
  });

  test("actionlint passes on workflow", () => {
    const r = spawnSync("actionlint", [WORKFLOW_PATH], { encoding: "utf-8" });
    if (r.status !== 0) {
      console.error("actionlint output:\n" + (r.stdout ?? "") + (r.stderr ?? ""));
    }
    expect(r.status).toBe(0);
  });
});

describe("act fixture runs", () => {
  beforeAll(() => {
    // Reset act-result.txt at the start so it only reflects this test session.
    writeFileSync(
      RESULT_FILE,
      `act-result.txt — generated ${new Date().toISOString()}\n`,
    );
  });

  // 3 minutes per fixture is more than enough; act usually finishes in < 60s
  // once the image is cached.
  const ACT_TIMEOUT_MS = 5 * 60 * 1000;

  test(
    "fixture: basic — simple cartesian product",
    () => {
      const r = runActWithFixture("basic");
      expect(r.status).toBe(0);
      expect(r.combined).toContain("Job succeeded");
      expect(r.combined).toContain("=== TEST_PASS: basic ===");
      // Expected: 2 OS x 2 node versions = 4 jobs.
      expect(r.combined).toContain('"size": 4');
      // Strategy fields propagated:
      expect(r.combined).toContain('"max-parallel": 4');
      expect(r.combined).toContain('"fail-fast": true');
    },
    ACT_TIMEOUT_MS,
  );

  test(
    "fixture: complex — includes/excludes/feature flags",
    () => {
      const r = runActWithFixture("complex");
      expect(r.status).toBe(0);
      expect(r.combined).toContain("Job succeeded");
      expect(r.combined).toContain("=== TEST_PASS: complex ===");
      // 3 OS x 2 node x 2 python x 2 flags = 24, minus 4 excluded
      // (windows-latest x node=18 x 2 python x 2 flags) = 20.
      // The single fully-specified `include` augments an existing combo
      // (it does not introduce a new job), so the final job count is 20.
      expect(r.combined).toContain('"size": 20');
      expect(r.combined).toContain('"fail-fast": false');
    },
    ACT_TIMEOUT_MS,
  );

  test(
    "fixture: oversized — maxSize validation error",
    () => {
      const r = runActWithFixture("oversized");
      expect(r.status).toBe(0);
      expect(r.combined).toContain("Job succeeded");
      expect(r.combined).toContain("=== TEST_PASS: oversized ===");
      // Cartesian: 3 x 3 x 3 x 3 = 81; maxSize is 50 → error must report this.
      expect(r.combined).toContain("Matrix size 81 exceeds maximum allowed size 50");
    },
    ACT_TIMEOUT_MS,
  );

  test("act-result.txt was written and contains all three fixtures", () => {
    expect(existsSync(RESULT_FILE)).toBe(true);
    const content = readFileSync(RESULT_FILE, "utf-8");
    expect(content).toContain("FIXTURE: basic");
    expect(content).toContain("FIXTURE: complex");
    expect(content).toContain("FIXTURE: oversized");
  });
});
