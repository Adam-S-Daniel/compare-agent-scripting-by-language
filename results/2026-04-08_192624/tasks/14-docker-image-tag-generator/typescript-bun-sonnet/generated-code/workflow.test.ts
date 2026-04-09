/**
 * Workflow structure tests + Act integration tests
 *
 * Structure tests verify the YAML file has the expected shape.
 * Act tests spin up real Docker containers via `act push --rm`
 * and assert on exact expected tag values in the output.
 *
 * All output is appended to act-result.txt (required artifact).
 */

import { describe, test, expect } from "bun:test";
import {
  existsSync,
  readFileSync,
  mkdtempSync,
  mkdirSync,
  writeFileSync,
  appendFileSync,
  copyFileSync,
} from "fs";
import { join } from "path";
import { tmpdir } from "os";

// Resolve paths relative to this file's directory
const projectDir = import.meta.dir;
const workflowPath = join(
  projectDir,
  ".github",
  "workflows",
  "docker-image-tag-generator.yml"
);
const scriptPath = join(projectDir, "tag-generator.ts");
const actResultPath = join(projectDir, "act-result.txt");

// ============================================================
// Helper: run a shell command and capture output
// ============================================================

interface CmdResult {
  exitCode: number;
  stdout: string;
  stderr: string;
  combined: string;
}

async function runCmd(args: string[], cwd?: string): Promise<CmdResult> {
  const proc = Bun.spawn(args, {
    cwd,
    stdout: "pipe",
    stderr: "pipe",
  });

  const [stdout, stderr, exitCode] = await Promise.all([
    Bun.readableStreamToText(proc.stdout),
    Bun.readableStreamToText(proc.stderr),
    proc.exited,
  ]);

  return { exitCode, stdout, stderr, combined: stdout + stderr };
}

// ============================================================
// Workflow structure tests
// ============================================================

describe("Workflow structure", () => {
  test("workflow YAML file exists", () => {
    expect(existsSync(workflowPath)).toBe(true);
  });

  test("tag-generator.ts script exists", () => {
    expect(existsSync(scriptPath)).toBe(true);
  });

  test("workflow has 'push' trigger", () => {
    const content = readFileSync(workflowPath, "utf-8");
    expect(content).toContain("push:");
  });

  test("workflow has 'jobs' section", () => {
    const content = readFileSync(workflowPath, "utf-8");
    expect(content).toContain("jobs:");
  });

  test("workflow has 'steps' section", () => {
    const content = readFileSync(workflowPath, "utf-8");
    expect(content).toContain("steps:");
  });

  test("workflow uses actions/checkout@v4", () => {
    const content = readFileSync(workflowPath, "utf-8");
    expect(content).toContain("actions/checkout@v4");
  });

  test("workflow references tag-generator.ts", () => {
    const content = readFileSync(workflowPath, "utf-8");
    expect(content).toContain("tag-generator.ts");
  });

  test("workflow has permissions block", () => {
    const content = readFileSync(workflowPath, "utf-8");
    expect(content).toContain("permissions:");
  });

  test("actionlint passes with exit code 0", async () => {
    const result = await runCmd(["actionlint", workflowPath]);
    if (result.exitCode !== 0) {
      console.error("actionlint output:", result.combined);
    }
    expect(result.exitCode).toBe(0);
  });
});

// ============================================================
// Act integration tests
// ============================================================

/** Fixture data + expected output for one test case */
interface ActTestCase {
  name: string;
  fixture: {
    branch: string;
    commitSha: string;
    tags: string[];
    prNumber?: number;
  };
  expectedTags: string[]; // exact set expected in TAGS= output line
}

const testCases: ActTestCase[] = [
  {
    name: "main-branch",
    fixture: {
      branch: "main",
      commitSha: "abc1234def567890",
      tags: [],
    },
    // main -> latest + main-{short-sha}
    expectedTags: ["latest", "main-abc1234"],
  },
  {
    name: "pr-build",
    fixture: {
      branch: "feature/my-feature",
      commitSha: "abc1234def567890",
      tags: [],
      prNumber: 42,
    },
    // PR -> only pr-{number}
    expectedTags: ["pr-42"],
  },
  {
    name: "semver-tag",
    fixture: {
      branch: "main",
      commitSha: "abc1234def567890",
      tags: ["v1.2.3"],
    },
    // main + semver tag -> latest + main-sha + v1.2.3
    expectedTags: ["latest", "main-abc1234", "v1.2.3"],
  },
  {
    name: "feature-branch",
    fixture: {
      branch: "feature/my-feature",
      commitSha: "abc1234def567890",
      tags: [],
    },
    // feature branch -> {sanitized-branch}-{short-sha}
    expectedTags: ["feature-my-feature-abc1234"],
  },
  {
    name: "branch-sanitization",
    fixture: {
      branch: "Feature/My_Complex Branch!",
      commitSha: "abc1234def567890",
      tags: [],
    },
    expectedTags: ["feature-my-complex-branch-abc1234"],
  },
];

