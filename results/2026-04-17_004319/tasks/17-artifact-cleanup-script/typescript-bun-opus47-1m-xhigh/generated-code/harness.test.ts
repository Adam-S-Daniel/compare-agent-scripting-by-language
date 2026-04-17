// Test harness that drives the cleanup script through the GitHub Actions
// workflow via `act`. Each test case sets up a temp git repo seeded with the
// project files + a fixture, runs `act push --rm` once, and asserts exact
// expected values in the captured output.
//
// All cumulative output is appended to `act-result.txt` (in the project
// root) so the run is auditable after the fact.
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { spawnSync } from "node:child_process";
import {
  appendFileSync,
  cpSync,
  existsSync,
  mkdtempSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
// Bun has a built-in YAML parser since 1.2 — avoids an external dep.
const parseYAML = (s: string): unknown => Bun.YAML.parse(s);

// Project root = directory containing this file.
const PROJECT_ROOT = resolve(import.meta.dir);
const ACT_RESULT = join(PROJECT_ROOT, "act-result.txt");
const WORKFLOW_PATH = join(
  PROJECT_ROOT,
  ".github/workflows/artifact-cleanup-script.yml",
);

// One test case = one fixture + the env vars to pass to the workflow + the
// substrings (and their absences) that MUST appear in the captured act output.
interface Case {
  fixture: string;
  dryRun: boolean;
  // Substrings that must appear in the act output.
  mustContain: string[];
  // Substrings that must NOT appear.
  mustNotContain: string[];
}

const CASES: Case[] = [
  {
    fixture: "case-max-age",
    dryRun: true,
    mustContain: [
      "DRY RUN",
      "Total artifacts: 4",
      "To delete: 2",
      "To retain: 2",
      "Bytes reclaimed: 3072",
      "Bytes retained: 12288",
      "old-build-1",
      "old-build-2",
      "older than 30 days",
      'SUMMARY {"totalArtifacts":4,"deletedCount":2,"retainedCount":2,"bytesReclaimed":3072,"bytesRetained":12288}',
      "Job succeeded",
    ],
    mustNotContain: ["fresh-build-1", "fresh-build-2"],
  },
  {
    fixture: "case-keep-latest",
    dryRun: true,
    mustContain: [
      "DRY RUN",
      "Total artifacts: 5",
      "To delete: 2",
      "To retain: 3",
      "Bytes reclaimed: 200",
      "Bytes retained: 700",
      "ci-a",
      "ci-b",
      "exceeds keep-latest-2",
      'SUMMARY {"totalArtifacts":5,"deletedCount":2,"retainedCount":3,"bytesReclaimed":200,"bytesRetained":700}',
      "Job succeeded",
    ],
    mustNotContain: ["rel-a"],
  },
  {
    fixture: "case-combined",
    dryRun: false,
    mustContain: [
      "Total artifacts: 4",
      "To delete: 3",
      "To retain: 1",
      "Bytes reclaimed: 5400",
      "Bytes retained: 200",
      "ancient",
      "ci-extra",
      "huge-recent",
      "older than 30 days",
      "exceeds keep-latest-1",
      "total size budget 1000 bytes exceeded",
      'SUMMARY {"totalArtifacts":4,"deletedCount":3,"retainedCount":1,"bytesReclaimed":5400,"bytesRetained":200}',
      "Job succeeded",
    ],
    // Use the exact banner string — "DRY RUN" alone appears in the unit
    // test name "...DRY RUN banner" that bun test prints inside the
    // workflow, so a bare substring would false-positive.
    mustNotContain: [
      "=== DRY RUN — no artifacts will be deleted ===",
      "ci-keep (200 bytes) —",
    ],
  },
];

// Run a command and return its captured output.
function run(
  cmd: string,
  args: string[],
  opts: { cwd?: string; env?: Record<string, string> } = {},
): { stdout: string; stderr: string; status: number } {
  const result = spawnSync(cmd, args, {
    cwd: opts.cwd,
    env: { ...process.env, ...(opts.env ?? {}) },
    encoding: "utf-8",
    stdio: ["ignore", "pipe", "pipe"],
    maxBuffer: 50 * 1024 * 1024,
  });
  return {
    stdout: result.stdout ?? "",
    stderr: result.stderr ?? "",
    status: result.status ?? -1,
  };
}

// ---- Workflow structure tests ----------------------------------------------

describe("workflow structure", () => {
  test("workflow file exists", () => {
    expect(existsSync(WORKFLOW_PATH)).toBe(true);
  });

  test("yaml parses and has expected triggers, jobs, and steps", async () => {
    const text = await Bun.file(WORKFLOW_PATH).text();
    const wf = parseYAML(text) as {
      on: Record<string, unknown>;
      jobs: Record<string, { steps: Array<{ name?: string; uses?: string }> }>;
    };
    // Triggers we declared.
    expect(Object.keys(wf.on).sort()).toEqual([
      "pull_request",
      "push",
      "schedule",
      "workflow_dispatch",
    ]);
    // Job exists with sensible step set.
    expect(wf.jobs.cleanup).toBeDefined();
    const stepNames = wf.jobs.cleanup.steps.map((s) => s.name ?? s.uses);
    expect(stepNames).toContain("Run unit tests (bun test)");
    expect(stepNames).toContain("Run cleanup planner");
    // Uses checkout@v4 specifically.
    expect(
      wf.jobs.cleanup.steps.some((s) => s.uses === "actions/checkout@v4"),
    ).toBe(true);
  });

  test("workflow references existing script and fixture files", () => {
    expect(existsSync(join(PROJECT_ROOT, "cleanup.ts"))).toBe(true);
    for (const c of CASES) {
      expect(
        existsSync(join(PROJECT_ROOT, `fixtures/${c.fixture}.artifacts.json`)),
      ).toBe(true);
      expect(
        existsSync(join(PROJECT_ROOT, `fixtures/${c.fixture}.policy.json`)),
      ).toBe(true);
    }
  });

  test("actionlint passes on the workflow", () => {
    const r = run("actionlint", [WORKFLOW_PATH]);
    if (r.status !== 0) {
      // surface the actionlint output if it ever fails
      console.error("actionlint stdout:", r.stdout);
      console.error("actionlint stderr:", r.stderr);
    }
    expect(r.status).toBe(0);
  });
});

// ---- act-driven end-to-end tests -------------------------------------------

// Reset act-result.txt once at the start so the file always contains exactly
// one run's worth of output (and is created fresh each time).
beforeAll(() => {
  writeFileSync(
    ACT_RESULT,
    `act-result.txt — generated ${new Date().toISOString()}\n`,
  );
});

// Track temp dirs so we can clean up.
const tempDirs: string[] = [];
afterAll(() => {
  for (const d of tempDirs) {
    try {
      rmSync(d, { recursive: true, force: true });
    } catch {
      /* best-effort */
    }
  }
});

// Set up a temp git repo with the project files. We copy the whole project
// (excluding node_modules / .git / act-result.txt). The fixture is selected
// via the FIXTURE env var passed to act, so all fixture files are present
// but only one case is exercised per run.
function setupTempRepo(label: string): string {
  const dir = mkdtempSync(join(tmpdir(), `act-${label}-`));
  tempDirs.push(dir);
  // Copy project tree, skipping volatile / output paths.
  cpSync(PROJECT_ROOT, dir, {
    recursive: true,
    filter: (src) => {
      if (src.endsWith("act-result.txt")) return false;
      if (src.includes("/node_modules")) return false;
      if (src.endsWith("/.git") || src.includes("/.git/")) return false;
      return true;
    },
  });
  // Initialize a fresh git repo so act has a valid context.
  run("git", ["init", "-q", "-b", "main"], { cwd: dir });
  run("git", ["config", "user.email", "ci@example.com"], { cwd: dir });
  run("git", ["config", "user.name", "ci"], { cwd: dir });
  run("git", ["add", "-A"], { cwd: dir });
  run("git", ["commit", "-q", "-m", "seed"], { cwd: dir });
  return dir;
}

describe("end-to-end via act", () => {
  for (const c of CASES) {
    test(
      `act push runs ${c.fixture} (dryRun=${c.dryRun}) successfully`,
      async () => {
        const repo = setupTempRepo(c.fixture);
        const r = run(
          "act",
          [
            "push",
            "--rm",
            "--env",
            `FIXTURE=${c.fixture}`,
            "--env",
            `DRY_RUN=${c.dryRun ? "true" : "false"}`,
          ],
          { cwd: repo },
        );
        const combined = r.stdout + "\n----- STDERR -----\n" + r.stderr;
        const banner = [
          "",
          "================================================================",
          `=== CASE: ${c.fixture}  (dryRun=${c.dryRun})  exit=${r.status} ===`,
          "================================================================",
          "",
        ].join("\n");
        appendFileSync(ACT_RESULT, banner + combined + "\n");

        expect(r.status).toBe(0);
        for (const needle of c.mustContain) {
          expect(combined).toContain(needle);
        }
        for (const needle of c.mustNotContain) {
          expect(combined).not.toContain(needle);
        }
      },
      // act + Bun install can take well over a minute per case.
      300_000,
    );
  }
});
