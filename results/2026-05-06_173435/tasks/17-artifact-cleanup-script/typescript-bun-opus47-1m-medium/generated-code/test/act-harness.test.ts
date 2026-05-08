// End-to-end harness: drives every fixture through the actual GitHub Actions
// workflow via `act`, captures its output to act-result.txt, then asserts on
// exact values produced for each case. We use a matrix job in the workflow so
// a single `act push` covers all fixture cases (well within the 3-run cap).
import { describe, expect, test, beforeAll } from "bun:test";
import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync, appendFileSync } from "node:fs";
import { join } from "node:path";
import { parse as parseYaml } from "yaml";

const PROJECT_ROOT = join(import.meta.dir, "..");
const ACT_RESULT_FILE = join(PROJECT_ROOT, "act-result.txt");

interface ExpectedSummary {
  totalCount: number;
  retainedCount: number;
  deletedCount: number;
  spaceReclaimedBytes: number;
  retainedSizeBytes: number;
  toDelete: string[]; // sorted ids
}

const EXPECTED: Record<string, ExpectedSummary> = {
  "basic-age": {
    totalCount: 3,
    retainedCount: 1,
    deletedCount: 2,
    spaceReclaimedBytes: 7500,
    retainedSizeBytes: 3000,
    toDelete: ["old-1", "old-2"],
  },
  "size-cap": {
    totalCount: 3,
    retainedCount: 2,
    deletedCount: 1,
    spaceReclaimedBytes: 600,
    retainedSizeBytes: 1200,
    toDelete: ["a1"],
  },
  "keep-latest": {
    totalCount: 4,
    retainedCount: 3,
    deletedCount: 1,
    spaceReclaimedBytes: 100,
    retainedSizeBytes: 600,
    toDelete: ["w1-old"],
  },
};

let actOutput = "";

// 10-minute budget — act needs ~60–90 s to execute the workflow.
beforeAll(() => {
  writeFileSync(ACT_RESULT_FILE, "");
  appendFileSync(ACT_RESULT_FILE, "===== act push --rm (single run, matrix over fixtures) =====\n");
  const result = spawnSync("act", ["push", "--rm"], {
    cwd: PROJECT_ROOT,
    encoding: "utf-8",
    timeout: 9 * 60 * 1000,
    maxBuffer: 64 * 1024 * 1024,
  });

  actOutput = (result.stdout ?? "") + (result.stderr ?? "");
  appendFileSync(ACT_RESULT_FILE, actOutput);
  appendFileSync(ACT_RESULT_FILE, `\n===== exit code: ${result.status} =====\n`);

  if (result.status !== 0) {
    const tail = actOutput.split("\n").slice(-80).join("\n");
    throw new Error(`act exited with code ${result.status}. Tail of output:\n${tail}`);
  }
}, 10 * 60 * 1000);

describe("workflow structure", () => {
  test("actionlint passes", () => {
    const r = spawnSync("actionlint", [".github/workflows/artifact-cleanup-script.yml"], {
      cwd: PROJECT_ROOT,
      encoding: "utf-8",
    });
    expect(r.status).toBe(0);
  });

  test("workflow YAML has the expected triggers, jobs and steps", () => {
    const wf = parseYaml(
      readFileSync(join(PROJECT_ROOT, ".github/workflows/artifact-cleanup-script.yml"), "utf-8"),
    );
    // YAML's `on:` is parsed as boolean `true` by some libs; the `yaml` pkg
    // returns the string key, so just access via bracket.
    const triggers = wf.on ?? wf[true];
    expect(Object.keys(triggers).sort()).toEqual(["pull_request", "push", "schedule", "workflow_dispatch"]);
    expect(Object.keys(wf.jobs).sort()).toEqual(["cleanup-fixtures", "unit-tests"]);
    expect(wf.jobs["cleanup-fixtures"].needs).toBe("unit-tests");
    expect(wf.jobs["cleanup-fixtures"].strategy.matrix.fixture).toEqual([
      "basic-age",
      "size-cap",
      "keep-latest",
    ]);
  });

  test("workflow references existing script and fixture files", () => {
    expect(existsSync(join(PROJECT_ROOT, "src/cli.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_ROOT, "src/cleanup.ts"))).toBe(true);
    for (const fx of Object.keys(EXPECTED)) {
      expect(existsSync(join(PROJECT_ROOT, `fixtures/${fx}.json`))).toBe(true);
    }
  });
});

describe("act execution", () => {
  test("act-result.txt was produced", () => {
    expect(existsSync(ACT_RESULT_FILE)).toBe(true);
    const stats = readFileSync(ACT_RESULT_FILE, "utf-8");
    expect(stats.length).toBeGreaterThan(100);
  });

  test("every job reports success", () => {
    // act prints "Job succeeded" for each successful job.
    const successes = actOutput.match(/Job succeeded/g) ?? [];
    // unit-tests + 3 matrix cleanup jobs = 4
    expect(successes.length).toBeGreaterThanOrEqual(4);
  });
});

// Per-fixture assertions: extract the JSON payload between the FIXTURE-START
// and FIXTURE-END markers our workflow prints, then compare to known-good values.
function extractFixtureJson(fixture: string): {
  dryRun: boolean;
  summary: ExpectedSummary;
  toDelete: string[];
  toRetain: string[];
} {
  // act prefixes lines with `| ` so we strip that. We anchor on the markers
  // and grab everything between.
  const startRe = new RegExp(`FIXTURE-START:${fixture}`);
  const endRe = new RegExp(`FIXTURE-END:${fixture}`);
  const lines = actOutput.split("\n");
  const startIdx = lines.findIndex(l => startRe.test(l));
  const endIdx = lines.findIndex(l => endRe.test(l));
  if (startIdx === -1 || endIdx === -1 || endIdx <= startIdx) {
    throw new Error(`Could not locate fixture markers for ${fixture}`);
  }
  const payload = lines
    .slice(startIdx + 1, endIdx)
    .map(l => l.replace(/^.*?\|\s?/, "")) // strip act's "[Job/Step] |" prefix
    .join("\n");
  // Find the JSON object — it starts at the first '{' and ends at the last '}'.
  const first = payload.indexOf("{");
  const last = payload.lastIndexOf("}");
  if (first === -1 || last === -1) {
    throw new Error(`No JSON in fixture output for ${fixture}:\n${payload}`);
  }
  return JSON.parse(payload.slice(first, last + 1));
}

describe.each(Object.keys(EXPECTED))("fixture: %s", fixture => {
  test("produces exactly the expected deletion plan", () => {
    const actual = extractFixtureJson(fixture);
    const expected = EXPECTED[fixture]!;
    expect(actual.dryRun).toBe(true);
    expect(actual.summary.totalCount).toBe(expected.totalCount);
    expect(actual.summary.retainedCount).toBe(expected.retainedCount);
    expect(actual.summary.deletedCount).toBe(expected.deletedCount);
    expect(actual.summary.spaceReclaimedBytes).toBe(expected.spaceReclaimedBytes);
    expect(actual.summary.retainedSizeBytes).toBe(expected.retainedSizeBytes);
    expect([...actual.toDelete].sort()).toEqual(expected.toDelete);
  });
});
