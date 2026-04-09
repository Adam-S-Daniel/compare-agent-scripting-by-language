/**
 * PR Label Assigner - Test Harness
 *
 * All tests run through `act` (GitHub Actions local runner).
 * Each test case:
 *   1. Creates a temp git repo with project files + fixture data
 *   2. Runs `act push --rm` and captures output
 *   3. Asserts act exits with code 0
 *   4. Parses act output and asserts on exact expected values
 *   5. Verifies "Job succeeded" appears
 *
 * Workflow structure tests also included (YAML parsing, actionlint, file refs).
 */

import { describe, test, expect, beforeAll, afterAll } from "bun:test";
import { mkdtemp, rm, readFile, writeFile, mkdir, cp } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { execSync } from "node:child_process";
import { parse as parseYaml } from "./yaml-parser";

// Path to the project root (where this test file lives)
const PROJECT_ROOT = import.meta.dir;

// Output file for all act results
const ACT_RESULT_FILE = join(PROJECT_ROOT, "act-result.txt");

// --- Test fixture definitions ---

interface TestFixture {
  name: string;
  changedFiles: string[];
  config: {
    rules: Array<{ pattern: string; label: string; priority: number }>;
    exclusiveMode?: boolean;
  };
  expectedLabels: string[];
  /** Map from label to expected files that triggered it */
  expectedLabelToFiles?: Record<string, string[]>;
}

const TEST_FIXTURES: TestFixture[] = [
  {
    name: "basic_docs_labeling",
    changedFiles: ["docs/README.md", "docs/guide/setup.md"],
    config: {
      rules: [
        { pattern: "docs/**", label: "documentation", priority: 1 },
        { pattern: "src/**", label: "source", priority: 1 },
      ],
    },
    expectedLabels: ["documentation"],
    expectedLabelToFiles: {
      documentation: ["docs/README.md", "docs/guide/setup.md"],
    },
  },
  {
    name: "multiple_labels_per_file",
    changedFiles: ["src/api/handler.test.ts"],
    config: {
      rules: [
        { pattern: "src/api/**", label: "api", priority: 2 },
        { pattern: "*.test.*", label: "tests", priority: 1 },
        { pattern: "src/**", label: "source", priority: 0 },
      ],
    },
    expectedLabels: ["api", "tests", "source"],
    expectedLabelToFiles: {
      api: ["src/api/handler.test.ts"],
      tests: ["src/api/handler.test.ts"],
      source: ["src/api/handler.test.ts"],
    },
  },
  {
    name: "priority_exclusive_mode",
    changedFiles: ["src/api/routes.ts", "src/utils/helper.ts"],
    config: {
      rules: [
        { pattern: "src/api/**", label: "api", priority: 10 },
        { pattern: "src/**", label: "source", priority: 1 },
      ],
      exclusiveMode: true,
    },
    // In exclusive mode: src/api/routes.ts only gets "api" (priority 10),
    // src/utils/helper.ts only gets "source" (priority 1)
    expectedLabels: ["api", "source"],
    expectedLabelToFiles: {
      api: ["src/api/routes.ts"],
      source: ["src/utils/helper.ts"],
    },
  },
  {
    name: "wildcard_extension_matching",
    changedFiles: [
      "src/app.test.ts",
      "tests/integration.test.js",
      "lib/utils.ts",
    ],
    config: {
      rules: [
        { pattern: "*.test.*", label: "tests", priority: 5 },
        { pattern: "lib/**", label: "library", priority: 3 },
      ],
    },
    expectedLabels: ["tests", "library"],
    expectedLabelToFiles: {
      tests: ["src/app.test.ts", "tests/integration.test.js"],
      library: ["lib/utils.ts"],
    },
  },
  {
    name: "no_matching_rules",
    changedFiles: ["random/file.xyz", "another/unknown.abc"],
    config: {
      rules: [
        { pattern: "docs/**", label: "documentation", priority: 1 },
        { pattern: "src/**", label: "source", priority: 1 },
      ],
    },
    expectedLabels: [],
  },
  {
    name: "complex_mixed_files",
    changedFiles: [
      "docs/api-reference.md",
      "src/api/users.ts",
      "src/api/users.test.ts",
      "config/settings.json",
      "src/core/engine.ts",
    ],
    config: {
      rules: [
        { pattern: "docs/**", label: "documentation", priority: 1 },
        { pattern: "src/api/**", label: "api", priority: 3 },
        { pattern: "*.test.*", label: "tests", priority: 2 },
        { pattern: "src/**", label: "source", priority: 0 },
        { pattern: "config/**", label: "configuration", priority: 1 },
      ],
    },
    expectedLabels: ["api", "tests", "configuration", "documentation", "source"],
    expectedLabelToFiles: {
      documentation: ["docs/api-reference.md"],
      api: ["src/api/users.ts", "src/api/users.test.ts"],
      tests: ["src/api/users.test.ts"],
      source: ["src/api/users.ts", "src/api/users.test.ts", "src/core/engine.ts"],
      configuration: ["config/settings.json"],
    },
  },
];

