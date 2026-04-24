// TDD test suite for Test Results Aggregator
// Red/green cycle: tests written first, then implementation makes them pass
import { describe, test, expect } from "bun:test";
import {
  existsSync,
  readFileSync,
  mkdirSync,
  cpSync,
  writeFileSync,
  rmSync,
} from "fs";
import { join } from "path";
import { parseJUnit } from "./src/parsers/junit";
import { parseJSON } from "./src/parsers/json-parser";
import { computeAggregation, parseFile } from "./src/aggregator";
import { generateMarkdown } from "./src/markdown";
import type { ParsedResult } from "./src/types";

const ROOT = import.meta.dir;
const FIXTURES_DIR = join(ROOT, "fixtures");
const WORKFLOW_FILE = join(ROOT, ".github/workflows/test-results-aggregator.yml");

// ─── JUnit XML Parser ────────────────────────────────────────────────────────

describe("parseJUnit", () => {
  test("parses a passed testcase", () => {
    const xml = `<?xml version="1.0"?>
<testsuite name="MySuite" tests="1" failures="0" time="0.5">
  <testcase name="my test" classname="MySuite" time="0.5"/>
</testsuite>`;
    const result = parseJUnit(xml, "test-run");
    expect(result.runId).toBe("test-run");
    expect(result.format).toBe("junit");
    expect(result.suites).toHaveLength(1);
    expect(result.suites[0].name).toBe("MySuite");
    expect(result.suites[0].tests).toHaveLength(1);
    expect(result.suites[0].tests[0].status).toBe("passed");
    expect(result.suites[0].tests[0].name).toBe("my test");
    expect(result.suites[0].tests[0].duration).toBe(0.5);
  });

  test("parses a failed testcase and extracts error message", () => {
    const xml = `<?xml version="1.0"?>
<testsuite name="MySuite" tests="1" failures="1" time="0.3">
  <testcase name="failing test" classname="MySuite" time="0.3">
    <failure message="Expected 42 but got 0">AssertionError</failure>
  </testcase>
</testsuite>`;
    const result = parseJUnit(xml, "test-run");
    const t = result.suites[0].tests[0];
    expect(t.status).toBe("failed");
    expect(t.error).toContain("Expected 42");
  });

  test("parses a skipped testcase", () => {
    const xml = `<?xml version="1.0"?>
<testsuite name="MySuite" tests="1" skipped="1" time="0">
  <testcase name="skipped test" classname="MySuite" time="0">
    <skipped/>
  </testcase>
</testsuite>`;
    const result = parseJUnit(xml, "test-run");
    expect(result.suites[0].tests[0].status).toBe("skipped");
  });

  test("handles <testsuites> root with multiple suites", () => {
    const xml = `<?xml version="1.0"?>
<testsuites>
  <testsuite name="Suite1" tests="1" time="1.0">
    <testcase name="test1" time="1.0"/>
  </testsuite>
  <testsuite name="Suite2" tests="1" time="2.0">
    <testcase name="test2" time="2.0"/>
  </testsuite>
</testsuites>`;
    const result = parseJUnit(xml, "multi-run");
    expect(result.suites).toHaveLength(2);
    expect(result.suites[0].name).toBe("Suite1");
    expect(result.suites[1].name).toBe("Suite2");
  });

  test("parses chrome fixture: 2 suites, 1 failure in AuthTests", () => {
    const content = readFileSync(join(FIXTURES_DIR, "junit-chrome.xml"), "utf-8");
    const result = parseJUnit(content, "junit-chrome");
    expect(result.suites).toHaveLength(2);
    const auth = result.suites.find((s) => s.name === "AuthTests")!;
    expect(auth.tests).toHaveLength(3);
    const flaky = auth.tests.find(
      (t) => t.name === "user login fails with bad password"
    )!;
    expect(flaky.status).toBe("failed");
    expect(flaky.error).toContain("Expected status 401");
  });

  test("parses firefox fixture: 0 failures (same test passes)", () => {
    const content = readFileSync(join(FIXTURES_DIR, "junit-firefox.xml"), "utf-8");
    const result = parseJUnit(content, "junit-firefox");
    const auth = result.suites.find((s) => s.name === "AuthTests")!;
    const sameTest = auth.tests.find(
      (t) => t.name === "user login fails with bad password"
    )!;
    expect(sameTest.status).toBe("passed");
  });
});

