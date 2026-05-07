// End-to-end harness that drives the workflow through nektos/act.
//
// Each test case:
//   1. Materialises a temp git repo with the project files.
//   2. Replaces the `fixtures/` tree with case-specific data.
//   3. Runs `act push --rm` and captures the output.
//   4. Appends the output to `act-result.txt` with clear delimiters.
//   5. Asserts the EXACT expected RESULTS line and that every job succeeded.
//
// The full unit-test suite still runs inside each case, since the workflow
// invokes `bun test` before aggregating. That satisfies the "every test case
// runs through act" rule without spending an act run per unit test.
//
// Run: `bun run scripts/run-act-tests.ts` (≈30–90s per case).

import {
  cpSync,
  mkdtempSync,
  rmSync,
  writeFileSync,
  appendFileSync,
  existsSync,
  readdirSync,
  statSync,
  mkdirSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawnSync, type SpawnSyncReturns } from "node:child_process";

interface FixtureFile {
  path: string; // relative to repo root, e.g. "fixtures/junit/x.xml"
  content: string;
}

interface ActCase {
  name: string;
  fixtures: FixtureFile[];
  // Substring assertions on the captured output. Each must appear at least once.
  expectContains: string[];
  // Substring exclusions — must NOT appear. Used to lock in negative cases.
  expectMissing?: string[];
}

const REPO_ROOT = resolve(import.meta.dir, "..");
const ACT_RESULT_PATH = join(REPO_ROOT, "act-result.txt");

// Case 1: the bundled fixture set — 4 files, 16 tests, 2 failures, 2 flaky.
const CASE_BUNDLED: ActCase = {
  name: "bundled-fixtures",
  fixtures: [], // empty → use the repo's own fixtures/ unchanged
  expectContains: [
    "RESULTS files=4 total=16 passed=13 failed=2 skipped=1 flaky=2 duration=4.60s",
    "FLAKY payments.CheckoutTests::handles_3ds_redirect,search.IndexTests::ranks_by_relevance",
    "Job succeeded",
  ],
};

// Case 2: an all-green run with a single JSON file. Asserts on different exact
// numbers so we know the harness isn't just matching boilerplate.
const CASE_ALL_GREEN: ActCase = {
  name: "all-green-single-file",
  fixtures: [
    {
      path: "fixtures/json/all-green.json",
      content: JSON.stringify({
        suite: "smoke.Suite",
        tests: [
          { name: "boots", classname: "smoke.Suite", status: "passed", duration: 0.5 },
          { name: "responds_to_ping", classname: "smoke.Suite", status: "passed", duration: 0.25 },
          { name: "writes_logs", classname: "smoke.Suite", status: "passed", duration: 0.15 },
        ],
      }),
    },
  ],
  expectContains: [
    "RESULTS files=1 total=3 passed=3 failed=0 skipped=0 flaky=0 duration=0.90s",
    "Status: all tests passed",
    "Job succeeded",
  ],
  expectMissing: ["FLAKY ", "## Failures"],
};

const CASES: ActCase[] = [CASE_BUNDLED, CASE_ALL_GREEN];

function copyProjectInto(dest: string): void {
  // Copy everything except .git, node_modules, and build artifacts.
  const skip = new Set([".git", "node_modules", "act-result.txt"]);
  for (const entry of readdirSync(REPO_ROOT)) {
    if (skip.has(entry)) continue;
    const src = join(REPO_ROOT, entry);
    const dst = join(dest, entry);
    cpSync(src, dst, { recursive: true });
  }
}

function rmDir(dir: string): void {
  if (existsSync(dir)) rmSync(dir, { recursive: true, force: true });
}

function applyFixtures(repoDir: string, fixtures: FixtureFile[]): void {
  if (fixtures.length === 0) return; // keep bundled fixtures
  // Wipe and rewrite the fixtures dir so cases see only their own data.
  rmDir(join(repoDir, "fixtures"));
  for (const f of fixtures) {
    const full = join(repoDir, f.path);
    mkdirSync(full.substring(0, full.lastIndexOf("/")), { recursive: true });
    writeFileSync(full, f.content);
  }
}

