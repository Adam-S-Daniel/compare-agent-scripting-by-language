// End-to-end tests: each test case bootstraps a temp git repo with the
// project files + that case's fixture data, runs `act push --rm`, captures
// the output, and asserts on EXACT expected substrings in the workflow log.
//
// This file also covers the "workflow structure" requirements: it parses
// the YAML, sanity-checks the structure, and asserts actionlint passes.
//
// All act output is appended to act-result.txt with delimiters per case.

import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { spawnSync } from "node:child_process";
import { cpSync, existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { parse as parseYaml } from "yaml";

const PROJECT_ROOT = import.meta.dir;
const WORKFLOW_PATH = join(PROJECT_ROOT, ".github/workflows/secret-rotation-validator.yml");
const ACT_RESULT_FILE = join(PROJECT_ROOT, "act-result.txt");

// Fresh act-result.txt per run: one append per test case below.
beforeAll(() => {
  writeFileSync(ACT_RESULT_FILE, `# act-result.txt — generated ${new Date().toISOString()}\n`);
});

// Fixture: a list of secrets paired with what we expect the workflow to print.
interface Case {
  id: string;
  secrets: unknown[];
  expects: string[]; // substrings that MUST appear in act output
  rejects?: string[]; // substrings that MUST NOT appear
}

const CASES: Case[] = [
  {
    id: "all-ok",
    secrets: [
      {
        name: "well-rested-key",
        lastRotated: "2026-05-01",
        rotationPolicyDays: 365,
        requiredBy: ["api"],
      },
    ],
    expects: [
      "POLICY_OK",
      // Markdown report sections
      "## Expired (0)",
      "## Warning (0)",
      "## OK (1)",
      "| well-rested-key |",
      // JSON summary fields exact
      `"total": 1`,
      `"expired": 0`,
      `"warning": 0`,
      `"ok": 1`,
      `"status": "ok"`,
    ],
    rejects: ["POLICY_FAIL"],
  },
  {
    id: "mixed",
    secrets: [
      // expired: age=126, policy=30 -> daysUntilDue=-96
      {
        name: "stripe-api-key",
        lastRotated: "2026-01-01",
        rotationPolicyDays: 30,
        requiredBy: ["billing-api"],
      },
      // warning: age=22, policy=30, warning=14 -> daysUntilDue=8
      {
        name: "github-deploy-token",
        lastRotated: "2026-04-15",
        rotationPolicyDays: 30,
        requiredBy: ["release-pipeline"],
      },
      // ok: age=27, policy=90 -> daysUntilDue=63
      {
        name: "session-jwt-signing-key",
        lastRotated: "2026-04-10",
        rotationPolicyDays: 90,
        requiredBy: ["auth-service"],
      },
    ],
    expects: [
      "POLICY_FAIL",
      "## Expired (1)",
      "## Warning (1)",
      "## OK (1)",
      "| stripe-api-key |",
      "| github-deploy-token |",
      "| session-jwt-signing-key |",
      // exact daysUntilDue numbers in JSON
      `"daysUntilDue": -96`,
      `"daysUntilDue": 8`,
      `"daysUntilDue": 63`,
      `"total": 3`,
      `"expired": 1`,
      `"warning": 1`,
    ],
    rejects: ["POLICY_OK"],
  },
];

// ---------- Workflow structure assertions ----------

describe("workflow file structure", () => {
  const yamlText = readFileSync(WORKFLOW_PATH, "utf8");
  const wf = parseYaml(yamlText) as Record<string, unknown>;

  test("declares expected triggers", () => {
    // YAML 'on' is parsed as JS boolean true under default schema; check both.
    const on = (wf.on ?? wf["on"] ?? (wf as { true?: unknown }).true) as Record<string, unknown>;
    expect(on).toBeDefined();
    expect(Object.keys(on)).toEqual(
      expect.arrayContaining(["push", "pull_request", "schedule", "workflow_dispatch"]),
    );
  });

  test("validate job runs on ubuntu-latest with bun setup + script invocation", () => {
    const jobs = wf.jobs as Record<string, { "runs-on": string; steps: Array<Record<string, unknown>> }>;
    const job = jobs.validate;
    expect(job["runs-on"]).toBe("ubuntu-latest");
    const stepText = JSON.stringify(job.steps);
    expect(stepText).toContain("actions/checkout@v4");
    expect(stepText).toContain("oven-sh/setup-bun@v2");
    expect(stepText).toContain("bun run validator.ts");
    expect(stepText).toContain("bun test");
  });

  test("references files that actually exist", () => {
    expect(existsSync(join(PROJECT_ROOT, "validator.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_ROOT, "fixtures/secrets.json"))).toBe(true);
  });

  test("actionlint passes", () => {
    const r = spawnSync("actionlint", [WORKFLOW_PATH], { encoding: "utf8" });
    if (r.status !== 0) console.error(r.stdout, r.stderr);
    expect(r.status).toBe(0);
  });
});

// ---------- act runs ----------

// One temp working tree per process — we reuse it by overwriting the fixture
// between cases, so docker layer caching kicks in for run #2.
let workdir = "";
beforeAll(() => {
  workdir = mkdtempSync(join(tmpdir(), "secret-rot-act-"));
  // Mirror the project files we need into the tmp tree.
  for (const f of [
    "validator.ts",
    "validator.test.ts",
    "package.json",
    "tsconfig.json",
    ".github",
    "fixtures",
  ]) {
    cpSync(join(PROJECT_ROOT, f), join(workdir, f), { recursive: true });
  }
  // Initialize a git repo (act expects one).
  for (const cmd of [
    ["git", "init", "-q", "-b", "main"],
    ["git", "config", "user.email", "test@example.com"],
    ["git", "config", "user.name", "Test"],
    ["git", "add", "."],
    ["git", "commit", "-q", "-m", "init"],
  ]) {
    const r = spawnSync(cmd[0], cmd.slice(1), { cwd: workdir, encoding: "utf8" });
    if (r.status !== 0) throw new Error(`${cmd.join(" ")} failed: ${r.stderr}`);
  }
});

afterAll(() => {
  if (workdir) rmSync(workdir, { recursive: true, force: true });
});

function runAct(): { code: number; output: string } {
  // -P and other defaults come from .actrc which we copy into workdir.
  cpSync(join(PROJECT_ROOT, ".actrc"), join(workdir, ".actrc"));
  // --pull=false since the image (act-ubuntu-pwsh:latest) is local-only.
  const r = spawnSync("act", ["push", "--rm", "--pull=false"], {
    cwd: workdir,
    encoding: "utf8",
    timeout: 10 * 60_000,
    maxBuffer: 32 * 1024 * 1024,
  });
  return { code: r.status ?? -1, output: (r.stdout ?? "") + "\n" + (r.stderr ?? "") };
}

for (const c of CASES) {
  test(
    `act case: ${c.id}`,
    () => {
      // Swap fixture for this case + commit so act picks it up from the tree.
      writeFileSync(join(workdir, "fixtures/secrets.json"), JSON.stringify(c.secrets, null, 2));
      const add = spawnSync("git", ["commit", "-q", "-am", `case ${c.id}`], {
        cwd: workdir,
        encoding: "utf8",
      });
      // commit may be empty on first iteration if file content unchanged — ignore.
      if (add.status !== 0 && !/(nothing to commit|nothing added)/i.test(add.stdout + add.stderr)) {
        // Try add+commit
        spawnSync("git", ["add", "-A"], { cwd: workdir });
        spawnSync("git", ["commit", "-q", "-m", `case ${c.id}`, "--allow-empty"], { cwd: workdir });
      }

      const { code, output } = runAct();

      // Append to required artifact.
      const banner = `\n===== CASE: ${c.id} (act exit=${code}) =====\n`;
      writeFileSync(ACT_RESULT_FILE, banner + output, { flag: "a" });

      expect(code).toBe(0);
      expect(output).toContain("Job succeeded");
      for (const needle of c.expects) {
        if (!output.includes(needle)) {
          // Helpful diff in failure
          console.error(`Missing in act output for case ${c.id}: ${JSON.stringify(needle)}`);
        }
        expect(output).toContain(needle);
      }
      for (const banned of c.rejects ?? []) {
        expect(output).not.toContain(banned);
      }
    },
    10 * 60_000,
  );
}
