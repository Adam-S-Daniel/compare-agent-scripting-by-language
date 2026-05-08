// Workflow structure tests + act execution tests.
// These tests verify the GitHub Actions workflow file:
//   1. Has correct YAML structure (triggers, jobs, steps)
//   2. References existing script files
//   3. Passes actionlint validation
//   4. Runs successfully via `act push --rm` and produces expected output
//
// NOTE: The act test has a long timeout (3 minutes) because container startup
// + workflow execution takes 30-90 seconds.
// The act tests only run the unit tests (validator + formatter) inside the
// container to avoid recursive act invocation.

import { describe, it, expect, test } from "bun:test";
import { spawnSync } from "child_process";
import { existsSync, readFileSync, appendFileSync, mkdtempSync, rmSync, cpSync } from "fs";
import { join } from "path";
import { tmpdir } from "os";

const PROJECT_DIR = process.cwd();
const WORKFLOW_FILE = ".github/workflows/secret-rotation-validator.yml";
const WORKFLOW_PATH = join(PROJECT_DIR, WORKFLOW_FILE);
const ACT_RESULT_PATH = join(PROJECT_DIR, "act-result.txt");

// ─── Workflow Structure Tests ────────────────────────────────────────────────

describe("workflow structure", () => {
  it("workflow file exists", () => {
    expect(existsSync(WORKFLOW_PATH)).toBe(true);
  });

  it("workflow triggers on push", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf8");
    expect(content).toContain("push:");
  });

  it("workflow triggers on pull_request", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf8");
    expect(content).toContain("pull_request:");
  });

  it("workflow triggers on workflow_dispatch", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf8");
    expect(content).toContain("workflow_dispatch:");
  });

  it("workflow uses actions/checkout", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf8");
    expect(content).toContain("actions/checkout");
  });

  it("workflow installs Bun", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf8");
    // Either via action or curl
    expect(content.toLowerCase()).toContain("bun");
  });

  it("workflow runs the validator script", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf8");
    expect(content).toContain("index.ts");
  });

  it("workflow references the fixtures file", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf8");
    expect(content).toContain("secrets.json");
  });

  it("script file exists", () => {
    expect(existsSync(join(PROJECT_DIR, "src/index.ts"))).toBe(true);
  });

  it("fixtures file exists", () => {
    expect(existsSync(join(PROJECT_DIR, "fixtures/secrets.json"))).toBe(true);
  });

  it("passes actionlint validation", () => {
    const result = spawnSync("actionlint", [WORKFLOW_PATH], {
      encoding: "utf8",
    });
    if (result.status !== 0) {
      console.error("actionlint output:", result.stdout, result.stderr);
    }
    expect(result.status).toBe(0);
  });
});

// ─── Act Execution Test ───────────────────────────────────────────────────────

// Copies project files to a fresh temp git repo, runs act push, captures output,
// appends it to act-result.txt, and asserts on exact expected values.
function runActTest(label: string, fixtureOverride?: object): string {
  const tmpDir = mkdtempSync(join(tmpdir(), "secret-rotation-act-"));

  try {
    // Copy project files (skip .git to avoid nested repo corruption)
    cpSync(PROJECT_DIR, tmpDir, {
      recursive: true,
      filter: (src) => !src.includes("/.git/") && !src.endsWith("/.git"),
    });

    // Write custom fixture if provided
    if (fixtureOverride) {
      const fixturePath = join(tmpDir, "fixtures/secrets.json");
      Bun.write(fixturePath, JSON.stringify(fixtureOverride, null, 2));
    }

    // Copy .actrc so act uses the correct container image
    if (existsSync(join(PROJECT_DIR, ".actrc"))) {
      cpSync(join(PROJECT_DIR, ".actrc"), join(tmpDir, ".actrc"));
    }

    // Initialize git repo and commit all files
    const gitInit = spawnSync(
      "bash",
      [
        "-c",
        [
          `cd "${tmpDir}"`,
          "git init",
          'git config user.email "test@example.com"',
          'git config user.name "Test"',
          "git add -A",
          'git commit -m "test: run secret rotation validator"',
        ].join(" && "),
      ],
      { encoding: "utf8", timeout: 30000 }
    );

    if (gitInit.status !== 0) {
      throw new Error(`git init failed: ${gitInit.stderr}`);
    }

    // Run act push with output capture.
    // --pull=false: act-ubuntu-pwsh:latest is a local-only image, skip remote pull
    const actResult = spawnSync(
      "bash",
      ["-c", `cd "${tmpDir}" && act push --rm --pull=false 2>&1`],
      { encoding: "utf8", timeout: 180000, maxBuffer: 20 * 1024 * 1024 }
    );

    const output = actResult.stdout ?? "";

    // Append to act-result.txt
    const delimiter = `\n${"=".repeat(60)}\nACT TEST CASE: ${label}\n${"=".repeat(60)}\n`;
    appendFileSync(ACT_RESULT_PATH, delimiter + output + "\n");

    return output;
  } finally {
    rmSync(tmpDir, { recursive: true, force: true });
  }
}

test(
  "act: workflow runs successfully with mixed urgency secrets",
  () => {
    const output = runActTest("mixed urgency secrets (expired + warning + ok)");

    // Job must succeed
    expect(output).toContain("Job succeeded");

    // All three secrets must appear in the output
    expect(output).toContain("EXPIRED_SECRET");
    expect(output).toContain("WARNING_SECRET");
    expect(output).toContain("OK_SECRET");

    // Urgency keywords must appear
    expect(output).toContain("expired");
    expect(output).toContain("warning");

    // Exact computed values must be present
    expect(output).toContain("-10"); // daysUntilExpiry for EXPIRED_SECRET
    expect(output).toContain("| 5 |"); // daysUntilExpiry for WARNING_SECRET
  },
  180000 // 3 minute timeout
);

test(
  "act: workflow produces JSON output with correct structure",
  () => {
    const output = runActTest("JSON format output verification");

    expect(output).toContain("Job succeeded");

    // JSON summary fields must appear in the act output
    expect(output).toContain('"expiredCount": 1');
    expect(output).toContain('"warningCount": 1');
    expect(output).toContain('"okCount": 1');

    // Exact urgency values in JSON
    expect(output).toContain('"urgency": "expired"');
    expect(output).toContain('"urgency": "warning"');
    expect(output).toContain('"urgency": "ok"');
  },
  180000
);
