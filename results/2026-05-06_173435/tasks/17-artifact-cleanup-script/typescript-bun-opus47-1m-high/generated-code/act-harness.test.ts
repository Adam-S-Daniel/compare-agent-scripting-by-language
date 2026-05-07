// End-to-end harness: every test case executes the planner through the
// GitHub Actions workflow via `act`. We do NOT exercise cli.ts directly here;
// the unit tests in cleanup.test.ts cover the pure logic, and this harness
// asserts that the full pipeline (workflow + bun install + script + fixture)
// produces the exact known-good output.
//
// Each case:
//   1. Builds an isolated temp git repo containing project files + that case's
//      fixture pinned at fixtures/<dir>/.
//   2. Runs `act push --rm` and captures all output.
//   3. Appends the captured output to ./act-result.txt with a clear delimiter.
//   4. Asserts act exited 0, every job reported "Job succeeded", and the
//      RESULT line matches the case's expected.txt verbatim.

import { describe, test, expect, beforeAll } from "bun:test";

// Heavy: shells out to docker via act. Opt in with RUN_ACT_HARNESS=1 so plain
// `bun test` (used by editors / CI / pre-commit) stays fast.
const SHOULD_RUN = process.env.RUN_ACT_HARNESS === "1";
const guarded = SHOULD_RUN ? test : test.skip;
import {
  cpSync,
  existsSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
  appendFileSync,
} from "node:fs";
import { spawnSync, execSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const PROJECT_ROOT = resolve(import.meta.dir);
const ACT_RESULT_PATH = join(PROJECT_ROOT, "act-result.txt");

interface ActCase {
  name: string;          // fixture directory under fixtures/
  expectedResultLine: string; // the literal RESULT line we expect in stdout.
}

const CASES: ActCase[] = [
  {
    name: "combined",
    expectedResultLine:
      "RESULT mode=dry-run total=5 kept=2 deleted=3 reclaimed_bytes=700",
  },
  {
    name: "noop",
    expectedResultLine:
      "RESULT mode=dry-run total=2 kept=2 deleted=0 reclaimed_bytes=0",
  },
];

// Files (relative to PROJECT_ROOT) that the temp repo needs to run the workflow.
// We deliberately do NOT copy node_modules / act-result.txt / .git.
const REPO_FILES = [
  "package.json",
  "tsconfig.json",
  "cleanup.ts",
  "cleanup.test.ts",
  "cli.ts",
  ".github",
  ".actrc",
];

function runActOnce(caseName: string): { exitCode: number; output: string } {
  const tmp = mkdtempSync(join(tmpdir(), `act-cleanup-${caseName}-`));
  try {
    // Stage the project files.
    for (const f of REPO_FILES) {
      const src = join(PROJECT_ROOT, f);
      if (!existsSync(src)) continue;
      cpSync(src, join(tmp, f), { recursive: true });
    }
    // Stage just this case's fixture under fixtures/<name>/. The workflow's
    // FIXTURE_DIR env defaults to the case name, so we pass that through.
    const fixtureSrc = join(PROJECT_ROOT, "fixtures", caseName);
    const fixtureDst = join(tmp, "fixtures", caseName);
    cpSync(fixtureSrc, fixtureDst, { recursive: true });

    // act expects a git repo; init one and commit so `push` events have a sha.
    execSync("git init -q -b main", { cwd: tmp });
    execSync("git config user.email harness@example.com", { cwd: tmp });
    execSync("git config user.name harness", { cwd: tmp });
    execSync("git add -A", { cwd: tmp });
    execSync("git commit -q -m fixture", { cwd: tmp });

    // Pass FIXTURE_DIR via the env so the workflow targets this case.
    const result = spawnSync(
      "act",
      [
        "push",
        "--rm",
        // The platform image act-ubuntu-pwsh:latest is built locally and not
        // pushed to any registry. Disable the pull so act uses the local copy.
        "--pull=false",
        "--env",
        `FIXTURE_DIR=${caseName}`,
      ],
      {
        cwd: tmp,
        encoding: "utf8",
        // Match runner timeouts; act jobs typically <90s.
        timeout: 600_000,
      },
    );
    const output =
      `--- act stdout ---\n${result.stdout ?? ""}\n` +
      `--- act stderr ---\n${result.stderr ?? ""}\n`;
    return { exitCode: result.status ?? -1, output };
  } finally {
    // Best-effort cleanup of the temp repo.
    try {
      rmSync(tmp, { recursive: true, force: true });
    } catch {
      // ignore
    }
  }
}

beforeAll(() => {
  // Reset the result log so re-runs don't accumulate stale output. Only do
  // this when we'll actually populate it — otherwise a plain `bun test`
  // (which skips this suite) would clobber the artifact from a prior run.
  if (!SHOULD_RUN) return;
  writeFileSync(ACT_RESULT_PATH, "# act-result.txt — captured workflow output\n\n");
});

describe("act end-to-end pipeline", () => {
  for (const c of CASES) {
    guarded(
      `case "${c.name}" runs through the workflow with expected RESULT line`,
      () => {
        const { exitCode, output } = runActOnce(c.name);

        const banner =
          `\n========== CASE: ${c.name} (act exit=${exitCode}) ==========\n`;
        appendFileSync(ACT_RESULT_PATH, banner);
        appendFileSync(ACT_RESULT_PATH, output);
        appendFileSync(ACT_RESULT_PATH, `========== END CASE: ${c.name} ==========\n`);

        // act must succeed.
        expect(exitCode).toBe(0);

        // Every job must report success. We have 2 jobs (unit-tests, cleanup-plan)
        // so we expect at least one "Job succeeded" per job.
        const succeededCount = (output.match(/Job succeeded/g) ?? []).length;
        expect(succeededCount).toBeGreaterThanOrEqual(2);

        // Exact-value assertion on the planner's machine-readable RESULT line.
        expect(output).toContain(c.expectedResultLine);

        // act should not log any "Job failed" lines.
        expect(output).not.toContain("Job failed");
      },
      // Generous per-test timeout: bun install + workflow run can take a while.
      300_000,
    );
  }

  guarded("act-result.txt was written and contains every case", () => {
    expect(existsSync(ACT_RESULT_PATH)).toBe(true);
    const content = readFileSync(ACT_RESULT_PATH, "utf8");
    for (const c of CASES) {
      expect(content).toContain(`CASE: ${c.name}`);
      expect(content).toContain(c.expectedResultLine);
    }
  });
});
