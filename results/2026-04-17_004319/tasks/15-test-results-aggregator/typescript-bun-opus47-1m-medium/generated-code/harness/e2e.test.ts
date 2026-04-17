// End-to-end harness: runs the workflow via `act` for each test case
// against a temporary git repo, captures output to act-result.txt,
// and asserts exact expected values.
import { describe, expect, test, beforeAll } from "bun:test";
import {
  mkdtempSync,
  cpSync,
  writeFileSync,
  rmSync,
  existsSync,
  readFileSync,
  appendFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { execSync, spawnSync } from "node:child_process";

const PROJECT_ROOT = process.cwd();
const ACT_RESULT = join(PROJECT_ROOT, "act-result.txt");

interface TestCase {
  name: string;
  // Overrides for fixture files (relative path → new contents)
  overrides?: Record<string, string>;
  expectContains: string[];
  expectJobSucceeded: boolean;
}

// Case A: default fixtures — flaky tests present, 2 failures total.
// Case B: all-green fixtures — no flaky tests, no failures.
const CASES: TestCase[] = [
  {
    name: "default-flaky",
    expectContains: [
      "| Total | 15 |",
      "| Passed | 10 |",
      "| Failed | 2 |",
      "| Skipped | 3 |",
      "auth.login_failure",
      "api.get_users",
      "All assertions passed",
    ],
    expectJobSucceeded: true,
  },
  {
    name: "all-green",
    overrides: {
      "fixtures/run1.xml": `<?xml version="1.0"?>
<testsuites>
  <testsuite name="auth" tests="1" failures="0" time="0.1">
    <testcase name="login_success" classname="auth" time="0.1"/>
  </testsuite>
  <testsuite name="api" tests="2" failures="0" skipped="1" time="0.2">
    <testcase name="get_users" classname="api" time="0.2"/>
    <testcase name="create_user" classname="api" time="0.0"><skipped/></testcase>
  </testsuite>
</testsuites>`,
      "fixtures/run2.json": JSON.stringify({
        suites: [
          {
            name: "auth",
            tests: [
              { name: "login_success", classname: "auth", status: "passed", time: 0.1 },
            ],
          },
          {
            name: "api",
            tests: [
              { name: "get_users", classname: "api", status: "passed", time: 0.2 },
              { name: "create_user", classname: "api", status: "skipped", time: 0 },
            ],
          },
        ],
      }),
      "fixtures/run3.xml": `<?xml version="1.0"?>
<testsuites>
  <testsuite name="auth" tests="1" failures="0" time="0.1">
    <testcase name="login_success" classname="auth" time="0.1"/>
  </testsuite>
  <testsuite name="api" tests="2" failures="0" skipped="1" time="0.2">
    <testcase name="get_users" classname="api" time="0.2"/>
    <testcase name="create_user" classname="api" time="0.0"><skipped/></testcase>
  </testsuite>
</testsuites>`,
      // All-green needs updated assertions in the workflow override too.
      // We accomplish that by patching the workflow to match this case.
      ".github/workflows/test-results-aggregator.yml": `name: Test Results Aggregator
on: [push, pull_request, workflow_dispatch]
permissions:
  contents: read
jobs:
  aggregate:
    name: Aggregate test results
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: oven-sh/setup-bun@v2
        with:
          bun-version: latest
      - name: Aggregate fixtures
        run: |
          bun run src/aggregator.ts fixtures/run1.xml fixtures/run2.json fixtures/run3.xml > aggregate-output.md
          echo "---BEGIN SUMMARY---"
          cat aggregate-output.md
          echo "---END SUMMARY---"
      - name: Assert all-green
        run: |
          set -e
          grep -q "| Total | 9 |" aggregate-output.md
          grep -q "| Passed | 6 |" aggregate-output.md
          grep -q "| Failed | 0 |" aggregate-output.md
          grep -q "✅ PASS" aggregate-output.md
          grep -q "_No flaky tests detected._" aggregate-output.md
          echo "All assertions passed"
`,
    },
    expectContains: [
      "| Total | 9 |",
      "| Passed | 6 |",
      "| Failed | 0 |",
      "_No flaky tests detected._",
      "All assertions passed",
    ],
    expectJobSucceeded: true,
  },
];

function setupTempRepo(tc: TestCase): string {
  const dir = mkdtempSync(join(tmpdir(), `act-${tc.name}-`));
  // Copy project files (excluding node_modules-like artifacts).
  for (const entry of [
    "src",
    "tests",
    "fixtures",
    ".github",
    ".actrc",
    "package.json",
    "tsconfig.json",
  ]) {
    const from = join(PROJECT_ROOT, entry);
    cpSync(from, join(dir, entry), { recursive: true });
  }
  // Apply overrides.
  for (const [rel, contents] of Object.entries(tc.overrides ?? {})) {
    writeFileSync(join(dir, rel), contents);
  }
  // Init git repo — act requires one.
  execSync("git init -q && git add -A && git -c user.email=t@t -c user.name=t commit -qm init", {
    cwd: dir,
    stdio: "ignore",
  });
  return dir;
}

function runAct(dir: string): { code: number; output: string } {
  const res = spawnSync("act", ["push", "--rm"], {
    cwd: dir,
    encoding: "utf8",
    timeout: 300_000,
  });
  return {
    code: res.status ?? -1,
    output: (res.stdout ?? "") + (res.stderr ?? ""),
  };
}

beforeAll(() => {
  // Reset act-result.txt so each harness run starts clean.
  try {
    rmSync(ACT_RESULT, { force: true });
  } catch {}
});

describe("workflow structure", () => {
  test("workflow file exists and actionlint passes", () => {
    const wf = join(PROJECT_ROOT, ".github/workflows/test-results-aggregator.yml");
    expect(existsSync(wf)).toBe(true);
    const res = spawnSync("actionlint", [wf], { encoding: "utf8" });
    expect(res.status).toBe(0);
  });
  test("workflow references existing script and fixtures", () => {
    const wf = readFileSync(
      join(PROJECT_ROOT, ".github/workflows/test-results-aggregator.yml"),
      "utf8",
    );
    expect(wf).toContain("src/aggregator.ts");
    expect(wf).toContain("actions/checkout@v4");
    expect(wf).toContain("oven-sh/setup-bun@v2");
    expect(existsSync(join(PROJECT_ROOT, "src/aggregator.ts"))).toBe(true);
    for (const f of ["run1.xml", "run2.json", "run3.xml"]) {
      expect(existsSync(join(PROJECT_ROOT, "fixtures", f))).toBe(true);
    }
  });
});

describe("act e2e cases", () => {
  for (const tc of CASES) {
    test(
      `case: ${tc.name}`,
      () => {
        const dir = setupTempRepo(tc);
        const { code, output } = runAct(dir);
        const banner = `\n\n===== CASE: ${tc.name} =====\nExitCode: ${code}\n`;
        appendFileSync(ACT_RESULT, banner + output);
        expect(code).toBe(0);
        for (const needle of tc.expectContains) {
          expect(output).toContain(needle);
        }
        if (tc.expectJobSucceeded) {
          expect(output).toContain("Job succeeded");
        }
      },
      600_000,
    );
  }
});
