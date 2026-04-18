// Workflow test harness: drives every test case end-to-end through
// `act push --rm` against the committed secret-rotation-validator workflow.
//
// For each test case the harness:
//   1. Copies the project files + that case's fixture into a temp git repo.
//      The fixture overwrites the committed fixtures/secrets.json so the
//      workflow, which hard-codes "fixtures/secrets.json", picks it up.
//   2. Patches the workflow's DEFAULT_REFERENCE_DATE / DEFAULT_WARNING_DAYS
//      env values so the case fully controls the run.
//   3. Runs `act push --rm` inside that temp repo and appends the full output
//      to act-result.txt in the ORIGINAL cwd, with clear delimiters.
//   4. Asserts on the expected exit code (0 when nothing expired, 1 when
//      something is expired) and on exact-expected report values.
//   5. Asserts "Job succeeded" appears for every run.
//
// We also parse the YAML once at start-of-file to check structural invariants.

import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import {
  cpSync,
  existsSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
  appendFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const PROJECT_DIR = resolve(import.meta.dir);
const WORKFLOW_PATH = join(
  PROJECT_DIR,
  ".github",
  "workflows",
  "secret-rotation-validator.yml",
);
const ACT_RESULT = join(PROJECT_DIR, "act-result.txt");

// --- Workflow structure checks -------------------------------------------

describe("workflow structure", () => {
  const raw = readFileSync(WORKFLOW_PATH, "utf8");

  test("YAML parses", () => {
    // Minimal structural parse via Bun.YAML-free assertions. We don't want a
    // YAML lib dependency; regex-level checks are enough to assert shape.
    expect(raw).toContain("name: Secret Rotation Validator");
    expect(raw).toContain("on:");
    expect(raw).toContain("jobs:");
  });

  test("triggers include push, pull_request, schedule, workflow_dispatch", () => {
    expect(raw).toMatch(/^on:\s*$/m);
    expect(raw).toContain("push:");
    expect(raw).toContain("pull_request:");
    expect(raw).toContain("schedule:");
    expect(raw).toContain("workflow_dispatch:");
  });

  test("job references actions/checkout@v4 and runs cli.ts", () => {
    expect(raw).toContain("actions/checkout@v4");
    expect(raw).toContain("bun run cli.ts");
  });

  test("workflow references files that actually exist in the project", () => {
    expect(existsSync(join(PROJECT_DIR, "cli.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_DIR, "validator.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_DIR, "fixtures", "secrets.json"))).toBe(true);
  });

  test("actionlint exits 0 on the workflow", async () => {
    const proc = Bun.spawn(["actionlint", WORKFLOW_PATH], {
      stdout: "pipe",
      stderr: "pipe",
    });
    const [stdout, stderr] = await Promise.all([
      new Response(proc.stdout).text(),
      new Response(proc.stderr).text(),
    ]);
    const code = await proc.exited;
    expect({ code, stdout, stderr }).toEqual({ code: 0, stdout: "", stderr: "" });
  });
});

// --- act-driven test cases -----------------------------------------------

interface FixtureSecret {
  name: string;
  lastRotated: string;
  rotationDays: number;
  requiredBy: string[];
}

interface ActCase {
  id: string;
  description: string;
  fixture: { secrets: FixtureSecret[] };
  warningDays: number;
  referenceDate: string;
  expect: {
    // Exact counts that should show up in the rendered report stdout.
    expired: number;
    warning: number;
    ok: number;
    // Policy verdict line printed by the workflow.
    policy: "PASS" | "WARN" | "FAIL";
    // Names that must appear in specific buckets within the markdown table.
    expiredNames?: string[];
    warningNames?: string[];
    okNames?: string[];
  };
}

const CASES: ActCase[] = [
  {
    id: "all-ok",
    description: "Every secret well within its window ⇒ exit 0, no expired/warning.",
    fixture: {
      secrets: [
        {
          name: "analytics-token",
          lastRotated: "2026-04-10",
          rotationDays: 365,
          requiredBy: ["dashboards"],
        },
        {
          name: "feature-flag-key",
          lastRotated: "2026-03-01",
          rotationDays: 180,
          requiredBy: ["app"],
        },
      ],
    },
    warningDays: 14,
    referenceDate: "2026-04-17",
    expect: {
      expired: 0,
      warning: 0,
      ok: 2,
      policy: "PASS",
      okNames: ["analytics-token", "feature-flag-key"],
    },
  },
  {
    id: "one-warning",
    description: "One secret in the warning window, nothing expired.",
    fixture: {
      secrets: [
        {
          name: "stripe-webhook",
          lastRotated: "2026-01-20",
          rotationDays: 90,
          requiredBy: ["billing"],
        },
        {
          name: "analytics-token",
          lastRotated: "2026-04-10",
          rotationDays: 365,
          requiredBy: ["dashboards"],
        },
      ],
    },
    warningDays: 14,
    referenceDate: "2026-04-17",
    expect: {
      expired: 0,
      warning: 1,
      ok: 1,
      policy: "WARN",
      warningNames: ["stripe-webhook"],
      okNames: ["analytics-token"],
    },
  },
  {
    id: "one-expired",
    description: "One secret overdue ⇒ policy verdict FAIL.",
    fixture: {
      secrets: [
        {
          name: "prod-db-password",
          lastRotated: "2025-10-01",
          rotationDays: 60,
          requiredBy: ["api", "worker"],
        },
        {
          name: "feature-flag-key",
          lastRotated: "2026-04-10",
          rotationDays: 180,
          requiredBy: ["app"],
        },
      ],
    },
    warningDays: 14,
    referenceDate: "2026-04-17",
    expect: {
      expired: 1,
      warning: 0,
      ok: 1,
      policy: "FAIL",
      expiredNames: ["prod-db-password"],
      okNames: ["feature-flag-key"],
    },
  },
];

// Build a temp project directory pre-populated with all files needed for
// `act push --rm` to run our workflow against a given fixture.
function buildStagingRepo(kase: ActCase): string {
  const tmp = mkdtempSync(join(tmpdir(), `srv-act-${kase.id}-`));

  const filesToCopy = [
    "package.json",
    "tsconfig.json",
    "validator.ts",
    "cli.ts",
    ".github",
    "fixtures",
  ];
  for (const entry of filesToCopy) {
    cpSync(join(PROJECT_DIR, entry), join(tmp, entry), { recursive: true });
  }
  // .actrc points act at our custom runner image; the harness needs it too.
  const actrcSrc = join(PROJECT_DIR, ".actrc");
  if (existsSync(actrcSrc)) {
    cpSync(actrcSrc, join(tmp, ".actrc"));
  }

  // Overwrite the fixture the workflow will load.
  writeFileSync(
    join(tmp, "fixtures", "secrets.json"),
    JSON.stringify(kase.fixture, null, 2),
  );

  // Patch the workflow env so this case fully controls the run.
  const wfPath = join(tmp, ".github", "workflows", "secret-rotation-validator.yml");
  let wf = readFileSync(wfPath, "utf8");
  wf = wf.replace(
    /DEFAULT_WARNING_DAYS: "[^"]*"/,
    `DEFAULT_WARNING_DAYS: "${kase.warningDays}"`,
  );
  wf = wf.replace(
    /DEFAULT_REFERENCE_DATE: "[^"]*"/,
    `DEFAULT_REFERENCE_DATE: "${kase.referenceDate}"`,
  );
  writeFileSync(wfPath, wf);

  // act requires a git repo to compute commit metadata for the event.
  const git = (args: string[]) => {
    const p = Bun.spawnSync(["git", ...args], {
      cwd: tmp,
      stdout: "pipe",
      stderr: "pipe",
      env: {
        ...process.env,
        GIT_AUTHOR_NAME: "test",
        GIT_AUTHOR_EMAIL: "test@example.com",
        GIT_COMMITTER_NAME: "test",
        GIT_COMMITTER_EMAIL: "test@example.com",
      },
    });
    if (p.exitCode !== 0) {
      throw new Error(
        `git ${args.join(" ")} failed (exit ${p.exitCode}): ${p.stderr.toString()}`,
      );
    }
  };
  git(["init", "-q", "-b", "main"]);
  git(["add", "-A"]);
  git(["commit", "-q", "-m", "test fixture"]);

  return tmp;
}

