// End-to-end harness: every scenario runs through the real workflow via act.
//
// Design:
// 1. Build a temp git repo for each scenario (copying project files + the
//    scenario's fixtures).
// 2. Run `act push --rm --env SCENARIO=<scenario>` once per scenario (3 runs
//    max — the harness must cap at 3 per benchmark rules).
// 3. Append each run's stdout/stderr to act-result.txt in the original cwd.
// 4. Parse the captured output and assert on EXACT expected values derived
//    from the fixtures — these are known-good counts, not substring checks.
//
// We also include workflow-structure tests that do not require act.
import { describe, expect, test, beforeAll } from "bun:test";
import { spawn } from "bun";
import { cp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

const ROOT = new URL("../..", import.meta.url).pathname;
const ACT_RESULT = join(ROOT, "act-result.txt");

// Skip act-invoking tests when running inside a GitHub Actions runner
// (including act itself, which sets GITHUB_ACTIONS=true). The harness spawns
// `act push`, which requires Docker on the host and would either recursively
// run in-container or outright fail. Workflow-structure tests still run in
// CI to validate the workflow file itself.
const IN_CI =
  process.env.GITHUB_ACTIONS === "true" || process.env.ACT === "true";
const describeActOnly = IN_CI ? describe.skip : describe;

// ---------------------------------------------------------------------------
// Expected results per scenario.
//
// These are computed by hand from the fixtures, so they serve as known-good
// values we can assert the workflow output against.
// ---------------------------------------------------------------------------

interface Expected {
  passed: number;
  failed: number;
  skipped: number;
  total: number;
  passRate: string;
  flaky: string[];
  consistentlyFailing: string[];
}

const EXPECTED: Record<string, Expected> = {
  // 6 tests total, all passing
  green: {
    passed: 6,
    failed: 0,
    skipped: 0,
    total: 6,
    passRate: "100.0%",
    flaky: [],
    consistentlyFailing: [],
  },
  // 6 tests. wobbly fails in run 1, passes in run 2 -> flaky
  flaky: {
    passed: 5,
    failed: 1,
    skipped: 0,
    total: 6,
    passRate: "83.3%",
    flaky: ["suite.b.wobbly"],
    consistentlyFailing: [],
  },
  // 4 tests. broken fails in both runs -> consistently failing
  "consistently-failing": {
    passed: 2,
    failed: 2,
    skipped: 0,
    total: 4,
    passRate: "50.0%",
    flaky: [],
    consistentlyFailing: ["suite.c.broken"],
  },
};

const SCENARIOS = Object.keys(EXPECTED);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function runCmd(
  cmd: string[],
  cwd: string,
  env?: Record<string, string>,
): Promise<{ code: number; stdout: string; stderr: string }> {
  const proc = spawn({
    cmd,
    cwd,
    env: { ...process.env, ...(env ?? {}) },
    stdout: "pipe",
    stderr: "pipe",
  });
  const [stdout, stderr] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
  ]);
  const code = await proc.exited;
  return { code, stdout, stderr };
}

async function buildScenarioRepo(scenario: string): Promise<string> {
  const dir = await (async () => {
    const d = join(tmpdir(), `act-harness-${scenario}-${Date.now()}`);
    await mkdir(d, { recursive: true });
    return d;
  })();

  // Copy the project files the workflow needs. The `tests` directory is
  // required too because the workflow's unit-tests job runs `bun test`.
  for (const name of [
    "package.json",
    "tsconfig.json",
    "bun.lock",
    "src",
    "tests",
    "fixtures",
    ".github",
    ".actrc",
  ]) {
    const from = join(ROOT, name);
    if (!existsSync(from)) continue;
    await cp(from, join(dir, name), { recursive: true });
  }

  // Initialize a git repo — act needs one to resolve event metadata.
  await runCmd(["git", "init", "-q", "-b", "main"], dir);
  await runCmd(["git", "config", "user.email", "harness@example.com"], dir);
  await runCmd(["git", "config", "user.name", "harness"], dir);
  await runCmd(["git", "add", "-A"], dir);
  await runCmd(["git", "commit", "-q", "-m", `scenario: ${scenario}`], dir);
  return dir;
}

/** Cache of act runs so the shared "this case's output" parsing re-uses one invocation. */
const actCache = new Map<string, { code: number; stdout: string; stderr: string }>();

async function runScenarioThroughAct(scenario: string): Promise<{
  code: number;
  stdout: string;
  stderr: string;
}> {
  if (actCache.has(scenario)) return actCache.get(scenario)!;

  const repoDir = await buildScenarioRepo(scenario);
  // --pull=false: the act-ubuntu-pwsh:latest image is a locally-built image
  // (see repo Dockerfile.act). Without this, act will try to pull it from
  // a registry and fail. -P binds ubuntu-latest to the local image.
  const result = await runCmd(
    [
      "act",
      "push",
      "--rm",
      "--pull=false",
      "-P",
      "ubuntu-latest=act-ubuntu-pwsh:latest",
      "--env",
      `SCENARIO=${scenario}`,
    ],
    repoDir,
  );

  // Append to act-result.txt in the original working directory. The entire
  // file is built up across scenarios so reviewers can see every run.
  const block = [
    "",
    "================================================================",
    `SCENARIO: ${scenario}`,
    `EXIT CODE: ${result.code}`,
    "----------------------------- STDOUT ---------------------------",
    result.stdout,
    "----------------------------- STDERR ---------------------------",
    result.stderr,
    "================================================================",
    "",
  ].join("\n");
  const prior = existsSync(ACT_RESULT) ? await readFile(ACT_RESULT, "utf8") : "";
  await writeFile(ACT_RESULT, prior + block, "utf8");

  actCache.set(scenario, result);
  // Clean up temp workspace.
  await rm(repoDir, { recursive: true, force: true });
  return result;
}

