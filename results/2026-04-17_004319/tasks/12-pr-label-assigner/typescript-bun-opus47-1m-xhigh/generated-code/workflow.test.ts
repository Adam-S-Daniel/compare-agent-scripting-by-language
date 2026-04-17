// End-to-end workflow tests.
//
// This file contains two layers of tests:
//
//   A. Structure tests (fast, no Docker): parse the workflow YAML, confirm
//      triggers/jobs/steps look right, confirm referenced paths exist, and
//      confirm `actionlint` still passes.
//
//   B. `act`-backed tests (slow): for each test case, spin up a temp git
//      repo, drop in that case's fixture, run `act push --rm`, and assert the
//      workflow output contains exactly the expected label set.
//
// Budget: per the task's guardrail we keep act runs to at most 3. The harness
// runs exactly three cases (docs-only, api-feature, mixed) and stops.
//
// All act output (successful or not) is appended to `act-result.txt` in the
// project root, with clear delimiters per case. That file is a required
// artifact of this test suite.

import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { parse as parseYaml } from "yaml";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const PROJECT_ROOT = import.meta.dir;
const WORKFLOW_PATH = resolve(PROJECT_ROOT, ".github/workflows/pr-label-assigner.yml");
const ACT_RESULT_FILE = resolve(PROJECT_ROOT, "act-result.txt");

// Files to copy into each temp repo. Node_modules is intentionally excluded —
// the workflow itself runs `bun install`.
const PROJECT_FILES = [
  "labeler.ts",
  "labeler.test.ts",
  "cli.ts",
  "cli.test.ts",
  "labels.config.json",
  "package.json",
  "bun.lock",
  "tsconfig.json",
  ".actrc",
];
const PROJECT_DIRS = [".github", "fixtures"];

interface ActResult {
  exitCode: number;
  stdout: string;
  stderr: string;
}

interface TestCase {
  name: string;
  // Fixture file path (relative to repo root) that the workflow will evaluate.
  fixtureRelPath: string;
  // Contents to write into that fixture (overrides whatever shipped in the repo).
  fixtureContent: string;
  // Labels we expect the workflow to print as the final LABELS_JSON line.
  expectedLabels: string[];
}

const CASES: TestCase[] = [
  {
    name: "docs-only",
    fixtureRelPath: "fixtures/act-case-docs.txt",
    fixtureContent: ["docs/readme.md", "docs/guides/setup.md"].join("\n") + "\n",
    // docs rule (pri 1) + markdown rule (pri 1) → dedupe to "documentation";
    // no size rule matches src/** so size/S wins the exclusive group.
    expectedLabels: ["documentation", "size/S"],
  },
  {
    name: "api-feature",
    fixtureRelPath: "fixtures/act-case-api.txt",
    fixtureContent:
      [
        "src/api/users.ts",
        "src/api/users.test.ts",
        "src/api/handlers/auth.ts",
      ].join("\n") + "\n",
    // api (pri 10) + tests (pri 3). size/L wins size group (pri 10).
    expectedLabels: ["api", "size/L", "tests"],
  },
  {
    name: "mixed",
    fixtureRelPath: "fixtures/act-case-mixed.txt",
    fixtureContent:
      [
        "docs/api/overview.md",
        "src/frontend/App.tsx",
        "src/backend/server.ts",
        "src/backend/db.test.ts",
        "package.json",
        ".github/workflows/ci.yml",
      ].join("\n") + "\n",
    // backend & frontend (pri 5), dependencies (pri 4), tests (pri 3),
    // ci (pri 2), documentation (pri 1), size/M from size group (pri 5).
    // Ties break alphabetically: backend,frontend,size/M @ pri 5.
    expectedLabels: [
      "backend",
      "frontend",
      "size/M",
      "dependencies",
      "tests",
      "ci",
      "documentation",
    ],
  },
];

// ---------------------------------------------------------------------------
// Structure tests (no Docker required)
// ---------------------------------------------------------------------------