// --- Helper functions ---

/** Set up a temp git repo with project files and a specific test fixture. */
async function setupTempRepo(fixture: TestFixture): Promise<string> {
  const tempDir = await mkdtemp(join(tmpdir(), "pr-label-test-"));

  // Initialize a git repo
  execSync("git init", { cwd: tempDir, stdio: "pipe" });
  execSync('git config user.email "test@test.com"', {
    cwd: tempDir,
    stdio: "pipe",
  });
  execSync('git config user.name "Test"', { cwd: tempDir, stdio: "pipe" });

  // Copy project files
  const filesToCopy = [
    "label-assigner.ts",
    "package.json",
    "tsconfig.json",
    "bun.lock",
  ];

  for (const f of filesToCopy) {
    try {
      await cp(join(PROJECT_ROOT, f), join(tempDir, f));
    } catch {
      // bun.lock might not exist, that's ok
    }
  }

  // Copy workflow
  await mkdir(join(tempDir, ".github", "workflows"), { recursive: true });
  await cp(
    join(PROJECT_ROOT, ".github", "workflows", "pr-label-assigner.yml"),
    join(tempDir, ".github", "workflows", "pr-label-assigner.yml")
  );

  // Write test fixture data
  await mkdir(join(tempDir, "test-fixtures"), { recursive: true });
  await writeFile(
    join(tempDir, "test-fixtures", "changed-files.txt"),
    fixture.changedFiles.join("\n")
  );
  await writeFile(
    join(tempDir, "test-fixtures", "label-config.json"),
    JSON.stringify(fixture.config)
  );

  // Commit everything so `act` can check it out
  execSync("git add -A", { cwd: tempDir, stdio: "pipe" });
  execSync('git commit -m "test setup"', { cwd: tempDir, stdio: "pipe" });

  return tempDir;
}

/** Run act push in a temp repo and return stdout + exit code. */
function runAct(repoDir: string): { output: string; exitCode: number } {
  try {
    const output = execSync(
      "act push --rm -P ubuntu-latest=catthehacker/ubuntu:act-latest 2>&1",
      {
        cwd: repoDir,
        timeout: 300_000, // 5 min timeout
        maxBuffer: 10 * 1024 * 1024,
        encoding: "utf-8",
      }
    );
    return { output, exitCode: 0 };
  } catch (err: unknown) {
    const e = err as { status?: number; stdout?: string; stderr?: string; output?: string[] };
    const output =
      (e.stdout ?? "") + (e.stderr ?? "") + (e.output?.join("") ?? "");
    return { output, exitCode: e.status ?? 1 };
  }
}

/** Append a delimited section to the act-result.txt file. */
async function appendActResult(
  testName: string,
  output: string
): Promise<void> {
  const section = `\n${"=".repeat(60)}\nTEST: ${testName}\n${"=".repeat(60)}\n${output}\n`;
  try {
    const existing = await readFile(ACT_RESULT_FILE, "utf-8");
    await writeFile(ACT_RESULT_FILE, existing + section);
  } catch {
    await writeFile(ACT_RESULT_FILE, section);
  }
}

/** Extract the JSON label result from act output.
 * Act prefixes each line with something like "[PR Label Assigner/assign-labels]   | ".
 * We need to strip these prefixes before parsing the JSON.
 */
function extractLabelResult(
  output: string
): { labels: string[]; labelToFiles: Record<string, string[]> } | null {
  const startMarker = "=== LABEL RESULT START ===";
  const endMarker = "=== LABEL RESULT END ===";
  const startIdx = output.indexOf(startMarker);
  const endIdx = output.indexOf(endMarker);
  if (startIdx === -1 || endIdx === -1) return null;
  const rawBlock = output.substring(startIdx + startMarker.length, endIdx);
  // Strip act line prefixes: lines like "[...] | <content>" -> "<content>"
  const cleanedLines = rawBlock.split("\n").map((line) => {
    const pipeIdx = line.indexOf("| ");
    if (pipeIdx !== -1) return line.substring(pipeIdx + 2);
    return line;
  });
  const jsonStr = cleanedLines.join("\n").trim();
  try {
    return JSON.parse(jsonStr);
  } catch {
    return null;
  }
}

