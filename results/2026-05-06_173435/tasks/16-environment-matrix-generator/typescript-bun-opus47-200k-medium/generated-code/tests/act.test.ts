// Integration test harness: for each fixture, set up a temp git repo with the
// project + fixture as fixtures/basic.json, run `act push --rm`, verify exit
// code, parse output, and assert exact expected values.
//
// All output appended to act-result.txt in cwd.

import { describe, expect, test, beforeAll } from "bun:test";
import { spawnSync } from "node:child_process";
import { mkdtempSync, mkdirSync, cpSync, writeFileSync, existsSync, appendFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import * as yaml from "yaml";

const projectDir = resolve(import.meta.dir, "..");
const actResultFile = join(projectDir, "act-result.txt");

interface ActCase {
  name: string;
  fixture: object;
  // expected: list of substrings that must appear in matrix.json output
  expectMatrixContains: string[];
  // expected matrix size from `include` array
  expectIncludeLength: number;
}

const cases: ActCase[] = [
  {
    name: "basic-2x2",
    fixture: {
      axes: { os: ["ubuntu-latest", "windows-latest"], node: ["18", "20"] },
      maxParallel: 4,
      failFast: true,
    },
    expectMatrixContains: [
      '"max-parallel": 4',
      '"fail-fast": true',
      '"os": "ubuntu-latest"',
      '"os": "windows-latest"',
      '"node": "18"',
      '"node": "20"',
    ],
    expectIncludeLength: 4,
  },
  {
    name: "with-include-exclude",
    fixture: {
      axes: { os: ["ubuntu-latest", "windows-latest", "macos-latest"], node: ["18", "20"] },
      exclude: [{ os: "windows-latest", node: "18" }],
      include: [{ os: "ubuntu-latest", node: "20", experimental: true }],
      maxParallel: 3,
      failFast: false,
    },
    expectMatrixContains: [
      '"experimental": true',
      '"max-parallel": 3',
      '"fail-fast": false',
    ],
    expectIncludeLength: 5, // 6 - 1 excluded; include augments existing entry
  },
];

function runAct(repoDir: string): { stdout: string; stderr: string; status: number } {
  const r = spawnSync(
    "act",
    ["push", "--rm", "-W", ".github/workflows/environment-matrix-generator.yml"],
    { cwd: repoDir, encoding: "utf8", env: { ...process.env }, maxBuffer: 50 * 1024 * 1024 },
  );
  return {
    stdout: r.stdout ?? "",
    stderr: r.stderr ?? "",
    status: r.status ?? -1,
  };
}

function setupRepo(fixture: object): string {
  const dir = mkdtempSync(join(tmpdir(), "matrix-act-"));
  // Copy project files (only what the workflow needs).
  for (const f of [
    "matrix.ts",
    "cli.ts",
    "matrix.test.ts",
    "package.json",
    "tsconfig.json",
    ".actrc",
  ]) {
    const src = join(projectDir, f);
    if (existsSync(src)) cpSync(src, join(dir, f));
  }
  // Copy node_modules if present (speeds up tests significantly in act)
  if (existsSync(join(projectDir, "bun.lock"))) {
    cpSync(join(projectDir, "bun.lock"), join(dir, "bun.lock"));
  }
  // .github/workflows
  mkdirSync(join(dir, ".github", "workflows"), { recursive: true });
  cpSync(
    join(projectDir, ".github", "workflows", "environment-matrix-generator.yml"),
    join(dir, ".github", "workflows", "environment-matrix-generator.yml"),
  );
  // Fixture
  mkdirSync(join(dir, "fixtures"), { recursive: true });
  writeFileSync(join(dir, "fixtures", "basic.json"), JSON.stringify(fixture, null, 2));
  // Init git
  spawnSync("git", ["init", "-q", "-b", "main"], { cwd: dir });
  spawnSync("git", ["config", "user.email", "t@t"], { cwd: dir });
  spawnSync("git", ["config", "user.name", "t"], { cwd: dir });
  spawnSync("git", ["add", "-A"], { cwd: dir });
  spawnSync("git", ["commit", "-q", "-m", "init"], { cwd: dir });
  return dir;
}

// Parse "----- BEGIN MATRIX JSON -----" ... "----- END MATRIX JSON -----" out
// of act stdout. act prefixes lines with [Workflow/Job] | so we strip that.
function extractMatrixJson(output: string): string {
  const lines = output.split("\n").map((l) => l.replace(/^\|? ?\[[^\]]+\]\s*\|\s?/, ""));
  const begin = lines.findIndex((l) => l.includes("BEGIN MATRIX JSON"));
  const end = lines.findIndex((l) => l.includes("END MATRIX JSON"));
  if (begin === -1 || end === -1 || end <= begin) {
    throw new Error("Could not find matrix JSON markers in output");
  }
  return lines.slice(begin + 1, end).join("\n").trim();
}

beforeAll(() => {
  // Reset act-result.txt for this run.
  if (existsSync(actResultFile)) rmSync(actResultFile);
  writeFileSync(actResultFile, `# act results - ${new Date().toISOString()}\n`);
});

describe("workflow structure", () => {
  test("workflow YAML parses and has expected structure", async () => {
    const text = await Bun.file(
      join(projectDir, ".github/workflows/environment-matrix-generator.yml"),
    ).text();
    const wf = yaml.parse(text);
    expect(wf.name).toBeDefined();
    expect(wf.on).toBeDefined();
    expect(wf.on.push !== undefined || wf.on.pull_request !== undefined).toBe(true);
    expect(wf.jobs).toBeDefined();
    expect(wf.jobs["generate-matrix"]).toBeDefined();
    expect(wf.jobs["generate-matrix"]["runs-on"]).toBe("ubuntu-latest");
    const steps = wf.jobs["generate-matrix"].steps;
    expect(steps.some((s: any) => s.uses?.startsWith("actions/checkout@"))).toBe(true);
    expect(steps.some((s: any) => /cli\.ts/.test(s.run ?? ""))).toBe(true);
  });

  test("workflow references files that exist", () => {
    expect(existsSync(join(projectDir, "cli.ts"))).toBe(true);
    expect(existsSync(join(projectDir, "matrix.ts"))).toBe(true);
  });

  test("actionlint passes", () => {
    const r = spawnSync(
      "actionlint",
      [".github/workflows/environment-matrix-generator.yml"],
      { cwd: projectDir, encoding: "utf8" },
    );
    if (r.status !== 0) console.error(r.stdout, r.stderr);
    expect(r.status).toBe(0);
  });
});

describe("act execution", () => {
  for (const c of cases) {
    test(
      `act case: ${c.name}`,
      () => {
        const repo = setupRepo(c.fixture);
        const result = runAct(repo);
        const block =
          `\n\n===== CASE: ${c.name} =====\nexit=${result.status}\n--- STDOUT ---\n${result.stdout}\n--- STDERR ---\n${result.stderr}\n`;
        appendFileSync(actResultFile, block);

        expect(result.status).toBe(0);
        // Every job must show success.
        expect(result.stdout).toContain("Job succeeded");

        const matrixJson = extractMatrixJson(result.stdout);
        const parsed = JSON.parse(matrixJson);
        expect(Array.isArray(parsed.include)).toBe(true);
        expect(parsed.include.length).toBe(c.expectIncludeLength);
        for (const sub of c.expectMatrixContains) {
          expect(matrixJson).toContain(sub);
        }
      },
      { timeout: 600_000 },
    );
  }
});
