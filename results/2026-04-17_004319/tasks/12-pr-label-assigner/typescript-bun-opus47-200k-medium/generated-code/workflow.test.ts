// Workflow tests: every test case runs through the real GitHub Actions pipeline
// via `act`. For each case we:
//   1. Stage this project into a throwaway git repo
//   2. Swap in the case's fixture file (the "changed files" for that PR)
//   3. Run `act push --rm`, capture the output
//   4. Append to act-result.txt (required artifact) and assert exact label set
//
// We're capped at 3 act invocations, so we only have 3 cases.

import { describe, test, expect, beforeAll, afterAll } from "bun:test";
import { mkdtempSync, cpSync, writeFileSync, existsSync, rmSync, appendFileSync, readFileSync } from "fs";
import { execSync, spawnSync } from "child_process";
import { tmpdir } from "os";
import { join } from "path";
import { parse as parseYaml } from "yaml";

const PROJECT = import.meta.dir;
const ACT_RESULT = join(PROJECT, "act-result.txt");

interface Case {
  name: string;
  files: string[];
  expectedLabels: string[]; // sorted
}

const CASES: Case[] = [
  {
    name: "api-and-tests",
    files: ["src/api/users.ts", "src/api/users.test.ts"],
    expectedLabels: ["api", "tests"],
  },
  {
    name: "docs-only",
    files: ["docs/intro.md", "README.md"],
    expectedLabels: ["documentation"],
  },
  {
    name: "mixed-priority",
    // src/core -> backend (group "area"), src/api -> api (higher priority wins per-file).
    // Different files contribute different group winners; both labels end up in the set.
    // .github/** -> ci. README.md -> documentation.
    files: ["src/core/util.ts", "src/api/users.ts", ".github/workflows/x.yml", "README.md"],
    expectedLabels: ["api", "backend", "ci", "documentation"],
  },
];

function runAct(workdir: string): { stdout: string; stderr: string; status: number | null } {
  const r = spawnSync("act", ["push", "--rm"], {
    cwd: workdir,
    encoding: "utf8",
    timeout: 5 * 60 * 1000,
    maxBuffer: 50 * 1024 * 1024,
  });
  return { stdout: r.stdout ?? "", stderr: r.stderr ?? "", status: r.status };
}

function setupRepo(c: Case): string {
  const dir = mkdtempSync(join(tmpdir(), `pr-label-${c.name}-`));
  // Copy essential project files
  for (const f of [
    "labeler.ts",
    "labeler.test.ts",
    "cli.ts",
    "rules.json",
    "package.json",
    "tsconfig.json",
    ".actrc",
    ".github",
  ]) {
    const src = join(PROJECT, f);
    if (existsSync(src)) cpSync(src, join(dir, f), { recursive: true });
  }
  // Case-specific fixture
  writeFileSync(join(dir, "fixture-files.json"), JSON.stringify(c.files));
  // Git init (act requires a git repo)
  execSync("git init -q && git config user.email a@b.c && git config user.name t && git add -A && git commit -q -m init", {
    cwd: dir,
  });
  return dir;
}

describe("workflow structure", () => {
  test("YAML parses and has required triggers/jobs/steps", () => {
    const text = readFileSync(join(PROJECT, ".github/workflows/pr-label-assigner.yml"), "utf8");
    const wf = parseYaml(text) as any;
    // yaml lib converts `on:` to key `true` in some cases; handle both
    const triggers = wf.on ?? wf[true];
    expect(triggers).toBeDefined();
    expect(triggers).toHaveProperty("push");
    expect(triggers).toHaveProperty("pull_request");
    expect(triggers).toHaveProperty("workflow_dispatch");
    expect(wf.jobs?.label).toBeDefined();
    const steps = wf.jobs.label.steps as any[];
    expect(steps.some((s) => s.uses?.startsWith("actions/checkout@"))).toBe(true);
    const runs = steps.map((s) => s.run ?? "").join("\n");
    expect(runs).toContain("bun test");
    expect(runs).toContain("cli.ts");
  });

  test("workflow references files that exist on disk", () => {
    for (const f of ["labeler.ts", "cli.ts", "rules.json"]) {
      expect(existsSync(join(PROJECT, f))).toBe(true);
    }
  });

  test("actionlint passes", () => {
    const r = spawnSync("actionlint", [".github/workflows/pr-label-assigner.yml"], {
      cwd: PROJECT,
      encoding: "utf8",
    });
    expect(r.stdout + r.stderr).toBe("");
    expect(r.status).toBe(0);
  });
});

describe("workflow end-to-end via act", () => {
  beforeAll(() => {
    // Fresh act-result.txt for this run
    if (existsSync(ACT_RESULT)) rmSync(ACT_RESULT);
    writeFileSync(ACT_RESULT, `# act results — ${new Date().toISOString()}\n`);
  });

  for (const c of CASES) {
    test(`case: ${c.name}`, () => {
      const dir = setupRepo(c);
      let result;
      try {
        result = runAct(dir);
      } finally {
        // Keep dir on failure for debugging; otherwise clean up
      }

      const combined = result.stdout + "\n" + result.stderr;
      appendFileSync(
        ACT_RESULT,
        `\n\n===== CASE: ${c.name} =====\nfiles: ${JSON.stringify(c.files)}\nexpected: ${c.expectedLabels.join(",")}\nexit: ${result.status}\n--- stdout+stderr ---\n${combined}\n`,
      );

      expect(result.status).toBe(0);
      expect(combined).toContain("Job succeeded");
      // Exact expected label set
      const expected = c.expectedLabels.join(",");
      expect(combined).toContain(`FINAL_LABELS=${expected}`);

      rmSync(dir, { recursive: true, force: true });
    }, 6 * 60 * 1000);
  }

  afterAll(() => {
    // Sanity: file exists and is non-empty
    expect(existsSync(ACT_RESULT)).toBe(true);
    expect(readFileSync(ACT_RESULT, "utf8").length).toBeGreaterThan(0);
  });
});
