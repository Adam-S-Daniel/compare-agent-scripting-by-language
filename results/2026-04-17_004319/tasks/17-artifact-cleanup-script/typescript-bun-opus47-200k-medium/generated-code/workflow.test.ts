// Workflow & act harness tests. Every functional test case runs through `act`.
import { describe, test, expect, beforeAll } from "bun:test";
import { existsSync, mkdtempSync, cpSync, writeFileSync, rmSync } from "node:fs";
import { appendFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { $ } from "bun";
import { parse as parseYaml } from "yaml";

const WORKSPACE = import.meta.dir;
const ACT_RESULT = join(WORKSPACE, "act-result.txt");
const WORKFLOW = join(WORKSPACE, ".github/workflows/artifact-cleanup-script.yml");

// Test cases drive different fixture files through the same workflow.
// Expected values are computed against the reference policy encoded in the workflow:
//   --max-age-days 30 --keep-latest-per-workflow 2 --now 2026-04-20T00:00:00Z --dry-run
interface Case {
  name: string;
  fixture: Array<{
    name: string;
    sizeBytes: number;
    createdAt: string;
    workflowRunId: string;
  }>;
  expectDeleted: number;
  expectRetained: number;
  expectBytesReclaimed: number;
  mustContain: string[];
}

const cases: Case[] = [
  {
    name: "default-mixed",
    fixture: [
      { name: "build-old", sizeBytes: 500, createdAt: "2026-01-01T00:00:00Z", workflowRunId: "w1" },
      { name: "build-new", sizeBytes: 50, createdAt: "2026-04-19T00:00:00Z", workflowRunId: "w1" },
      { name: "logs-1", sizeBytes: 50, createdAt: "2026-04-18T00:00:00Z", workflowRunId: "w2" },
      { name: "logs-2", sizeBytes: 50, createdAt: "2026-04-17T00:00:00Z", workflowRunId: "w2" },
      { name: "logs-3", sizeBytes: 50, createdAt: "2026-04-16T00:00:00Z", workflowRunId: "w2" },
    ],
    // build-old deleted by age; logs-3 deleted as excess of w2 (keep 2 newest).
    expectDeleted: 2,
    expectRetained: 3,
    expectBytesReclaimed: 550,
    mustContain: ["[DELETE] build-old", "[DELETE] logs-3", "[KEEP] build-new"],
  },
  {
    name: "all-fresh-single-workflow",
    fixture: [
      { name: "fresh-a", sizeBytes: 10, createdAt: "2026-04-19T00:00:00Z", workflowRunId: "wX" },
      { name: "fresh-b", sizeBytes: 10, createdAt: "2026-04-18T00:00:00Z", workflowRunId: "wX" },
    ],
    expectDeleted: 0,
    expectRetained: 2,
    expectBytesReclaimed: 0,
    mustContain: ["Delete: 0", "Retain: 2"],
  },
  {
    name: "keep-latest-kicks-in",
    fixture: [
      { name: "r1", sizeBytes: 10, createdAt: "2026-04-19T00:00:00Z", workflowRunId: "wK" },
      { name: "r2", sizeBytes: 10, createdAt: "2026-04-18T00:00:00Z", workflowRunId: "wK" },
      { name: "r3", sizeBytes: 10, createdAt: "2026-04-17T00:00:00Z", workflowRunId: "wK" },
      { name: "r4", sizeBytes: 10, createdAt: "2026-04-16T00:00:00Z", workflowRunId: "wK" },
    ],
    // keepLatestPerWorkflow=2 -> delete r3, r4.
    expectDeleted: 2,
    expectRetained: 2,
    expectBytesReclaimed: 20,
    mustContain: ["[DELETE] r3", "[DELETE] r4", "[KEEP] r1", "[KEEP] r2"],
  },
];

beforeAll(() => {
  // Reset the cumulative act-result.txt on fresh run.
  if (existsSync(ACT_RESULT)) rmSync(ACT_RESULT);
  writeFileSync(ACT_RESULT, `# act results — generated ${new Date().toISOString()}\n\n`);
});

describe("workflow structure", () => {
  test("actionlint passes on workflow", async () => {
    const proc = Bun.spawnSync(["actionlint", WORKFLOW]);
    expect(proc.exitCode).toBe(0);
  });

  test("workflow YAML parses and contains expected triggers/jobs/steps", async () => {
    const raw = await Bun.file(WORKFLOW).text();
    const doc = parseYaml(raw) as Record<string, unknown>;
    // YAML "on:" parses to key `true` in some loaders; yaml package preserves "on".
    const on = (doc["on"] ?? (doc as Record<string, unknown>)[true as unknown as string]) as Record<
      string,
      unknown
    >;
    expect(on).toBeDefined();
    expect(Object.keys(on)).toEqual(
      expect.arrayContaining(["push", "pull_request", "workflow_dispatch", "schedule"]),
    );
    const jobs = doc.jobs as Record<string, { steps: Array<Record<string, unknown>> }>;
    expect(jobs.cleanup).toBeDefined();
    const stepUses = jobs.cleanup.steps.map((s) => s.uses).filter(Boolean);
    expect(stepUses).toEqual(
      expect.arrayContaining(["actions/checkout@v4", "oven-sh/setup-bun@v2"]),
    );
    // Steps reference cleanup.ts and fixtures/artifacts.json.
    const joinedRun = jobs.cleanup.steps.map((s) => (s.run as string) ?? "").join("\n");
    expect(joinedRun).toContain("cleanup.ts");
    expect(joinedRun).toContain("fixtures/artifacts.json");
  });

  test("referenced script files exist", () => {
    expect(existsSync(join(WORKSPACE, "cleanup.ts"))).toBe(true);
    expect(existsSync(join(WORKSPACE, "cleanup.test.ts"))).toBe(true);
    expect(existsSync(join(WORKSPACE, "fixtures/artifacts.json"))).toBe(true);
    expect(existsSync(join(WORKSPACE, "package.json"))).toBe(true);
  });
});

// Run each case through `act push --rm` in an isolated temp git repo.
async function runActCase(c: Case): Promise<string> {
  const tmp = mkdtempSync(join(tmpdir(), `act-case-${c.name}-`));
  try {
    // Copy project files (exclude node_modules, .git, act-result.txt).
    for (const f of [
      "cleanup.ts",
      "cleanup.test.ts",
      "package.json",
      "bun.lock",
      "tsconfig.json",
      ".actrc",
      ".github",
      "fixtures",
    ]) {
      const src = join(WORKSPACE, f);
      if (existsSync(src)) cpSync(src, join(tmp, f), { recursive: true });
    }
    // Overwrite fixture with this case's data.
    writeFileSync(
      join(tmp, "fixtures/artifacts.json"),
      JSON.stringify(c.fixture, null, 2),
    );

    // Initialize git repo (act needs it).
    await $`git init -q && git add -A && git -c user.email=t@t -c user.name=t commit -q -m init`.cwd(tmp);

    const proc = Bun.spawnSync({
      cmd: ["act", "push", "--rm", "--pull=false"],
      cwd: tmp,
      stdout: "pipe",
      stderr: "pipe",
    });
    const out = new TextDecoder().decode(proc.stdout) + new TextDecoder().decode(proc.stderr);
    const header = `\n\n===== CASE: ${c.name} (exit=${proc.exitCode}) =====\n`;
    appendFileSync(ACT_RESULT, header + out);
    if (proc.exitCode !== 0) {
      throw new Error(`act failed for case ${c.name}; see act-result.txt`);
    }
    return out;
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
}

describe("act-run workflow cases", () => {
  for (const c of cases) {
    test(
      `case: ${c.name}`,
      async () => {
        const out = await runActCase(c);
        expect(out).toContain(`Delete: ${c.expectDeleted}`);
        expect(out).toContain(`Retain: ${c.expectRetained}`);
        expect(out).toContain(`Bytes reclaimed: ${c.expectBytesReclaimed}`);
        for (const s of c.mustContain) expect(out).toContain(s);
        // Every job reports success.
        expect(out).toMatch(/Job succeeded/);
      },
      { timeout: 300_000 },
    );
  }

  test("act-result.txt exists and is non-empty", () => {
    expect(existsSync(ACT_RESULT)).toBe(true);
    const size = Bun.file(ACT_RESULT).size;
    expect(size).toBeGreaterThan(100);
  });
});
