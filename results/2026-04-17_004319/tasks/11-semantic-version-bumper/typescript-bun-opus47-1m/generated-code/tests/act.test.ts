// End-to-end workflow tests driven by act.
//
// For each test case we:
//   1. Create a fresh temp directory that mirrors this project.
//   2. Write that case's fixture data (test-case/start_version + commits.log).
//   3. Initialize a git repo (act push requires one).
//   4. Run `act push --rm` inside that directory.
//   5. Append the full output to ../act-result.txt in the project root.
//   6. Assert act exited with code 0 AND parse the captured output to verify
//      the exact expected NEW_VERSION / BUMP_TYPE values.
//   7. Assert every job reports "Job succeeded".
//
// Plus workflow structure tests: YAML parses, expected jobs/steps exist,
// referenced scripts exist on disk, actionlint exits 0.

import { afterAll, beforeAll, describe, expect, test } from "bun:test";

// When this test file is itself running inside the act container, don't
// attempt to re-invoke act (no docker, and it would recurse anyway).
const INSIDE_ACT = process.env.ACT === "true" || process.env.SKIP_ACT_HARNESS === "1";
import {
  cp,
  mkdtemp,
  readFile,
  rm,
  stat,
  writeFile,
  appendFile,
  mkdir,
} from "node:fs/promises";
import { join, resolve } from "node:path";
import { tmpdir } from "node:os";
import { parse as parseYaml } from "yaml";

const ROOT = resolve(import.meta.dir, "..");
const WORKFLOW = join(ROOT, ".github", "workflows", "semantic-version-bumper.yml");
const ACT_RESULT = join(ROOT, "act-result.txt");

interface ActRun {
  code: number;
  stdout: string;
  stderr: string;
  combined: string;
}

// Copy the project into `destDir`, excluding transient/vendor dirs to keep
// the copy fast and avoid shipping node_modules into the act container.
async function snapshotProject(destDir: string): Promise<void> {
  const skip = new Set(["node_modules", ".git", "act-result.txt"]);
  const entries = await Array.fromAsync(
    new Bun.Glob("*").scan({ cwd: ROOT, onlyFiles: false, dot: true }),
  );
  for (const entry of entries) {
    if (skip.has(entry)) continue;
    const src = join(ROOT, entry);
    const dst = join(destDir, entry);
    await cp(src, dst, { recursive: true });
  }
}

async function runAct(cwd: string): Promise<ActRun> {
  // Ensure git is initialized — act push requires a git repo.
  const setupCmds = [
    ["git", "init", "-q", "-b", "main"],
    ["git", "config", "user.email", "test@example.com"],
    ["git", "config", "user.name", "test"],
    ["git", "add", "-A"],
    ["git", "commit", "-q", "-m", "test fixture"],
  ];
  for (const cmd of setupCmds) {
    const p = Bun.spawn(cmd, { cwd, stdout: "pipe", stderr: "pipe" });
    await p.exited;
  }

  const proc = Bun.spawn(
    ["act", "push", "--rm", "--pull=false", "-W", ".github/workflows/semantic-version-bumper.yml"],
    {
      cwd,
      stdout: "pipe",
      stderr: "pipe",
      env: { ...process.env },
    },
  );
  const [stdout, stderr] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
  ]);
  const code = await proc.exited;
  return { code, stdout, stderr, combined: stdout + stderr };
}

async function appendResult(label: string, run: ActRun): Promise<void> {
  const banner =
    "\n" + "=".repeat(78) + "\n" + `TEST CASE: ${label}\n` + "=".repeat(78) + "\n";
  const tail = `\n--- exit code: ${run.code} ---\n`;
  await appendFile(
    ACT_RESULT,
    banner + "--- stdout ---\n" + run.stdout + "\n--- stderr ---\n" + run.stderr + tail,
  );
}

beforeAll(async () => {
  // Only (re)initialize act-result.txt when we're actually going to run act.
  // This guard prevents the skipped-run case (e.g. when SKIP_ACT_HARNESS=1)
  // from clobbering a previously-written results artifact.
  if (INSIDE_ACT) return;
  await writeFile(ACT_RESULT, `act-result for semantic-version-bumper\nstarted: ${new Date().toISOString()}\n`);
});

// ---------- Structure tests (fast) ----------