// ─── JSON Parser ─────────────────────────────────────────────────────────────

describe("parseJSON", () => {
  test("parses a valid JSON result file", () => {
    const json = JSON.stringify({
      suite: "MyTests",
      tests: [
        { name: "test one", status: "passed", duration: 0.1 },
        { name: "test two", status: "failed", duration: 0.2, error: "oops" },
        { name: "test three", status: "skipped", duration: 0 },
      ],
    });
    const result = parseJSON(json, "my-run");
    expect(result.format).toBe("json");
    expect(result.suites).toHaveLength(1);
    expect(result.suites[0].tests).toHaveLength(3);
    expect(result.suites[0].tests[0].status).toBe("passed");
    expect(result.suites[0].tests[1].status).toBe("failed");
    expect(result.suites[0].tests[1].error).toBe("oops");
    expect(result.suites[0].tests[2].status).toBe("skipped");
  });

  test("throws a meaningful error on invalid JSON", () => {
    expect(() => parseJSON("not json", "run")).toThrow(/Failed to parse JSON/);
  });

  test("throws a meaningful error on missing required fields", () => {
    expect(() =>
      parseJSON(JSON.stringify({ notSuite: true }), "run")
    ).toThrow(/Invalid JSON format/);
  });

  test("parses unit fixture: UnitTests suite with 4 tests", () => {
    const content = readFileSync(
      join(FIXTURES_DIR, "results-unit.json"),
      "utf-8"
    );
    const result = parseJSON(content, "results-unit");
    expect(result.suites[0].name).toBe("UnitTests");
    expect(result.suites[0].tests).toHaveLength(4);
  });
});

// ─── parseFile (file-format dispatch) ────────────────────────────────────────

describe("parseFile", () => {
  test("dispatches .xml files to JUnit parser", () => {
    const r = parseFile(join(FIXTURES_DIR, "junit-chrome.xml"));
    expect(r.format).toBe("junit");
    expect(r.runId).toBe("junit-chrome");
  });

  test("dispatches .json files to JSON parser", () => {
    const r = parseFile(join(FIXTURES_DIR, "results-unit.json"));
    expect(r.format).toBe("json");
    expect(r.runId).toBe("results-unit");
  });

  test("throws on non-existent file", () => {
    expect(() => parseFile("/no/such/file.xml")).toThrow(/File not found/);
  });

  test("throws on unsupported extension", () => {
    // Create a temp file with bad extension
    const tmp = "/tmp/test-bad-ext.csv";
    writeFileSync(tmp, "data");
    expect(() => parseFile(tmp)).toThrow(/Unsupported file format/);
    rmSync(tmp);
  });
});

// ─── Aggregation ─────────────────────────────────────────────────────────────

