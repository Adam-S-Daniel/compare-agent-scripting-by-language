// End-to-end harness: every test case spins up a temporary git repo populated
// with our project files + the fixture's commit log, runs `act push --rm`,
// captures stdout, and asserts on exact expected values from the workflow's
// step output ("BUMP_RESULT_*=...") plus "Job succeeded" lines.
//
// All output is appended to act-result.txt with clear delimiters. Total runs
// are kept at 3 (one per case) — diagnose from the captured output if a case
// fails rather than re-running blindly.

import { describe, expect, test, beforeAll } from "bun:test";

// When running INSIDE act (the workflow's `bun test` step), skip the harness
// to avoid recursive `act` invocation. act sets ACT=true by default.
const INSIDE_ACT = process.env.ACT === "true";
const d = INSIDE_ACT ? describe.skip : describe;
import { spawnSync } from "node:child_process";
import {
  mkdtempSync,
  rmSync,
  cpSync,
  writeFileSync,
  appendFileSync,
  existsSync,
  readFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const PROJECT = resolve(import.meta.dir);
const ACT_RESULT = join(PROJECT, "act-result.txt");

interface Case {
  name: string;
  fixture: string;
  startVersion: string;
  expectedBump: string;
  expectedNewVersion: string;
}

const CASES: Case[] = [
  { name: "feat", fixture: "fixtures/feat.log", startVersion: "1.1.0", expectedBump: "minor", expectedNewVersion: "1.2.0" },
  { name: "fix", fixture: "fixtures/fix.log", startVersion: "0.4.2", expectedBump: "patch", expectedNewVersion: "0.4.3" },
  { name: "breaking", fixture: "fixtures/breaking.log", startVersion: "2.5.7", expectedBump: "major", expectedNewVersion: "3.0.0" },
];

beforeAll(() => {
  // Reset the artifact at the start of every harness run.
  writeFileSync(ACT_RESULT, `# act-result.txt — generated ${new Date().toISOString()}\n\n`);
});

function runActCase(c: Case): { code: number; output: string } {
  const work = mkdtempSync(join(tmpdir(), `act-${c.name}-`));
  try {
    // Copy project files needed inside the act container. Avoid copying
    // host-only state (.git, node_modules, act-result.txt itself).
    const items = [
      "bumper.ts",
      "bump.ts",
      "bumper.test.ts",
      "package.json",
      "fixtures",
      ".github",
      ".actrc",
    ];
    for (const it of items) {
      const src = join(PROJECT, it);
      if (existsSync(src)) cpSync(src, join(work, it), { recursive: true });
    }
    // Seed package.json with the case's starting version (the workflow also
    // does this, but writing it here too keeps the repo realistic).
    writeFileSync(
      join(work, "package.json"),
      JSON.stringify({ name: "semantic-version-bumper", version: c.startVersion, type: "module", private: true }, null, 2) + "\n",
    );

    // Initialize a fresh git repo so act has something to work with.
    const sh = (cmd: string, args: string[]) =>
      spawnSync(cmd, args, { cwd: work, encoding: "utf8" });
    sh("git", ["init", "-q", "-b", "main"]);
    sh("git", ["config", "user.email", "test@example.com"]);
    sh("git", ["config", "user.name", "Test"]);
    sh("git", ["add", "-A"]);
    sh("git", ["commit", "-q", "-m", "initial"]);

    // Run act, threading the fixture path + starting version through env.
    const args = [
      "push",
      "--rm",
      "--env",
      `COMMIT_LOG=${c.fixture}`,
      "--env",
      `START_VERSION=${c.startVersion}`,
    ];
    const res = spawnSync("act", args, {
      cwd: work,
      encoding: "utf8",
      timeout: 300_000,
      maxBuffer: 32 * 1024 * 1024,
    });
    const output = (res.stdout || "") + "\n--- stderr ---\n" + (res.stderr || "");

    appendFileSync(
      ACT_RESULT,
      `\n========== CASE: ${c.name} ==========\n` +
        `fixture=${c.fixture} start=${c.startVersion} expected=${c.expectedNewVersion} bump=${c.expectedBump}\n` +
        `act exit code: ${res.status}\n` +
        output +
        `\n========== END CASE: ${c.name} ==========\n`,
    );

    return { code: res.status ?? -1, output };
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
}

d("workflow structure", () => {
  test("workflow file exists and references real script paths", () => {
    const wf = readFileSync(join(PROJECT, ".github/workflows/semantic-version-bumper.yml"), "utf8");
    expect(wf).toContain("bun run bump.ts");
    expect(wf).toContain("bun test");
    // referenced files exist
    expect(existsSync(join(PROJECT, "bump.ts"))).toBe(true);
    expect(existsSync(join(PROJECT, "bumper.ts"))).toBe(true);
    expect(existsSync(join(PROJECT, "fixtures/feat.log"))).toBe(true);
  });

  test("workflow declares expected triggers and jobs", () => {
    const wf = readFileSync(join(PROJECT, ".github/workflows/semantic-version-bumper.yml"), "utf8");
    expect(wf).toMatch(/^on:/m);
    expect(wf).toContain("push:");
    expect(wf).toContain("workflow_dispatch:");
    expect(wf).toContain("test:");
    expect(wf).toContain("bump:");
    expect(wf).toContain("needs: test");
  });

  test("actionlint passes", () => {
    const res = spawnSync("actionlint", [".github/workflows/semantic-version-bumper.yml"], {
      cwd: PROJECT,
      encoding: "utf8",
    });
    if (res.status !== 0) {
      console.error("actionlint output:\n", res.stdout, res.stderr);
    }
    expect(res.status).toBe(0);
  });
});

d("act end-to-end", () => {
  for (const c of CASES) {
    test(
      `case ${c.name}: ${c.startVersion} + ${c.fixture} -> ${c.expectedNewVersion} (${c.expectedBump})`,
      () => {
        const { code, output } = runActCase(c);
        if (code !== 0) {
          console.error(`act failed (exit ${code}). Tail:\n` + output.slice(-3000));
        }
        expect(code).toBe(0);
        // Exact expected step-output values (workflow echoes BUMP_RESULT_*=...).
        expect(output).toContain(`BUMP_RESULT_PREVIOUS=${c.startVersion}`);
        expect(output).toContain(`BUMP_RESULT_NEW=${c.expectedNewVersion}`);
        expect(output).toContain(`BUMP_RESULT_TYPE=${c.expectedBump}`);
        // updated package.json was printed
        expect(output).toContain(`"version": "${c.expectedNewVersion}"`);
        // Both jobs completed.
        const successCount = (output.match(/Job succeeded/g) ?? []).length;
        expect(successCount).toBeGreaterThanOrEqual(2);
      },
      360_000,
    );
  }
});
