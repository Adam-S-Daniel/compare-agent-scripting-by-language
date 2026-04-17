// End-to-end harness: drives the workflow through `act` for each test case.
// Each case gets its own temp git repo (so `act` treats it as a push event)
// with the project files + that case's fixture data. All act output is
// appended to act-result.txt at the cwd root.
import { describe, expect, test, beforeAll } from "bun:test";
import { mkdtempSync, writeFileSync, appendFileSync, readFileSync, cpSync, existsSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";

const PROJECT_ROOT = resolve(".");
const ACT_RESULT = join(PROJECT_ROOT, "act-result.txt");

interface Case {
  name: string;
  fixture: string;
  startVersion: string;
  expectedVersion: string;
  expectedBump: string;
}

const CASES: Case[] = [
  { name: "feat-minor",     fixture: "feat-commits.txt",     startVersion: "1.1.0", expectedVersion: "1.2.0", expectedBump: "minor" },
  { name: "fix-patch",      fixture: "fix-commits.txt",      startVersion: "2.0.5", expectedVersion: "2.0.6", expectedBump: "patch" },
  { name: "breaking-major", fixture: "breaking-commits.txt", startVersion: "1.4.2", expectedVersion: "2.0.0", expectedBump: "major" },
];

function setupRepo(c: Case): string {
  const dir = mkdtempSync(join(tmpdir(), `act-bumper-${c.name}-`));
  // Copy project files the workflow needs.
  for (const f of ["src", "fixtures", "package.json", "tsconfig.json", ".github", ".actrc"]) {
    const src = join(PROJECT_ROOT, f);
    if (existsSync(src)) cpSync(src, join(dir, f), { recursive: true });
  }
  // Override starting version / fixture by writing an event file that act uses
  // via workflow_dispatch inputs -> but we want `act push` to pick them up via
  // env. Easiest: set env vars directly by rewriting the workflow's env block
  // is overkill; use act's --env flag instead in runAct.
  // Track the case data on disk so the assert step can read it.
  writeFileSync(join(dir, ".case.json"), JSON.stringify(c, null, 2));
  // Init a git repo so `act push` fires.
  for (const args of [
    ["init", "-q", "-b", "main"],
    ["config", "user.email", "t@t"],
    ["config", "user.name", "t"],
    ["add", "-A"],
    ["commit", "-q", "-m", "init"],
  ]) {
    const r = spawnSync("git", args, { cwd: dir });
    if (r.status !== 0) throw new Error(`git ${args.join(" ")} failed: ${r.stderr?.toString()}`);
  }
  return dir;
}

function runAct(dir: string, c: Case): { stdout: string; status: number } {
  const r = spawnSync(
    "act",
    [
      "push",
      "--rm",
      "--env", `FIXTURE=${c.fixture}`,
      "--env", `START_VERSION=${c.startVersion}`,
    ],
    { cwd: dir, encoding: "utf8", maxBuffer: 50 * 1024 * 1024 },
  );
  return { stdout: (r.stdout ?? "") + (r.stderr ?? ""), status: r.status ?? -1 };
}

beforeAll(() => {
  // Fresh log file per test run.
  if (existsSync(ACT_RESULT)) rmSync(ACT_RESULT);
  writeFileSync(ACT_RESULT, `act harness run at ${new Date().toISOString()}\n`);
});

describe("workflow structure", () => {
  test("actionlint passes", () => {
    const r = spawnSync("actionlint", [".github/workflows/semantic-version-bumper.yml"], { cwd: PROJECT_ROOT, encoding: "utf8" });
    expect(r.status).toBe(0);
  });

  test("workflow references existing script paths", () => {
    const yml = readFileSync(join(PROJECT_ROOT, ".github/workflows/semantic-version-bumper.yml"), "utf8");
    expect(yml).toContain("src/cli.ts");
    expect(existsSync(join(PROJECT_ROOT, "src/cli.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_ROOT, "fixtures/feat-commits.txt"))).toBe(true);
  });

  test("workflow has expected triggers and jobs", () => {
    const yml = readFileSync(join(PROJECT_ROOT, ".github/workflows/semantic-version-bumper.yml"), "utf8");
    expect(yml).toMatch(/^on:/m);
    expect(yml).toContain("push:");
    expect(yml).toContain("pull_request:");
    expect(yml).toContain("workflow_dispatch:");
    expect(yml).toMatch(/jobs:\s*\n\s+bump:/);
    expect(yml).toContain("actions/checkout@v4");
  });
});

describe("act end-to-end", () => {
  for (const c of CASES) {
    test(`case ${c.name}: ${c.startVersion} + ${c.fixture} -> ${c.expectedVersion}`, () => {
      const dir = setupRepo(c);
      const { stdout, status } = runAct(dir, c);

      // Delimit per-case output in act-result.txt.
      appendFileSync(ACT_RESULT,
        `\n===== CASE ${c.name} =====\n` +
        `fixture=${c.fixture} start=${c.startVersion} expected=${c.expectedVersion}\n` +
        `act exit=${status}\n` +
        stdout +
        `===== END ${c.name} =====\n`
      );

      expect(status).toBe(0);
      // Every job in our workflow shows "Job succeeded" line from act.
      expect(stdout).toMatch(/Job succeeded/);
      // The bump-output.txt content is echoed via `tee` and captured in stdout.
      expect(stdout).toContain(`current=${c.startVersion}`);
      expect(stdout).toContain(`bump=${c.expectedBump}`);
      expect(stdout).toContain(`next=${c.expectedVersion}`);
      expect(stdout).toContain(`VERSION=${c.expectedVersion}`);
      // And the resulting package.json also shows the exact version.
      expect(stdout).toMatch(new RegExp(`"version":\\s*"${c.expectedVersion.replace(/\./g, "\\.")}"`));

      rmSync(dir, { recursive: true, force: true });
    }, 240_000);
  }
});
