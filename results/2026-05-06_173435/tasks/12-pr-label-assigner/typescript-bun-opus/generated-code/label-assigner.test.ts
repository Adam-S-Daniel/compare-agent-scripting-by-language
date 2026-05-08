import { describe, test, expect, beforeAll } from "bun:test";
import { readFileSync, existsSync, mkdirSync, writeFileSync, cpSync, rmSync } from "fs";
import { execSync } from "child_process";
import { join } from "path";
import { parse } from "yaml";

const PROJECT_DIR = import.meta.dir;
const WORKFLOW_PATH = join(PROJECT_DIR, ".github/workflows/pr-label-assigner.yml");
const ACT_RESULT_FILE = join(PROJECT_DIR, "act-result.txt");

// Clear act-result.txt at the start
writeFileSync(ACT_RESULT_FILE, "");

interface TestCase {
  name: string;
  changedFiles: string;
  expectedLabels: string[];
  expectedFileMatches: Record<string, string[]>;
}

const TEST_CASES: TestCase[] = [
  {
    name: "API and docs files",
    changedFiles: "src/api/routes.ts,docs/readme.md,app.test.ts",
    expectedLabels: ["api", "core", "documentation", "tests"],
    expectedFileMatches: {
      "src/api/routes.ts": ["api", "core"],
      "docs/readme.md": ["documentation"],
      "app.test.ts": ["tests"],
    },
  },
  {
    name: "Config and CI files",
    changedFiles: "jest.config.ts,.github/workflows/ci.yml,src/utils/helper.ts",
    expectedLabels: ["ci", "config", "core"],
    expectedFileMatches: {
      "jest.config.ts": ["config"],
      ".github/workflows/ci.yml": ["ci"],
      "src/utils/helper.ts": ["core"],
    },
  },
  {
    name: "Styles and nested tests",
    changedFiles: "src/components/button.css,src/api/auth.test.ts,README.md",
    expectedLabels: ["api", "core", "documentation", "styles", "tests"],
    expectedFileMatches: {
      "src/components/button.css": ["core", "styles"],
      "src/api/auth.test.ts": ["api", "core", "tests"],
      "README.md": ["documentation"],
    },
  },
];

function runActForTestCase(testCase: TestCase): string {
  const tempDir = join("/tmp", `act-test-${Date.now()}-${Math.random().toString(36).slice(2)}`);
  mkdirSync(tempDir, { recursive: true });

  // Copy project files to temp dir
  const filesToCopy = [
    "label-assigner.ts",
    "types.ts",
    "label-config.json",
  ];
  for (const f of filesToCopy) {
    cpSync(join(PROJECT_DIR, f), join(tempDir, f));
  }
  mkdirSync(join(tempDir, ".github/workflows"), { recursive: true });
  cpSync(WORKFLOW_PATH, join(tempDir, ".github/workflows/pr-label-assigner.yml"));

  // Copy .actrc
  cpSync(join(PROJECT_DIR, ".actrc"), join(tempDir, ".actrc"));

  // Initialize git repo
  execSync(
    `cd "${tempDir}" && git init && git add -A && git commit -m "init" --allow-empty`,
    { stdio: "pipe" }
  );

  // Run act with the test case's changed files
  let output: string;
  try {
    output = execSync(
      `cd "${tempDir}" && act push --rm --pull=false --env CHANGED_FILES="${testCase.changedFiles}"`,
      { stdio: "pipe", timeout: 120000, encoding: "utf-8" }
    );
  } catch (e: any) {
    output = (e.stdout || "") + "\n" + (e.stderr || "");
    // Clean up
    rmSync(tempDir, { recursive: true, force: true });
    return output;
  }

  rmSync(tempDir, { recursive: true, force: true });
  return output;
}

describe("Workflow Structure Tests", () => {
  test("workflow YAML is valid and has expected structure", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    const workflow = parse(content);

    expect(workflow.name).toBe("PR Label Assigner");
    expect(workflow.on.push).toBeDefined();
    expect(workflow.on.pull_request).toBeDefined();
    expect(workflow.on.workflow_dispatch).toBeDefined();
    expect(workflow.permissions.contents).toBe("read");
    expect(workflow.jobs["assign-labels"]).toBeDefined();
    expect(workflow.jobs["assign-labels"].steps.length).toBeGreaterThanOrEqual(3);
  });

  test("workflow references existing script files", () => {
    expect(existsSync(join(PROJECT_DIR, "label-assigner.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_DIR, "types.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_DIR, "label-config.json"))).toBe(true);
  });

  test("actionlint passes with exit code 0", () => {
    const result = execSync(`actionlint "${WORKFLOW_PATH}" 2>&1 || true`, {
      encoding: "utf-8",
    });
    // actionlint outputs nothing on success
    const exitCode = execSync(
      `actionlint "${WORKFLOW_PATH}" > /dev/null 2>&1; echo $?`,
      { encoding: "utf-8" }
    ).trim();
    expect(exitCode).toBe("0");
  });

  test("workflow has checkout step using actions/checkout@v4", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    const workflow = parse(content);
    const steps = workflow.jobs["assign-labels"].steps;
    const checkoutStep = steps.find(
      (s: any) => s.uses && s.uses.startsWith("actions/checkout@")
    );
    expect(checkoutStep).toBeDefined();
    expect(checkoutStep.uses).toBe("actions/checkout@v4");
  });
});

describe("Integration Tests via Act", () => {
  let actOutputs: string[] = [];

  beforeAll(() => {
    // Run all test cases through act (counts as one act push per case, max 3 total)
    for (const tc of TEST_CASES) {
      const output = runActForTestCase(tc);
      actOutputs.push(output);

      // Append to act-result.txt
      const delimiter = `\n${"=".repeat(60)}\nTEST CASE: ${tc.name}\n${"=".repeat(60)}\n`;
      const existing = readFileSync(ACT_RESULT_FILE, "utf-8");
      writeFileSync(ACT_RESULT_FILE, existing + delimiter + output + "\n");
    }
  }, 360000);

  test("act-result.txt exists and is non-empty", () => {
    expect(existsSync(ACT_RESULT_FILE)).toBe(true);
    const content = readFileSync(ACT_RESULT_FILE, "utf-8");
    expect(content.length).toBeGreaterThan(0);
  });

  test("Test Case 1: API and docs - correct labels", () => {
    const output = actOutputs[0];
    expect(output).toContain("Job succeeded");
    expect(output).toContain("LABELS: api,core,documentation,tests");
    expect(output).toContain("src/api/routes.ts: api, core");
    expect(output).toContain("docs/readme.md: documentation");
    expect(output).toContain("app.test.ts: tests");
  });

  test("Test Case 2: Config and CI - correct labels", () => {
    const output = actOutputs[1];
    expect(output).toContain("Job succeeded");
    expect(output).toContain("LABELS: ci,config,core");
    expect(output).toContain("jest.config.ts: config");
    expect(output).toContain(".github/workflows/ci.yml: ci");
    expect(output).toContain("src/utils/helper.ts: core");
  });

  test("Test Case 3: Styles and nested tests - correct labels", () => {
    const output = actOutputs[2];
    expect(output).toContain("Job succeeded");
    expect(output).toContain("LABELS: api,core,documentation,styles,tests");
    expect(output).toContain("src/components/button.css: core, styles");
    expect(output).toContain("src/api/auth.test.ts: tests, api, core");
    expect(output).toContain("README.md: documentation");
  });
});
