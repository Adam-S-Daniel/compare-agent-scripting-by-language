/**
 * Docker Image Tag Generator — Full Test Suite
 *
 * TDD approach: every test case exercises the generator through the GitHub
 * Actions workflow via `act`. Each test:
 *   1. Creates a temp git repo with the project files + fixture data
 *   2. Runs `act push --rm` and captures output
 *   3. Asserts act exits 0 and the output contains the exact expected tags
 *   4. All output is appended to act-result.txt
 *
 * Also includes workflow-structure tests (YAML parsing, actionlint, file refs).
 */

import { describe, test, expect, beforeAll, afterAll } from "bun:test";
import { mkdtemp, rm, readFile, writeFile, cp, mkdir } from "fs/promises";
import { tmpdir } from "os";
import { join } from "path";
import { parse as yamlParse } from "./yaml-parser.ts";

// Path to the real project directory
const PROJECT_DIR = import.meta.dir;
const ACT_RESULT_FILE = join(PROJECT_DIR, "act-result.txt");

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Run a shell command and return { stdout, stderr, exitCode }. */
async function run(
  cmd: string[],
  opts: { cwd?: string; env?: Record<string, string> } = {}
): Promise<{ stdout: string; stderr: string; exitCode: number }> {
  const proc = Bun.spawn(cmd, {
    cwd: opts.cwd ?? PROJECT_DIR,
    env: { ...process.env, ...opts.env },
    stdout: "pipe",
    stderr: "pipe",
  });
  const [stdout, stderr] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
  ]);
  const exitCode = await proc.exited;
  return { stdout, stderr, exitCode };
}

/** Append text to act-result.txt. */
async function appendResult(text: string): Promise<void> {
  const existing = await readFile(ACT_RESULT_FILE, "utf-8").catch(() => "");
  await writeFile(ACT_RESULT_FILE, existing + text + "\n");
}

// Test fixture interface
interface TestFixture {
  name: string;
  branch: string;
  commit: string;
  tag: string;
  pr: string;
  expectedTags: string;  // comma-separated expected TAGS= value
}

// All test fixtures exercised through act
const fixtures: TestFixture[] = [
  {
    name: "main-branch",
    branch: "main",
    commit: "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0",
    tag: "",
    pr: "",
    expectedTags: "latest,main-a1b2c3d",
  },
  {
    name: "feature-branch",
    branch: "feature/awesome-widget",
    commit: "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef",
    tag: "",
    pr: "",
    expectedTags: "feature-awesome-widget-deadbee",
  },
  {
    name: "pr-event",
    branch: "fix/login-bug",
    commit: "1234567890abcdef1234567890abcdef12345678",
    tag: "",
    pr: "42",
    expectedTags: "pr-42,fix-login-bug-1234567",
  },
  {
    name: "semver-tag-on-main",
    branch: "main",
    commit: "fedcba9876543210fedcba9876543210fedcba98",
    tag: "v1.2.3",
    pr: "",
    expectedTags: "v1.2.3,latest,main-fedcba9",
  },
  {
    name: "semver-tag-on-release",
    branch: "release/v2.0.0",
    commit: "abcdef1234567890abcdef1234567890abcdef12",
    tag: "v2.0.0",
    pr: "",
    expectedTags: "v2.0.0,release-v2.0.0-abcdef1",
  },
  {
    name: "uppercase-branch",
    branch: "Feature/CAPS-Test",
    commit: "aabbccddee1122334455aabbccddee1122334455",
    tag: "",
    pr: "",
    expectedTags: "feature-caps-test-aabbccd",
  },
  {
    name: "special-chars-branch",
    branch: "feat/hello@world#2!",
    commit: "ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00",
    tag: "",
    pr: "",
    expectedTags: "feat-hello-world-2-ff00ff0",
  },
  {
    name: "master-branch",
    branch: "master",
    commit: "0000000000000000000000000000000000000000",
    tag: "",
    pr: "",
    expectedTags: "latest,master-0000000",
  },
];

/**
 * Create a temp git repo containing the project files, with a workflow
 * that runs only the specific test-tags matrix entry for `fixture`.
 */
async function setupTempRepo(fixture: TestFixture): Promise<string> {
  const tempDir = await mkdtemp(join(tmpdir(), "tag-gen-test-"));

  // Copy project files
  await cp(join(PROJECT_DIR, "generate-tags.ts"), join(tempDir, "generate-tags.ts"));

  // Create a single-entry workflow for this fixture (no matrix — simpler act invocation)
  const workflowDir = join(tempDir, ".github", "workflows");
  await mkdir(workflowDir, { recursive: true });

  const workflow = `name: Test ${fixture.name}

on: [push]

permissions:
  contents: read

jobs:
  test-tags:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Bun
        uses: oven-sh/setup-bun@v2
        with:
          bun-version: latest

      - name: "Run test: ${fixture.name}"
        shell: bash
        env:
          GIT_BRANCH: "${fixture.branch}"
          GIT_COMMIT: "${fixture.commit}"
          GIT_TAG: "${fixture.tag}"
          PR_NUMBER: "${fixture.pr}"
        run: |
          echo "=== Test: ${fixture.name} ==="
          OUTPUT=$(bun run generate-tags.ts)
          echo "$OUTPUT"

          ACTUAL=$(echo "$OUTPUT" | grep '^TAGS=' | cut -d= -f2)
          EXPECTED="${fixture.expectedTags}"

          echo "Expected: \${EXPECTED}"
          echo "Actual:   \${ACTUAL}"

          if [ "\$ACTUAL" = "\$EXPECTED" ]; then
            echo "PASS: ${fixture.name}"
          else
            echo "FAIL: ${fixture.name} — expected '\${EXPECTED}' but got '\${ACTUAL}'"
            exit 1
          fi
`;

  await writeFile(join(workflowDir, "test.yml"), workflow);

  // Initialise git repo (act requires it)
  await run(["git", "init"], { cwd: tempDir });
  await run(["git", "config", "user.email", "test@test.com"], { cwd: tempDir });
  await run(["git", "config", "user.name", "Test"], { cwd: tempDir });
  await run(["git", "add", "."], { cwd: tempDir });
  await run(["git", "commit", "-m", "init"], { cwd: tempDir });

  return tempDir;
}

