// Workflow integration tests. These run every fixture through `act` in a
// fresh temp git repo and assert on the exact labels produced, the job status,
// and the overall pipeline exit code.
//
// All act output is appended to act-result.txt (required artifact).
//
// Keep the number of `act push` runs small — the benchmark spec caps at 3.
import { describe, expect, test, beforeAll } from "bun:test";
import {
  mkdtempSync,
  cpSync,
  rmSync,
  readFileSync,
  writeFileSync,
  existsSync,
  appendFileSync,
  statSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { parse as parseYaml } from "yaml";

const PROJECT_ROOT = import.meta.dir;
const ACT_RESULT_FILE = join(PROJECT_ROOT, "act-result.txt");

interface FixtureCase {
  name: string;
  fixtureDir: string; // relative to project root
  expectedLabels: string[]; // exact, ordered
}

const CASES: FixtureCase[] = [
  {
    name: "default",
    fixtureDir: "fixtures/default",
    expectedLabels: ["api", "tests", "documentation", "config"],
  },
  {
    name: "tests-only",
    fixtureDir: "fixtures/tests-only",
    expectedLabels: ["tests"],
  },
  {
    name: "docs-heavy",
    fixtureDir: "fixtures/docs-heavy",
    expectedLabels: ["documentation", "ci"],
  },
];

/**
 * Copy the entire project into a temp directory, init git, and (optionally)
 * swap the workflow's default fixture path for the one under test.
 * Each fixture already contains files.txt + expected.txt; the workflow reads
 * fixtures/default, so we point it at the specific fixture for each case.
 */
function setupRepo(fixtureDir: string): string {
  const tmp = mkdtempSync(join(tmpdir(), "pr-label-act-"));
  // Copy the whole project except act-result.txt and node_modules.
  cpSync(PROJECT_ROOT, tmp, {
    recursive: true,
    filter: (src) => {
      const rel = src.replace(PROJECT_ROOT, "");
      // Skip large/irrelevant dirs; avoid the parent's .git interfering with
      // the fresh repo we'll init inside the temp dir.
      return (
        !rel.startsWith("/node_modules") &&
        rel !== "/.git" &&
        !rel.startsWith("/.git/") &&
        !rel.startsWith("/.claude") &&
        !rel.endsWith("/act-result.txt")
      );
    },
  });
  // Rewrite the workflow so its default fixture points to the selected one.
  const wfPath = join(tmp, ".github/workflows/pr-label-assigner.yml");
  const wf = readFileSync(wfPath, "utf8").replace(
    /FIXTURE_DIR:-fixtures\/default/g,
    `FIXTURE_DIR:-${fixtureDir}`,
  );
  writeFileSync(wfPath, wf);

  // Initialize a git repo — act requires one to run `push`.
  const git = (args: string[]) =>
    spawnSync("git", args, { cwd: tmp, stdio: "pipe" });
  git(["init", "-q", "-b", "main"]);
  git(["config", "user.email", "test@example.com"]);
  git(["config", "user.name", "Test"]);
  git(["add", "-A"]);
  git(["commit", "-q", "-m", "fixture"]);
  return tmp;
}

function runAct(repo: string): { code: number; stdout: string; stderr: string } {
  const res = spawnSync(
    "act",
    [
      "push",
      "--rm",
      "--pull=false", // the custom image is local; don't try to pull it
      "-P",
      "ubuntu-latest=act-ubuntu-pwsh:latest",
    ],
    { cwd: repo, encoding: "utf8", timeout: 10 * 60 * 1000 },
  );
  return {
    code: res.status ?? -1,
    stdout: res.stdout ?? "",
    stderr: res.stderr ?? "",
  };
}

function appendResult(label: string, body: string): void {
  const sep = "\n" + "=".repeat(80) + "\n";
  appendFileSync(ACT_RESULT_FILE, `${sep}CASE: ${label}${sep}${body}\n`);
}

describe("workflow structure", () => {
  test("workflow file exists and parses as YAML", () => {
    const path = join(PROJECT_ROOT, ".github/workflows/pr-label-assigner.yml");
    expect(existsSync(path)).toBe(true);
    const doc = parseYaml(readFileSync(path, "utf8"));
    expect(doc).toBeTruthy();
    expect(doc.name).toBe("PR Label Assigner");
  });

  test("workflow declares expected triggers", () => {
    const doc = parseYaml(
      readFileSync(
        join(PROJECT_ROOT, ".github/workflows/pr-label-assigner.yml"),
        "utf8",
      ),
    );
    // YAML parses the `on:` key as the boolean true, not the string "on".
    // Accept both so the test is robust across parsers.
    const on = doc.on ?? doc[true];
    expect(on).toBeTruthy();
    expect("push" in on).toBe(true);
    expect("pull_request" in on).toBe(true);
    expect("workflow_dispatch" in on).toBe(true);
    expect("schedule" in on).toBe(true);
  });

  test("workflow has a job that runs bun test and the CLI", () => {
    const doc = parseYaml(
      readFileSync(
        join(PROJECT_ROOT, ".github/workflows/pr-label-assigner.yml"),
        "utf8",
      ),
    );
    const jobs = doc.jobs;
    expect(Object.keys(jobs).length).toBeGreaterThan(0);
    const steps = jobs["test-and-label"].steps;
    const runCmds = steps
      .filter((s: Record<string, unknown>) => typeof s.run === "string")
      .map((s: Record<string, unknown>) => s.run as string)
      .join("\n");
    expect(runCmds).toContain("bun test");
    expect(runCmds).toContain("cli.ts");
    // Checkout action is present and pinned.
    const uses = steps
      .filter((s: Record<string, unknown>) => typeof s.uses === "string")
      .map((s: Record<string, unknown>) => s.uses as string);
    expect(uses).toContain("actions/checkout@v4");
    expect(uses.some((u: string) => u.startsWith("oven-sh/setup-bun@"))).toBe(
      true,
    );
  });

  test("script files referenced by the workflow exist", () => {
    for (const f of ["cli.ts", "labeler.ts", "rules.json"]) {
      expect(existsSync(join(PROJECT_ROOT, f))).toBe(true);
    }
  });

  test("actionlint passes with exit code 0", () => {
    const res = spawnSync(
      "actionlint",
      [".github/workflows/pr-label-assigner.yml"],
      { cwd: PROJECT_ROOT, encoding: "utf8" },
    );
    if (res.status !== 0) {
      console.error("actionlint output:", res.stdout, res.stderr);
    }
    expect(res.status).toBe(0);
  });
});

describe("workflow via act", () => {
  // One act run per case. The harness writes all output to act-result.txt.
  beforeAll(() => {
    // Start a fresh log file each run.
    writeFileSync(ACT_RESULT_FILE, `act results for ${new Date().toISOString()}\n`);
  });

  for (const c of CASES) {
    test(
      `case '${c.name}': act exits 0, job succeeds, labels match exactly`,
      () => {
        const repo = setupRepo(c.fixtureDir);
        try {
          const { code, stdout, stderr } = runAct(repo);
          appendResult(
            c.name,
            `exit_code=${code}\n\n---STDOUT---\n${stdout}\n---STDERR---\n${stderr}`,
          );

          // Assertion 1: act exited cleanly.
          expect(code).toBe(0);

          // Assertion 2: every job in this workflow reported success.
          expect(stdout).toContain("Job succeeded");

          // Assertion 3: the "Assign labels for fixture" step emitted the
          // exact expected label set, in order, between the marker lines.
          const begin = stdout.indexOf("LABELS_BEGIN");
          const end = stdout.indexOf("LABELS_END");
          expect(begin).toBeGreaterThan(-1);
          expect(end).toBeGreaterThan(begin);
          const slice = stdout.slice(begin, end);
          // Act prefixes every output line with a job/step tag; strip those.
          const labels = slice
            .split("\n")
            .slice(1) // drop LABELS_BEGIN line
            .map((l) => l.replace(/^\s*\|\s?/, "").trim())
            // act prefixes lines like "[PR Label ... / Unit tests ...]  |  value"
            .map((l) => l.replace(/^\[[^\]]+\]\s*\|?\s*/, "").trim())
            .filter((l) => l.length > 0);
          expect(labels).toEqual(c.expectedLabels);

          // Assertion 4: the explicit LABEL_COUNT line matches too.
          expect(stdout).toContain(`LABEL_COUNT=${c.expectedLabels.length}`);
        } finally {
          rmSync(repo, { recursive: true, force: true });
        }
      },
      { timeout: 10 * 60 * 1000 },
    );
  }

  test("act-result.txt exists and has content for every case", () => {
    expect(existsSync(ACT_RESULT_FILE)).toBe(true);
    const txt = readFileSync(ACT_RESULT_FILE, "utf8");
    for (const c of CASES) {
      expect(txt).toContain(`CASE: ${c.name}`);
    }
    expect(statSync(ACT_RESULT_FILE).size).toBeGreaterThan(100);
  });
});