function extractScenarioBlock(output: string, scenario: string): string {
  // Our workflow prints `=== SCENARIO:<name> ===` and `=== END:<name> ===`
  // around the markdown so we can isolate just that section.
  const re = new RegExp(
    `=== SCENARIO:${scenario} ===([\\s\\S]*?)=== END:${scenario} ===`,
  );
  const m = output.match(re);
  return m ? m[1] : "";
}

// ---------------------------------------------------------------------------
// Setup: truncate act-result.txt at the start of the run so each suite run
// produces a fresh artifact.
// ---------------------------------------------------------------------------

beforeAll(async () => {
  await writeFile(ACT_RESULT, "# act harness results\n", "utf8");
});

// ---------------------------------------------------------------------------
// Workflow structure tests (no act required).
// ---------------------------------------------------------------------------

describe("workflow structure", () => {
  const workflowPath = join(ROOT, ".github", "workflows", "test-results-aggregator.yml");

  test("workflow file exists", () => {
    expect(existsSync(workflowPath)).toBe(true);
  });

  // actionlint is a host-side tool; the act container image does not ship it.
  // Skip the binary check in CI — all other structure assertions still run.
  test.skipIf(IN_CI)("actionlint passes cleanly", async () => {
    const { code, stdout, stderr } = await runCmd(
      ["actionlint", workflowPath],
      ROOT,
    );
    if (code !== 0) {
      console.error("actionlint stdout:", stdout);
      console.error("actionlint stderr:", stderr);
    }
    expect(code).toBe(0);
  });

  test("workflow declares the expected triggers", async () => {
    const text = await readFile(workflowPath, "utf8");
    expect(text).toMatch(/^\s*push:/m);
    expect(text).toMatch(/^\s*pull_request:/m);
    expect(text).toMatch(/^\s*workflow_dispatch:/m);
    expect(text).toMatch(/^\s*schedule:/m);
  });

  test("workflow declares unit-tests and aggregate jobs", async () => {
    const text = await readFile(workflowPath, "utf8");
    expect(text).toContain("unit-tests:");
    expect(text).toContain("aggregate:");
    expect(text).toMatch(/needs:\s*unit-tests/);
  });

  test("workflow references existing script path", async () => {
    const text = await readFile(workflowPath, "utf8");
    expect(text).toContain("src/index.ts");
    expect(existsSync(join(ROOT, "src", "index.ts"))).toBe(true);
  });

  test("workflow uses actions/checkout@v4", async () => {
    const text = await readFile(workflowPath, "utf8");
    expect(text).toContain("actions/checkout@v4");
  });

  test("scenario fixtures all exist", () => {
    for (const scenario of SCENARIOS) {
      const dir = join(ROOT, "fixtures", "scenarios", scenario);
      expect(existsSync(dir)).toBe(true);
    }
  });
});

// ---------------------------------------------------------------------------
// End-to-end act harness — runs the workflow for each scenario.
//
// NOTE: we respect the "at most 3 act push runs" limit by having exactly one
// act invocation per scenario (3 total).
// ---------------------------------------------------------------------------

describeActOnly("act harness", () => {
  for (const scenario of SCENARIOS) {
    const expected = EXPECTED[scenario];

    test(`scenario '${scenario}' exits 0 and prints expected totals`, async () => {
      const { code, stdout, stderr } = await runScenarioThroughAct(scenario);
      if (code !== 0) {
        console.error(`act stdout for ${scenario}:\n${stdout}`);
        console.error(`act stderr for ${scenario}:\n${stderr}`);
      }
      expect(code).toBe(0);

      // Every job must report success.
      const combined = stdout + "\n" + stderr;
      const successes = (combined.match(/Job succeeded/g) ?? []).length;
      expect(successes).toBeGreaterThanOrEqual(2);

      // Extract the summary markdown the aggregate step printed.
      const block = extractScenarioBlock(combined, scenario);
      expect(block.length).toBeGreaterThan(0);

      // Assert the exact totals row.
      const totalsLine = `| ${expected.passed} | ${expected.failed} | ${expected.skipped} | ${expected.total} |`;
      expect(block).toContain(totalsLine);

      // Pass rate is deterministic for these fixtures.
      expect(block).toContain(`**Pass rate:** ${expected.passRate}`);

      // Flaky section presence must match expectation.
      if (expected.flaky.length === 0) {
        expect(block).not.toContain("## Flaky Tests");
      } else {
        expect(block).toContain("## Flaky Tests");
        for (const name of expected.flaky) expect(block).toContain(name);
      }

      // Consistently-failing section presence must match expectation.
      if (expected.consistentlyFailing.length === 0) {
        expect(block).not.toContain("## Consistently Failing");
      } else {
        expect(block).toContain("## Consistently Failing");
        for (const name of expected.consistentlyFailing) expect(block).toContain(name);
      }
    }, 180_000);
  }

  test("act-result.txt artifact is written", async () => {
    // Depends on the scenario tests having run first. We require the file to
    // exist and contain each scenario's section.
    expect(existsSync(ACT_RESULT)).toBe(true);
    const text = await readFile(ACT_RESULT, "utf8");
    for (const scenario of SCENARIOS) {
      expect(text).toContain(`SCENARIO: ${scenario}`);
    }
  });
});
