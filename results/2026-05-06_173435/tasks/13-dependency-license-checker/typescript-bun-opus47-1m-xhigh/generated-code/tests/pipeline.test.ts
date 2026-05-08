// End-to-end pipeline test harness. Each case spins up a temp git repo
// containing the project files plus a "test-case.json" describing which
// fixture to scan and what the expected outcome is, then drives it through
// nektos/act and asserts on EXACT expected output.
//
// All raw `act` output is appended to act-result.txt in the project root,
// each case clearly delimited, so a human can diagnose failures without
// re-running act.
//
// We deliberately limit ourselves to 3 act runs total, in line with the
// task instructions.
import { describe, expect, test, beforeAll } from "bun:test";
import { spawnSync } from "bun";
import {
  cpSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
  existsSync,
  appendFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { parse as parseYaml } from "yaml";

const projectRoot = resolve(import.meta.dir, "..");
const actResultPath = join(projectRoot, "act-result.txt");
const workflowPath = join(projectRoot, ".github", "workflows", "dependency-license-checker.yml");

// Each case: which fixtures to ship in the temp repo, what the workflow
// should observe, and what the harness should see in act's stdout.
interface PipelineCase {
  label: string;
  // Files to drop into the temp repo, keyed by destination path.
  files: Record<string, string>;
  // Contents of the test-case.json we commit at the repo root.
  testCase: {
    label: string;
    manifest: string;
    policy: string;
    licenses: string;
    expected_exit_code: number;
    expected_summary: string;
  };
  // Strings that MUST appear verbatim in act's combined stdout/stderr.
  expectInOutput: string[];
}

const cases: PipelineCase[] = [
  {
    label: "approved",
    // Drop the manifest at under-test/package.json so the parser's
    // basename-based format detection picks the package.json reader.
    files: {
      "under-test/package.json": readFileSync(
        join(projectRoot, "fixtures", "cases", "approved", "package.json"),
        "utf8",
      ),
    },
    testCase: {
      label: "approved",
      manifest: "under-test/package.json",
      policy: "fixtures/policy.json",
      licenses: "fixtures/licenses.json",
      expected_exit_code: 0,
      expected_summary: "Summary: total=4 approved=4 denied=0 unknown=0",
    },
    expectInOutput: [
      "EXIT_CODE=0",
      "OBSERVED_SUMMARY=Summary: total=4 approved=4 denied=0 unknown=0",
      "TEST_CASE_OK=approved",
      "Job succeeded",
    ],
  },
  {
    label: "denied",
    files: {
      "under-test/package.json": readFileSync(
        join(projectRoot, "fixtures", "cases", "denied", "package.json"),
        "utf8",
      ),
    },
    testCase: {
      label: "denied",
      manifest: "under-test/package.json",
      policy: "fixtures/policy.json",
      licenses: "fixtures/licenses.json",
      expected_exit_code: 2,
      expected_summary: "Summary: total=4 approved=1 denied=2 unknown=1",
    },
    expectInOutput: [
      "EXIT_CODE=2",
      "OBSERVED_SUMMARY=Summary: total=4 approved=1 denied=2 unknown=1",
      "TEST_CASE_OK=denied",
      "Job succeeded",
    ],
  },
  {
    label: "python",
    files: {
      "requirements.txt": readFileSync(
        join(projectRoot, "fixtures", "cases", "python", "requirements.txt"),
        "utf8",
      ),
    },
    testCase: {
      label: "python",
      manifest: "requirements.txt",
      policy: "fixtures/policy.json",
      licenses: "fixtures/licenses.json",
      expected_exit_code: 2,
      expected_summary: "Summary: total=4 approved=3 denied=1 unknown=0",
    },
    expectInOutput: [
      "EXIT_CODE=2",
      "OBSERVED_SUMMARY=Summary: total=4 approved=3 denied=1 unknown=0",
      "TEST_CASE_OK=python",
      "Job succeeded",
    ],
  },
];

// Files we copy from the project root into every temp repo. These are the
// pieces the workflow needs to actually run the script.
const COPIED_PATHS = [
  ".github",
  ".actrc",
  "src",
  "fixtures",
  "package.json",
  "tsconfig.json",
];

function makeTempRepo(label: string, c: PipelineCase): string {
  const dir = mkdtempSync(join(tmpdir(), `dlc-${label}-`));
  for (const p of COPIED_PATHS) {
    const src = join(projectRoot, p);
    if (!existsSync(src)) continue;
    cpSync(src, join(dir, p), { recursive: true });
  }
  for (const [rel, content] of Object.entries(c.files)) {
    const dest = join(dir, rel);
    mkdirSync(dest.substring(0, dest.lastIndexOf("/")), { recursive: true });
    writeFileSync(dest, content);
  }
  writeFileSync(join(dir, "test-case.json"), JSON.stringify(c.testCase, null, 2));

  // Initialise a git repo on branch "main" so `act push` is happy.
  const gitOpts = { cwd: dir };
  const runs = [
    ["git", "init", "-q", "-b", "main"],
    ["git", "config", "user.email", "harness@example.com"],
    ["git", "config", "user.name", "harness"],
    ["git", "add", "-A"],
    ["git", "commit", "-q", "-m", `case ${label}`],
  ];
  for (const cmd of runs) {
    const r = spawnSync({ cmd, ...gitOpts });
    if (r.exitCode !== 0) {
      throw new Error(
        `git step ${cmd.join(" ")} failed: ${r.stderr.toString()}`,
      );
    }
  }
  return dir;
}

interface ActRun {
  exitCode: number;
  stdout: string;
  stderr: string;
  combined: string;
}

function runAct(repo: string): ActRun {
  // --rm removes containers after the run. --pull=false reuses cached
  // images so successive cases don't re-pull the runner image. The
  // ubuntu-latest mapping comes from .actrc inside the repo.
  const result = spawnSync({
    cmd: ["act", "push", "--rm", "--pull=false"],
    cwd: repo,
    env: { ...process.env, DOCKER_HOST: process.env.DOCKER_HOST ?? "" },
  });
  const stdout = result.stdout.toString();
  const stderr = result.stderr.toString();
  return {
    exitCode: result.exitCode ?? -1,
    stdout,
    stderr,
    combined: stdout + "\n--- stderr ---\n" + stderr,
  };
}

// Memoise the act runs so each case only triggers act once even if Bun
// re-orders test execution. Keyed by case label.
const actRuns = new Map<string, ActRun>();

// We run act inside beforeAll so each case fires once, regardless of test
// ordering. Bun's hook timeout argument keeps the runner from killing us
// halfway through a slow act invocation.
const HOOK_TIMEOUT_MS = 600_000;
beforeAll(() => {
  // Reset act-result.txt at the start of a harness run.
  writeFileSync(actResultPath, `# act-result.txt — generated ${new Date().toISOString()}\n`);
  for (const c of cases) {
    const repo = makeTempRepo(c.label, c);
    let run: ActRun;
    try {
      run = runAct(repo);
    } finally {
      // Clean up the temp repo unconditionally, even on act failure.
      rmSync(repo, { recursive: true, force: true });
    }
    actRuns.set(c.label, run);
    appendFileSync(
      actResultPath,
      [
        "",
        `===== BEGIN CASE: ${c.label} =====`,
        `EXIT_CODE_FROM_ACT=${run.exitCode}`,
        run.combined,
        `===== END CASE: ${c.label} =====`,
        "",
      ].join("\n"),
    );
  }
}, HOOK_TIMEOUT_MS);

describe("act pipeline", () => {
  for (const c of cases) {
    describe(`case '${c.label}'`, () => {
      test("act exits with code 0", () => {
        const run = actRuns.get(c.label)!;
        expect(run.exitCode).toBe(0);
      });

      test("every job in the workflow shows 'Job succeeded'", () => {
        const run = actRuns.get(c.label)!;
        expect(run.combined).toContain("Job succeeded");
      });

      for (const needle of c.expectInOutput) {
        test(`output contains exact value: '${needle}'`, () => {
          const run = actRuns.get(c.label)!;
          expect(run.combined).toContain(needle);
        });
      }
    });
  }
});

describe("workflow structure", () => {
  // Pre-parse the YAML once; reused across structure assertions.
  let workflow: any;
  beforeAll(() => {
    const text = readFileSync(workflowPath, "utf8");
    workflow = parseYaml(text);
  });

  test("workflow uses every required trigger event", () => {
    // YAML's bare key "on" is reserved (parses as boolean true), so we
    // accept either "on" or true as the key for the triggers map.
    const triggers = workflow.on ?? workflow[true];
    expect(triggers).toBeDefined();
    expect(Object.keys(triggers).sort()).toEqual([
      "pull_request",
      "push",
      "schedule",
      "workflow_dispatch",
    ]);
  });

  test("workflow declares the license-check job with the expected steps", () => {
    const job = workflow.jobs?.["license-check"];
    expect(job).toBeDefined();
    expect(job["runs-on"]).toBe("ubuntu-latest");
    const stepNames = job.steps.map((s: { name: string }) => s.name);
    expect(stepNames).toEqual([
      "Check out repository",
      "Set up Bun",
      "Resolve test-case parameters",
      "Run dependency license checker",
      "Upload compliance report",
      "Verify outcome matches test-case expectations",
    ]);
  });

  test("workflow references files that actually exist on disk", () => {
    const job = workflow.jobs["license-check"];
    const runStep = job.steps.find(
      (s: { id?: string }) => s.id === "check",
    );
    expect(runStep.run).toContain("src/cli.ts");
    expect(existsSync(join(projectRoot, "src", "cli.ts"))).toBe(true);
    expect(existsSync(join(projectRoot, "fixtures", "policy.json"))).toBe(true);
    expect(existsSync(join(projectRoot, "fixtures", "licenses.json"))).toBe(true);
  });

  test("workflow restricts permissions to read-only", () => {
    expect(workflow.permissions).toEqual({ contents: "read" });
  });

  test("actionlint passes on the workflow", () => {
    const r = spawnSync({
      cmd: ["actionlint", workflowPath],
      cwd: projectRoot,
    });
    if (r.exitCode !== 0) {
      console.error(r.stdout.toString(), r.stderr.toString());
    }
    expect(r.exitCode).toBe(0);
  });
});