describe("computeAggregation", () => {
  test("computes totals from a single result", () => {
    const results: ParsedResult[] = [
      {
        runId: "run1",
        format: "junit",
        suites: [
          {
            name: "Suite",
            duration: 1.0,
            tests: [
              { name: "p", suiteName: "Suite", status: "passed", duration: 0.5 },
              {
                name: "f",
                suiteName: "Suite",
                status: "failed",
                duration: 0.3,
                error: "oops",
              },
              { name: "s", suiteName: "Suite", status: "skipped", duration: 0.2 },
            ],
          },
        ],
      },
    ];
    const agg = computeAggregation(results);
    expect(agg.totalTests).toBe(3);
    expect(agg.passed).toBe(1);
    expect(agg.failed).toBe(1);
    expect(agg.skipped).toBe(1);
    expect(agg.duration).toBeCloseTo(1.0);
    expect(agg.fileCount).toBe(1);
    expect(agg.failedTests).toHaveLength(1);
    expect(agg.failedTests[0].error).toBe("oops");
  });

  test("identifies flaky tests across multiple runs", () => {
    const results: ParsedResult[] = [
      {
        runId: "run1",
        format: "junit",
        suites: [
          {
            name: "Suite",
            duration: 1.0,
            tests: [
              {
                name: "flaky",
                suiteName: "Suite",
                status: "failed",
                duration: 0.5,
                error: "err",
              },
            ],
          },
        ],
      },
      {
        runId: "run2",
        format: "junit",
        suites: [
          {
            name: "Suite",
            duration: 1.0,
            tests: [
              { name: "flaky", suiteName: "Suite", status: "passed", duration: 0.5 },
            ],
          },
        ],
      },
    ];
    const agg = computeAggregation(results);
    expect(agg.flakyTests).toHaveLength(1);
    expect(agg.flakyTests[0].name).toBe("flaky");
    expect(agg.flakyTests[0].passedRuns).toBe(1);
    expect(agg.flakyTests[0].failedRuns).toBe(1);
  });

  test("does not mark consistently failing tests as flaky", () => {
    const results: ParsedResult[] = [
      {
        runId: "run1",
        format: "junit",
        suites: [
          {
            name: "Suite",
            duration: 1.0,
            tests: [
              {
                name: "broken",
                suiteName: "Suite",
                status: "failed",
                duration: 0.5,
                error: "e",
              },
            ],
          },
        ],
      },
      {
        runId: "run2",
        format: "junit",
        suites: [
          {
            name: "Suite",
            duration: 1.0,
            tests: [
              {
                name: "broken",
                suiteName: "Suite",
                status: "failed",
                duration: 0.5,
                error: "e",
              },
            ],
          },
        ],
      },
    ];
    const agg = computeAggregation(results);
    expect(agg.flakyTests).toHaveLength(0);
  });

  // Key integration test: all 3 fixtures combined produce known-good totals
  test("aggregates all fixtures: 14 total, 9 passed, 2 failed, 3 skipped, 1 flaky", () => {
    const chrome = parseJUnit(
      readFileSync(join(FIXTURES_DIR, "junit-chrome.xml"), "utf-8"),
      "junit-chrome"
    );
    const firefox = parseJUnit(
      readFileSync(join(FIXTURES_DIR, "junit-firefox.xml"), "utf-8"),
      "junit-firefox"
    );
    const unit = parseJSON(
      readFileSync(join(FIXTURES_DIR, "results-unit.json"), "utf-8"),
      "results-unit"
    );

    const agg = computeAggregation([chrome, firefox, unit]);
    expect(agg.totalTests).toBe(14);
    expect(agg.passed).toBe(9);
    expect(agg.failed).toBe(2);
    expect(agg.skipped).toBe(3);
    expect(agg.flakyTests).toHaveLength(1);
    expect(agg.flakyTests[0].name).toBe("user login fails with bad password");
    expect(agg.flakyTests[0].suiteName).toBe("AuthTests");
    expect(agg.fileCount).toBe(3);
  });
});

// ─── Markdown Generation ──────────────────────────────────────────────────────

