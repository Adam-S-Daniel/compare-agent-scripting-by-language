// Workflow tests: verify YAML structure, actionlint, and full act execution.
// The act test is gated by SKIP_ACT_TESTS=true so CI doesn't recurse into Docker.

import { describe, it, expect } from "bun:test";
import { spawnSync } from "child_process";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";

const PROJECT_ROOT = path.resolve(import.meta.dir, "..");
const WORKFLOW_PATH = path.join(PROJECT_ROOT, ".github/workflows/test-results-aggregator.yml");
const ACT_RESULT_FILE = path.join(PROJECT_ROOT, "act-result.txt");
const SKIP_ACT = process.env.SKIP_ACT_TESTS === "true";

// ---------------------------------------------------------------------------
// Workflow structure tests (fast, always run)
// ---------------------------------------------------------------------------

describe("Workflow structure", () => {
  it("workflow YAML file exists", () => {
    expect(fs.existsSync(WORKFLOW_PATH)).toBe(true);
  });

  it("aggregator.ts script exists", () => {
    expect(fs.existsSync(path.join(PROJECT_ROOT, "aggregator.ts"))).toBe(true);
  });

  it("fixtures directory exists", () => {
    expect(fs.existsSync(path.join(PROJECT_ROOT, "fixtures"))).toBe(true);
  });

  it("fixture run1/results.xml exists", () => {
    expect(fs.existsSync(path.join(PROJECT_ROOT, "fixtures/run1/results.xml"))).toBe(true);
  });

  it("fixture run2/results.xml exists", () => {
    expect(fs.existsSync(path.join(PROJECT_ROOT, "fixtures/run2/results.xml"))).toBe(true);
  });

  it("fixture run3/results.json exists", () => {
    expect(fs.existsSync(path.join(PROJECT_ROOT, "fixtures/run3/results.json"))).toBe(true);
  });

  it("workflow has push trigger", () => {
    const content = fs.readFileSync(WORKFLOW_PATH, "utf8");
    expect(content).toContain("push:");
  });

  it("workflow has pull_request trigger", () => {
    const content = fs.readFileSync(WORKFLOW_PATH, "utf8");
    expect(content).toContain("pull_request:");
  });

  it("workflow has workflow_dispatch trigger", () => {
    const content = fs.readFileSync(WORKFLOW_PATH, "utf8");
    expect(content).toContain("workflow_dispatch:");
  });

  it("workflow has schedule trigger", () => {
    const content = fs.readFileSync(WORKFLOW_PATH, "utf8");
    expect(content).toContain("schedule:");
    expect(content).toContain("cron:");
  });

  it("workflow uses actions/checkout@v4", () => {
    const content = fs.readFileSync(WORKFLOW_PATH, "utf8");
    expect(content).toContain("actions/checkout@v4");
  });

  it("workflow uses oven-sh/setup-bun", () => {
    const content = fs.readFileSync(WORKFLOW_PATH, "utf8");
    expect(content).toContain("oven-sh/setup-bun");
  });

  it("workflow runs bun test", () => {
    const content = fs.readFileSync(WORKFLOW_PATH, "utf8");
    expect(content).toContain("bun test");
  });

  it("workflow runs aggregator.ts on fixtures/", () => {
    const content = fs.readFileSync(WORKFLOW_PATH, "utf8");
    expect(content).toContain("aggregator.ts fixtures/");
  });
});

// ---------------------------------------------------------------------------
// Actionlint validation (fast, always run)
// ---------------------------------------------------------------------------

describe("Actionlint validation", () => {
  it("passes actionlint with exit code 0", () => {
    const result = spawnSync("actionlint", [WORKFLOW_PATH], { encoding: "utf8" });
    if (result.status !== 0) {
      console.error("actionlint output:", result.stdout, result.stderr);
    }
    expect(result.status).toBe(0);
  });
});

// ---------------------------------------------------------------------------
// Act integration test (slow ~60s, skipped in CI to avoid recursion)
// ---------------------------------------------------------------------------

describe("Act workflow execution", () => {
  it.skipIf(SKIP_ACT)(
    "runs the full workflow via act and produces exact expected values",
    async () => {
      // 1. Create an isolated temp git repo with all project files
      const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "test-results-aggregator-"));

      try {
        // Copy everything including .actrc (needed for custom Docker image mapping)
        const cpResult = spawnSync("cp", ["-r", `${PROJECT_ROOT}/.`, tmpDir], {
          encoding: "utf8",
        });
        if (cpResult.status !== 0) {
          throw new Error(`cp failed: ${cpResult.stderr}`);
        }

        // Initialise git repo (act requires a valid git repo)
        const gitCmds = [
          "git init",
          'git config user.email "test@test.com"',
          'git config user.name "Test User"',
          "git add -A",
          'git commit -m "test: initial commit"',
        ];
        for (const cmd of gitCmds) {
          const r = spawnSync("bash", ["-c", cmd], { cwd: tmpDir, encoding: "utf8" });
          if (r.status !== 0) {
            throw new Error(`Git command failed: ${cmd}\n${r.stderr}`);
          }
        }

        // 2. Run act push --rm --pull=false (image is local, don't pull from Docker Hub)
        const actResult = spawnSync("act", ["push", "--rm", "--pull=false"], {
          cwd: tmpDir,
          timeout: 180_000, // 3-minute cap
          encoding: "utf8",
        });

        const output = (actResult.stdout ?? "") + "\n" + (actResult.stderr ?? "");

        // 3. Append output to act-result.txt (required artifact)
        const sep = "=".repeat(60);
        const entry = [
          sep,
          "=== Test Case: Full Workflow Run ===",
          sep,
          output,
          sep,
          "=== End of Test Case ===",
          sep,
          "",
          "",
        ].join("\n");
        fs.appendFileSync(ACT_RESULT_FILE, entry);

        // 4. Assert act succeeded
        if (actResult.status !== 0) {
          console.error("act output (last 2000 chars):", output.slice(-2000));
        }
        expect(actResult.status).toBe(0);
        expect(output).toContain("Job succeeded");

        // 5. Assert EXACT expected values in aggregator output
        expect(output).toContain("| Total Tests | 8 |");
        expect(output).toContain("| Passed | 6 |");
        expect(output).toContain("| Failed | 1 |");
        expect(output).toContain("| Skipped | 1 |");
        expect(output).toContain("| Duration | 4.30s |");
        // Flaky test detection
        expect(output).toContain("test-add");
        // Suite rows
        expect(output).toContain("| MathOperations |");
        expect(output).toContain("| StringOperations |");
      } finally {
        fs.rmSync(tmpDir, { recursive: true, force: true });
      }
    },
    180_000 // Bun test-level timeout: 3 minutes
  );
});