describe.skipIf(INSIDE_ACT)("workflow structure", () => {
  test("workflow YAML parses and references our script files", async () => {
    const raw = await readFile(WORKFLOW, "utf8");
    const parsed = parseYaml(raw) as Record<string, unknown>;
    expect(parsed.name).toBe("semantic-version-bumper");
    // YAML parses "on" as boolean true under strict spec; accept either key.
    const triggers = (parsed.on ?? parsed.true) as Record<string, unknown>;
    expect(triggers).toBeDefined();
    expect("push" in triggers).toBe(true);
    expect("workflow_dispatch" in triggers).toBe(true);
    expect("pull_request" in triggers).toBe(true);

    const jobs = parsed.jobs as Record<string, { steps: Array<Record<string, unknown>> }>;
    expect(Object.keys(jobs).sort()).toEqual(["bumper", "summary", "unit-tests"]);

    // The bumper job must reference our CLI script at src/cli.ts somewhere.
    const bumperSteps = JSON.stringify(jobs.bumper.steps);
    expect(bumperSteps).toContain("src/cli.ts");

    // Files referenced by the workflow must exist on disk.
    await stat(join(ROOT, "src", "cli.ts"));
    await stat(join(ROOT, "package.json"));
  });

  test("actionlint exits 0", async () => {
    const proc = Bun.spawn(["actionlint", WORKFLOW], { stdout: "pipe", stderr: "pipe" });
    const [out, err] = await Promise.all([
      new Response(proc.stdout).text(),
      new Response(proc.stderr).text(),
    ]);
    const code = await proc.exited;
    if (code !== 0) {
      console.error("actionlint output:\n" + out + "\n" + err);
    }
    expect(code).toBe(0);
  });
});

// ---------- End-to-end act runs (slow) ----------

interface Case {
  label: string;
  startVersion: string;
  commitsFixture: string;
  expectedNewVersion: string;
  expectedBump: "major" | "minor" | "patch" | "none";
}

const cases: Case[] = [
  { label: "feat-bumps-minor", startVersion: "1.1.0", commitsFixture: "feat-minor.log", expectedNewVersion: "1.2.0", expectedBump: "minor" },
  { label: "fix-bumps-patch", startVersion: "0.9.3", commitsFixture: "fix-patch.log", expectedNewVersion: "0.9.4", expectedBump: "patch" },
  { label: "breaking-bumps-major", startVersion: "2.3.4", commitsFixture: "breaking-major.log", expectedNewVersion: "3.0.0", expectedBump: "major" },
  { label: "noop-no-bump", startVersion: "0.5.0", commitsFixture: "noop-none.log", expectedNewVersion: "0.5.0", expectedBump: "none" },
];

// Each act run takes ~60s; allow plenty of headroom.
const ACT_TIMEOUT_MS = 300_000;

const tempDirs: string[] = [];
afterAll(async () => {
  for (const d of tempDirs) {
    await rm(d, { recursive: true, force: true });
  }
});

for (const c of cases) {
  test.skipIf(INSIDE_ACT)(
    `act: ${c.label}`,
    async () => {
      const dir = await mkdtemp(join(tmpdir(), `svb-act-${c.label}-`));
      tempDirs.push(dir);

      await snapshotProject(dir);
      // Ensure .actrc is present in the copied dir so act uses our custom image.
      // (snapshotProject already copies .actrc; nothing extra needed.)

      await mkdir(join(dir, "test-case"), { recursive: true });
      await writeFile(join(dir, "test-case", "start_version"), c.startVersion + "\n");
      await cp(join(ROOT, "fixtures", c.commitsFixture), join(dir, "test-case", "commits.log"));

      const run = await runAct(dir);
      await appendResult(c.label, run);

      // Assert act exited 0.
      expect(run.code).toBe(0);

      // Assert every job reports success. act prints "Job succeeded" per job.
      const jobSuccessCount = (run.combined.match(/Job succeeded/g) ?? []).length;
      expect(jobSuccessCount).toBeGreaterThanOrEqual(3);

      // Assert exact expected NEW_VERSION appears in the captured output.
      expect(run.combined).toContain(`NEW_VERSION=${c.expectedNewVersion}`);
      expect(run.combined).toContain(`BUMP_TYPE=${c.expectedBump}`);
    },
    ACT_TIMEOUT_MS,
  );
}
