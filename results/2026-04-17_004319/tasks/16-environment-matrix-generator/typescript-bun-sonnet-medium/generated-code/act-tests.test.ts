// Act integration tests: run the full workflow through nektos/act and
// assert on exact expected values in the output.
//
// Saves all act output to act-result.txt in the current working directory.
// Limit: at most 1 act push run (diagnose from output, don't re-run blindly).

import { describe, it, expect, beforeAll, afterAll } from "bun:test";
import { mkdirSync, cpSync, writeFileSync, appendFileSync, existsSync } from "fs";
import { spawnSync } from "child_process";
import { join } from "path";

const PROJECT_DIR = process.cwd();
const ACT_RESULT_FILE = join(PROJECT_DIR, "act-result.txt");
const TMP_DIR = `/tmp/act-matrix-${Date.now()}`;

// Shared state populated by beforeAll
let actOutput = "";
let actExitCode = -1;

function setupTempRepo(dir: string): void {
  mkdirSync(dir, { recursive: true });

  // Copy project files into temp dir
  const filesToCopy = [
    "matrix-generator.ts",
    "matrix-generator.test.ts",
    ".github",
    "fixtures",
    ".actrc",
  ];
  for (const f of filesToCopy) {
    const src = join(PROJECT_DIR, f);
    if (existsSync(src)) {
      cpSync(src, join(dir, f), { recursive: true });
    }
  }

  // Initialize git repo so act can check it out
  const gitCmds = [
    ["git", "init"],
    ["git", "config", "user.email", "test@test.com"],
    ["git", "config", "user.name", "Test"],
    ["git", "add", "-A"],
    ["git", "commit", "-m", "test: initial commit"],
  ];
  for (const cmd of gitCmds) {
    const r = spawnSync(cmd[0], cmd.slice(1), { cwd: dir, encoding: "utf8" });
    if (r.status !== 0) {
      throw new Error(`Git setup failed (${cmd.join(" ")}): ${r.stderr}`);
    }
  }
}

beforeAll(
  () => {
    // Set up temp repo and run act once
    setupTempRepo(TMP_DIR);

    const result = spawnSync(
      "act",
      ["push", "--rm", "--pull=false", "--container-architecture", "linux/amd64"],
      {
        cwd: TMP_DIR,
        encoding: "utf8",
        timeout: 300_000,
      }
    );

    actOutput = (result.stdout ?? "") + (result.stderr ?? "");
    actExitCode = result.status ?? -1;

    // Append to act-result.txt with a clear delimiter
    const delimiter = `\n${"=".repeat(60)}\nACT RUN: ${new Date().toISOString()}\nEXIT CODE: ${actExitCode}\n${"=".repeat(60)}\n`;
    appendFileSync(ACT_RESULT_FILE, delimiter + actOutput + "\n");
  },
  300_000 // 5-minute timeout for act to finish
);

describe("act workflow execution", () => {
  it("act-result.txt exists", () => {
    expect(existsSync(ACT_RESULT_FILE)).toBe(true);
  });

  it("act exited with code 0", () => {
    if (actExitCode !== 0) {
      // Print output to help diagnose failures
      console.error("=== ACT OUTPUT (failed) ===\n" + actOutput.slice(0, 4000));
    }
    expect(actExitCode).toBe(0);
  });

  it("generate-matrix job succeeded", () => {
    expect(actOutput).toContain("Job succeeded");
  });

  it("basic matrix has exactly 4 combinations", () => {
    expect(actOutput).toContain("BASIC_COMBINATIONS=4");
  });

  it("exclude matrix has exactly 5 combinations", () => {
    expect(actOutput).toContain("EXCLUDE_COMBINATIONS=5");
  });

  it("include matrix has exactly 5 combinations", () => {
    expect(actOutput).toContain("INCLUDE_COMBINATIONS=5");
  });

  it("too-large matrix validation passes (exits 1 as expected)", () => {
    expect(actOutput).toContain("TOO_LARGE_VALIDATION=PASSED");
  });

  it("unit tests passed in workflow", () => {
    // bun test outputs "X pass" on success
    expect(actOutput).toMatch(/\d+ pass/);
  });
});
