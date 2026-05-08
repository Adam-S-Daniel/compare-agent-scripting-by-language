// End-to-end harness: runs the workflow under nektos/act for several
// fixture sets and asserts EXACT expected aggregation values.
//
// Per task spec:
//   * Each test case spins up an isolated temp git repo with the project files
//     plus that case's fixtures.
//   * `act push --rm` is invoked once per case.
//   * All output is appended (clearly delimited) to ./act-result.txt.
//   * We assert exit code 0, "Job succeeded", and the EXACT ::AGG:: line.
//   * Workflow structure tests (yaml shape, file refs, actionlint) are also here.
import { describe, expect, test, beforeAll } from "bun:test";
import {
  writeFileSync,
  appendFileSync,
  mkdtempSync,
  cpSync,
  mkdirSync,
  existsSync,
  readFileSync,
  statSync,
} from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { spawnSync } from "node:child_process";

const REPO_ROOT = import.meta.dir;
const ACT_RESULT = join(REPO_ROOT, "act-result.txt");

// Reset the aggregate result file once per run so artifacts are clean.
beforeAll(() => writeFileSync(ACT_RESULT, ""));

// Files that must be staged into the isolated act workspace.
const PROJECT_FILES = [
  "package.json",
  "bun.lock",
  "tsconfig.json",
  "src",
  ".github",
  ".actrc",
];

function setupRepo(fixtureFiles: Record<string, string>): string {
  const dir = mkdtempSync(join(tmpdir(), "act-agg-"));
  for (const f of PROJECT_FILES) {
    const src = join(REPO_ROOT, f);
    if (!existsSync(src)) continue;
    const dst = join(dir, f);
    const st = statSync(src);
    if (st.isDirectory()) cpSync(src, dst, { recursive: true });
    else cpSync(src, dst);
  }
  // Write per-case fixture files.
  mkdirSync(join(dir, "fixtures"), { recursive: true });
  for (const [name, content] of Object.entries(fixtureFiles)) {
    writeFileSync(join(dir, "fixtures", name), content);
  }
  // Initialize a git repo (act requires one).
  const git = (args: string[]) =>
    spawnSync("git", args, { cwd: dir, stdio: "ignore" });
  git(["init", "-q", "-b", "main"]);
  git(["config", "user.email", "t@t.t"]);
  git(["config", "user.name", "t"]);
  git(["add", "-A"]);
  git(["commit", "-q", "-m", "init"]);
  return dir;
}

interface ActResult {
  exitCode: number;
  stdout: string;
  stderr: string;
}

function runAct(repoDir: string, caseName: string): ActResult {
  const res = spawnSync("act", ["push", "--rm"], {
    cwd: repoDir,
    encoding: "utf8",
    timeout: 5 * 60 * 1000,
  });
  const banner = `\n===== CASE: ${caseName} =====\n`;
  appendFileSync(
    ACT_RESULT,
    banner +
      `[stdout]\n${res.stdout ?? ""}\n[stderr]\n${res.stderr ?? ""}\n[exit] ${res.status}\n`,
  );
  return {
    exitCode: res.status ?? -1,
    stdout: res.stdout ?? "",
    stderr: res.stderr ?? "",
  };
}

interface Expected {
  passed: number;
  failed: number;
  skipped: number;
  flaky: number;
  runs: number;
}

function assertAct(out: string, exitCode: number, expected: Expected) {
  expect(exitCode).toBe(0);
  expect(out).toContain("Job succeeded");
  // The CLI prints a single canonical status line we anchor on.
  const expectedLine = `::AGG:: passed=${expected.passed} failed=${expected.failed} skipped=${expected.skipped} flaky=${expected.flaky} runs=${expected.runs}`;
  expect(out).toContain(expectedLine);
}

