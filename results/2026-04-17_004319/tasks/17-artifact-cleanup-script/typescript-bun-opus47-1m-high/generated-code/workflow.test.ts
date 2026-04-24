import { describe, expect, test, beforeAll } from "bun:test";
import { spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, rmSync, cpSync, writeFileSync, appendFileSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { parse as parseYaml } from "yaml";

// Workflow harness tests: validate structure, then run every test case through
// `act` so the pipeline itself exercises the script. Output is appended to
// act-result.txt in the repo root (required artifact).

const REPO = process.cwd();
const WORKFLOW = join(REPO, ".github/workflows/artifact-cleanup-script.yml");
const ACT_RESULT = join(REPO, "act-result.txt");

interface TestCase {
  name: string;
  fixture: {
    name: string;
    now: string;
    dryRun?: boolean;
    policy: Record<string, number>;
    artifacts: Array<{
      id: string;
      name: string;
      sizeBytes: number;
      createdAt: string;
      workflowRunId: string;
    }>;
  };
  expected: {
    deletedCount: number;
    retainedCount: number;
    bytesReclaimed: number;
    totalArtifacts: number;
    dryRun: boolean;
    deletedIds: string[];
  };
}

const DAY = 86_400_000;
const NOW_ISO = "2026-04-19T00:00:00Z";
const NOW_MS = Date.parse(NOW_ISO);
const daysAgo = (d: number) => new Date(NOW_MS - d * DAY).toISOString();

// Three fixtures chosen for distinct coverage: age-only (dry run),
// keep-latest-per-workflow (live), and combined policies incl. size cap (live).
const CASES: TestCase[] = [
  {
    name: "age-policy-dry-run",
    fixture: {
      name: "age-policy-dry-run",
      now: NOW_ISO,
      dryRun: true,
      policy: { maxAgeDays: 30 },
      artifacts: [
        { id: "old", name: "build", sizeBytes: 1000, createdAt: daysAgo(60), workflowRunId: "wf-A" },
        { id: "fresh", name: "build", sizeBytes: 500, createdAt: daysAgo(5), workflowRunId: "wf-A" },
      ],
    },
    expected: {
      deletedCount: 1,
      retainedCount: 1,
      bytesReclaimed: 1000,
      totalArtifacts: 2,
      dryRun: true,
      deletedIds: ["old"],
    },
  },
  {
    name: "keep-latest-per-workflow",
    fixture: {
      name: "keep-latest-per-workflow",
      now: NOW_ISO,
      dryRun: false,
      policy: { keepLatestPerWorkflow: 2 },
      artifacts: [
        { id: "A-1", name: "art", sizeBytes: 100, createdAt: daysAgo(5), workflowRunId: "wf-A" },
        { id: "A-2", name: "art", sizeBytes: 100, createdAt: daysAgo(3), workflowRunId: "wf-A" },
        { id: "A-3", name: "art", sizeBytes: 100, createdAt: daysAgo(1), workflowRunId: "wf-A" },
        { id: "B-1", name: "art", sizeBytes: 100, createdAt: daysAgo(2), workflowRunId: "wf-B" },
      ],
    },
    expected: {
      deletedCount: 1,
      retainedCount: 3,
      bytesReclaimed: 100,
      totalArtifacts: 4,
      dryRun: false,
      deletedIds: ["A-1"],
    },
  },
  {
    name: "combined-policy-with-size-cap",
    fixture: {
      name: "combined-policy-with-size-cap",
      now: NOW_ISO,
      dryRun: false,
      policy: { maxAgeDays: 30, keepLatestPerWorkflow: 2, maxTotalSizeBytes: 500 },
      artifacts: [
        { id: "very-old", name: "a", sizeBytes: 200, createdAt: daysAgo(100), workflowRunId: "wf-A" },
        { id: "A-old", name: "a", sizeBytes: 200, createdAt: daysAgo(10), workflowRunId: "wf-A" },
        { id: "A-mid", name: "a", sizeBytes: 200, createdAt: daysAgo(5), workflowRunId: "wf-A" },
        { id: "A-new", name: "a", sizeBytes: 200, createdAt: daysAgo(1), workflowRunId: "wf-A" },
      ],
    },
    // age-policy deletes very-old. keep-latest=2 deletes A-old (keep A-mid/A-new).
    // Remaining 400B <= 500 cap, so size rule no-ops.
    expected: {
      deletedCount: 2,
      retainedCount: 2,
      bytesReclaimed: 400,
      totalArtifacts: 4,
      dryRun: false,
      deletedIds: ["A-old", "very-old"],
    },
  },
];

describe("workflow file structure", () => {
  const yamlText = readFileSync(WORKFLOW, "utf8");
  const wf = parseYaml(yamlText);

  test("declares expected triggers", () => {
    // YAML parses `on:` as the boolean true. Access via either key.
    const on = (wf as Record<string, unknown>).on ?? (wf as Record<string, unknown>)[true as unknown as string];
    expect(on).toBeDefined();
    const triggers = Object.keys(on as object);
    expect(triggers).toContain("push");
    expect(triggers).toContain("pull_request");
    expect(triggers).toContain("workflow_dispatch");
    expect(triggers).toContain("schedule");
  });

  test("declares read-only top-level permissions", () => {
    expect(wf.permissions?.contents).toBe("read");
  });

  test("has test and cleanup jobs with cleanup depending on test", () => {
    expect(wf.jobs.test).toBeDefined();
    expect(wf.jobs.cleanup).toBeDefined();
    expect(wf.jobs.cleanup.needs).toBe("test");
  });

  test("references script files that exist on disk", () => {
    const cleanupSteps = wf.jobs.cleanup.steps as Array<{ run?: string }>;
    const runLines = cleanupSteps.map((s) => s.run ?? "").join("\n");
    expect(runLines).toContain("run-case.ts");
    expect(existsSync(join(REPO, "run-case.ts"))).toBe(true);
    expect(existsSync(join(REPO, "cleanup.ts"))).toBe(true);
    expect(existsSync(join(REPO, "fixtures/case.json"))).toBe(true);
  });

  test("all referenced uses: actions resolve to valid action refs", () => {
    const steps: Array<{ uses?: string }> = [];
    for (const job of Object.values(wf.jobs) as Array<{ steps: Array<{ uses?: string }> }>) {
      steps.push(...job.steps);
    }
    const uses = steps.map((s) => s.uses).filter(Boolean) as string[];
    expect(uses).toContain("actions/checkout@v4");
    expect(uses.some((u) => u.startsWith("oven-sh/setup-bun@"))).toBe(true);
  });
});

describe("actionlint", () => {
  test("workflow passes actionlint cleanly", () => {
    const res = spawnSync("actionlint", [WORKFLOW], { encoding: "utf8" });
    if (res.status !== 0) {
      console.error(res.stdout, res.stderr);
    }
    expect(res.status).toBe(0);
  });
});

// ---- act-driven cases ----
// Each case sets up a throwaway temp git repo with the full project files and
// that case's fixture, runs `act push --rm`, and asserts on exact output.

function setupActRepo(tc: TestCase): string {
  const dir = mkdtempSync(join(tmpdir(), "act-cleanup-"));
  // Copy project files needed by the workflow.
  const toCopy = [
    ".github",
    "fixtures",
    ".actrc",
    "cleanup.ts",
    "cli.ts",
    "run-case.ts",
    "cleanup.test.ts",
    "cli.test.ts",
    "package.json",
    "bun.lock",
    "tsconfig.json",
  ];
  for (const p of toCopy) {
    if (existsSync(join(REPO, p))) {
      cpSync(join(REPO, p), join(dir, p), { recursive: true });
    }
  }
  // Overwrite fixture with this case's payload.
  writeFileSync(
    join(dir, "fixtures/case.json"),
    JSON.stringify(tc.fixture, null, 2)
  );
  // Initialize git (act requires a repo).
  spawnSync("git", ["init", "-q"], { cwd: dir });
  spawnSync("git", ["config", "user.email", "t@t"], { cwd: dir });
  spawnSync("git", ["config", "user.name", "t"], { cwd: dir });
  spawnSync("git", ["add", "-A"], { cwd: dir });
  spawnSync("git", ["commit", "-qm", "init"], { cwd: dir });
  return dir;
}

function runAct(dir: string): { stdout: string; stderr: string; status: number | null } {
  // `--pull=false` forces use of the local act-ubuntu-pwsh image without
  // trying to pull from a registry (which 403s in this sandbox).
  const res = spawnSync("act", ["push", "--rm", "--pull=false"], {
    cwd: dir,
    encoding: "utf8",
    timeout: 5 * 60 * 1000,
  });
  return { stdout: res.stdout ?? "", stderr: res.stderr ?? "", status: res.status };
}

beforeAll(() => {
  // Fresh result file per run.
  writeFileSync(ACT_RESULT, `# act results — generated ${new Date().toISOString()}\n`);
});

describe("act pipeline cases", () => {
  for (const tc of CASES) {
    test(
      `case ${tc.name}: pipeline succeeds with expected plan`,
      () => {
        const dir = setupActRepo(tc);
        let got;
        try {
          got = runAct(dir);
        } finally {
          // Best effort.
          try {
            rmSync(dir, { recursive: true, force: true });
          } catch {}
        }
        const combined = got.stdout + "\n" + got.stderr;
        appendFileSync(
          ACT_RESULT,
          [
            `\n\n===== CASE: ${tc.name} =====`,
            `exit status: ${got.status}`,
            "----- stdout -----",
            got.stdout,
            "----- stderr -----",
            got.stderr,
            `===== END CASE: ${tc.name} =====\n`,
          ].join("\n")
        );

        expect(got.status).toBe(0);
        // Both jobs must succeed per benchmark rule.
        const successMatches = combined.match(/Job succeeded/g) ?? [];
        expect(successMatches.length).toBeGreaterThanOrEqual(2);

        // Locate RESULT_JSON line and assert exact expected values.
        const resultLine = combined.split("\n").find((l) => l.includes("RESULT_JSON="));
        expect(resultLine).toBeTruthy();
        const jsonPart = resultLine!.slice(resultLine!.indexOf("RESULT_JSON=") + "RESULT_JSON=".length).trim();
        // act prefixes each line with "| " from the step name; strip leading cruft
        // up to the first '{'.
        const braceIdx = jsonPart.indexOf("{");
        const result = JSON.parse(jsonPart.slice(braceIdx));
        expect(result.deletedCount).toBe(tc.expected.deletedCount);
        expect(result.retainedCount).toBe(tc.expected.retainedCount);
        expect(result.bytesReclaimed).toBe(tc.expected.bytesReclaimed);
        expect(result.totalArtifacts).toBe(tc.expected.totalArtifacts);
        expect(result.dryRun).toBe(tc.expected.dryRun);
        expect(result.deletedIds).toEqual(tc.expected.deletedIds);
      },
      10 * 60 * 1000
    );
  }
});
