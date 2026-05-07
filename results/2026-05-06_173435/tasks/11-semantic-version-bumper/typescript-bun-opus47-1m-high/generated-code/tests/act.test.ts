// End-to-end harness: every test case runs through `act push --rm` against a
// throwaway git working copy of the project, with the relevant fixture data
// pre-staged. We capture the act output for each case and append it (clearly
// delimited) to act-result.txt at the project root, then assert on EXACT values
// parsed out of the run.
//
// This file performs all act runs from a single `beforeAll` and shares output
// across the per-case tests. That keeps us under the "≤ 3 act runs" budget
// (we do exactly 3 cases here: feat -> minor, breaking -> major, fix -> patch)
// while still asserting per case.

import { beforeAll, describe, expect, test } from "bun:test";
import { spawnSync } from "node:child_process";
import {
  cpSync,
  existsSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const ACT_RESULT_FILE = resolve(ROOT, "act-result.txt");

interface CaseDef {
  name: string;
  // Initial package.json version we plant into the throwaway repo
  startingVersion: string;
  // Fixture file basename in fixtures/, used to seed fixtures/commits.txt
  fixture: "feat" | "fix" | "breaking" | "none";
  expectedBump: "major" | "minor" | "patch" | "none";
  expectedNewVersion: string;
}

const CASES: CaseDef[] = [
  {
    name: "feat -> minor (1.1.0 -> 1.2.0)",
    startingVersion: "1.1.0",
    fixture: "feat",
    expectedBump: "minor",
    expectedNewVersion: "1.2.0",
  },
  {
    name: "breaking -> major (1.4.2 -> 2.0.0)",
    startingVersion: "1.4.2",
    fixture: "breaking",
    expectedBump: "major",
    expectedNewVersion: "2.0.0",
  },
  {
    name: "fix-only -> patch (0.5.0 -> 0.5.1)",
    startingVersion: "0.5.0",
    fixture: "fix",
    expectedBump: "patch",
    expectedNewVersion: "0.5.1",
  },
];

interface RunOutcome {
  exitCode: number;
  output: string;
}

const outcomes = new Map<string, RunOutcome>();

function setupTempProject(c: CaseDef): string {
  const dir = mkdtempSync(resolve(tmpdir(), `act-svb-${c.fixture}-`));
  // Copy everything from the project except node_modules / .git / huge artifacts.
  cpSync(ROOT, dir, {
    recursive: true,
    filter: (src) => {
      const rel = src.slice(ROOT.length);
      if (rel === "" || rel === "/") return true;
      // Use exact "/.git" + boundary, NOT startsWith("/.git") — that would also
      // exclude "/.github" (workflow dir). Boundary = end-of-string or "/".
      if (rel === "/node_modules" || rel.startsWith("/node_modules/")) return false;
      if (rel === "/.git" || rel.startsWith("/.git/")) return false;
      if (rel === "/act-result.txt") return false;
      if (rel === "/CHANGELOG.md") return false;
      if (rel === "/bun.lockb" || rel === "/bun.lock") return false;
      return true;
    },
  });

  // Plant the starting version
  const pkgPath = resolve(dir, "package.json");
  const pkg = JSON.parse(readFileSync(pkgPath, "utf8")) as Record<string, unknown>;
  pkg.version = c.startingVersion;
  writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + "\n", "utf8");

  // Seed fixtures/commits.txt from the named fixture so the workflow uses it directly.
  const fixtureSrc = resolve(dir, `fixtures/commits-${c.fixture}.txt`);
  const fixtureDst = resolve(dir, "fixtures/commits.txt");
  cpSync(fixtureSrc, fixtureDst);

  // act needs a git repo to checkout from. Initialize a minimal one.
  const git = (args: string[]) =>
    spawnSync("git", args, { cwd: dir, encoding: "utf8" });
  git(["init", "-q", "-b", "main"]);
  git(["config", "user.email", "test@example.com"]);
  git(["config", "user.name", "Test"]);
  git(["add", "-A"]);
  git(["commit", "-q", "-m", "seed"]);
  return dir;
}

beforeAll(() => {
  // Reset the result artifact.
  writeFileSync(
    ACT_RESULT_FILE,
    `# act results — generated ${new Date().toISOString()}\n`,
    "utf8",
  );

  for (const c of CASES) {
    const dir = setupTempProject(c);
    const banner =
      `\n========================================================================\n` +
      `CASE: ${c.name}\n` +
      `  starting_version=${c.startingVersion}\n` +
      `  fixture=${c.fixture}\n` +
      `  expected_bump=${c.expectedBump}\n` +
      `  expected_new_version=${c.expectedNewVersion}\n` +
      `  workdir=${dir}\n` +
      `========================================================================\n`;

    // The .actrc inside `dir` already pins -P ubuntu-latest=act-ubuntu-pwsh:latest
    // --pull=false: the runner image (`act-ubuntu-pwsh`) is local-only;
    //               act would otherwise attempt a registry pull and fail.
    // --action-offline-mode: avoids slow re-fetching of action repos when present
    //               in the act cache; it's a perf hint, not a correctness one.
    const result = spawnSync(
      "act",
      [
        "push",
        "--rm",
        "--pull=false",
        "-W",
        ".github/workflows/semantic-version-bumper.yml",
      ],
      {
        cwd: dir,
        encoding: "utf8",
        env: { ...process.env, FIXTURE: c.fixture },
        // act runs can be slow; allow up to 5 min per case.
        timeout: 5 * 60 * 1000,
        maxBuffer: 50 * 1024 * 1024,
      },
    );
    const stdout = result.stdout ?? "";
    const stderr = result.stderr ?? "";
    const combined = `${banner}--- STDOUT ---\n${stdout}\n--- STDERR ---\n${stderr}\n--- EXIT: ${result.status} ---\n`;

    // Append to the result artifact so the user can inspect every run after the suite.
    const fs = require("node:fs") as typeof import("node:fs");
    fs.appendFileSync(ACT_RESULT_FILE, combined, "utf8");

    outcomes.set(c.name, {
      exitCode: result.status ?? -1,
      output: stdout + "\n" + stderr,
    });

    // Cleanup throwaway worktree.
    rmSync(dir, { recursive: true, force: true });
  }
});

describe("act push runs", () => {
  test("produced act-result.txt", () => {
    expect(existsSync(ACT_RESULT_FILE)).toBe(true);
  });

  for (const c of CASES) {
    test(`${c.name}: act exits 0`, () => {
      const o = outcomes.get(c.name);
      expect(o).toBeDefined();
      expect(o!.exitCode).toBe(0);
    });

    test(`${c.name}: every job reports success`, () => {
      const o = outcomes.get(c.name)!;
      // act prints "✔ Job succeeded" for each successful job.
      expect(o.output).toContain("Job succeeded");
      // And no "Job failed".
      expect(o.output).not.toContain("Job failed");
    });

    test(`${c.name}: emits exact expected new_version`, () => {
      const o = outcomes.get(c.name)!;
      // Our workflow prints a marker line: RESULT::previous=...::new=...::bump=...
      const marker = /RESULT::previous=([0-9.]+)::new=([0-9.]+)::bump=(\w+)/.exec(o.output);
      expect(marker).not.toBeNull();
      const [, prev, next, bump] = marker as RegExpExecArray;
      expect(prev).toBe(c.startingVersion);
      expect(next).toBe(c.expectedNewVersion);
      expect(bump).toBe(c.expectedBump);
    });
  }
});
