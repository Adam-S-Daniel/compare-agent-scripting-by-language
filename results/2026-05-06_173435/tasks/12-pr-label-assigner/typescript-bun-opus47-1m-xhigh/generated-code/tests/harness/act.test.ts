// End-to-end test harness: every test case runs through the
// real GitHub Actions workflow via `act push --rm`.
//
// For each case we:
//   1. Materialise an isolated temp git repo containing the project
//      files + that case's fixture data.
//   2. Run `act push --rm` from that repo, capturing combined output.
//   3. Append the captured output to <project>/act-result.txt with a
//      clear delimiter for the case.
//   4. Assert: exit code is 0, every job ended with "Job succeeded",
//      and the LABELS_OUTPUT line contains the exact expected labels.
//
// Also includes structural checks on the workflow YAML itself (what
// the spec calls "Workflow Structure Tests"): triggers/jobs/steps and
// referenced script paths exist, and `actionlint` exits 0.

import {
  beforeAll,
  beforeEach,
  describe,
  expect,
  test,
} from "bun:test";
import {
  appendFileSync,
  cpSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { parse as parseYaml } from "yaml";
import { cases } from "./act-cases.ts";

const PROJECT_ROOT = join(import.meta.dir, "..", "..");
const WORKFLOW_PATH = join(PROJECT_ROOT, ".github/workflows/pr-label-assigner.yml");
const ACT_RESULT_PATH = join(PROJECT_ROOT, "act-result.txt");

// Files that constitute the "shippable" project — copied into each temp repo.
// We deliberately do NOT copy the project-root .actrc: it pins a local-only
// image tag with forcePull, which act can't pull from a registry. The
// default catthehacker image works fine for our needs (node + curl).
const PROJECT_FILES = [
  "package.json",
  "bun.lock",
  "tsconfig.json",
  "pr-label-assigner.ts",
  ".github",
];

// Truncate the act-result file once before any test runs, so each
// harness invocation produces a fresh, fully-rebuilt artifact.
beforeAll(() => {
  writeFileSync(ACT_RESULT_PATH, "");
});

// ---------- Workflow structure tests --------------------------------

describe("workflow structure", () => {
  test("workflow file exists", () => {
    expect(existsSync(WORKFLOW_PATH)).toBe(true);
  });

  test("workflow declares the expected triggers, job, and steps", async () => {
    const yaml = await Bun.file(WORKFLOW_PATH).text();
    const wf = parseYaml(yaml) as {
      on: Record<string, unknown>;
      jobs: Record<
        string,
        { steps: Array<{ name?: string; uses?: string; run?: string }> }
      >;
    };

    // Triggers
    expect(Object.keys(wf.on).sort()).toEqual([
      "pull_request",
      "push",
      "workflow_dispatch",
    ]);

    // Single job named assign-labels
    expect(Object.keys(wf.jobs)).toEqual(["assign-labels"]);
    const job = wf.jobs["assign-labels"]!;

    // Step names (in order)
    const names = job.steps.map((s) => s.name);
    expect(names).toEqual([
      "Checkout",
      "Install bun",
      "Install project dependencies",
      "Assign labels from changed file paths",
      "Append to job summary",
    ]);

    // Checkout uses the pinned v4
    expect(job.steps[0]!.uses).toBe("actions/checkout@v4");

    // The assign step references our actual script file
    const assign = job.steps.find(
      (s) => s.name === "Assign labels from changed file paths",
    );
    expect(assign?.run).toContain("pr-label-assigner.ts");
  });

  test("script and fixture files referenced by the workflow exist", () => {
    expect(existsSync(join(PROJECT_ROOT, "pr-label-assigner.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_ROOT, "fixtures/config.json"))).toBe(true);
    expect(existsSync(join(PROJECT_ROOT, "fixtures/files.txt"))).toBe(true);
  });

  test("actionlint passes with exit code 0", async () => {
    const proc = Bun.spawn(["actionlint", WORKFLOW_PATH], {
      stdout: "pipe",
      stderr: "pipe",
    });
    const [stdout, stderr] = await Promise.all([
      new Response(proc.stdout).text(),
      new Response(proc.stderr).text(),
    ]);
    await proc.exited;
    if (proc.exitCode !== 0) {
      // Surface the lint output to make debugging trivial.
      console.error("actionlint stdout:\n" + stdout);
      console.error("actionlint stderr:\n" + stderr);
    }
    expect(proc.exitCode).toBe(0);
  });
});

// ---------- act-driven end-to-end cases ----------------------------

describe("act push end-to-end", () => {
  let workDir: string;

  beforeEach(() => {
    workDir = mkdtempSync(join(tmpdir(), "pr-label-act-"));
  });

  for (const c of cases) {
    test(
      c.name,
      async () => {
        // 1. Copy the project files into the temp repo.
        const repo = join(workDir, c.name);
        mkdirSync(repo, { recursive: true });
        for (const f of PROJECT_FILES) {
          const src = join(PROJECT_ROOT, f);
          if (!existsSync(src)) continue; // bun.lock may be absent on fresh clones
          cpSync(src, join(repo, f), { recursive: true });
        }

        // 2. Write this case's fixture data.
        mkdirSync(join(repo, "fixtures"), { recursive: true });
        writeFileSync(
          join(repo, "fixtures/config.json"),
          JSON.stringify(c.config, null, 2),
        );
        writeFileSync(
          join(repo, "fixtures/files.txt"),
          c.files.join("\n") + "\n",
        );

        // 3. Initialise a git repo so `act push` has a HEAD to operate on.
        await sh(repo, ["git", "init", "-q", "-b", "main"]);
        await sh(repo, ["git", "config", "user.email", "test@example.com"]);
        await sh(repo, ["git", "config", "user.name", "Test"]);
        await sh(repo, ["git", "add", "."]);
        await sh(repo, ["git", "commit", "-q", "-m", `case: ${c.name}`]);

        // 4. Run act push against the temp repo, capture combined output.
        const proc = Bun.spawn(["act", "push", "--rm"], {
          cwd: repo,
          stdout: "pipe",
          stderr: "pipe",
          env: { ...process.env, NO_COLOR: "1" },
        });
        const [stdout, stderr] = await Promise.all([
          new Response(proc.stdout).text(),
          new Response(proc.stderr).text(),
        ]);
        await proc.exited;
        const combined = stdout + stderr;

        // 5. Append to the persistent artifact.
        appendCaseOutput(c.name, c.description, proc.exitCode ?? -1, combined);

        // 6. Assertions.
        // (a) act exited cleanly
        expect(proc.exitCode).toBe(0);
        // (b) every job ended with "Job succeeded"
        expect(combined).toContain("Job succeeded");
        // (c) the LABELS_OUTPUT line is present and parses to exactly
        //     the expected label set (set equality, order-independent)
        const labels = extractLabels(combined);
        expect(labels.sort()).toEqual([...c.expectedLabels].sort());
      },
      // act + bun install + script ~= 30-90s; give it a generous budget.
      180_000,
    );
  }
});

// ---------- helpers ------------------------------------------------

async function sh(cwd: string, cmd: string[]): Promise<void> {
  const p = Bun.spawn(cmd, { cwd, stdout: "pipe", stderr: "pipe" });
  await p.exited;
  if (p.exitCode !== 0) {
    const err = await new Response(p.stderr).text();
    throw new Error(`${cmd.join(" ")} failed (exit ${p.exitCode}): ${err}`);
  }
}

function extractLabels(actOutput: string): string[] {
  // act prefixes step output lines with `| ` (and sometimes job tags),
  // so we match on the LABELS_OUTPUT= marker emitted by the workflow.
  const m = actOutput.match(/LABELS_OUTPUT=(\{.*?\})/);
  if (!m) {
    throw new Error(
      "LABELS_OUTPUT line not found in act output — workflow may have failed before printing.",
    );
  }
  const parsed = JSON.parse(m[1]!) as { labels: string[] };
  return parsed.labels;
}

function appendCaseOutput(
  name: string,
  description: string,
  exitCode: number,
  output: string,
): void {
  const banner = `\n${"=".repeat(72)}\n`;
  const block =
    banner +
    `CASE: ${name}\n` +
    `DESCRIPTION: ${description}\n` +
    `ACT EXIT CODE: ${exitCode}\n` +
    banner +
    output +
    `\n${"-".repeat(72)}\nEND CASE: ${name}\n`;
  appendFileSync(ACT_RESULT_PATH, block);
}
