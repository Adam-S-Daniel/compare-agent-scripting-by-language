// Workflow harness tests.
//
// Per the task spec, the validator must be exercised through the GitHub Actions
// workflow via `act`. This file:
//   1. Validates the workflow YAML structure and that actionlint passes.
//   2. Runs `act push --rm` once per fixture inside an isolated temp git repo,
//      capturing output to act-result.txt and asserting on exact expected
//      values from the validator's summary line.

import { describe, expect, test, beforeAll } from "bun:test";
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync, appendFileSync, cpSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const PROJECT = resolve(import.meta.dir);
const WORKFLOW = join(PROJECT, ".github/workflows/secret-rotation-validator.yml");
const ACT_RESULT = join(PROJECT, "act-result.txt");

interface Case {
  fixture: string;
  expectExpired: number;
  expectWarning: number;
  expectOk: number;
  expectTotal: number;
}

const CASES: Case[] = [
  // 2026-05-08, warn=7
  // db-password: 2025-01-01 + 90d => 2025-04-01 (expired)
  // api-token:   2026-04-01 + 30d => 2026-05-01 (expired)
  // stripe-key:  2026-05-01 + 90d => 2026-07-30 (ok)
  { fixture: "has-expired.json", expectTotal: 3, expectExpired: 2, expectWarning: 0, expectOk: 1 },
  // warn-key: 2026-04-15 + 30d => 2026-05-15 (warning, 7 days out)
  // stripe-key (ok)
  { fixture: "has-warning.json", expectTotal: 2, expectExpired: 0, expectWarning: 1, expectOk: 1 },
  // both ok
  { fixture: "all-ok.json", expectTotal: 2, expectExpired: 0, expectWarning: 0, expectOk: 2 },
];

function setupTempRepo(fixturePath: string): string {
  const dir = mkdtempSync(join(tmpdir(), "srv-act-"));
  // Copy needed project files into temp repo.
  for (const f of [
    "validator.ts",
    "cli.ts",
    "validator.test.ts",
    "package.json",
    "tsconfig.json",
    "bun.lock",
    ".actrc",
  ]) {
    const src = join(PROJECT, f);
    if (existsSync(src)) cpSync(src, join(dir, f));
  }
  // Copy workflow.
  mkdirSync(join(dir, ".github/workflows"), { recursive: true });
  cpSync(WORKFLOW, join(dir, ".github/workflows/secret-rotation-validator.yml"));
  // Workflow reads fixtures/active.json; copy the chosen case there.
  mkdirSync(join(dir, "fixtures"), { recursive: true });
  cpSync(join(PROJECT, "fixtures", fixturePath), join(dir, "fixtures", "active.json"));
  // Init git repo (act requires one).
  spawnSync("git", ["init", "-q", "-b", "main"], { cwd: dir });
  spawnSync("git", ["config", "user.email", "test@example.com"], { cwd: dir });
  spawnSync("git", ["config", "user.name", "Test"], { cwd: dir });
  spawnSync("git", ["add", "-A"], { cwd: dir });
  spawnSync("git", ["commit", "-q", "-m", "init"], { cwd: dir });
  return dir;
}

function appendResult(header: string, body: string): void {
  appendFileSync(ACT_RESULT, `\n===== ${header} =====\n${body}\n`);
}

describe("workflow structure", () => {
  test("actionlint passes", () => {
    const r = spawnSync("actionlint", [WORKFLOW], { encoding: "utf8" });
    expect(r.stdout + r.stderr).toBe("");
    expect(r.status).toBe(0);
  });

  test("workflow references existing files", async () => {
    const text = await Bun.file(WORKFLOW).text();
    expect(text).toContain("cli.ts");
    expect(existsSync(join(PROJECT, "cli.ts"))).toBe(true);
    expect(existsSync(join(PROJECT, "validator.ts"))).toBe(true);
  });

  test("declares expected triggers and job", async () => {
    const text = await Bun.file(WORKFLOW).text();
    expect(text).toMatch(/^on:\s*$/m);
    expect(text).toContain("push:");
    expect(text).toContain("pull_request:");
    expect(text).toContain("workflow_dispatch:");
    expect(text).toContain("schedule:");
    expect(text).toMatch(/jobs:\s*\n\s+validate:/);
    expect(text).toContain("actions/checkout@v4");
  });
});

describe("workflow execution via act", () => {
  beforeAll(() => {
    // Reset the artifact at the start of the harness run.
    writeFileSync(ACT_RESULT, `act run log @ ${new Date().toISOString()}\n`);
  });

  for (const c of CASES) {
    test(
      `act push succeeds and reports expected counts for ${c.fixture}`,
      () => {
        const repo = setupTempRepo(c.fixture);
        const env = {
          ...process.env,
          // Pass fixture as workflow input via INPUT_ env (workflow uses
          // github.event.inputs.fixture, which act maps from --input flags).
        } as Record<string, string>;
        const r = spawnSync(
          "act",
          ["push", "--rm", "--pull=false"],
          { cwd: repo, env, encoding: "utf8", maxBuffer: 50 * 1024 * 1024 },
        );
        const combined = (r.stdout ?? "") + "\n----STDERR----\n" + (r.stderr ?? "");
        appendResult(`fixture=${c.fixture} exit=${r.status}`, combined);
        try {
          expect(r.status).toBe(0);
          // Every job should report success.
          expect(combined).toContain("Job succeeded");
          // Exact summary line emitted by the workflow's "Print summary line" step.
          const expected =
            `ROTATION_SUMMARY total=${c.expectTotal} expired=${c.expectExpired} ` +
            `warning=${c.expectWarning} ok=${c.expectOk}`;
          expect(combined).toContain(expected);
        } finally {
          rmSync(repo, { recursive: true, force: true });
        }
      },
      10 * 60 * 1000,
    );
  }
});