describe("workflow file structure", () => {
  let workflow: {
    name: string;
    on: Record<string, unknown>;
    permissions?: Record<string, string>;
    env?: Record<string, string>;
    jobs: Record<string, { steps: { name?: string; uses?: string; run?: string }[] }>;
  };

  beforeAll(async () => {
    const text = await Bun.file(WORKFLOW_PATH).text();
    workflow = parseYaml(text);
  });

  test("workflow YAML parses successfully", () => {
    expect(workflow).toBeTruthy();
    expect(workflow.name).toBe("PR Label Assigner");
  });

  test("workflow has expected trigger events", () => {
    const triggers = workflow.on;
    expect(triggers).toBeTruthy();
    expect(Object.keys(triggers)).toEqual(
      expect.arrayContaining(["push", "pull_request", "workflow_dispatch"]),
    );
  });

  test("workflow declares contents:read permission", () => {
    expect(workflow.permissions?.contents).toBe("read");
  });

  test("workflow has an assign-labels job with checkout and script steps", () => {
    const job = workflow.jobs["assign-labels"];
    expect(job).toBeTruthy();
    const stepNames = job.steps.map((s) => s.name ?? s.uses ?? "").filter(Boolean);
    expect(stepNames).toEqual(
      expect.arrayContaining([
        "Checkout repository",
        "Install Bun",
        "Install dependencies",
        "Run unit tests",
        "Assign labels from fixture",
      ]),
    );
    // Checkout must be the standard action at v4.
    const checkout = job.steps.find((s) => s.name === "Checkout repository");
    expect(checkout?.uses).toBe("actions/checkout@v4");
  });

  test("workflow references files that exist on disk", async () => {
    // The workflow references cli.ts directly in a run: step and points at
    // labels.config.json via the LABEL_CONFIG env var. Check both, and confirm
    // each referenced path resolves to a real file in the project.
    const stepsText = JSON.stringify(workflow.jobs);
    expect(stepsText).toContain("cli.ts");
    expect(workflow.env?.LABEL_CONFIG).toBe("labels.config.json");
    expect(workflow.env?.DEFAULT_FIXTURE).toBe("fixtures/mixed.txt");
    expect(await Bun.file(resolve(PROJECT_ROOT, "cli.ts")).exists()).toBe(true);
    expect(
      await Bun.file(resolve(PROJECT_ROOT, workflow.env!.LABEL_CONFIG)).exists(),
    ).toBe(true);
    expect(
      await Bun.file(resolve(PROJECT_ROOT, workflow.env!.DEFAULT_FIXTURE)).exists(),
    ).toBe(true);
    expect(await Bun.file(resolve(PROJECT_ROOT, "labeler.ts")).exists()).toBe(true);
  });

  test("actionlint passes with exit code 0", async () => {
    const proc = Bun.spawn(["actionlint", WORKFLOW_PATH], {
      stdout: "pipe",
      stderr: "pipe",
    });
    const stdout = await new Response(proc.stdout).text();
    const stderr = await new Response(proc.stderr).text();
    const code = await proc.exited;
    if (code !== 0) {
      console.error("actionlint stdout:\n" + stdout + "\nstderr:\n" + stderr);
    }
    expect(code).toBe(0);
  });
});

// ---------------------------------------------------------------------------
// act-backed tests
// ---------------------------------------------------------------------------

// Reset act-result.txt once, before any case runs.
beforeAll(async () => {
  await Bun.write(ACT_RESULT_FILE, `act-result.txt created ${new Date().toISOString()}\n`);
});

afterAll(() => {
  // Clean up temp repos the harness created; keep act-result.txt intact.
  for (const dir of createdTempDirs) {
    try {
      rmSync(dir, { recursive: true, force: true });
    } catch {
      // ignore
    }
  }
});

const createdTempDirs: string[] = [];