// --- Workflow structure tests ------------------------------------------
describe("workflow structure", () => {
  const wfPath = join(REPO_ROOT, ".github/workflows/test-results-aggregator.yml");
  const wfText = readFileSync(wfPath, "utf8");

  test("references files that exist", () => {
    expect(existsSync(join(REPO_ROOT, "src/cli.ts"))).toBe(true);
    expect(existsSync(join(REPO_ROOT, "src/aggregator.ts"))).toBe(true);
    expect(existsSync(join(REPO_ROOT, "package.json"))).toBe(true);
    expect(wfText).toContain("src/cli.ts");
  });

  test("declares expected triggers and jobs", () => {
    expect(wfText).toMatch(/^on:/m);
    expect(wfText).toContain("push:");
    expect(wfText).toContain("pull_request:");
    expect(wfText).toContain("workflow_dispatch:");
    expect(wfText).toContain("schedule:");
    expect(wfText).toMatch(/^jobs:/m);
    expect(wfText).toContain("actions/checkout@v4");
    expect(wfText).toContain("oven-sh/setup-bun@v2");
  });

  test("actionlint passes", () => {
    const r = spawnSync("actionlint", [wfPath], { encoding: "utf8" });
    expect(r.status).toBe(0);
  });
});

// --- act-driven cases ---------------------------------------------------
describe("act-driven aggregation cases", () => {
  // Case A: the canonical 3-run fixture set we already validated locally.
  test("3-run mixed JUnit + JSON: 10/2/3 with 2 flaky", () => {
    const dir = setupRepo({
      "run-1-junit.xml": readFileSync(
        join(REPO_ROOT, "fixtures/run-1-junit.xml"),
        "utf8",
      ),
      "run-2-junit.xml": readFileSync(
        join(REPO_ROOT, "fixtures/run-2-junit.xml"),
        "utf8",
      ),
      "run-3-results.json": readFileSync(
        join(REPO_ROOT, "fixtures/run-3-results.json"),
        "utf8",
      ),
    });
    const r = runAct(dir, "3-run-mixed");
    assertAct(r.stdout, r.exitCode, {
      passed: 10,
      failed: 2,
      skipped: 3,
      flaky: 2,
      runs: 3,
    });
  }, 5 * 60 * 1000);

  // Case B: All-passing single run, no flakies.
  test("single all-green JSON run: 4 passed, 0 flaky", () => {
    const dir = setupRepo({
      "only.json": JSON.stringify({
        tests: [
          { suite: "core", name: "a", status: "passed", duration: 0.1 },
          { suite: "core", name: "b", status: "passed", duration: 0.2 },
          { suite: "core", name: "c", status: "passed", duration: 0.3 },
          { suite: "ext", name: "d", status: "passed", duration: 0.4 },
        ],
      }),
    });
    const r = runAct(dir, "single-all-green");
    assertAct(r.stdout, r.exitCode, {
      passed: 4,
      failed: 0,
      skipped: 0,
      flaky: 0,
      runs: 1,
    });
  }, 5 * 60 * 1000);

  // Case C: Two runs, one flaky, one consistently failing.
  test("two JUnit runs: flaky vs consistent failure", () => {
    const xmlA = `<?xml version="1.0"?><testsuites>
      <testsuite name="t" tests="2" failures="1">
        <testcase classname="t" name="flaky" time="0.1"><failure message="x">x</failure></testcase>
        <testcase classname="t" name="always_bad" time="0.2"><failure message="y">y</failure></testcase>
      </testsuite></testsuites>`;
    const xmlB = `<?xml version="1.0"?><testsuites>
      <testsuite name="t" tests="2" failures="1">
        <testcase classname="t" name="flaky" time="0.1"/>
        <testcase classname="t" name="always_bad" time="0.2"><failure message="y">y</failure></testcase>
      </testsuite></testsuites>`;
    const dir = setupRepo({ "a.xml": xmlA, "b.xml": xmlB });
    const r = runAct(dir, "flaky-vs-consistent");
    // a: 0 passed, 2 failed; b: 1 passed (flaky), 1 failed.
    // Totals: passed=1, failed=3, skipped=0, flaky=1 (only "flaky"), runs=2.
    assertAct(r.stdout, r.exitCode, {
      passed: 1,
      failed: 3,
      skipped: 0,
      flaky: 1,
      runs: 2,
    });
  }, 5 * 60 * 1000);
});
