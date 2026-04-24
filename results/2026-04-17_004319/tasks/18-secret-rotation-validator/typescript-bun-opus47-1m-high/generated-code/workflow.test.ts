// Workflow / act integration tests.
//
// For each test case we:
//   1. Build a throwaway git repo with the project files + that case's config.
//   2. Run `act push --rm`, capturing stdout+stderr.
//   3. Append the raw output to act-result.txt (a required artifact).
//   4. Assert exit 0, that every job reported "Job succeeded", and that the
//      workflow emitted the EXACT SUMMARY line we expect for that fixture.
//
// Also runs structural checks (actionlint, YAML shape, referenced paths exist).

import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { $ } from "bun";
import { mkdtempSync, cpSync, writeFileSync, appendFileSync, existsSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const PROJECT_ROOT = import.meta.dir;
const WORKFLOW_PATH = join(PROJECT_ROOT, ".github/workflows/secret-rotation-validator.yml");
const ACT_RESULT = join(PROJECT_ROOT, "act-result.txt");

// Reset the artifact once, at the start of the suite — each case then appends.
beforeAll(() => {
  if (existsSync(ACT_RESULT)) rmSync(ACT_RESULT);
  writeFileSync(ACT_RESULT, `# act results — generated ${new Date().toISOString()}\n`);
});

afterAll(() => {
  // Leave act-result.txt behind; the grading harness needs it.
});

// ---------- Structural checks -------------------------------------------------

describe("workflow structure", () => {
  test("the workflow file exists", () => {
    expect(existsSync(WORKFLOW_PATH)).toBe(true);
  });

  test("actionlint passes", async () => {
    const result = await $`actionlint ${WORKFLOW_PATH}`.nothrow().quiet();
    if (result.exitCode !== 0) {
      console.error("actionlint stdout:", result.stdout.toString());
      console.error("actionlint stderr:", result.stderr.toString());
    }
    expect(result.exitCode).toBe(0);
  });

  test("workflow declares the expected triggers and a validate job", async () => {
    const text = await Bun.file(WORKFLOW_PATH).text();
    const { parse } = await import("yaml");
    // `on` parses as the boolean `true` in YAML 1.1 — `parse` from the `yaml`
    // package is YAML 1.2-safe but we stay defensive just in case.
    const wf = parse(text) as Record<string, unknown>;
    const triggers = (wf.on ?? wf[true as unknown as string]) as Record<string, unknown>;
    expect(triggers).toBeDefined();
    for (const trig of ["push", "pull_request", "workflow_dispatch", "schedule"]) {
      expect(triggers).toHaveProperty(trig);
    }
    const jobs = wf.jobs as Record<string, { steps: Array<Record<string, unknown>> }>;
    expect(jobs).toHaveProperty("validate");
    const stepNames = jobs.validate.steps.map((s) => s.name);
    expect(stepNames).toContain("Checkout");
    expect(stepNames).toContain("Install Bun");
    expect(stepNames).toContain("Run validator unit tests");
    expect(stepNames).toContain("Generate rotation report (markdown)");
    expect(stepNames).toContain("Generate rotation report (json)");
  });

  test("workflow references project files that exist", () => {
    // cli.ts is invoked by the workflow via `bun run cli.ts`.
    expect(existsSync(join(PROJECT_ROOT, "cli.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_ROOT, "validator.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_ROOT, "validator.test.ts"))).toBe(true);
    // Default CONFIG_PATH in the workflow is fixtures/valid.json.
    expect(existsSync(join(PROJECT_ROOT, "fixtures/valid.json"))).toBe(true);
  });
});

// ---------- act-based pipeline tests -----------------------------------------

interface ActCase {
  label: string;
  configFixture: string; // path relative to PROJECT_ROOT
  warningDays: string;
  now: string;
  allowExpired: boolean;
  expectedSummary: string; // EXACT "SUMMARY ..." line the workflow should emit
  expectedGateOutcome: "gated-pass" | "gated-fail-tolerated" | "no-gate";
}

const CASES: ActCase[] = [
  {
    label: "all-ok",
    configFixture: "fixtures/all-ok.json",
    warningDays: "14",
    now: "2026-04-20",
    allowExpired: false,
    expectedSummary: "SUMMARY expired=0 warning=0 ok=2 total=2",
    expectedGateOutcome: "no-gate",
  },
  {
    label: "warning-only",
    configFixture: "fixtures/warning-only.json",
    warningDays: "14",
    now: "2026-04-20",
    allowExpired: false,
    expectedSummary: "SUMMARY expired=0 warning=1 ok=1 total=2",
    expectedGateOutcome: "no-gate",
  },
  {
    label: "mixed-tolerated",
    configFixture: "fixtures/valid.json",
    warningDays: "14",
    now: "2026-04-20",
    allowExpired: true, // validator exits 1, but gate step lets it pass
    expectedSummary: "SUMMARY expired=2 warning=1 ok=1 total=4",
    expectedGateOutcome: "gated-fail-tolerated",
  },
];

// Build one sandbox repo per case and run act against it. Returns act stdout.
async function runActCase(c: ActCase): Promise<{ output: string; exitCode: number }> {
  // Throwaway repo copy. We only need the files actually used by the workflow.
  const sandbox = mkdtempSync(join(tmpdir(), `secret-rotation-${c.label}-`));
  const filesToCopy = [
    ".github",
    ".actrc",
    "cli.ts",
    "validator.ts",
    "validator.test.ts",
    "fixtures",
    "package.json",
    "tsconfig.json",
  ];
  for (const name of filesToCopy) {
    const src = join(PROJECT_ROOT, name);
    if (existsSync(src)) cpSync(src, join(sandbox, name), { recursive: true });
  }

  // We don't overwrite fixtures/valid.json — the unit tests depend on its
  // canonical contents. Instead, the workflow reads CONFIG_PATH from process
  // env (injected via act --env), pointing at this case's specific fixture.

  // Initialize a git repo so act's `push` event has something to point at.
  await $`git init -q`.cwd(sandbox).quiet();
  await $`git -c user.email=t@t -c user.name=t add -A`.cwd(sandbox).quiet();
  await $`git -c user.email=t@t -c user.name=t commit -q -m init`.cwd(sandbox).quiet();

  // Run act. We inject per-case env so the workflow doesn't need per-case YAML.
  const envArgs = [
    "--env", `CONFIG_PATH=${c.configFixture}`,
    "--env", `WARNING_DAYS=${c.warningDays}`,
    "--env", `NOW_OVERRIDE=${c.now}`,
    "--env", `ALLOW_EXPIRED=${c.allowExpired ? "true" : "false"}`,
  ];
  // --pull=false tells act not to try pulling the locally-built image from a registry.
  const proc = Bun.spawn(["act", "push", "--rm", "--pull=false", ...envArgs], {
    cwd: sandbox,
    stdout: "pipe",
    stderr: "pipe",
  });
  const [stdout, stderr] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
  ]);
  const exitCode = await proc.exited;
  const output = `$ act push --rm ${envArgs.join(" ")}\n--- STDOUT ---\n${stdout}\n--- STDERR ---\n${stderr}\n`;

  // Persist so the grading harness can inspect everything.
  appendFileSync(
    ACT_RESULT,
    `\n================ CASE: ${c.label} ================\n` +
      `cwd: ${sandbox}\nexit: ${exitCode}\n${output}`,
  );

  // Keep the sandbox on disk for a couple of cases so failures are debuggable;
  // act's `--rm` only removes containers, not our temp dirs.
  return { output, exitCode };
}

describe("workflow executes end-to-end via act", () => {
  for (const c of CASES) {
    test(`case "${c.label}" — ${c.expectedSummary}`, async () => {
      const { output, exitCode } = await runActCase(c);
      // 1. act exited with code 0.
      expect(exitCode).toBe(0);
      // 2. Every job reported success (act prints "Job succeeded" when a job finishes cleanly).
      expect(output).toContain("Job succeeded");
      // 3. The workflow emitted the exact summary line we expect.
      expect(output).toContain(c.expectedSummary);
      // 4. Gate step behavior matches the case.
      if (c.expectedGateOutcome === "gated-fail-tolerated") {
        expect(output).toContain("Expired secrets tolerated (ALLOW_EXPIRED=true)");
      }
    }, 240_000);
  }
});
