// Workflow integration tests. For each fixture, set up a temp git repo
// containing the project plus that fixture wired in as the default, run the
// workflow under `act`, and assert the captured output contains the exact
// expected new version + bump type. Also runs structural checks on the YAML
// itself (triggers, jobs, steps, referenced paths) and verifies actionlint
// passes. All output is appended to act-result.txt.
import { describe, test, expect, beforeAll } from "bun:test";
import { execFileSync, spawnSync } from "node:child_process";
import {
  mkdtempSync,
  writeFileSync,
  readFileSync,
  appendFileSync,
  existsSync,
  cpSync,
  rmSync,
} from "node:fs";
import { join, resolve } from "node:path";
import { tmpdir } from "node:os";

const ROOT = resolve(import.meta.dir, "..");
const WORKFLOW = join(ROOT, ".github/workflows/semantic-version-bumper.yml");
const ACT_RESULT = join(ROOT, "act-result.txt");

interface Case {
  name: string;
  fixture: string;
  expectedNewVersion: string;
  expectedBumpType: "major" | "minor" | "patch" | "none";
}

const CASES: Case[] = [
  // 1.1.0 + feat -> 1.2.0
  { name: "feat-only", fixture: "feat-only", expectedNewVersion: "1.2.0", expectedBumpType: "minor" },
  // 2.3.4 + fix -> 2.3.5
  { name: "fix-only", fixture: "fix-only", expectedNewVersion: "2.3.5", expectedBumpType: "patch" },
  // 0.9.4 + breaking -> 1.0.0
  { name: "breaking", fixture: "breaking", expectedNewVersion: "1.0.0", expectedBumpType: "major" },
  // 5.0.0 + only docs/chore -> 5.0.0
  { name: "no-bump", fixture: "no-bump", expectedNewVersion: "5.0.0", expectedBumpType: "none" },
];

// Reset act-result.txt at the start of the test run so it accumulates the
// output of every case in this run only.
beforeAll(() => {
  writeFileSync(
    ACT_RESULT,
    `# act-result.txt — generated ${new Date().toISOString()}\n`,
  );
});

describe("workflow structure", () => {
  test("workflow file exists", () => {
    expect(existsSync(WORKFLOW)).toBe(true);
  });

  test("workflow YAML has expected triggers and steps", () => {
    const yml = readFileSync(WORKFLOW, "utf8");
    // Light structural checks via regex — avoid pulling a YAML dep.
    expect(yml).toMatch(/^name:\s*Semantic Version Bumper/m);
    expect(yml).toMatch(/^\s*push:/m);
    expect(yml).toMatch(/^\s*pull_request:/m);
    expect(yml).toMatch(/^\s*workflow_dispatch:/m);
    expect(yml).toMatch(/runs-on:\s*ubuntu-latest/);
    expect(yml).toMatch(/actions\/checkout@v4/);
    expect(yml).toMatch(/bun run src\/cli\.ts/);
    expect(yml).toMatch(/Job succeeded/);
  });

  test("paths referenced by the workflow exist", () => {
    expect(existsSync(join(ROOT, "src/cli.ts"))).toBe(true);
    for (const c of CASES) {
      expect(existsSync(join(ROOT, "fixtures", c.fixture, "version.txt"))).toBe(true);
      expect(existsSync(join(ROOT, "fixtures", c.fixture, "commits.txt"))).toBe(true);
    }
  });

  test("actionlint passes on the workflow", () => {
    const r = spawnSync("actionlint", [WORKFLOW], { encoding: "utf8" });
    if (r.status !== 0) {
      console.error("actionlint stdout:", r.stdout);
      console.error("actionlint stderr:", r.stderr);
    }
    expect(r.status).toBe(0);
  });
});

// Build a temp directory containing only what `act` needs: the workflow,
// source, fixtures, package.json, and an `.actrc` selecting the prebuilt
// pwsh-enabled image. Initialize a git repo so checkout@v4 has something
// reasonable to work with under act's local checkout shim.
function stageRepoForCase(c: Case): string {
  const dir = mkdtempSync(join(tmpdir(), `svb-${c.name}-`));
  for (const sub of [".github", "src", "fixtures", "tests"]) {
    cpSync(join(ROOT, sub), join(dir, sub), { recursive: true });
  }
  for (const f of ["package.json", ".actrc"]) {
    if (existsSync(join(ROOT, f))) cpSync(join(ROOT, f), join(dir, f));
  }
  // git init so act's checkout shim is happy.
  execFileSync("git", ["init", "-q", "-b", "main"], { cwd: dir });
  execFileSync("git", ["config", "user.email", "test@example.com"], { cwd: dir });
  execFileSync("git", ["config", "user.name", "test"], { cwd: dir });
  execFileSync("git", ["add", "-A"], { cwd: dir });
  execFileSync("git", ["commit", "-q", "-m", `test: stage ${c.name}`], { cwd: dir });
  return dir;
}

// Override the workflow's default fixture by writing a small env override
// file and passing it via --env-file. This is more reliable than mutating
// the YAML per-case.
function runActForCase(workdir: string, c: Case): { stdout: string; status: number } {
  const envFile = join(workdir, ".act-env");
  writeFileSync(envFile, `FIXTURE_DIR=${c.fixture}\n`);
  const r = spawnSync(
    "act",
    ["push", "--rm", "--env-file", envFile],
    { cwd: workdir, encoding: "utf8", maxBuffer: 50 * 1024 * 1024 },
  );
  const stdout = (r.stdout ?? "") + "\n" + (r.stderr ?? "");
  return { stdout, status: r.status ?? 1 };
}

describe("workflow execution via act", () => {
  for (const c of CASES) {
    test(`case: ${c.name} expects new version ${c.expectedNewVersion} (${c.expectedBumpType})`, () => {
      const workdir = stageRepoForCase(c);
      try {
        const { stdout, status } = runActForCase(workdir, c);
        const banner =
          `\n\n========== CASE: ${c.name} (fixture=${c.fixture}) ==========\n` +
          `expected NEW_VERSION=${c.expectedNewVersion} BUMP_TYPE=${c.expectedBumpType}\n` +
          `act exit status: ${status}\n` +
          `---- act output ----\n`;
        appendFileSync(ACT_RESULT, banner + stdout + "\n========== END CASE ==========\n");
        // Assertions
        expect(status).toBe(0);
        expect(stdout).toContain(`NEW_VERSION=${c.expectedNewVersion}`);
        expect(stdout).toContain(`BUMP_TYPE=${c.expectedBumpType}`);
        expect(stdout).toContain("Job succeeded");
      } finally {
        rmSync(workdir, { recursive: true, force: true });
      }
    }, 600_000);
  }
});
