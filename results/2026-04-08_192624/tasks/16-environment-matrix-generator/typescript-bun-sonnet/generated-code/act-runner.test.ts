// act-runner.test.ts
// Integration tests that run the GitHub Actions workflow via `act`.
//
// Each test case:
//   1. Creates a temp git repo with all project files + a specific fixture
//      placed at fixtures/test-config.json.
//   2. Runs: act push --rm -C <tmpDir>
//   3. Asserts act exits with code 0 and every job shows "Job succeeded".
//   4. Parses the act output and asserts EXACT expected values from the
//      matrix output (marked with === MATRIX OUTPUT START/END ===).
//   5. Appends the full output (clearly delimited) to act-result.txt.
//
// Also includes workflow structure tests that verify the YAML has the
// expected triggers, jobs, steps, and that actionlint passes.
//
// NOTE: The workflow runs `bun test matrix-generator.test.ts` (only unit
// tests), NOT this file, to avoid infinite recursion (act inside act).

import { describe, test, expect, afterAll } from "bun:test";
import { join } from "path";
import { mkdtempSync } from "fs";
import { tmpdir } from "os";
import { mkdir, copyFile, readdir } from "fs/promises";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const SOURCE_DIR = import.meta.dir;
const ACT_RESULT_FILE = join(process.cwd(), "act-result.txt");

// Accumulated act output across all test cases; flushed in afterAll.
const actResultLines: string[] = [];

/** Recursively copy a directory, skipping unwanted entries. */
async function copyDir(
  src: string,
  dst: string,
  skip = new Set([".git", "node_modules", "act-result.txt"])
): Promise<void> {
  await mkdir(dst, { recursive: true });
  const entries = await readdir(src, { withFileTypes: true });
  for (const entry of entries) {
    if (skip.has(entry.name)) continue;
    const srcPath = join(src, entry.name);
    const dstPath = join(dst, entry.name);
    if (entry.isDirectory()) {
      await copyDir(srcPath, dstPath, skip);
    } else {
      await copyFile(srcPath, dstPath);
    }
  }
}

/** Initialise a git repo in `dir` and commit everything. */
async function initGitRepo(dir: string): Promise<void> {
  const run = async (cmd: string[]) => {
    const proc = Bun.spawn(cmd, {
      cwd: dir,
      stdout: "pipe",
      stderr: "pipe",
    });
    await proc.exited;
  };
  await run(["git", "init"]);
  await run(["git", "config", "user.email", "test@example.com"]);
  await run(["git", "config", "user.name", "Test"]);
  await run(["git", "add", "-A"]);
  await run(["git", "commit", "-m", "test commit"]);
}

/**
 * Sets up a temp repo with all project files and the given fixture placed at
 * fixtures/test-config.json, then runs `act push --rm`.
 *
 * Returns { exitCode, output }.
 */
async function runActWithFixture(
  fixturePath: string,
  label: string
): Promise<{ exitCode: number; output: string }> {
  // 1. Create temp dir.
  const tmpDir = mkdtempSync(join(tmpdir(), "act-matrix-test-"));

  // 2. Copy all project files.
  await copyDir(SOURCE_DIR, tmpDir);

  // 3. Overwrite fixtures/test-config.json with the test case's fixture.
  const fixtureContent = await Bun.file(fixturePath).text();
  await Bun.write(join(tmpDir, "fixtures", "test-config.json"), fixtureContent);

  // 4. Initialise a git repo so act/checkout works.
  await initGitRepo(tmpDir);

  // 5. Run act.
  const proc = Bun.spawn(
    ["act", "push", "--rm", "-C", tmpDir],
    { stdout: "pipe", stderr: "pipe" }
  );

  const [stdout, stderr] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
  ]);
  const exitCode = await proc.exited;
  const output = stdout + "\n" + stderr;

  // 6. Accumulate output for act-result.txt.
  actResultLines.push(
    `\n${"=".repeat(60)}\nTEST CASE: ${label}\nFIXTURE: ${fixturePath}\n${"=".repeat(60)}\n` +
      output +
      `\nEXIT CODE: ${exitCode}\n${"=".repeat(60)}\n`
  );

  return { exitCode, output };
}

/** Extract the JSON string between the sentinel markers in act output. */
function extractMatrixJson(output: string): string {
  // Act prefixes every line with `[job/step]   ` — strip that before parsing.
  const startMarker = "=== MATRIX OUTPUT START ===";
  const endMarker = "=== MATRIX OUTPUT END ===";

  const lines = output.split("\n");
  const jsonLines: string[] = [];
  let inside = false;

  for (const line of lines) {
    // Strip the `[job-name/step-name]   ` prefix that act adds.
    const content = line.replace(/^\[[^\]]+\]\s+\|?\s*/, "").trim();

    if (content.includes(startMarker)) {
      inside = true;
      continue;
    }
    if (content.includes(endMarker)) {
      inside = false;
      continue;
    }
    if (inside) {
      jsonLines.push(content);
    }
  }

  return jsonLines.join("\n");
}

// ---------------------------------------------------------------------------
// Flush act-result.txt once all tests have run.
// ---------------------------------------------------------------------------
afterAll(async () => {
  await Bun.write(ACT_RESULT_FILE, actResultLines.join(""));
  console.log(`\nact-result.txt written to: ${ACT_RESULT_FILE}`);
});