// ---------------------------------------------------------------------------
// Workflow structure tests
// ---------------------------------------------------------------------------

describe("Workflow structure tests", () => {
  let workflowContent: string;
  let workflowYaml: any;

  beforeAll(async () => {
    const wfPath = join(PROJECT_DIR, ".github", "workflows", "docker-image-tag-generator.yml");
    workflowContent = await readFile(wfPath, "utf-8");
    workflowYaml = yamlParse(workflowContent);
  });

  test("actionlint passes with exit code 0", async () => {
    const wfPath = join(PROJECT_DIR, ".github", "workflows", "docker-image-tag-generator.yml");
    const result = await run(["actionlint", wfPath]);
    await appendResult(`=== actionlint ===\nExit code: ${result.exitCode}\n${result.stdout}\n${result.stderr}\n`);
    expect(result.exitCode).toBe(0);
  });

  test("workflow has correct trigger events", () => {
    const triggers = workflowYaml["on"] ?? workflowYaml[true];
    expect(triggers).toBeDefined();
    // Check push and pull_request triggers exist
    expect(triggers.push).toBeDefined();
    expect(triggers.pull_request).toBeDefined();
    expect(triggers.workflow_dispatch).toBeDefined();
  });

  test("workflow has generate-tags and test-tags jobs", () => {
    expect(workflowYaml.jobs).toBeDefined();
    expect(workflowYaml.jobs["generate-tags"]).toBeDefined();
    expect(workflowYaml.jobs["test-tags"]).toBeDefined();
  });

  test("workflow references generate-tags.ts (file exists)", async () => {
    // Check that the workflow references the script
    expect(workflowContent).toContain("generate-tags.ts");
    // Check that the referenced file actually exists
    const file = Bun.file(join(PROJECT_DIR, "generate-tags.ts"));
    expect(await file.exists()).toBe(true);
  });

  test("checkout step uses actions/checkout@v4", () => {
    expect(workflowContent).toContain("actions/checkout@v4");
  });

  test("bun setup step uses oven-sh/setup-bun@v2", () => {
    expect(workflowContent).toContain("oven-sh/setup-bun@v2");
  });

  test("test-tags job has 8 matrix entries", () => {
    const testJob = workflowYaml.jobs["test-tags"];
    const includes = testJob.strategy?.matrix?.include;
    expect(includes).toBeDefined();
    expect(includes.length).toBe(8);
  });
});

// ---------------------------------------------------------------------------
// Act integration tests — one per fixture
// ---------------------------------------------------------------------------

describe("Act integration tests", () => {
  // Clear act-result.txt before running
  beforeAll(async () => {
    await writeFile(ACT_RESULT_FILE, "");
  });

  for (const fixture of fixtures) {
    test(`act: ${fixture.name}`, async () => {
      let tempDir: string | undefined;
      try {
        tempDir = await setupTempRepo(fixture);

        const result = await run(
          [
            "act", "push",
            "--rm",
            "-P", "ubuntu-latest=catthehacker/ubuntu:act-latest",
            "--defaultbranch", "main",
          ],
          { cwd: tempDir }
        );

        const combinedOutput = result.stdout + "\n" + result.stderr;

        // Append to act-result.txt
        await appendResult(
          `${"=".repeat(60)}\n` +
          `Test: ${fixture.name}\n` +
          `${"=".repeat(60)}\n` +
          `Exit code: ${result.exitCode}\n` +
          combinedOutput
        );

        // Assert act exited successfully
        // Assert act exited with code 0
        if (result.exitCode !== 0) {
          throw new Error(`act failed for ${fixture.name} (exit code ${result.exitCode}):\n${combinedOutput.slice(-2000)}`);
        }
        expect(result.exitCode).toBe(0);

        // Assert "Job succeeded" appears in output
        expect(combinedOutput).toContain("Job succeeded");

        // Assert exact expected tags appear in TAGS= output
        expect(combinedOutput).toContain(`TAGS=${fixture.expectedTags}`);

        // Assert PASS marker
        expect(combinedOutput).toContain(`PASS: ${fixture.name}`);

      } finally {
        if (tempDir) {
          await rm(tempDir, { recursive: true, force: true });
        }
      }
    }, 180_000); // 3 minute timeout per test — act can be slow
  }
});