describe("generateMarkdown", () => {
  test("includes summary table with all metrics", () => {
    const agg = {
      totalTests: 10,
      passed: 8,
      failed: 1,
      skipped: 1,
      duration: 3.14,
      flakyTests: [],
      failedTests: [],
      fileCount: 2,
    };
    const md = generateMarkdown(agg);
    expect(md).toContain("## Test Results Summary");
    expect(md).toContain("| Total Tests | 10 |");
    expect(md).toContain("| Passed | 8 |");
    expect(md).toContain("| Failed | 1 |");
    expect(md).toContain("| Skipped | 1 |");
    expect(md).toContain("3.14s");
    expect(md).toContain("| Files Processed | 2 |");
  });

  test("includes flaky tests section when flaky tests exist", () => {
    const agg = {
      totalTests: 2,
      passed: 1,
      failed: 1,
      skipped: 0,
      duration: 1.0,
      flakyTests: [
        { name: "flaky test", suiteName: "Suite", passedRuns: 1, failedRuns: 1 },
      ],
      failedTests: [],
      fileCount: 2,
    };
    const md = generateMarkdown(agg);
    expect(md).toContain("## Flaky Tests (1)");
    expect(md).toContain("flaky test");
    expect(md).toContain("Suite");
  });

  test("reports zero flaky tests when none exist", () => {
    const agg = {
      totalTests: 1,
      passed: 1,
      failed: 0,
      skipped: 0,
      duration: 0.1,
      flakyTests: [],
      failedTests: [],
      fileCount: 1,
    };
    const md = generateMarkdown(agg);
    expect(md).toContain("## Flaky Tests (0)");
    expect(md).toContain("No flaky tests detected");
  });

  test("includes failed tests table with error details", () => {
    const agg = {
      totalTests: 1,
      passed: 0,
      failed: 1,
      skipped: 0,
      duration: 0.5,
      flakyTests: [],
      failedTests: [
        { name: "my test", suiteName: "Suite", runId: "run1", error: "oops" },
      ],
      fileCount: 1,
    };
    const md = generateMarkdown(agg);
    expect(md).toContain("## Failed Tests (1)");
    expect(md).toContain("my test");
    expect(md).toContain("oops");
  });

  test("full fixture aggregation generates correct markdown values", () => {
    const chrome = parseJUnit(
      readFileSync(join(FIXTURES_DIR, "junit-chrome.xml"), "utf-8"),
      "junit-chrome"
    );
    const firefox = parseJUnit(
      readFileSync(join(FIXTURES_DIR, "junit-firefox.xml"), "utf-8"),
      "junit-firefox"
    );
    const unit = parseJSON(
      readFileSync(join(FIXTURES_DIR, "results-unit.json"), "utf-8"),
      "results-unit"
    );
    const agg = computeAggregation([chrome, firefox, unit]);
    const md = generateMarkdown(agg);

    expect(md).toContain("| Total Tests | 14 |");
    expect(md).toContain("| Passed | 9 |");
    expect(md).toContain("| Failed | 2 |");
    expect(md).toContain("| Skipped | 3 |");
    expect(md).toContain("## Flaky Tests (1)");
    expect(md).toContain("user login fails with bad password");
    expect(md).toContain("## Failed Tests (2)");
  });
});

// ─── Workflow Structure Tests ─────────────────────────────────────────────────

describe("workflow structure", () => {
  test("workflow file exists at expected path", () => {
    expect(existsSync(WORKFLOW_FILE)).toBe(true);
  });

  test("workflow has push trigger", () => {
    const content = readFileSync(WORKFLOW_FILE, "utf-8");
    expect(content).toContain("push:");
  });

  test("workflow has pull_request trigger", () => {
    const content = readFileSync(WORKFLOW_FILE, "utf-8");
    expect(content).toContain("pull_request:");
  });

  test("workflow references run.ts", () => {
    const content = readFileSync(WORKFLOW_FILE, "utf-8");
    expect(content).toContain("run.ts");
  });

  test("workflow uses actions/checkout@v4", () => {
    const content = readFileSync(WORKFLOW_FILE, "utf-8");
    expect(content).toContain("actions/checkout@v4");
  });

  test("workflow uses oven-sh/setup-bun", () => {
    const content = readFileSync(WORKFLOW_FILE, "utf-8");
    expect(content).toContain("oven-sh/setup-bun");
  });

  test("workflow references fixtures directory", () => {
    const content = readFileSync(WORKFLOW_FILE, "utf-8");
    expect(content).toContain("fixtures");
  });

  test("run.ts exists", () => {
    expect(existsSync(join(ROOT, "run.ts"))).toBe(true);
  });

  test("src/aggregator.ts exists", () => {
    expect(existsSync(join(ROOT, "src/aggregator.ts"))).toBe(true);
  });

  test("fixtures/junit-chrome.xml exists", () => {
    expect(existsSync(join(FIXTURES_DIR, "junit-chrome.xml"))).toBe(true);
  });

  test("fixtures/junit-firefox.xml exists", () => {
    expect(existsSync(join(FIXTURES_DIR, "junit-firefox.xml"))).toBe(true);
  });

  test("fixtures/results-unit.json exists", () => {
    expect(existsSync(join(FIXTURES_DIR, "results-unit.json"))).toBe(true);
  });

  test("actionlint passes on workflow file", () => {
    const result = Bun.spawnSync(["actionlint", WORKFLOW_FILE], {
      stderr: "pipe",
      stdout: "pipe",
    });
    if (result.exitCode !== 0) {
      console.error("actionlint stderr:", result.stderr.toString());
      console.error("actionlint stdout:", result.stdout.toString());
    }
    expect(result.exitCode).toBe(0);
  }, 15000);
});