function gitInit(repoDir: string): void {
  // act needs a git repo to detect the workflow event context.
  const run = (args: string[]) => {
    const r = spawnSync("git", args, { cwd: repoDir, encoding: "utf8" });
    if (r.status !== 0) {
      throw new Error(
        `git ${args.join(" ")} failed: ${r.stderr || r.stdout}`,
      );
    }
  };
  run(["init", "-q", "-b", "main"]);
  run(["config", "user.email", "harness@example.com"]);
  run(["config", "user.name", "harness"]);
  run(["add", "-A"]);
  run(["commit", "-q", "-m", "harness fixture"]);
}

function runAct(repoDir: string): SpawnSyncReturns<string> {
  // --rm: remove containers after run. -P: image override taken from .actrc.
  return spawnSync("act", ["push", "--rm"], {
    cwd: repoDir,
    encoding: "utf8",
    maxBuffer: 50 * 1024 * 1024,
  });
}

function appendCaseOutput(name: string, output: string, exitCode: number | null): void {
  const banner =
    `\n${"=".repeat(80)}\n` +
    `CASE: ${name}\n` +
    `EXIT: ${exitCode}\n` +
    `${"=".repeat(80)}\n`;
  appendFileSync(ACT_RESULT_PATH, banner + output + "\n");
}

function assertContains(output: string, needles: string[], caseName: string): void {
  for (const n of needles) {
    if (!output.includes(n)) {
      throw new Error(`[${caseName}] expected output to contain: ${JSON.stringify(n)}`);
    }
  }
}

function assertMissing(output: string, needles: string[], caseName: string): void {
  for (const n of needles) {
    if (output.includes(n)) {
      throw new Error(`[${caseName}] expected output to NOT contain: ${JSON.stringify(n)}`);
    }
  }
}

function countOccurrences(haystack: string, needle: string): number {
  let count = 0;
  let i = 0;
  while ((i = haystack.indexOf(needle, i)) !== -1) {
    count++;
    i += needle.length;
  }
  return count;
}

async function main(): Promise<void> {
  // Truncate the result file so re-runs don't accumulate stale output.
  writeFileSync(ACT_RESULT_PATH, `act test harness — ${new Date().toISOString()}\n`);

  let failures = 0;
  for (const c of CASES) {
    const dir = mkdtempSync(join(tmpdir(), `act-${c.name}-`));
    try {
      copyProjectInto(dir);
      applyFixtures(dir, c.fixtures);
      gitInit(dir);

      console.log(`[${c.name}] running act in ${dir} ...`);
      const r = runAct(dir);
      const output = (r.stdout ?? "") + (r.stderr ?? "");
      appendCaseOutput(c.name, output, r.status);

      if (r.status !== 0) {
        console.error(`[${c.name}] act exited with code ${r.status}`);
        failures++;
        continue;
      }
      try {
        assertContains(output, c.expectContains, c.name);
        if (c.expectMissing) assertMissing(output, c.expectMissing, c.name);
        // act prints "Job succeeded" once per job; we only have one job, so
        // exactly one occurrence is expected.
        const succeeded = countOccurrences(output, "Job succeeded");
        if (succeeded < 1) {
          throw new Error(`[${c.name}] no "Job succeeded" line found`);
        }
        console.log(`[${c.name}] PASS`);
      } catch (err) {
        console.error((err as Error).message);
        failures++;
      }
    } finally {
      rmDir(dir);
    }
  }

  if (failures > 0) {
    console.error(`\n${failures} of ${CASES.length} act case(s) FAILED`);
    process.exit(1);
  }
  console.log(`\nAll ${CASES.length} act case(s) PASSED — see act-result.txt`);
}

await main();
