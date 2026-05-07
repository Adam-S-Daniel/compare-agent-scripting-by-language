#!/usr/bin/env bun
// End-to-end harness: for every fixture case, build an isolated temp git repo
// containing the project + that fixture as `fixtures/basic.json` (the workflow
// default), run `act push --rm`, capture the output, and assert exact values.
// All output is appended to act-result.txt in the project root.
import { describe, expect, test, beforeAll } from "bun:test";
import { spawnSync } from "node:child_process";
import { mkdtempSync, cpSync, writeFileSync, appendFileSync, existsSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { parse as parseYaml } from "yaml";
import { readFileSync } from "node:fs";

const PROJECT_ROOT = import.meta.dir;
const ACT_RESULT = join(PROJECT_ROOT, "act-result.txt");
const ACTRC = join(PROJECT_ROOT, ".actrc");

interface ActCase {
  name: string;
  fixturePath: string; // path inside project to original fixture
  expectedTotal: number;
  expectedSubstrings: string[];
  expectExit: number;
}

const CASES: ActCase[] = [
  {
    name: "basic-2x2",
    fixturePath: "fixtures/basic.json",
    expectedTotal: 4,
    expectedSubstrings: [
      '"total": 4',
      '"max-parallel": 4',
      '"fail-fast": true',
      '"os": "ubuntu-latest"',
      '"node": "20"',
      "MATRIX_TOTAL=4",
    ],
    expectExit: 0,
  },
  {
    name: "include-exclude",
    fixturePath: "fixtures/include-exclude.json",
    expectedTotal: 5,
    expectedSubstrings: [
      '"total": 5',
      '"experimental": true',
      '"max-parallel": 3',
      '"fail-fast": false',
      "MATRIX_TOTAL=5",
    ],
    expectExit: 0,
  },
];

function copyProject(dest: string) {
  // Copy needed files; skip node_modules (bun install will repopulate) and
  // anything that would bloat the temp repo.
  const includes = [
    "matrix.ts",
    "matrix.test.ts",
    "cli.ts",
    "package.json",
    "tsconfig.json",
    "bun.lock",
    ".github",
    "fixtures",
    ".actrc",
  ];
  for (const item of includes) {
    const src = join(PROJECT_ROOT, item);
    if (existsSync(src)) {
      cpSync(src, join(dest, item), { recursive: true });
    }
  }
}

function gitInit(dir: string) {
  const run = (...args: string[]) =>
    spawnSync("git", args, { cwd: dir, stdio: "pipe" });
  run("init", "-q", "-b", "main");
  run("config", "user.email", "act@example.com");
  run("config", "user.name", "act");
  run("add", "-A");
  run("commit", "-q", "-m", "initial");
}

function runAct(dir: string): { code: number; output: string } {
  // Use the prebuilt act-ubuntu-pwsh image declared in .actrc. --rm removes
  // the container after the run; -W pins the workflow file.
  const proc = spawnSync(
    "act",
    [
      "push",
      "--rm",
      "--pull=false",
      "-W",
      ".github/workflows/environment-matrix-generator.yml",
    ],
    { cwd: dir, encoding: "utf8", timeout: 10 * 60_000 },
  );
  const output = (proc.stdout ?? "") + (proc.stderr ?? "");
  return { code: proc.status ?? -1, output };
}

beforeAll(() => {
  // Truncate act-result.txt so a fresh run starts clean.
  writeFileSync(ACT_RESULT, "");
  // Ensure .actrc exists (it ships with the workspace).
  expect(existsSync(ACTRC)).toBe(true);
});

describe("workflow structure", () => {
  const wf = parseYaml(
    readFileSync(
      join(PROJECT_ROOT, ".github/workflows/environment-matrix-generator.yml"),
      "utf8",
    ),
  ) as any;

  test("declares the expected triggers", () => {
    // YAML 'on' is sometimes parsed as `true` by libs that treat it as a
    // boolean keyword. Accept either key.
    const on = wf.on ?? wf[true];
    expect(Object.keys(on)).toEqual(
      expect.arrayContaining(["push", "pull_request", "workflow_dispatch", "schedule"]),
    );
  });

  test("references cli.ts and the default fixture", () => {
    const text = readFileSync(
      join(PROJECT_ROOT, ".github/workflows/environment-matrix-generator.yml"),
      "utf8",
    );
    expect(text).toContain("cli.ts");
    expect(text).toContain("fixtures/basic.json");
    expect(existsSync(join(PROJECT_ROOT, "cli.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_ROOT, "fixtures/basic.json"))).toBe(true);
  });

  test("actionlint passes", () => {
    const r = spawnSync(
      "actionlint",
      [".github/workflows/environment-matrix-generator.yml"],
      { cwd: PROJECT_ROOT, encoding: "utf8" },
    );
    expect(r.status).toBe(0);
  });
});

describe("act end-to-end", () => {
  for (const c of CASES) {
    test(
      `case: ${c.name}`,
      () => {
        const tmp = mkdtempSync(join(tmpdir(), `actcase-${c.name}-`));
        try {
          copyProject(tmp);
          // Replace the default fixture with the case fixture so the workflow
          // uses it without needing inputs.
          cpSync(
            join(PROJECT_ROOT, c.fixturePath),
            join(tmp, "fixtures/basic.json"),
          );
          gitInit(tmp);

          const { code, output } = runAct(tmp);
          appendFileSync(
            ACT_RESULT,
            `\n===== CASE: ${c.name} =====\n` +
              `cwd: ${tmp}\nfixture: ${c.fixturePath}\nexit: ${code}\n` +
              `----- BEGIN OUTPUT -----\n${output}\n----- END OUTPUT -----\n`,
          );

          expect(code).toBe(c.expectExit);
          expect(output).toContain("Job succeeded");
          for (const s of c.expectedSubstrings) {
            expect(output).toContain(s);
          }
        } finally {
          rmSync(tmp, { recursive: true, force: true });
        }
      },
      10 * 60_000,
    );
  }
});
