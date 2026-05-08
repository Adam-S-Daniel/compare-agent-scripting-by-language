// End-to-end tests that exercise the GitHub Actions workflow via `act`.
//
// For each fixture under tests/fixtures/, the harness:
//   1. Creates a fresh tmp dir,
//   2. Copies the project's source + workflow + that fixture's package.json
//      and commits.txt into it,
//   3. Initializes a git repo so act has something to dispatch on,
//   4. Runs `act push --rm`,
//   5. Appends the captured output to act-result.txt with delimiters,
//   6. Asserts: exit code 0, "Job succeeded", and EXACT expected
//      OLD_VERSION / NEW_VERSION / BUMP_TYPE lines.
//
// The harness deliberately does NOT copy the act.test.ts or the workflow
// structure tests into the temp repo — that would either recurse (infinite
// act-in-act) or break (no actionlint inside the container).

import { describe, expect, test, beforeAll } from "bun:test";
import {
  mkdtempSync, mkdirSync, copyFileSync, readdirSync, statSync,
  writeFileSync, readFileSync, appendFileSync, rmSync,
} from "node:fs";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join } from "node:path";

const REPO_ROOT = join(import.meta.dir, "..");
const ACT_RESULT = join(REPO_ROOT, "act-result.txt");
const FIXTURES_DIR = join(REPO_ROOT, "tests", "fixtures");

interface Expected {
  old: string;
  new: string;
  bump: "major" | "minor" | "patch" | "none";
}

// We're capped at ~3 act invocations during development; cover the three
// bump types exhaustively (no-bump is exercised by the bun-only CLI tests).
const CASES = ["feat-minor", "fix-patch", "breaking-major"] as const;

function copyDir(src: string, dst: string): void {
  mkdirSync(dst, { recursive: true });
  for (const entry of readdirSync(src)) {
    const srcPath = join(src, entry);
    const dstPath = join(dst, entry);
    if (statSync(srcPath).isDirectory()) {
      copyDir(srcPath, dstPath);
    } else {
      copyFileSync(srcPath, dstPath);
    }
  }
}

function setupTempRepo(fixture: string): string {
  const tmp = mkdtempSync(join(tmpdir(), `svb-act-${fixture}-`));

  // Project files the workflow actually needs at runtime.
  copyFileSync(join(REPO_ROOT, "tsconfig.json"), join(tmp, "tsconfig.json"));
  copyFileSync(join(REPO_ROOT, ".actrc"), join(tmp, ".actrc"));
  copyDir(join(REPO_ROOT, "src"), join(tmp, "src"));

  // Only the unit tests get copied — the workflow runs only those.
  mkdirSync(join(tmp, "tests"));
  copyFileSync(join(REPO_ROOT, "tests", "lib.test.ts"), join(tmp, "tests", "lib.test.ts"));
  copyFileSync(join(REPO_ROOT, "tests", "cli.test.ts"), join(tmp, "tests", "cli.test.ts"));

  mkdirSync(join(tmp, ".github", "workflows"), { recursive: true });
  copyFileSync(
    join(REPO_ROOT, ".github", "workflows", "semantic-version-bumper.yml"),
    join(tmp, ".github", "workflows", "semantic-version-bumper.yml"),
  );

  // Per-fixture starting state — these are what the workflow consumes.
  copyFileSync(join(FIXTURES_DIR, fixture, "package.json"), join(tmp, "package.json"));
  copyFileSync(join(FIXTURES_DIR, fixture, "commits.txt"), join(tmp, "commits.txt"));

  // act needs the directory to be a git repo (it dispatches a "push" event).
  const git = (args: string[]) => spawnSync("git", args, { cwd: tmp });
  git(["init", "-q", "-b", "main"]);
  git(["config", "user.email", "test@example.com"]);
  git(["config", "user.name", "test"]);
  git(["add", "-A"]);
  git(["commit", "-q", "-m", `fixture: ${fixture}`]);

  return tmp;
}

function appendCaseOutput(fixture: string, code: number | null, stdout: string, stderr: string): void {
  const sep = "=".repeat(80);
  const block = [
    "",
    sep,
    `## Fixture: ${fixture}`,
    `## Exit code: ${code}`,
    sep,
    "### stdout",
    stdout,
    "### stderr",
    stderr,
    sep,
    "",
  ].join("\n");
  appendFileSync(ACT_RESULT, block);
}

describe("act end-to-end (workflow runs through the actual pipeline)", () => {
  beforeAll(() => {
    // Start each harness run with a fresh artifact file.
    writeFileSync(ACT_RESULT, "# act-result.txt\n# Output captured from `act push --rm` per fixture.\n");
  });

  test.each(CASES)(
    "fixture %s: workflow runs cleanly and produces the expected version",
    async (fixture) => {
      const expected: Expected = JSON.parse(
        readFileSync(join(FIXTURES_DIR, fixture, "expected.json"), "utf8"),
      );

      const tmp = setupTempRepo(fixture);
      try {
        const result = spawnSync(
          "act",
          [
            "push",
            "--rm",
            "--pull=false", // use the locally-built act-ubuntu-pwsh image
            "--workflows", ".github/workflows/semantic-version-bumper.yml",
          ],
          { cwd: tmp, encoding: "utf8", maxBuffer: 50 * 1024 * 1024 },
        );

        appendCaseOutput(fixture, result.status, result.stdout ?? "", result.stderr ?? "");

        expect(result.status).toBe(0);

        const combined = (result.stdout ?? "") + "\n" + (result.stderr ?? "");
        // Exact-match assertions on the values our CLI prints.
        expect(combined).toContain(`OLD_VERSION=${expected.old}`);
        expect(combined).toContain(`NEW_VERSION=${expected.new}`);
        expect(combined).toContain(`BUMP_TYPE=${expected.bump}`);
        // act prints "Job succeeded" once per job that finishes cleanly.
        expect(combined).toContain("Job succeeded");
      } finally {
        rmSync(tmp, { recursive: true, force: true });
      }
    },
    600_000, // 10 min — single act run is ~30-90s, generous to absorb cold-start noise.
  );
});
