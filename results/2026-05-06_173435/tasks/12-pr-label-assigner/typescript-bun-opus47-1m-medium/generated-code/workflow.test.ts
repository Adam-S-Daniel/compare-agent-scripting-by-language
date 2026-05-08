// Tests for the GitHub Actions workflow file: structural validation,
// actionlint, and end-to-end execution via act for each fixture.

import { describe, test, expect, beforeAll } from "bun:test";
import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, mkdirSync, cpSync, writeFileSync, appendFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { parse as parseYaml } from "yaml";

const REPO = process.cwd();
const WORKFLOW = join(REPO, ".github/workflows/pr-label-assigner.yml");
const ACT_RESULT = join(REPO, "act-result.txt");

describe("workflow structure", () => {
  let yml: any;
  beforeAll(() => {
    yml = parseYaml(readFileSync(WORKFLOW, "utf8"));
  });

  test("workflow file exists", () => {
    expect(existsSync(WORKFLOW)).toBe(true);
  });

  test("has expected triggers", () => {
    // YAML parser converts `on:` to literal "on"; key is true in some versions
    const onKey = yml.on ?? yml[true as unknown as string];
    expect(onKey).toBeDefined();
    expect(Object.keys(onKey)).toEqual(expect.arrayContaining(["push", "pull_request", "workflow_dispatch"]));
  });

  test("has assign-labels job with required steps", () => {
    const job = yml.jobs["assign-labels"];
    expect(job).toBeDefined();
    expect(job["runs-on"]).toBe("ubuntu-latest");
    const stepNames = job.steps.map((s: any) => s.name);
    expect(stepNames).toEqual(expect.arrayContaining(["Checkout", "Setup Bun", "Run unit tests", "Run labeler on fixture"]));
  });

  test("references existing script and fixtures", () => {
    expect(existsSync(join(REPO, "labeler.ts"))).toBe(true);
    expect(existsSync(join(REPO, "fixtures/case1.json"))).toBe(true);
    expect(existsSync(join(REPO, "fixtures/case2.json"))).toBe(true);
    expect(existsSync(join(REPO, "fixtures/case3.json"))).toBe(true);
  });

  test("actionlint passes with exit code 0", () => {
    const res = spawnSync("actionlint", [WORKFLOW], { encoding: "utf8" });
    if (res.status !== 0) console.error(res.stdout, res.stderr);
    expect(res.status).toBe(0);
  });
});

// ---- act end-to-end ----

interface Case {
  fixture: string;
  expectedLabels: string[];
}

const cases: Case[] = [
  { fixture: "fixtures/case1.json", expectedLabels: ["api", "documentation", "tests"] },
  { fixture: "fixtures/case2.json", expectedLabels: ["api", "typescript"] },
  { fixture: "fixtures/case3.json", expectedLabels: [] },
];

function runAct(fixture: string): { stdout: string; status: number | null } {
  // Build a clean temp git repo with project files and the chosen fixture as default.
  const tmp = join(tmpdir(), `pr-label-act-${Date.now()}-${Math.random().toString(36).slice(2)}`);
  mkdirSync(tmp, { recursive: true });
  for (const item of [
    "labeler.ts",
    "labeler.test.ts",
    "package.json",
    "tsconfig.json",
    ".github",
    "fixtures",
    ".actrc",
  ]) {
    const src = join(REPO, item);
    if (existsSync(src)) cpSync(src, join(tmp, item), { recursive: true });
  }

  // Override workflow's default fixture by editing the env.FIXTURE for the run.
  // Simplest: write a small override via a setup step? Instead, copy chosen
  // fixture to the default path used in workflow: fixtures/case1.json.
  cpSync(join(REPO, fixture), join(tmp, "fixtures/case1.json"));

  spawnSync("git", ["init", "-q", "-b", "main"], { cwd: tmp });
  spawnSync("git", ["add", "-A"], { cwd: tmp });
  spawnSync("git", ["-c", "user.email=t@t", "-c", "user.name=t", "commit", "-q", "-m", "init"], { cwd: tmp });

  const res = spawnSync("act", ["push", "--rm", "--pull=false"], { cwd: tmp, encoding: "utf8", maxBuffer: 100 * 1024 * 1024 });
  const out = (res.stdout || "") + "\n" + (res.stderr || "");
  rmSync(tmp, { recursive: true, force: true });
  return { stdout: out, status: res.status };
}

describe("act end-to-end", () => {
  beforeAll(() => {
    if (existsSync(ACT_RESULT)) rmSync(ACT_RESULT);
    writeFileSync(ACT_RESULT, `# act-result.txt — generated ${new Date().toISOString()}\n\n`);
  });

  for (const c of cases) {
    test(`runs workflow for ${c.fixture}`, () => {
      const { stdout, status } = runAct(c.fixture);
      appendFileSync(ACT_RESULT, `\n========== ${c.fixture} ==========\n`);
      appendFileSync(ACT_RESULT, stdout);
      appendFileSync(ACT_RESULT, `\n[exit=${status}]\n`);

      expect(status).toBe(0);
      expect(stdout).toMatch(/Job succeeded/);

      // Assert exact final labels JSON appears in output.
      const expectedJson = JSON.stringify({ labels: c.expectedLabels });
      expect(stdout.includes(expectedJson)).toBe(true);
    }, 240_000);
  }
});