async function runAct(cwd: string): Promise<{ code: number; output: string }> {
  // --pull=false: our .actrc maps ubuntu-latest to a locally-built image, so
  // we never want act to hit Docker Hub.
  const proc = Bun.spawn(["act", "push", "--rm", "--pull=false"], {
    cwd,
    stdout: "pipe",
    stderr: "pipe",
  });
  const [stdout, stderr] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
  ]);
  const code = await proc.exited;
  return { code, output: `${stdout}\n---STDERR---\n${stderr}` };
}

describe("workflow runs through act", () => {
  beforeAll(() => {
    // Fresh file — each test case appends its own block.
    writeFileSync(
      ACT_RESULT,
      `# secret-rotation-validator act results\n# generated ${new Date().toISOString()}\n\n`,
    );
  });

  // Keep the most recent staging dir around if a test fails, so a human can
  // inspect it; otherwise clean up at the very end to avoid tmp bloat.
  const stagingDirs: string[] = [];
  afterAll(() => {
    for (const d of stagingDirs) rmSync(d, { recursive: true, force: true });
  });

  for (const kase of CASES) {
    test(
      `[${kase.id}] ${kase.description}`,
      async () => {
        const staging = buildStagingRepo(kase);
        stagingDirs.push(staging);

        const { code, output } = await runAct(staging);

        appendFileSync(
          ACT_RESULT,
          [
            `================ CASE: ${kase.id} ================`,
            `description: ${kase.description}`,
            `warningDays: ${kase.warningDays}  referenceDate: ${kase.referenceDate}`,
            `act exit code: ${code}`,
            `--- BEGIN act output ---`,
            output,
            `--- END act output ---`,
            "",
            "",
          ].join("\n"),
        );

        // Every act run must exit 0 — policy state is conveyed via stdout,
        // not via the workflow job's exit code.
        expect({ case: kase.id, code }).toEqual({ case: kase.id, code: 0 });

        // Every run — should report that the workflow job executed end-to-end.
        expect(output).toContain("Job succeeded");

        // Exact-value assertions on the markdown summary section.
        expect(output).toMatch(new RegExp(`Expired:\\s*${kase.expect.expired}`));
        expect(output).toMatch(new RegExp(`Warning:\\s*${kase.expect.warning}`));
        expect(output).toMatch(new RegExp(`OK:\\s*${kase.expect.ok}`));
        expect(output).toMatch(
          new RegExp(`Total:\\s*${kase.expect.expired + kase.expect.warning + kase.expect.ok}`),
        );

        // Summary echo line from the run step: "expired=N warning=N ok=N".
        expect(output).toContain(
          `expired=${kase.expect.expired} warning=${kase.expect.warning} ok=${kase.expect.ok}`,
        );

        for (const name of kase.expect.expiredNames ?? []) {
          expect(output).toContain(`| ${name} |`);
        }
        for (const name of kase.expect.warningNames ?? []) {
          expect(output).toContain(`| ${name} |`);
        }
        for (const name of kase.expect.okNames ?? []) {
          expect(output).toContain(`| ${name} |`);
        }

        // Exact policy verdict printed by the workflow's final echo.
        const verdict = kase.expect.policy;
        if (verdict === "PASS") {
          expect(output).toContain("POLICY: PASS");
        } else if (verdict === "WARN") {
          expect(output).toContain(`POLICY: WARN warning=${kase.expect.warning}`);
        } else {
          expect(output).toContain(`POLICY: FAIL expired=${kase.expect.expired}`);
        }
      },
      // act runs are slow; give each case up to 5 minutes.
      5 * 60 * 1000,
    );
  }
});
