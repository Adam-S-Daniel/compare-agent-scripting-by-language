/**
 * Act-Based Integration Test Harness
 *
 * Runs on the HOST (not inside Docker/act). Calls `act push --rm` for each
 * test case, captures stdout/stderr to act-result.txt, and asserts exact
 * expected values from the workflow output.
 *
 * Skipped automatically when running inside CI (GITHUB_ACTIONS=true or ACT=true)
 * because nested Docker/act execution is not supported.
 *
 * Test cases:
 *   1. Workflow structure validation (YAML content checks, file existence)
 *   2. actionlint passes on the workflow file
 *   3. Unit tests pass inside the workflow (28 tests)
 *   4. Mixed secrets fixture: expired + warning + ok labels appear
 *   5. All-ok fixture: "All secrets are within their rotation policy" message
 *   6. Expired fixture: "require immediate rotation" warning appears
 */

import { describe, it, expect, beforeAll } from "bun:test";
import { spawnSync } from "child_process";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";

// ─── Configuration ────────────────────────────────────────────────────────────

const WORKSPACE = path.resolve(__dirname, "..");
const WORKFLOW_PATH = path.join(WORKSPACE, ".github/workflows/secret-rotation-validator.yml");
const ACT_RESULT_PATH = path.join(WORKSPACE, "act-result.txt");

// Skip all act tests when running inside CI/Docker
const IN_CI = !!(process.env.GITHUB_ACTIONS || process.env.ACT);

// ─── Helpers ──────────────────────────────────────────────────────────────────

/** Append a delimited block to act-result.txt */
function appendActResult(label: string, output: string, exitCode: number): void {
  const block = [
    `\n${"=".repeat(80)}`,
    `TEST CASE: ${label}`,
    `EXIT CODE: ${exitCode}`,
    `TIMESTAMP: ${new Date().toISOString()}`,
    `${"=".repeat(80)}`,
    output,
    `${"=".repeat(80)}\n`,
  ].join("\n");
  fs.appendFileSync(ACT_RESULT_PATH, block, "utf8");
}

/**
 * Run `act push --rm` in a temporary git repo containing the project files.
 * Each test case gets an isolated temp dir to avoid state leakage.
 *
 * @param label - Human-readable test case name (used in act-result.txt)
 * @param fixtureFile - Optional fixture file path (relative to workspace root)
 * @returns { stdout: combined output, exitCode }
 */
function runActInTempRepo(
  label: string,
  fixtureFile?: string
): { stdout: string; exitCode: number } {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "secret-rotation-"));

  try {
    // Sync workspace (excluding .git, node_modules, act-result.txt)
    const rsync = spawnSync(
      "rsync",
      [
        "-a",
        "--exclude=.git",
        "--exclude=node_modules",
        "--exclude=act-result.txt",
        `${WORKSPACE}/`,
        `${tmpDir}/`,
      ],
      { encoding: "utf8" }
    );
    if (rsync.status !== 0) {
      throw new Error(`rsync failed: ${rsync.stderr}`);
    }

    // Initialise a bare git repo so act's git detection works
    spawnSync("git", ["init"], { cwd: tmpDir, encoding: "utf8" });
    spawnSync("git", ["config", "user.email", "test@ci.example.com"], {
      cwd: tmpDir,
      encoding: "utf8",
    });
    spawnSync("git", ["config", "user.name", "CI Test"], {
      cwd: tmpDir,
      encoding: "utf8",
    });
    spawnSync("git", ["add", "-A"], { cwd: tmpDir, encoding: "utf8" });
    spawnSync("git", ["commit", "-m", "chore: test fixture"], {
      cwd: tmpDir,
      encoding: "utf8",
    });

    // Build act arguments
    const actArgs = [
      "push",
      "--rm",
      "--no-cache-server",
      "-P",
      "ubuntu-latest=ghcr.io/catthehacker/ubuntu:act-latest",
    ];

    if (fixtureFile) {
      actArgs.push("--env", `FIXTURE_FILE=${fixtureFile}`);
    }

    const result = spawnSync("act", actArgs, {
      cwd: tmpDir,
      encoding: "utf8",
      timeout: 300_000,
      maxBuffer: 50 * 1024 * 1024,
    });

    const combined = (result.stdout ?? "") + (result.stderr ?? "");
    const exitCode = result.status ?? 1;

    appendActResult(label, combined, exitCode);
    return { stdout: combined, exitCode };
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
}

// ─── Workflow Structure Tests (no act, always run) ────────────────────────────

