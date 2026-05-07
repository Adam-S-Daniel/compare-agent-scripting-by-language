// End-to-end pipeline tests: every assertion runs through `act push`.
//
// For each case we:
//   1. Build an isolated temp git repo with our project + that case's fixtures
//   2. Run `act push --rm` and capture its output
//   3. Append the output to act-result.txt (required artifact)
//   4. Assert exit code 0, "Job succeeded", and the EXACT AGG_SUMMARY line
//      (whose totals are deterministic for the fixture data we ship in).
//
// We keep this to 2 cases so we stay under the 3-run limit.

import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { spawnSync } from "node:child_process";
import { cpSync, mkdirSync, mkdtempSync, rmSync, writeFileSync, appendFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const PROJECT_ROOT = process.cwd();
const ACT_OUTPUT_PATH = join(PROJECT_ROOT, "act-result.txt");

// One-shot reset of the aggregated act log.
beforeAll(() => {
  writeFileSync(ACT_OUTPUT_PATH, `# act run log — ${new Date().toISOString()}\n\n`);
});

afterAll(() => {
  // Helpful trailing marker.
  appendFileSync(ACT_OUTPUT_PATH, `\n# end of run log\n`);
});

interface Case {
  name: string;
  fixtures: { filename: string; contents: string }[];
  // Expected AGG_SUMMARY values (the cli prints one line of these).
  expect: { passed: number; failed: number; skipped: number; total: number; flaky: number; runs: number };
}

const FIXTURE_RUN1 = `<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="MathSuite" tests="3" failures="0" skipped="0" time="0.45">
    <testcase classname="MathSuite" name="adds two numbers" time="0.10"/>
    <testcase classname="MathSuite" name="multiplies" time="0.05"/>
    <testcase classname="MathSuite" name="flaky network call" time="0.30"/>
  </testsuite>
  <testsuite name="StringSuite" tests="2" failures="0" skipped="1" time="0.02">
    <testcase classname="StringSuite" name="trims whitespace" time="0.01"/>
    <testcase classname="StringSuite" name="todo: unicode" time="0.01">
      <skipped/>
    </testcase>
  </testsuite>
</testsuites>
`;

const FIXTURE_RUN2 = `<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="MathSuite" tests="3" failures="2" skipped="0" time="0.50">
    <testcase classname="MathSuite" name="adds two numbers" time="0.10"/>
    <testcase classname="MathSuite" name="multiplies" time="0.05">
      <failure message="expected 12 got 13">AssertionError</failure>
    </testcase>
    <testcase classname="MathSuite" name="flaky network call" time="0.35">
      <failure message="ECONNRESET">network blip</failure>
    </testcase>
  </testsuite>
</testsuites>
`;

const FIXTURE_RUN3 = `{
  "suite": "ApiSuite",
  "tests": [
    { "name": "GET /healthz", "status": "passed", "durationMs": 12 },
    { "name": "POST /widgets", "status": "passed", "durationMs": 28 },
    { "name": "DELETE /widgets/:id", "status": "skipped", "durationMs": 0 },
    { "name": "flaky network call", "status": "passed", "durationMs": 310 }
  ]
}
`;

const cases: Case[] = [
  {
    name: "full-matrix",
    fixtures: [
      { filename: "run-1.xml", contents: FIXTURE_RUN1 },
      { filename: "run-2.xml", contents: FIXTURE_RUN2 },
      { filename: "run-3.json", contents: FIXTURE_RUN3 },
    ],
    // 5 + 3 + 4 = 12 cases. run-1: 4 passed + 1 skipped. run-2: 1 passed + 2 failed.
    // run-3: 3 passed + 1 skipped. -> passed=8, failed=2, skipped=2, total=12.
    // flaky: MathSuite::multiplies (pass+fail) and MathSuite::flaky network call (pass+fail) -> 2.
    expect: { passed: 8, failed: 2, skipped: 2, total: 12, flaky: 2, runs: 3 },
  },
  {
    name: "all-passing-json-only",
    fixtures: [{ filename: "run-3.json", contents: FIXTURE_RUN3 }],
    expect: { passed: 3, failed: 0, skipped: 1, total: 4, flaky: 0, runs: 1 },
  },
];

// Build a self-contained workspace so act sees a clean repo with the case's
// fixtures and nothing else from our dev tree.
function makeCaseRepo(c: Case): string {
  const dir = mkdtempSync(join(tmpdir(), `tra-${c.name}-`));
  for (const sub of ["src", "tests", "fixtures", ".github/workflows"]) {
    mkdirSync(join(dir, sub), { recursive: true });
  }
  // Copy code + workflow + config.
  cpSync(join(PROJECT_ROOT, "src"), join(dir, "src"), { recursive: true });
  cpSync(join(PROJECT_ROOT, ".github"), join(dir, ".github"), { recursive: true });
  cpSync(join(PROJECT_ROOT, "package.json"), join(dir, "package.json"));
  cpSync(join(PROJECT_ROOT, "tsconfig.json"), join(dir, "tsconfig.json"));
  cpSync(join(PROJECT_ROOT, ".actrc"), join(dir, ".actrc"));
  // Copy a single, minimal test so `bun test` in CI passes (and proves the harness works).
  cpSync(join(PROJECT_ROOT, "tests/parser.test.ts"), join(dir, "tests/parser.test.ts"));
  cpSync(join(PROJECT_ROOT, "tests/aggregate.test.ts"), join(dir, "tests/aggregate.test.ts"));
  cpSync(join(PROJECT_ROOT, "tests/markdown.test.ts"), join(dir, "tests/markdown.test.ts"));

  // Write the case-specific fixtures.
  for (const f of c.fixtures) {
    writeFileSync(join(dir, "fixtures", f.filename), f.contents);
  }
  // Init a git repo so `act push` has something to act on.
  for (const cmd of [
    ["git", "init", "-q", "-b", "main"],
    ["git", "config", "user.email", "ci@example.com"],
    ["git", "config", "user.name", "ci"],
    ["git", "add", "-A"],
    ["git", "commit", "-q", "-m", "init"],
  ]) {
    const r = spawnSync(cmd[0], cmd.slice(1), { cwd: dir });
    if (r.status !== 0) throw new Error(`${cmd.join(" ")} failed: ${r.stderr}`);
  }
  return dir;
}

function runAct(dir: string): { status: number | null; output: string } {
  // --artifact-server-path lets actions/upload-artifact@v4 work locally without a real GitHub backend.
  const artifactDir = join(dir, ".act-artifacts");
  mkdirSync(artifactDir, { recursive: true });
  const r = spawnSync(
    "act",
    ["push", "--rm", "--pull=false", "--artifact-server-path", artifactDir],
    { cwd: dir, encoding: "utf8", maxBuffer: 50 * 1024 * 1024 }
  );
  return { status: r.status, output: (r.stdout ?? "") + (r.stderr ?? "") };
}

describe("act pipeline", () => {
  for (const c of cases) {
    test(
      c.name,
      () => {
        const dir = makeCaseRepo(c);
        try {
          const { status, output } = runAct(dir);
          appendFileSync(
            ACT_OUTPUT_PATH,
            `\n========== CASE: ${c.name} (exit=${status}) ==========\n${output}\n========== END ${c.name} ==========\n`
          );

          expect(status).toBe(0);
          expect(output).toContain("Job succeeded");

          const expected =
            `AGG_SUMMARY passed=${c.expect.passed} failed=${c.expect.failed} ` +
            `skipped=${c.expect.skipped} total=${c.expect.total} ` +
            `flaky=${c.expect.flaky} runs=${c.expect.runs}`;
          expect(output).toContain(expected);
        } finally {
          rmSync(dir, { recursive: true, force: true });
        }
      },
      { timeout: 5 * 60 * 1000 }
    );
  }
});
