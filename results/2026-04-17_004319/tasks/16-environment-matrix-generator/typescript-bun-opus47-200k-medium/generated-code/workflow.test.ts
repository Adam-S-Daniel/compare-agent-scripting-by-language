// Integration test harness: runs the GitHub Actions workflow via `act` for
// each test case, parses output, asserts on exact values. Every case is
// executed through the CI pipeline, not directly against the script.

import { describe, expect, test, beforeAll } from "bun:test";
import { $ } from "bun";
import { existsSync, readFileSync, writeFileSync, appendFileSync } from "node:fs";
import { parse as parseYaml } from "yaml";

const RESULT_FILE = `${import.meta.dir}/act-result.txt`;
const WORKFLOW_PATH = `${import.meta.dir}/.github/workflows/environment-matrix-generator.yml`;

interface Case {
  name: string;
  fixture: string;
  expectedCombinations: number;
  expectContains?: string[];
}

const cases: Case[] = [
  {
    name: "basic",
    fixture: "fixtures/basic.json",
    expectedCombinations: 4,
    expectContains: [
      '"os":"ubuntu-latest","node":18',
      '"os":"macos-latest","node":20',
      '"max-parallel":4',
      '"fail-fast":true',
    ],
  },
  {
    name: "complex",
    fixture: "fixtures/complex.json",
    expectedCombinations: 8,
    expectContains: [
      '"experimental":true',
      '"max-parallel":6',
      '"fail-fast":false',
    ],
  },
];

// Run act once with a chosen fixture by rewriting the workflow default.
// To avoid multiple `act push` runs (limit of 3), we embed all cases in a
// single workflow run by using matrix strategy: run act once.
// However, act supports workflow_dispatch inputs via --input. But push events
// trigger automatically. We'll run once per case but batch via a single act
// invocation per case — actually limit = 3 and we have 2 cases.

async function runAct(fixture: string): Promise<{ code: number; stdout: string }> {
  // Set fixture via env var passed to act workflow (push event won't pick up
  // dispatch inputs). We set FIXTURE env override in the workflow via --env.
  const proc = Bun.spawn(
    [
      "act",
      "push",
      "--rm",
      "--pull=false",
      "--env",
      `FIXTURE=${fixture}`,
      "-W",
      ".github/workflows/environment-matrix-generator.yml",
    ],
    {
      cwd: import.meta.dir,
      stdout: "pipe",
      stderr: "pipe",
    },
  );
  const stdout = await new Response(proc.stdout).text();
  const stderr = await new Response(proc.stderr).text();
  const code = await proc.exited;
  return { code, stdout: stdout + "\n" + stderr };
}

describe("workflow structure", () => {
  test("workflow file exists and is valid YAML", () => {
    expect(existsSync(WORKFLOW_PATH)).toBe(true);
    const parsed = parseYaml(readFileSync(WORKFLOW_PATH, "utf8"));
    expect(parsed.name).toBe("Environment Matrix Generator");
    // YAML parses 'on' as boolean true sometimes; handle both
    const on = parsed.on ?? parsed[true];
    expect(on).toBeDefined();
    expect(on.push !== undefined || on.pull_request !== undefined).toBe(true);
    expect(on.workflow_dispatch).toBeDefined();
    expect(parsed.jobs).toBeDefined();
    expect(parsed.jobs.generate).toBeDefined();
  });

  test("workflow references existing script and fixtures", () => {
    expect(existsSync(`${import.meta.dir}/generate.ts`)).toBe(true);
    expect(existsSync(`${import.meta.dir}/matrix.ts`)).toBe(true);
    expect(existsSync(`${import.meta.dir}/fixtures/basic.json`)).toBe(true);
    expect(existsSync(`${import.meta.dir}/fixtures/complex.json`)).toBe(true);
  });

  test("actionlint passes with exit code 0", async () => {
    const proc = Bun.spawn(["actionlint", WORKFLOW_PATH], {
      cwd: import.meta.dir,
      stdout: "pipe",
      stderr: "pipe",
    });
    const code = await proc.exited;
    expect(code).toBe(0);
  });
});

describe("act pipeline execution", () => {
  beforeAll(() => {
    writeFileSync(RESULT_FILE, `# act-result.txt — generated ${new Date().toISOString()}\n\n`);
  });

  for (const c of cases) {
    test(
      `case: ${c.name}`,
      async () => {
        const { code, stdout } = await runAct(c.fixture);
        appendFileSync(
          RESULT_FILE,
          `\n========== CASE: ${c.name} (fixture=${c.fixture}) ==========\n`,
        );
        appendFileSync(RESULT_FILE, `exit_code=${code}\n`);
        appendFileSync(RESULT_FILE, stdout);
        appendFileSync(RESULT_FILE, `\n========== END CASE: ${c.name} ==========\n`);

        expect(code).toBe(0);
        expect(stdout).toContain("Job succeeded");

        // Extract generated JSON between MATRIX_BEGIN/MATRIX_END markers.
        // act prefixes each line with something like "[workflow/job]   | ".
        const m = stdout.match(/MATRIX_BEGIN[\s\S]*?\n([\s\S]*?)\n[^\n]*MATRIX_END/);
        expect(m).not.toBeNull();
        // Strip the act log prefix `[...]   | ` from each captured line.
        const json = m![1]
          .split("\n")
          .map((l) => l.replace(/^\[[^\]]+\][^|]*\|\s?/, ""))
          .join("")
          .trim();
        const parsed = JSON.parse(json);
        expect(parsed.combinations.length).toBe(c.expectedCombinations);

        if (c.expectContains) {
          for (const needle of c.expectContains) {
            expect(json).toContain(needle);
          }
        }
      },
      300_000,
    );
  }
});
