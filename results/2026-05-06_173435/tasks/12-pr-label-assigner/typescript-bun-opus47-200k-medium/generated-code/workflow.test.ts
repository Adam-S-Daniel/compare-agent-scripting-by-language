// End-to-end tests: every scenario runs through the GitHub Actions workflow
// via `act`. We set up a disposable git repo per test case, swap in the
// fixture file list, run `act push --rm`, and assert on the parsed output.
//
// All act output is appended to act-result.txt as a required artifact.

import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { mkdtempSync, writeFileSync, cpSync, existsSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const PROJECT_ROOT = import.meta.dir;
const ACT_RESULT_FILE = join(PROJECT_ROOT, "act-result.txt");

interface ActRun {
  exitCode: number;
  stdout: string;
  stderr: string;
}

function runAct(repoDir: string): ActRun {
  const proc = spawnSync(
    "act",
    ["push", "--rm", "--workflows", ".github/workflows/pr-label-assigner.yml"],
    { cwd: repoDir, encoding: "utf8", env: { ...process.env }, maxBuffer: 50 * 1024 * 1024 },
  );
  return {
    exitCode: proc.status ?? -1,
    stdout: proc.stdout ?? "",
    stderr: proc.stderr ?? "",
  };
}

function setupRepo(files: string[]): string {
  const dir = mkdtempSync(join(tmpdir(), "pr-label-assigner-"));
  for (const entry of [
    "index.ts",
    "labeler.ts",
    "labeler.test.ts",
    "package.json",
    "rules.json",
    ".github",
    ".actrc",
  ]) {
    const src = join(PROJECT_ROOT, entry);
    if (existsSync(src)) cpSync(src, join(dir, entry), { recursive: true });
  }
  // Create fixtures dir + override files.json with this case's input.
  spawnSync("mkdir", ["-p", join(dir, "fixtures")]);
  writeFileSync(join(dir, "fixtures", "files.json"), JSON.stringify(files), "utf8");

  // Init git so act has HEAD/branch context
  const env = { ...process.env, GIT_AUTHOR_NAME: "t", GIT_AUTHOR_EMAIL: "t@t", GIT_COMMITTER_NAME: "t", GIT_COMMITTER_EMAIL: "t@t" };
  spawnSync("git", ["init", "-q", "-b", "main"], { cwd: dir, env });
  spawnSync("git", ["add", "."], { cwd: dir, env });
  spawnSync("git", ["commit", "-q", "-m", "init", "--no-gpg-sign"], { cwd: dir, env });
  return dir;
}

function appendActLog(label: string, run: ActRun): void {
  const sep = "=".repeat(72);
  const block = [
    sep,
    `TEST CASE: ${label}`,
    `EXIT CODE: ${run.exitCode}`,
    sep,
    "--- STDOUT ---",
    run.stdout,
    "--- STDERR ---",
    run.stderr,
    "",
  ].join("\n");
  writeFileSync(ACT_RESULT_FILE, block, { flag: "a" });
}

function extractLabels(stdout: string): string[] {
  // The "Assign labels" step prints `LABELS_JSON={"labels":[...]}` via ::notice::.
  const match = stdout.match(/LABELS_JSON=(\{"labels":\[[^\]]*\]\})/);
  if (!match) {
    throw new Error(
      `Could not find LABELS_JSON line in act stdout. Output:\n${stdout.slice(-2000)}`,
    );
  }
  const parsed = JSON.parse(match[1]) as { labels: string[] };
  return parsed.labels;
}

function countJobSucceeded(stdout: string): number {
  return (stdout.match(/Job succeeded/g) || []).length;
}

beforeAll(() => {
  // Fresh log file for the run.
  if (existsSync(ACT_RESULT_FILE)) rmSync(ACT_RESULT_FILE);
  writeFileSync(ACT_RESULT_FILE, `act run started at ${new Date().toISOString()}\n`);
});

describe("workflow structure", () => {
  test("workflow YAML has expected structure and references existing files", async () => {
    const path = join(PROJECT_ROOT, ".github/workflows/pr-label-assigner.yml");
    const text = await Bun.file(path).text();
    // Minimal structural checks (avoid pulling in a YAML lib — actionlint already
    // parses the file and we assert that separately).
    expect(text).toMatch(/^name: PR Label Assigner$/m);
    expect(text).toMatch(/^on:\s*$/m);
    expect(text).toMatch(/^\s+push:/m);
    expect(text).toMatch(/^\s+pull_request:/m);
    expect(text).toMatch(/^\s+workflow_dispatch:/m);
    expect(text).toMatch(/^jobs:\s*$/m);
    expect(text).toMatch(/assign-labels:/);
    expect(text).toMatch(/uses: actions\/checkout@v4/);
    expect(text).toMatch(/index\.ts/);
    // Files referenced by the workflow must exist.
    expect(existsSync(join(PROJECT_ROOT, "index.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_ROOT, "labeler.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_ROOT, "rules.json"))).toBe(true);
    expect(existsSync(join(PROJECT_ROOT, "fixtures/files.json"))).toBe(true);
  });

  test("actionlint passes with exit code 0", () => {
    const result = spawnSync(
      "actionlint",
      [".github/workflows/pr-label-assigner.yml"],
      { cwd: PROJECT_ROOT, encoding: "utf8" },
    );
    expect(result.status).toBe(0);
  });
});

interface Case {
  name: string;
  files: string[];
  expected: string[];
}

// Expected labels reflect the priority ordering from rules.json:
//   api(1), frontend(5), documentation(10), tests(20), ci(30), config(40)
const cases: Case[] = [
  {
    name: "docs-api-frontend",
    files: ["docs/intro.md", "src/api/users.ts", "src/web/App.tsx"],
    expected: ["api", "frontend", "documentation"],
  },
  {
    name: "tests-only",
    files: ["src/util.test.ts"],
    expected: ["tests"],
  },
  {
    name: "config-and-ci",
    files: [".github/workflows/foo.yml", "tsconfig.json"],
    expected: ["ci", "config"],
  },
];

const harnessDirs: string[] = [];

afterAll(() => {
  for (const d of harnessDirs) {
    try { rmSync(d, { recursive: true, force: true }); } catch {}
  }
});

describe("act end-to-end", () => {
  // Run each case sequentially through act and assert exact label set.
  for (const c of cases) {
    test(
      `act runs case: ${c.name}`,
      async () => {
        const dir = setupRepo(c.files);
        const result = runAct(dir);
        appendActLog(c.name, result);
        harnessDirs.push(dir);

        expect(result.exitCode).toBe(0);
        const succeeded = countJobSucceeded(result.stdout + result.stderr);
        expect(succeeded).toBeGreaterThanOrEqual(1);

        const labels = extractLabels(result.stdout + result.stderr);
        expect(labels).toEqual(c.expected);
      },
      { timeout: 300_000 },
    );
  }
});
