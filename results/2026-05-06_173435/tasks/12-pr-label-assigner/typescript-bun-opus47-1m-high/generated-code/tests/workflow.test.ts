/**
 * Workflow structure + end-to-end act tests.
 *
 * All behavioral test cases are driven through the GitHub Actions workflow
 * via `act`. To stay within the run-budget, we bundle every scenario into a
 * single `act push` invocation: the workflow accepts a multi-case fixture
 * file and emits a delimited LABELS-BEGIN/END block per case. We parse those
 * blocks back out and assert exact-equal labels against the expected values.
 *
 * Skip act runs (still runs structure tests) by setting ACT_SKIP=1.
 */
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import {
  cpSync,
  existsSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { parse as parseYaml } from "yaml";

const ROOT = resolve(import.meta.dir, "..");
const ACT_RESULT_FILE = join(ROOT, "act-result.txt");

// ---------- Workflow structure tests (fast, no Docker) ----------

interface WorkflowYaml {
  name: string;
  on: Record<string, unknown>;
  permissions: Record<string, string>;
  jobs: Record<string, { steps: Array<{ uses?: string; run?: string; name?: string }>; needs?: string | string[] }>;
}

describe("workflow structure", () => {
  const yamlPath = join(ROOT, ".github/workflows/pr-label-assigner.yml");
  const yamlText = readFileSync(yamlPath, "utf8");
  const wf = parseYaml(yamlText) as WorkflowYaml;

  test("declares expected triggers", () => {
    expect(wf.on).toBeDefined();
    expect(Object.keys(wf.on).sort()).toEqual(
      ["pull_request", "push", "workflow_dispatch"].sort(),
    );
  });

  test("has unit-tests and assign-labels jobs", () => {
    expect(wf.jobs["unit-tests"]).toBeDefined();
    expect(wf.jobs["assign-labels"]).toBeDefined();
  });

  test("assign-labels depends on unit-tests", () => {
    const needs = wf.jobs["assign-labels"]?.needs;
    expect(Array.isArray(needs) ? needs : [needs]).toContain("unit-tests");
  });

  test("checks out via actions/checkout@v4", () => {
    const allSteps = Object.values(wf.jobs).flatMap((j) => j.steps);
    const checkoutUses = allSteps.filter((s) => s.uses?.startsWith("actions/checkout@"));
    expect(checkoutUses.length).toBeGreaterThan(0);
    for (const step of checkoutUses) {
      expect(step.uses).toBe("actions/checkout@v4");
    }
  });

  test("references the script and rules file we ship", () => {
    expect(yamlText).toContain("src/cli.ts");
    expect(yamlText).toContain("rules.json");
    expect(existsSync(join(ROOT, "src/cli.ts"))).toBe(true);
    expect(existsSync(join(ROOT, "rules.json"))).toBe(true);
  });

  test("declares appropriate permissions", () => {
    expect(wf.permissions).toBeDefined();
    expect(wf.permissions["contents"]).toBeDefined();
  });

  test("actionlint passes on the workflow", () => {
    const r = spawnSync("actionlint", [".github/workflows/pr-label-assigner.yml"], {
      cwd: ROOT, encoding: "utf8",
    });
    if (r.status !== 0) {
      console.error("actionlint stderr:", r.stderr);
      console.error("actionlint stdout:", r.stdout);
    }
    expect(r.status).toBe(0);
  });
});

// ---------- act end-to-end test ----------

interface Scenario {
  name: string;
  files: string[];
  // Labels expected, in priority/declaration order.
  expected: string[];
}

const SCENARIOS: Scenario[] = [
  {
    name: "docs-only",
    files: ["docs/intro.md", "docs/guide/usage.md", "README.md"],
    expected: ["documentation"],
  },
  {
    name: "api-and-tests",
    // src/api/users.test.ts matches BOTH "api" (src/api/**) AND "tests"
    // (**/*.test.ts) — verifies multi-label-per-file.
    files: ["src/api/users.ts", "src/api/users.test.ts"],
    expected: ["api", "tests"],
  },
  {
    name: "everything",
    files: [
      "docs/x.md",
      "src/api/v1/handler.ts",
      "tests/foo.spec.ts",
      ".github/workflows/build.yml",
      "package.json",
    ],
    // documentation(1), api(2), tests(3), ci(4), config(5).
    // package.json matches the config "*.json" pattern;
    // .github/workflows/build.yml is excluded from "config" by its exclude.
    expected: ["documentation", "api", "tests", "ci", "config"],
  },
  {
    name: "no-match",
    files: ["weird/file.bin", "another/file.exe"],
    expected: [],
  },
];

const SHOULD_SKIP_ACT = process.env.ACT_SKIP === "1";
const actDescribe = SHOULD_SKIP_ACT ? describe.skip : describe;

let tempRepo = "";
let actResult: { status: number; stdout: string; stderr: string } | null = null;

beforeAll(() => {
  if (SHOULD_SKIP_ACT) return;

  // Reset artifact at the start of the run.
  writeFileSync(ACT_RESULT_FILE, "");

  // Build a clean temp repo (no node_modules, no act-result.txt) so act has
  // a deterministic checkout target.
  tempRepo = mkdtempSync(join(tmpdir(), "pr-label-assigner-"));
  cpSync(ROOT, tempRepo, {
    recursive: true,
    filter: (src) => {
      const rel = src.slice(ROOT.length).replace(/^\//, "");
      if (rel === "") return true;
      if (rel.startsWith("node_modules")) return false;
      if (rel === ".git" || rel.startsWith(".git/")) return false;
      if (rel === "act-result.txt") return false;
      return true;
    },
  });

  // Compose the multi-case fixture.
  const fixtureLines: string[] = [];
  for (const s of SCENARIOS) {
    fixtureLines.push(`--- CASE: ${s.name} ---`);
    for (const f of s.files) fixtureLines.push(f);
  }
  writeFileSync(join(tempRepo, "fixture.txt"), fixtureLines.join("\n") + "\n");
  writeFileSync(join(tempRepo, ".act.env"), "FIXTURE_FILE=fixture.txt\n");

  // Initialize git so checkout/git-ls-files work inside act.
  const git = (args: string[]) =>
    spawnSync("git", args, { cwd: tempRepo, encoding: "utf8" });
  git(["init", "-q", "-b", "main"]);
  git(["config", "user.email", "test@example.com"]);
  git(["config", "user.name", "test"]);
  git(["add", "-A"]);
  git(["commit", "-q", "-m", "init"]);

  // Run act once for all scenarios.
  const r = spawnSync(
    "act",
    [
      "push",
      "--rm",
      "--pull=false",
      "--env-file", ".act.env",
      "-W", ".github/workflows/pr-label-assigner.yml",
    ],
    { cwd: tempRepo, encoding: "utf8", maxBuffer: 100 * 1024 * 1024 },
  );
  actResult = {
    status: r.status ?? -1,
    stdout: r.stdout ?? "",
    stderr: r.stderr ?? "",
  };

  // Persist full output to act-result.txt — required artifact.
  const banner = `========== act push (single run, ${SCENARIOS.length} scenarios) ==========\n`;
  writeFileSync(
    ACT_RESULT_FILE,
    banner +
      `exit: ${actResult.status}\n` +
      `--- stdout ---\n${actResult.stdout}\n` +
      `--- stderr ---\n${actResult.stderr}\n` +
      `========== END ==========\n`,
  );
}, 600_000);

afterAll(() => {
  if (tempRepo && existsSync(tempRepo)) {
    rmSync(tempRepo, { recursive: true, force: true });
  }
});

/**
 * Pull a per-case labels block out of act stdout. Looks for:
 *   ----- LABELS-BEGIN: <name> -----
 *   <labels...>
 *   ----- LABELS-END: <name> -----
 * Lines may be prefixed with `| ` (act's job-output indent) or
 * `[<job>]   |  ` style; we strip a generic leading `[...] | ` if present.
 */
function extractLabels(stdout: string, caseName: string): string[] {
  const beginRe = new RegExp(
    `LABELS-BEGIN: ${caseName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")} -----`,
  );
  const endRe = new RegExp(
    `LABELS-END: ${caseName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")} -----`,
  );
  const lines = stdout.split("\n");
  const beginIdx = lines.findIndex((l) => beginRe.test(l));
  const endIdx = lines.findIndex((l) => endRe.test(l));
  if (beginIdx === -1 || endIdx === -1 || endIdx <= beginIdx) return [];
  const between = lines.slice(beginIdx + 1, endIdx);
  return between
    .map((l) => {
      // Strip act prefix like "[PR Label Assigner/Assign labels] | " or
      // tee/echo line-level "| ".
      let s = l.replace(/^\[[^\]]+\]\s*\|?\s*/, "");
      s = s.replace(/^\|\s?/, "");
      return s.trim();
    })
    .filter((l) => l.length > 0);
}

actDescribe("act end-to-end", () => {
  test("act exited successfully", () => {
    expect(actResult).not.toBeNull();
    if (actResult?.status !== 0) {
      console.error("act stderr:\n", actResult?.stderr);
    }
    expect(actResult?.status).toBe(0);
  });

  test("both jobs report Job succeeded", () => {
    const text = actResult?.stdout ?? "";
    const succeeded = (text.match(/Job succeeded/g) || []).length;
    // unit-tests + assign-labels = 2 jobs.
    expect(succeeded).toBeGreaterThanOrEqual(2);
  });

  for (const scenario of SCENARIOS) {
    test(`scenario "${scenario.name}" produces exactly ${JSON.stringify(scenario.expected)}`, () => {
      const labels = extractLabels(actResult?.stdout ?? "", scenario.name);
      expect(labels).toEqual(scenario.expected);
    });
  }
});
