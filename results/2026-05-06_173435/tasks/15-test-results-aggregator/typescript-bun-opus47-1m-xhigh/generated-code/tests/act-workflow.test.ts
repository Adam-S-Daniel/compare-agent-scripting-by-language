// End-to-end workflow tests via nektos/act.
//
// For each test case we:
//   1. Build a temporary git repo containing all of the project's source +
//      that case's fixtures placed under ./test-input/.
//   2. Run `act push --rm` from inside the temp dir.
//   3. Capture combined stdout/stderr, append it to act-result.txt with a
//      delimiter, and assert on the exit code, "Job succeeded", and exact
//      expected values from the aggregator output.
//
// Skipped automatically when SKIP_ACT_TESTS=1 is set, which is the case when
// `bun test` runs *inside* the workflow itself (we'd otherwise recurse into
// act-in-act forever).
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { spawnSync } from "node:child_process";
import {
  appendFileSync,
  cpSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const PROJECT_ROOT = resolve(import.meta.dir, "..");
const ACT_RESULT_PATH = join(PROJECT_ROOT, "act-result.txt");
const SHOULD_SKIP = process.env.SKIP_ACT_TESTS === "1";
const describeOrSkip = SHOULD_SKIP ? describe.skip : describe;

// Items copied from the project root into each temp repo. Intentionally lists
// only what the workflow needs — keeps temp repos small and avoids picking up
// transient files like node_modules/ or act-result.txt itself.
const COPY_ITEMS = [
  "src",
  "tests",
  ".github",
  ".actrc",
  "package.json",
  "tsconfig.json",
  ".gitignore",
];

interface TestCase {
  name: string;
  fixtureDir: string;
  // Pieces of the rendered markdown summary that, taken together, uniquely
  // identify the correct output for this fixture set.
  expectedSummaryContains: string[];
  // Fragments that must NOT appear (used to assert e.g. "no Flaky Tests").
  expectedSummaryAbsent?: string[];
}

const CASES: TestCase[] = [
  {
    name: "all-passing",
    fixtureDir: join(PROJECT_ROOT, "fixtures/all-passing"),
    expectedSummaryContains: [
      "**Status:** PASSED",
      "Aggregated across 2 runs.",
      "| Total | 5 |",
      "| Passed | 5 |",
      "| Failed | 0 |",
      "| Skipped | 0 |",
      "| Duration | 0.55s |",
      "| run-1.xml | 3 | 0 | 0 | 0.45s |",
      "| run-2.xml | 2 | 0 | 0 | 0.10s |",
    ],
    expectedSummaryAbsent: ["## Flaky Tests", "## Failing Tests"],
  },
  {
    name: "with-flaky",
    fixtureDir: join(PROJECT_ROOT, "fixtures/with-flaky"),
    expectedSummaryContains: [
      "**Status:** FAILED",
      "Aggregated across 3 runs.",
      "| Total | 9 |",
      "| Passed | 6 |",
      "| Failed | 3 |",
      "| Duration | 2.70s |",
      "## Flaky Tests",
      "Detected 2 flaky tests",
      "| ApiSuite.create | 1 | 2 | 3 |",
      "| ApiSuite.flaky_login | 2 | 1 | 3 |",
    ],
  },
  {
    name: "mixed",
    fixtureDir: join(PROJECT_ROOT, "fixtures/mixed"),
    expectedSummaryContains: [
      "**Status:** FAILED",
      "Aggregated across 2 runs.",
      "| Total | 6 |",
      "| Passed | 4 |",
      "| Failed | 1 |",
      "| Skipped | 1 |",
      "| Duration | 2.60s |",
      "## Failing Tests",
      "| IntegrationSuite.queue_publish | broker refused connection |",
      "| junit-run.xml | 2 | 0 | 1 | 0.10s |",
      "| integration-run.json | 2 | 1 | 0 | 2.50s |",
    ],
    expectedSummaryAbsent: ["## Flaky Tests"],
  },
];

function shellOk(cmd: string, args: string[], cwd: string): void {
  const r = spawnSync(cmd, args, { cwd, stdio: "pipe", encoding: "utf8" });
  if (r.status !== 0) {
    throw new Error(
      `command failed (${cmd} ${args.join(" ")}): exit ${r.status}\n${r.stdout}\n${r.stderr}`,
    );
  }
}

function setupTempRepo(testCase: TestCase): string {
  const tmpRoot = mkdtempSync(join(tmpdir(), `tra-${testCase.name}-`));
  // Copy project files needed to run the workflow.
  for (const item of COPY_ITEMS) {
    const src = join(PROJECT_ROOT, item);
    if (!existsSync(src)) continue;
    cpSync(src, join(tmpRoot, item), { recursive: true });
  }
  // Place this case's fixtures into the well-known path the workflow reads.
  const inputDir = join(tmpRoot, "test-input");
  mkdirSync(inputDir, { recursive: true });
  cpSync(testCase.fixtureDir, inputDir, { recursive: true });
  // act push needs a real git repo with at least one commit. Use a local
  // identity (env vars override missing ~/.gitconfig in CI sandboxes).
  const gitEnv = {
    ...process.env,
    GIT_AUTHOR_NAME: "test",
    GIT_AUTHOR_EMAIL: "test@example.com",
    GIT_COMMITTER_NAME: "test",
    GIT_COMMITTER_EMAIL: "test@example.com",
  };
  const runGit = (args: string[]): void => {
    const r = spawnSync("git", args, {
      cwd: tmpRoot,
      env: gitEnv,
      stdio: "pipe",
      encoding: "utf8",
    });
    if (r.status !== 0) {
      throw new Error(
        `git ${args.join(" ")} failed: exit ${r.status}\n${r.stdout}\n${r.stderr}`,
      );
    }
  };
  runGit(["init", "-q", "-b", "main"]);
  runGit(["add", "."]);
  runGit(["commit", "-q", "-m", "fixture commit"]);
  void shellOk; // keep the ergonomic helper available even if unused later
  return tmpRoot;
}

function runActPush(cwd: string): { stdout: string; status: number } {
  const r = spawnSync("act", ["push", "--rm"], {
    cwd,
    stdio: "pipe",
    encoding: "utf8",
    // act + Docker can be slow to pull/start the image. 5 minutes per run is
    // generous; failures usually surface inside the first 60 seconds.
    timeout: 5 * 60 * 1000,
  });
  // Combine into one stream so the saved log shows interleaved output.
  const combined = `${r.stdout ?? ""}${r.stderr ?? ""}`;
  return { stdout: combined, status: r.status ?? -1 };
}

function appendActLog(testCaseName: string, content: string, status: number): void {
  const header = [
    "",
    "================================================================",
    `=== TEST CASE: ${testCaseName}  (act exit code ${status})`,
    "================================================================",
    "",
  ].join("\n");
  appendFileSync(ACT_RESULT_PATH, header + content + "\n");
}

function extractSummary(actOutput: string): string {
  // The workflow brackets the summary with explicit markers so we can pull it
  // out of act's noisy log without depending on internal formatting.
  const begin = actOutput.indexOf("===AGGREGATOR_SUMMARY_BEGIN===");
  const end = actOutput.indexOf("===AGGREGATOR_SUMMARY_END===");
  if (begin === -1 || end === -1 || end < begin) {
    return "";
  }
  return actOutput.slice(begin, end);
}

beforeAll(() => {
  if (SHOULD_SKIP) return;
  // Reset act-result.txt so each `bun test` invocation produces a fresh log.
  writeFileSync(
    ACT_RESULT_PATH,
    `# act test harness output — generated ${new Date().toISOString()}\n`,
  );
});

const tempDirsToClean: string[] = [];
afterAll(() => {
  for (const dir of tempDirsToClean) {
    try {
      rmSync(dir, { recursive: true, force: true });
    } catch {
      // best-effort cleanup; leftover temp dirs are harmless
    }
  }
});

describeOrSkip("workflow runs through act for each fixture", () => {
  for (const tc of CASES) {
    test(
      `case "${tc.name}" succeeds and emits the expected summary`,
      () => {
        const tmpRoot = setupTempRepo(tc);
        tempDirsToClean.push(tmpRoot);
        const { stdout, status } = runActPush(tmpRoot);
        appendActLog(tc.name, stdout, status);

        // Hard requirements from the task spec:
        expect(status).toBe(0);
        expect(stdout).toContain("Job succeeded");

        const summary = extractSummary(stdout);
        expect(summary.length).toBeGreaterThan(0);
        for (const fragment of tc.expectedSummaryContains) {
          expect(summary).toContain(fragment);
        }
        for (const fragment of tc.expectedSummaryAbsent ?? []) {
          expect(summary).not.toContain(fragment);
        }
      },
      // Per-test timeout of 6 minutes — first run pulls a Docker image the
      // first time, subsequent runs are faster.
      6 * 60 * 1000,
    );
  }
});