async function runShell(
  cmd: string[],
  cwd: string,
  env?: Record<string, string>,
): Promise<ActResult> {
  const proc = Bun.spawn(cmd, {
    cwd,
    env: { ...process.env, ...(env ?? {}) } as Record<string, string>,
    stdout: "pipe",
    stderr: "pipe",
  });
  const [stdout, stderr] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
  ]);
  const exitCode = await proc.exited;
  return { stdout, stderr, exitCode };
}

async function setupTempRepo(tcase: TestCase): Promise<string> {
  const dir = mkdtempSync(join(tmpdir(), `pr-labeler-act-${tcase.name}-`));
  createdTempDirs.push(dir);

  // Copy project files.
  for (const f of PROJECT_FILES) {
    const src = resolve(PROJECT_ROOT, f);
    const dst = resolve(dir, f);
    const file = Bun.file(src);
    if (await file.exists()) {
      await Bun.write(dst, file);
    }
  }
  // Copy dirs recursively via `cp -r` (fine: these are small trees).
  for (const d of PROJECT_DIRS) {
    const src = resolve(PROJECT_ROOT, d);
    const r = await runShell(["cp", "-r", src, dir], PROJECT_ROOT);
    if (r.exitCode !== 0) {
      throw new Error(`failed to copy ${d}: ${r.stderr}`);
    }
  }

  // Write the case's fixture file (overrides any shipped fixture of same name).
  await Bun.write(resolve(dir, tcase.fixtureRelPath), tcase.fixtureContent);

  // Initialize a git repo so act has something to read as the "push" event.
  const gitCmds: string[][] = [
    ["git", "init", "-q", "-b", "main"],
    ["git", "config", "user.email", "harness@example.test"],
    ["git", "config", "user.name", "Harness"],
    ["git", "add", "-A"],
    ["git", "commit", "-q", "-m", `case ${tcase.name}`],
  ];
  for (const c of gitCmds) {
    const r = await runShell(c, dir);
    if (r.exitCode !== 0) {
      throw new Error(`git setup failed (${c.join(" ")}): ${r.stderr}`);
    }
  }
  return dir;
}

async function appendToActResult(header: string, body: string): Promise<void> {
  const existing = await Bun.file(ACT_RESULT_FILE).text();
  const delim = "=".repeat(70);
  const chunk = `\n${delim}\n${header}\n${delim}\n${body}\n`;
  await Bun.write(ACT_RESULT_FILE, existing + chunk);
}

describe("workflow via act", () => {
  for (const tcase of CASES) {
    test(
      `case ${tcase.name}: labels match expected set`,
      async () => {
        const dir = await setupTempRepo(tcase);
        const result = await runShell(
          [
            "act",
            "push",
            "--rm",
            // --pull=false: use the local act-ubuntu-pwsh image directly
            // without trying to pull from a remote registry (it's a local build).
            "--pull=false",
            "-W",
            ".github/workflows/pr-label-assigner.yml",
            "--env",
            `PR_LABELER_FIXTURE=${tcase.fixtureRelPath}`,
          ],
          dir,
        );
        const body =
          `CASE: ${tcase.name}\n` +
          `CWD: ${dir}\n` +
          `EXIT_CODE: ${result.exitCode}\n` +
          `--- STDOUT ---\n${result.stdout}\n` +
          `--- STDERR ---\n${result.stderr}\n`;
        await appendToActResult(`act case: ${tcase.name}`, body);

        // Surface diagnostics if it failed — helps diagnose without re-running.
        if (result.exitCode !== 0) {
          console.error(body);
        }

        expect(result.exitCode).toBe(0);

        // Every job must report success.
        expect(result.stdout).toMatch(/Job succeeded/);

        // The workflow prints a deterministic JSON line; find it and compare.
        const match = result.stdout.match(/LABELS_JSON:\s*(\{.*\})/);
        expect(match).toBeTruthy();
        const parsed = JSON.parse(match![1]) as { labels: string[] };
        expect(parsed.labels).toEqual(tcase.expectedLabels);
      },
      { timeout: 240_000 },
    );
  }
});
