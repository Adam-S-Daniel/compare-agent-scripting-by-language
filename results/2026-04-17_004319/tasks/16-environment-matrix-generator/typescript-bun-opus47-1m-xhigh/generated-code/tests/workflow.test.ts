// Workflow integration tests.
//
// This test suite exercises the full CI pipeline by running the workflow
// with `act` (nektos/act). It does NOT invoke the TypeScript code directly;
// every assertion is on the output act produces after running the workflow
// inside a Docker container.
//
// Structure:
//   1. YAML structure tests (read the workflow file, assert triggers/jobs).
//   2. actionlint test (exit code 0).
//   3. Per-fixture act run tests: for each test case, copy the project into
//      a fresh temp git repo with the fixture's config as the default, run
//      `act push --rm`, append the output to act-result.txt in the original
//      project root, and assert on expected substrings + "Job succeeded" +
//      exit code 0.
//
// Act output accumulates in act-result.txt in the project root — that is
// the required artifact for this task.

import { describe, expect, test, beforeAll } from "bun:test";
import {
  cpSync,
  existsSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
  appendFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const PROJECT_ROOT = resolve(
  dirname(fileURLToPath(import.meta.url)),
  "..",
);
const WORKFLOW_PATH = join(
  PROJECT_ROOT,
  ".github/workflows/environment-matrix-generator.yml",
);
const ACT_RESULT = join(PROJECT_ROOT, "act-result.txt");

// Files copied into the per-test-case temp repo. We deliberately exclude
// node_modules, .git, and previous act-result.txt so the harness is hermetic.
const PROJECT_FILES = [
  "src",
  "tests",
  "fixtures",
  ".github",
  ".actrc",
  "package.json",
  "tsconfig.json",
];

// ---- YAML structure tests -------------------------------------------------

describe("workflow: YAML structure", () => {
  const yaml = readFileSync(WORKFLOW_PATH, "utf8");

  test("declares the expected trigger events", () => {
    // The workflow must be runnable on push, pull_request, and manually.
    expect(yaml).toMatch(/on:/);
    expect(yaml).toMatch(/push:/);
    expect(yaml).toMatch(/pull_request:/);
    expect(yaml).toMatch(/workflow_dispatch:/);
  });

  test("declares jobs and their dependencies", () => {
    expect(yaml).toMatch(/jobs:/);
    expect(yaml).toMatch(/unit-tests:/);
    expect(yaml).toMatch(/generate-matrix:/);
    // generate-matrix must wait for unit-tests so a broken generator never
    // produces a matrix the world would consume.
    expect(yaml).toMatch(/needs:\s*unit-tests/);
  });

  test("uses actions/checkout@v4", () => {
    expect(yaml).toMatch(/actions\/checkout@v4/);
  });

  test("references the CLI script and fixture path", () => {
    expect(yaml).toContain("src/cli.ts");
    expect(yaml).toContain("fixtures/default.json");
    expect(existsSync(join(PROJECT_ROOT, "src/cli.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_ROOT, "fixtures/default.json"))).toBe(true);
  });

  test("declares read-only contents permission", () => {
    expect(yaml).toMatch(/permissions:\s*\n\s*contents:\s*read/);
  });
});

// ---- actionlint test ------------------------------------------------------

describe("workflow: actionlint", () => {
  test("passes actionlint with no errors", () => {
    const proc = Bun.spawnSync(["actionlint", WORKFLOW_PATH], {
      stdout: "pipe",
      stderr: "pipe",
    });
    if (proc.exitCode !== 0) {
      // Surface the diagnostic in the assertion message so failures explain
      // themselves without requiring a rerun.
      const out =
        proc.stdout.toString() + proc.stderr.toString();
      throw new Error(`actionlint failed:\n${out}`);
    }
    expect(proc.exitCode).toBe(0);
  });
});

// ---- act-based per-fixture tests ------------------------------------------

interface ActTestCase {
  name: string;
  fixture: Record<string, unknown>;
  // Strings the act output must contain (exact expected values, not just
  // "some number"). These are what prove the generator produced the correct
  // matrix for this fixture.
  expected: string[];
}

const ACT_CASES: ActTestCase[] = [
  // Case 1: full-featured config — cross product + exclude + include +
  // fail-fast + max-parallel.
  {
    name: "complex-matrix",
    fixture: {
      dimensions: {
        os: ["ubuntu-latest", "windows-latest"],
        node: [18, 20],
      },
      exclude: [{ os: "windows-latest", node: 18 }],
      include: [{ os: "macos-latest", node: 20, experimental: true }],
      maxParallel: 3,
      failFast: false,
      maxSize: 20,
    },
    expected: [
      // Fully expanded matrix combinations, serialized as they appear in
      // JSON.stringify(..., null, 2) output:
      `"os": "ubuntu-latest"`,
      `"os": "windows-latest"`,
      `"os": "macos-latest"`,
      `"node": 18`,
      `"node": 20`,
      `"experimental": true`,
      `"totalSize": 4`,
      `"fail-fast": false`,
      `"max-parallel": 3`,
      `TOTAL_SIZE=4`,
    ],
  },
  // Case 2: minimal config — single combination.
  {
    name: "simple-matrix",
    fixture: {
      dimensions: { os: ["ubuntu-latest"], node: [20] },
    },
    expected: [
      `"os": "ubuntu-latest"`,
      `"node": 20`,
      `"totalSize": 1`,
      `TOTAL_SIZE=1`,
    ],
  },
  // Case 3: boolean feature flags with excludes.
  {
    name: "feature-flags",
    fixture: {
      dimensions: {
        os: ["ubuntu-latest", "macos-latest"],
        experimental: [true, false],
      },
      exclude: [{ os: "macos-latest", experimental: true }],
      maxParallel: 2,
      failFast: true,
      maxSize: 10,
    },
    expected: [
      `"os": "ubuntu-latest"`,
      `"os": "macos-latest"`,
      `"experimental": true`,
      `"experimental": false`,
      `"totalSize": 3`,
      `"fail-fast": true`,
      `"max-parallel": 2`,
      `TOTAL_SIZE=3`,
    ],
  },
];

beforeAll(() => {
  // Reset the accumulator so it only contains this test run's output.
  writeFileSync(ACT_RESULT, "");
});

// Helper: set up a temp project copy with the given fixture installed as
// fixtures/default.json, initialize a git repo, and run `act push --rm`.
// Returns combined stdout+stderr and the exit code.
function runActCase(c: ActTestCase): { output: string; exitCode: number } {
  const tmp = mkdtempSync(join(tmpdir(), `emg-act-${c.name}-`));
  try {
    // 1. Copy project files into the temp directory.
    for (const entry of PROJECT_FILES) {
      const src = join(PROJECT_ROOT, entry);
      if (!existsSync(src)) continue;
      cpSync(src, join(tmp, entry), { recursive: true });
    }
    // 2. Overwrite the default fixture with this case's config.
    writeFileSync(
      join(tmp, "fixtures", "default.json"),
      JSON.stringify(c.fixture, null, 2),
    );
    // 3. Initialize a git repo — act needs one to resolve the push event.
    const git = (args: string[]) =>
      Bun.spawnSync(["git", "-C", tmp, ...args], {
        stdout: "pipe",
        stderr: "pipe",
      });
    git(["init", "-q", "-b", "main"]);
    git(["config", "user.email", "test@example.com"]);
    git(["config", "user.name", "Test"]);
    git(["add", "."]);
    git(["commit", "-q", "-m", "fixture"]);

    // 4. Run act with the push event.
    const proc = Bun.spawnSync(["act", "push", "--rm"], {
      cwd: tmp,
      stdout: "pipe",
      stderr: "pipe",
      env: { ...process.env },
    });
    const output =
      proc.stdout.toString() + "\n--STDERR--\n" + proc.stderr.toString();
    // 5. Append to the consolidated act-result.txt artifact.
    const header = `\n\n===== CASE: ${c.name} (exit=${proc.exitCode}) =====\n`;
    appendFileSync(ACT_RESULT, header + output);
    return { output, exitCode: proc.exitCode ?? -1 };
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
}

describe("workflow: act integration", () => {
  for (const c of ACT_CASES) {
    test(
      `act runs workflow for fixture "${c.name}"`,
      () => {
        const { output, exitCode } = runActCase(c);
        // Exit code must be 0 — act reports non-zero on job failure.
        if (exitCode !== 0) {
          throw new Error(
            `act exited with ${exitCode}\n--- last output ---\n${output.slice(-4000)}`,
          );
        }
        expect(exitCode).toBe(0);
        // "Job succeeded" must appear for BOTH jobs (unit-tests and
        // generate-matrix).
        const successes = output.match(/Job succeeded/g) ?? [];
        expect(successes.length).toBeGreaterThanOrEqual(2);
        // Every expected exact substring must be present.
        for (const needle of c.expected) {
          if (!output.includes(needle)) {
            throw new Error(
              `expected substring not found in act output: ${JSON.stringify(needle)}`,
            );
          }
        }
      },
      // Act boots Docker and installs Bun — each case can take a while.
      300_000,
    );
  }
});