// --- Workflow Structure Tests ---

describe("Workflow Structure Tests", () => {
  let workflowContent: string;
  let workflow: Record<string, unknown>;

  beforeAll(async () => {
    workflowContent = await readFile(
      join(PROJECT_ROOT, ".github", "workflows", "pr-label-assigner.yml"),
      "utf-8"
    );
    workflow = parseYaml(workflowContent) as Record<string, unknown>;
  });

  test("workflow YAML has correct triggers", () => {
    const on = workflow["on"] as Record<string, unknown>;
    expect(on).toBeDefined();
    // Must have push trigger
    expect(on["push"]).toBeDefined();
    // Must have pull_request trigger
    expect(on["pull_request"]).toBeDefined();
    // Must have workflow_dispatch trigger
    expect(on["workflow_dispatch"]).toBeDefined();
  });

  test("workflow has assign-labels job with expected steps", () => {
    const jobs = workflow["jobs"] as Record<string, unknown>;
    expect(jobs).toBeDefined();
    const job = jobs["assign-labels"] as Record<string, unknown>;
    expect(job).toBeDefined();

    const steps = job["steps"] as Array<Record<string, unknown>>;
    expect(steps).toBeDefined();
    expect(steps.length).toBeGreaterThanOrEqual(4);

    // Check key steps exist
    const stepNames = steps.map((s) => s["name"] as string);
    expect(stepNames).toContain("Checkout repository");
    expect(stepNames).toContain("Setup Bun");
    expect(stepNames).toContain("Run label assigner");
  });

  test("workflow references label-assigner.ts correctly", () => {
    // The workflow run step should reference our script
    expect(workflowContent).toContain("bun run label-assigner.ts");
  });

  test("label-assigner.ts file exists at referenced path", async () => {
    const file = Bun.file(join(PROJECT_ROOT, "label-assigner.ts"));
    expect(await file.exists()).toBe(true);
  });

  test("actionlint passes with exit code 0", () => {
    const workflowPath = join(
      PROJECT_ROOT,
      ".github",
      "workflows",
      "pr-label-assigner.yml"
    );
    let exitCode = 0;
    try {
      execSync(`actionlint ${workflowPath}`, { stdio: "pipe" });
    } catch {
      exitCode = 1;
    }
    expect(exitCode).toBe(0);
  });
});

// --- Act Integration Tests ---

describe("Act Integration Tests", () => {
  // Clear the result file before all tests
  beforeAll(async () => {
    await writeFile(ACT_RESULT_FILE, "PR Label Assigner - Act Test Results\n");
  });

  for (const fixture of TEST_FIXTURES) {
    test(
      `act: ${fixture.name}`,
      async () => {
        let tempDir: string | undefined;
        try {
          // Set up temp repo with this fixture
          tempDir = await setupTempRepo(fixture);

          // Run act
          const { output, exitCode } = runAct(tempDir);

          // Append output to act-result.txt
          await appendActResult(fixture.name, output);

          // Assert act exited with code 0
          expect(exitCode).toBe(0);

          // Assert "Job succeeded" appears
          // act uses different success messages; check for common patterns
          const hasSuccess =
            output.includes("Job succeeded") ||
            output.includes("✅  Job succeeded") ||
            output.includes("succeeded");
          expect(hasSuccess).toBe(true);

          // Parse the label result from output
          const result = extractLabelResult(output);
          expect(result).not.toBeNull();

          if (result) {
            // Assert exact expected labels (sorted for comparison)
            const actualLabels = [...result.labels].sort();
            const expectedLabels = [...fixture.expectedLabels].sort();
            expect(actualLabels).toEqual(expectedLabels);

            // Assert label-to-files mapping if specified
            if (fixture.expectedLabelToFiles) {
              for (const [label, expectedFiles] of Object.entries(
                fixture.expectedLabelToFiles
              )) {
                const actualFiles = result.labelToFiles[label];
                expect(actualFiles).toBeDefined();
                expect([...actualFiles].sort()).toEqual(
                  [...expectedFiles].sort()
                );
              }
            }
          }
        } finally {
          // Cleanup temp directory
          if (tempDir) {
            await rm(tempDir, { recursive: true, force: true });
          }
        }
      },
      { timeout: 300_000 } // 5 min per test
    );
  }
});