/**
 * Parse the TAGS= line from act's raw output.
 * Act prefixes step output with "[job-name] | " so we just search
 * for any line containing "TAGS=".
 */
function parseTagsFromOutput(output: string): string[] {
  // Strip ANSI color codes for cleaner parsing
  const clean = output.replace(/\x1b\[[0-9;]*m/g, "");
  const line = clean.split("\n").find((l) => l.includes("TAGS="));
  if (!line) return [];
  const match = line.match(/TAGS=(.+)$/);
  if (!match) return [];
  return match[1]
    .trim()
    .split(",")
    .map((t) => t.trim())
    .filter(Boolean);
}

/**
 * Set up a temporary git repository containing the project files
 * plus the test-case-specific fixture, then run act push --rm.
 */
async function runActTestCase(tc: ActTestCase): Promise<CmdResult> {
  const tempDir = mkdtempSync(join(tmpdir(), `dktag-${tc.name}-`));

  // — copy project files into temp repo —
  copyFileSync(scriptPath, join(tempDir, "tag-generator.ts"));

  mkdirSync(join(tempDir, ".github", "workflows"), { recursive: true });
  copyFileSync(
    workflowPath,
    join(tempDir, ".github", "workflows", "docker-image-tag-generator.yml")
  );

  // — write fixture file (read by tag-generator.ts at runtime) —
  mkdirSync(join(tempDir, "fixtures"), { recursive: true });
  writeFileSync(
    join(tempDir, "fixtures", "test-input.json"),
    JSON.stringify(tc.fixture, null, 2),
    "utf-8"
  );

  // — initialise git repo and commit everything —
  const gitEnv = {
    ...process.env,
    GIT_AUTHOR_EMAIL: "test@example.com",
    GIT_AUTHOR_NAME: "Test User",
    GIT_COMMITTER_EMAIL: "test@example.com",
    GIT_COMMITTER_NAME: "Test User",
  } as Record<string, string>;

  for (const cmd of [
    ["git", "init"],
    ["git", "config", "user.email", "test@example.com"],
    ["git", "config", "user.name", "Test User"],
    ["git", "add", "-A"],
    ["git", "commit", "-m", "test: add project files"],
  ]) {
    const r = await runCmd(cmd, tempDir);
    if (r.exitCode !== 0 && !cmd.includes("init")) {
      throw new Error(
        `git setup failed for ${tc.name}: ${cmd.join(" ")}\n${r.combined}`
      );
    }
  }

  // — run act push --rm with the pre-pulled image —
  const result = await runCmd(
    [
      "act",
      "push",
      "--rm",
      "-P",
      "ubuntu-latest=catthehacker/ubuntu:act-latest",
    ],
    tempDir
  );

  return result;
}

// Write a header to act-result.txt once before all act tests run.
// Individual tests append their sections.
{
  const header =
    `${"=".repeat(70)}\n` +
    `ACT INTEGRATION TEST RESULTS\n` +
    `Run date: ${new Date().toISOString()}\n` +
    `${"=".repeat(70)}\n`;
  writeFileSync(actResultPath, header, "utf-8");
}

describe("Act integration tests", () => {
  for (const tc of testCases) {
    test(
      `act: ${tc.name}`,
      async () => {
        const delimiter =
          `\n${"─".repeat(70)}\n` +
          `TEST CASE: ${tc.name}\n` +
          `FIXTURE: ${JSON.stringify(tc.fixture)}\n` +
          `EXPECTED TAGS: ${tc.expectedTags.join(", ")}\n` +
          `${"─".repeat(70)}\n`;

        let result: CmdResult;
        try {
          result = await runActTestCase(tc);
        } catch (err) {
          const msg = `SETUP ERROR: ${err}\n`;
          appendFileSync(actResultPath, delimiter + msg, "utf-8");
          throw err;
        }

        // Append full act output to the artifact file
        appendFileSync(
          actResultPath,
          delimiter + result.combined + "\n",
          "utf-8"
        );

        // 1. act must exit with code 0
        if (result.exitCode !== 0) {
          console.error(`act output for ${tc.name}:\n${result.combined}`);
        }
        expect(result.exitCode).toBe(0);

        // 2. Every job must show "Job succeeded"
        expect(result.combined).toContain("Job succeeded");

        // 3. Parse and assert exact expected tag values
        const actualTags = parseTagsFromOutput(result.combined);

        if (actualTags.length === 0) {
          console.error(
            `No TAGS= line found in output for ${tc.name}:\n${result.combined}`
          );
        }

        // Assert each expected tag is present
        for (const expected of tc.expectedTags) {
          expect(actualTags).toContain(expected);
        }

        // Assert no extra unexpected tags
        expect(actualTags.length).toBe(tc.expectedTags.length);
      },
      5 * 60 * 1000 // 5-minute timeout per act test case
    );
  }
});