describe("Workflow structure validation", () => {
  it("workflow file exists at the expected path", () => {
    expect(fs.existsSync(WORKFLOW_PATH)).toBe(true);
  });

  it("workflow has correct triggers (push, pull_request, schedule, workflow_dispatch)", () => {
    const content = fs.readFileSync(WORKFLOW_PATH, "utf8");
    expect(content).toContain("push:");
    expect(content).toContain("pull_request:");
    expect(content).toContain("schedule:");
    expect(content).toContain("workflow_dispatch:");
  });

  it("workflow defines the validate-secrets job", () => {
    const content = fs.readFileSync(WORKFLOW_PATH, "utf8");
    expect(content).toContain("validate-secrets:");
  });

  it("workflow uses actions/checkout@v4", () => {
    const content = fs.readFileSync(WORKFLOW_PATH, "utf8");
    expect(content).toContain("actions/checkout@v4");
  });

  it("workflow uses oven-sh/setup-bun@v2", () => {
    const content = fs.readFileSync(WORKFLOW_PATH, "utf8");
    expect(content).toContain("oven-sh/setup-bun@v2");
  });

  it("workflow references bun test", () => {
    const content = fs.readFileSync(WORKFLOW_PATH, "utf8");
    expect(content).toContain("bun test");
  });

  it("workflow references src/index.ts", () => {
    const content = fs.readFileSync(WORKFLOW_PATH, "utf8");
    expect(content).toContain("src/index.ts");
  });

  it("src/index.ts exists", () => {
    expect(fs.existsSync(path.join(WORKSPACE, "src/index.ts"))).toBe(true);
  });

  it("src/rotation-validator.ts exists", () => {
    expect(fs.existsSync(path.join(WORKSPACE, "src/rotation-validator.ts"))).toBe(true);
  });

  it("src/types.ts exists", () => {
    expect(fs.existsSync(path.join(WORKSPACE, "src/types.ts"))).toBe(true);
  });

  it("fixtures/secrets-mixed.json exists", () => {
    expect(fs.existsSync(path.join(WORKSPACE, "fixtures/secrets-mixed.json"))).toBe(true);
  });

  it("fixtures/secrets-all-ok.json exists", () => {
    expect(fs.existsSync(path.join(WORKSPACE, "fixtures/secrets-all-ok.json"))).toBe(true);
  });

  it("fixtures/secrets-with-expired.json exists", () => {
    expect(
      fs.existsSync(path.join(WORKSPACE, "fixtures/secrets-with-expired.json"))
    ).toBe(true);
  });
});

// ─── actionlint Validation (no act, always run) ───────────────────────────────

describe("actionlint validation", () => {
  it("actionlint exits with code 0", () => {
    const result = spawnSync("actionlint", [WORKFLOW_PATH], { encoding: "utf8" });
    const output = (result.stdout ?? "") + (result.stderr ?? "");
    appendActResult("actionlint", output, result.status ?? 1);
    expect(result.status).toBe(0);
  });
});

// ─── Act Integration Tests (host-only, skip inside CI) ───────────────────────

describe("act integration: unit tests in CI", () => {
  it("bun test passes inside the workflow (28 tests passing)", () => {
    if (IN_CI) {
      console.log("Skipping act test — nested Docker not supported in CI");
      return;
    }

    const { stdout, exitCode } = runActInTempRepo("act: unit tests");

    // All workflow jobs succeed
    expect(stdout).toContain("Job succeeded");
    expect(exitCode).toBe(0);

    // Exactly 28 unit tests pass inside the container
    expect(stdout).toMatch(/28 pass/);
    // Only check for non-zero failures (bun outputs " 0 fail" which is acceptable)
    expect(stdout).not.toMatch(/[1-9]\d* fail/);
  });
}, 300_000);

describe("act integration: mixed fixture (expired + warning + ok)", () => {
  it("report contains EXPIRED, WARNING, and OK labels, and correct secret names", () => {
    if (IN_CI) {
      console.log("Skipping act test — nested Docker not supported in CI");
      return;
    }

    const { stdout, exitCode } = runActInTempRepo(
      "act: mixed fixture",
      "fixtures/secrets-mixed.json"
    );

    expect(exitCode).toBe(0);
    expect(stdout).toContain("Job succeeded");

    // Urgency labels from the markdown report
    expect(stdout).toContain("EXPIRED");
    expect(stdout).toContain("WARNING");
    expect(stdout).toContain("OK");

    // Exact secret names
    expect(stdout).toContain("DB_PASSWORD");
    expect(stdout).toContain("API_KEY");
    expect(stdout).toContain("JWT_SECRET");
  });
}, 300_000);

describe("act integration: all-ok fixture", () => {
  it("reports all secrets OK and no expired warning message", () => {
    if (IN_CI) {
      console.log("Skipping act test — nested Docker not supported in CI");
      return;
    }

    const { stdout, exitCode } = runActInTempRepo(
      "act: all-ok fixture",
      "fixtures/secrets-all-ok.json"
    );

    expect(exitCode).toBe(0);
    expect(stdout).toContain("Job succeeded");
    // Exact string from src/index.ts "Check for expired secrets" step
    expect(stdout).toContain("All secrets are within their rotation policy");
    // Must NOT see the expiry warning
    expect(stdout).not.toContain("require immediate rotation");
  });
}, 300_000);

describe("act integration: expired secrets fixture", () => {
  it("reports expired count > 0 with immediate-rotation warning", () => {
    if (IN_CI) {
      console.log("Skipping act test — nested Docker not supported in CI");
      return;
    }

    const { stdout, exitCode } = runActInTempRepo(
      "act: expired fixture",
      "fixtures/secrets-with-expired.json"
    );

    // Workflow uses `|| true` so it still exits 0 even with expired secrets
    expect(exitCode).toBe(0);
    expect(stdout).toContain("Job succeeded");

    // Exact warning string from Check-for-expired-secrets step
    expect(stdout).toContain("require immediate rotation");
    // The expired secret name must appear in the report
    expect(stdout).toContain("DB_PASSWORD");
  });
}, 300_000);