// ─── Act Integration Test (skipped inside GitHub Actions to avoid recursion) ─

describe("act integration", () => {
  const tmpDir = `/tmp/act-test-${Date.now()}`;
  const actResultFile = join(ROOT, "act-result.txt");

  test.skipIf(!!process.env.GITHUB_ACTIONS)(
    "runs workflow via act and asserts exact output values",
    async () => {
      // Set up an isolated temp git repo with all project files
      mkdirSync(tmpDir, { recursive: true });

      const filesToCopy = [
        "src",
        "fixtures",
        "run.ts",
        "package.json",
        "aggregator.test.ts",
        ".github",
      ];
      for (const f of filesToCopy) {
        const src = join(ROOT, f);
        if (existsSync(src)) {
          cpSync(src, join(tmpDir, f), { recursive: true });
        }
      }

      // Copy .actrc so act uses the correct container image
      const actrc = join(ROOT, ".actrc");
      if (existsSync(actrc)) {
        cpSync(actrc, join(tmpDir, ".actrc"));
      }

      // Initialize git repo (act requires a git repo)
      Bun.spawnSync(["git", "init"], { cwd: tmpDir });
      Bun.spawnSync(["git", "config", "user.email", "test@example.com"], {
        cwd: tmpDir,
      });
      Bun.spawnSync(["git", "config", "user.name", "Test"], { cwd: tmpDir });
      Bun.spawnSync(["git", "add", "-A"], { cwd: tmpDir });
      const commit = Bun.spawnSync(["git", "commit", "-m", "test"], {
        cwd: tmpDir,
      });
      expect(commit.exitCode).toBe(0);

      // Run the workflow via act (--pull=false uses the local image without trying to pull)
      const actResult = Bun.spawnSync(["act", "push", "--rm", "--pull=false"], {
        cwd: tmpDir,
        stdout: "pipe",
        stderr: "pipe",
        env: { ...process.env },
        timeout: 180000,
      });

      const output =
        actResult.stdout.toString() + "\n" + actResult.stderr.toString();

      // Append output to act-result.txt (required artifact)
      const header = `\n${"=".repeat(60)}\nAct Test Run - ${new Date().toISOString()}\n${"=".repeat(60)}\n`;
      const existing = existsSync(actResultFile)
        ? readFileSync(actResultFile, "utf-8")
        : "";
      writeFileSync(actResultFile, existing + header + output + "\n");

      // Assert act exited successfully
      if (actResult.exitCode !== 0) {
        console.error("Act output:\n", output.slice(0, 3000));
      }
      expect(actResult.exitCode).toBe(0);

      // Assert on exact expected values from the aggregator output
      expect(output).toContain("Total Tests | 14");
      expect(output).toContain("Passed | 9");
      expect(output).toContain("Failed | 2");
      expect(output).toContain("Skipped | 3");
      expect(output).toContain("Flaky Tests (1)");
      expect(output).toContain("user login fails with bad password");
      expect(output).toContain("Failed Tests (2)");
      expect(output).toContain("Job succeeded");

      // Cleanup temp dir
      rmSync(tmpDir, { recursive: true, force: true });
    },
    180000
  );
});
