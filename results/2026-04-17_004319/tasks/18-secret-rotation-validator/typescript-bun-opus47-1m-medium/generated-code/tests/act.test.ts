// Integration tests: every test case executes the workflow end-to-end via act.
// We set up a throwaway git repo per case (copying project files + the case's
// fixture as fixtures/mixed.json so the workflow's defaults pick it up), run
// `act push --rm`, capture the combined output, and assert on EXACT expected
// values (bucket counts + cli exit code + "Job succeeded").
//
// Output for every case is appended to act-result.txt in the project root with
// clear delimiters — the spec requires this file as a final artifact.

import { describe, expect, test, beforeAll } from "bun:test";
import { execSync, spawnSync } from "node:child_process";
import {
  mkdtempSync,
  cpSync,
  writeFileSync,
  rmSync,
  existsSync,
  readFileSync,
  appendFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const PROJECT_ROOT = resolve(import.meta.dir, "..");
const ACT_RESULT = join(PROJECT_ROOT, "act-result.txt");

interface ActCase {
  name: string;
  fixture: string; // relative path (under fixtures/) to copy as fixtures/mixed.json
  expected: { expired: number; warning: number; ok: number; cliExit: number };
}

// Two cases — each = 1 act run. Budget: <=3 act runs total.
const CASES: ActCase[] = [
  {
    name: "mixed-secrets",
    fixture: "fixtures/mixed.json",
    expected: { expired: 1, warning: 1, ok: 1, cliExit: 1 },
  },
  {
    name: "all-ok",
    fixture: "fixtures/all-ok.json",
    expected: { expired: 0, warning: 0, ok: 2, cliExit: 0 },
  },
];

function truncateActResult() {
  writeFileSync(ACT_RESULT, `# act-result.txt — generated ${new Date().toISOString()}\n\n`);
}

function appendResult(section: string) {
  appendFileSync(ACT_RESULT, section);
}

function setupRepo(c: ActCase): string {
  const dir = mkdtempSync(join(tmpdir(), `act-${c.name}-`));
  // Copy project files the workflow needs.
  for (const p of [
    "src",
    "fixtures",
    ".github",
    "package.json",
    "tsconfig.json",
    ".actrc",
  ]) {
    const from = join(PROJECT_ROOT, p);
    if (existsSync(from)) cpSync(from, join(dir, p), { recursive: true });
  }
  // Override the default fixture path for this case by copying the chosen
  // fixture over fixtures/mixed.json (which is the workflow's default input).
  cpSync(join(PROJECT_ROOT, c.fixture), join(dir, "fixtures/mixed.json"));
  // Initialize git — act requires a git repo to simulate a push event.
  execSync("git init -q && git add -A && git -c user.email=a@b -c user.name=t commit -qm init", {
    cwd: dir,
    stdio: "ignore",
  });
  return dir;
}

function runAct(dir: string): { stdout: string; exit: number } {
  const res = spawnSync("act", ["push", "--rm"], {
    cwd: dir,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
  });
  return {
    stdout: (res.stdout ?? "") + (res.stderr ?? ""),
    exit: res.status ?? -1,
  };
}

describe("act end-to-end", () => {
  beforeAll(() => {
    truncateActResult();
  });

  for (const c of CASES) {
    test(
      `case: ${c.name}`,
      () => {
        const dir = setupRepo(c);
        let out: { stdout: string; exit: number };
        try {
          out = runAct(dir);
        } finally {
          // Keep the fixture on disk in case of failure? No — it's in tmp.
          rmSync(dir, { recursive: true, force: true });
        }

        appendResult(
          `\n========== CASE: ${c.name} ==========\n` +
            `act exit: ${out.exit}\n` +
            `--- act output ---\n${out.stdout}\n` +
            `--- end case ${c.name} ---\n`,
        );

        // 1. act itself succeeded.
        expect(out.exit).toBe(0);

        // 2. The summary job step emits the exact bucket counts.
        const summary = out.stdout.match(
          /RESULT_SUMMARY SUMMARY expired=(\d+) warning=(\d+) ok=(\d+)/,
        );
        expect(summary).not.toBeNull();
        expect(Number(summary![1])).toBe(c.expected.expired);
        expect(Number(summary![2])).toBe(c.expected.warning);
        expect(Number(summary![3])).toBe(c.expected.ok);

        // 3. The CLI exit code matches expectation (1 when expired present).
        const cliExit = out.stdout.match(/RESULT_CLI_EXIT (\d+)/);
        expect(cliExit).not.toBeNull();
        expect(Number(cliExit![1])).toBe(c.expected.cliExit);

        // 4. Every job in this workflow shows "Job succeeded".
        expect(out.stdout).toContain("Job succeeded");
      },
      600_000,
    );
  }

  test("act-result.txt artifact exists and contains all cases", () => {
    expect(existsSync(ACT_RESULT)).toBe(true);
    const body = readFileSync(ACT_RESULT, "utf8");
    for (const c of CASES) expect(body).toContain(`CASE: ${c.name}`);
  });
});