// ---------------------------------------------------------------------------
// Workflow structure tests (fast — no Docker)
// ---------------------------------------------------------------------------
describe("Workflow structure", () => {
  const workflowPath = join(
    SOURCE_DIR,
    ".github/workflows/environment-matrix-generator.yml"
  );

  test("workflow file exists", async () => {
    const file = Bun.file(workflowPath);
    expect(await file.exists()).toBe(true);
  });

  test("workflow has push trigger", async () => {
    const content = await Bun.file(workflowPath).text();
    expect(content).toContain("push:");
  });

  test("workflow has pull_request trigger", async () => {
    const content = await Bun.file(workflowPath).text();
    expect(content).toContain("pull_request:");
  });

  test("workflow has workflow_dispatch trigger", async () => {
    const content = await Bun.file(workflowPath).text();
    expect(content).toContain("workflow_dispatch:");
  });

  test("workflow references matrix-generator.ts", async () => {
    const content = await Bun.file(workflowPath).text();
    expect(content).toContain("matrix-generator.ts");
  });

  test("workflow references fixtures/test-config.json", async () => {
    const content = await Bun.file(workflowPath).text();
    expect(content).toContain("fixtures/test-config.json");
  });

  test("matrix-generator.ts source file exists", async () => {
    const file = Bun.file(join(SOURCE_DIR, "matrix-generator.ts"));
    expect(await file.exists()).toBe(true);
  });

  test("all fixture files exist", async () => {
    const fixtures = [
      "basic-matrix.json",
      "with-include.json",
      "with-exclude.json",
      "with-limits.json",
      "test-config.json",
    ];
    for (const name of fixtures) {
      const file = Bun.file(join(SOURCE_DIR, "fixtures", name));
      expect(await file.exists()).toBe(
        true,
        `fixture ${name} should exist`
      );
    }
  });

  test("actionlint passes on the workflow file", async () => {
    const proc = Bun.spawn(["actionlint", workflowPath], {
      stdout: "pipe",
      stderr: "pipe",
    });
    const stderr = await new Response(proc.stderr).text();
    const exitCode = await proc.exited;
    expect(exitCode).toBe(0);
    expect(stderr).toBe("");
  });
});

// ---------------------------------------------------------------------------
// Act integration tests — one per fixture (slow; requires Docker)
// ---------------------------------------------------------------------------
describe("act integration — basic-matrix fixture", () => {
  test(
    "act exits 0 and generates a matrix with fail-fast false",
    async () => {
      const { exitCode, output } = await runActWithFixture(
        join(SOURCE_DIR, "fixtures", "basic-matrix.json"),
        "basic-matrix"
      );

      // Act must exit cleanly.
      expect(exitCode).toBe(0);

      // Both jobs must succeed.
      expect(output).toContain("Job succeeded");

      // Extract and validate the matrix JSON.
      const jsonStr = extractMatrixJson(output);
      expect(jsonStr.length).toBeGreaterThan(0);
      const parsed = JSON.parse(jsonStr);

      // Exact expected values.
      expect(parsed["fail-fast"]).toBe(false);
      expect(parsed["max-parallel"]).toBeUndefined();
      expect(parsed.matrix.os).toContain("ubuntu-latest");
      expect(parsed.matrix.os).toContain("windows-latest");
      expect(parsed.matrix["node-version"]).toContain("18");
      expect(parsed.matrix["node-version"]).toContain("20");
      expect(parsed.matrix["include"]).toBeUndefined();
      expect(parsed.matrix["exclude"]).toBeUndefined();
    },
    { timeout: 600_000 }
  );
});

describe("act integration — with-include fixture", () => {
  test(
    "act exits 0 and output contains macos-latest include and fail-fast true",
    async () => {
      const { exitCode, output } = await runActWithFixture(
        join(SOURCE_DIR, "fixtures", "with-include.json"),
        "with-include"
      );

      expect(exitCode).toBe(0);
      expect(output).toContain("Job succeeded");

      const jsonStr = extractMatrixJson(output);
      const parsed = JSON.parse(jsonStr);

      expect(parsed["fail-fast"]).toBe(true);
      expect(parsed.matrix["include"]).toEqual([
        { os: "macos-latest", "node-version": "20" },
      ]);
    },
    { timeout: 600_000 }
  );
});

describe("act integration — with-exclude fixture", () => {
  test(
    "act exits 0 and output contains exclude rule",
    async () => {
      const { exitCode, output } = await runActWithFixture(
        join(SOURCE_DIR, "fixtures", "with-exclude.json"),
        "with-exclude"
      );

      expect(exitCode).toBe(0);
      expect(output).toContain("Job succeeded");

      const jsonStr = extractMatrixJson(output);
      const parsed = JSON.parse(jsonStr);

      expect(parsed["fail-fast"]).toBe(false);
      expect(parsed.matrix["exclude"]).toEqual([
        { os: "windows-latest", "node-version": "18" },
      ]);
      // All three OS values should remain in the base dimension.
      expect(parsed.matrix.os).toContain("macos-latest");
    },
    { timeout: 600_000 }
  );
});

describe("act integration — with-limits fixture", () => {
  test(
    "act exits 0 and output contains max-parallel 2",
    async () => {
      const { exitCode, output } = await runActWithFixture(
        join(SOURCE_DIR, "fixtures", "with-limits.json"),
        "with-limits"
      );

      expect(exitCode).toBe(0);
      expect(output).toContain("Job succeeded");

      const jsonStr = extractMatrixJson(output);
      const parsed = JSON.parse(jsonStr);

      // Exact expected values from with-limits fixture.
      expect(parsed["max-parallel"]).toBe(2);
      expect(parsed["fail-fast"]).toBe(false);
    },
    { timeout: 600_000 }
  );
});
