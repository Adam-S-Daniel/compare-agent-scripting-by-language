// Workflow tests.
//
// Two layers:
//   1. Structure tests — parse the YAML and check triggers/jobs/steps.
//      These run instantly and would catch most regressions during normal
//      development.
//   2. Pipeline tests — set up a throwaway git repo with a per-case fixture,
//      invoke `act push --rm` against the workflow, and assert against
//      expected exact substrings in the captured output. Slow (~30-90s
//      per case) but exercises the real CI path end-to-end.
//
// All act output is appended to ./act-result.txt in the project root, with
// clear delimiters per case. That file is the artifact the benchmark expects.

import { describe, expect, test, beforeAll } from "bun:test";
import { execSync, spawnSync } from "node:child_process";
import {
  cpSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
  appendFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";

// Bun ships native YAML parsing. We rely on it instead of pulling a
// dependency for one-shot workflow file parsing.
const parseYaml = (text: string): any => Bun.YAML.parse(text);

const PROJECT_ROOT = join(import.meta.dir, "..");
const WORKFLOW_PATH = join(PROJECT_ROOT, ".github", "workflows", "dependency-license-checker.yml");
const ACT_RESULT_PATH = join(PROJECT_ROOT, "act-result.txt");

// --- Structure tests -------------------------------------------------------

describe("workflow structure", () => {
  let yaml: any;
  beforeAll(() => {
    yaml = parseYaml(readFileSync(WORKFLOW_PATH, "utf8"));
  });

  test("file exists at the expected path", () => {
    expect(existsSync(WORKFLOW_PATH)).toBe(true);
  });

  test("declares the four expected triggers", () => {
    // YAML 'on' is a reserved key in some parsers; our tiny parser preserves it.
    const on = yaml.on ?? yaml.true; // Some parsers treat YAML 1.1 `on` as boolean true
    expect(Object.keys(on).sort()).toEqual([
      "pull_request",
      "push",
      "schedule",
      "workflow_dispatch",
    ]);
  });

  test("has unit-tests and license-check jobs with proper dependency", () => {
    expect(Object.keys(yaml.jobs).sort()).toEqual(["license-check", "unit-tests"]);
    expect(yaml.jobs["license-check"].needs).toBe("unit-tests");
  });

  test("checks out the repo via actions/checkout@v4 in both jobs", () => {
    for (const jobName of ["unit-tests", "license-check"]) {
      const steps = yaml.jobs[jobName].steps;
      const checkout = steps.find((s: any) => s.uses && s.uses.startsWith("actions/checkout@"));
      expect(checkout).toBeDefined();
      expect(checkout.uses).toBe("actions/checkout@v4");
    }
  });

  test("references src/cli.ts in the license-check job", () => {
    const steps = yaml.jobs["license-check"].steps;
    const runStep = steps.find((s: any) => typeof s.run === "string" && s.run.includes("src/cli.ts"));
    expect(runStep).toBeDefined();
    // and the file actually exists on disk
    expect(existsSync(join(PROJECT_ROOT, "src", "cli.ts"))).toBe(true);
  });

  test("declares read-only contents permission", () => {
    expect(yaml.permissions.contents).toBe("read");
  });

  test("actionlint passes against the workflow file (exit code 0)", () => {
    const r = spawnSync("actionlint", [WORKFLOW_PATH], { encoding: "utf8" });
    expect(r.status).toBe(0);
  });
});

// --- Pipeline (act) tests --------------------------------------------------

interface CaseSpec {
  name: string;
  manifest: object;
  config: object;
  licenses: object;
  expectedExitCode: number;
  expectedSubstrings: string[];
}

const cases: CaseSpec[] = [
  {
    name: "approved",
    manifest: {
      name: "case-approved",
      dependencies: { "left-pad": "^1.3.0", "lodash": "~4.17.21" },
    },
    config: { allow: ["MIT", "Apache-2.0"], deny: ["GPL-3.0"] },
    licenses: { "left-pad": "MIT", "lodash": "MIT" },
    expectedExitCode: 0,
    expectedSubstrings: [
      "[APPROVED] left-pad@1.3.0 -> MIT",
      "[APPROVED] lodash@4.17.21 -> MIT",
      "Totals: 2 deps, 2 approved, 0 denied, 0 unknown",
      "LICENSE_EXIT_CODE=0",
    ],
  },
  {
    name: "denied",
    manifest: {
      name: "case-denied",
      dependencies: { "left-pad": "^1.3.0", "evil-lib": "2.0.0" },
    },
    config: { allow: ["MIT"], deny: ["GPL-3.0"] },
    licenses: { "left-pad": "MIT", "evil-lib": "GPL-3.0" },
    expectedExitCode: 1,
    expectedSubstrings: [
      "[APPROVED] left-pad@1.3.0 -> MIT",
      "[DENIED] evil-lib@2.0.0 -> GPL-3.0",
      "Totals: 2 deps, 1 approved, 1 denied, 0 unknown",
      "LICENSE_EXIT_CODE=1",
    ],
  },
  {
    name: "unknown",
    manifest: {
      name: "case-unknown",
      dependencies: { "mystery-lib": "0.1.0" },
    },
    config: { allow: ["MIT"], deny: ["GPL-3.0"] },
    licenses: {}, // the lib isn't in the lookup table
    expectedExitCode: 2,
    expectedSubstrings: [
      "[UNKNOWN] mystery-lib@0.1.0 -> (no license info)",
      "Totals: 1 deps, 0 approved, 0 denied, 1 unknown",
      "LICENSE_EXIT_CODE=2",
    ],
  },
];

function setupTempRepo(spec: CaseSpec): string {
  const tmp = mkdtempSync(join(tmpdir(), `act-license-${spec.name}-`));
  // Copy minimal project files. We could copy node_modules too, but bun
  // is installed inside act and `bun install` (no deps) runs essentially
  // for free in our tree.
  for (const path of [
    "src",
    "tests/parse.test.ts",
    "tests/compliance.test.ts",
    "tests/report.test.ts",
    "tests/cli.test.ts",
    "package.json",
    "tsconfig.json",
    ".actrc",
  ]) {
    const from = join(PROJECT_ROOT, path);
    const to = join(tmp, path);
    mkdirSync(dirname(to), { recursive: true });
    cpSync(from, to, { recursive: true });
  }
  // Workflow + fixture dir.
  mkdirSync(join(tmp, ".github", "workflows"), { recursive: true });
  cpSync(WORKFLOW_PATH, join(tmp, ".github", "workflows", "dependency-license-checker.yml"));
  const fixDir = join(tmp, "tests", "fixtures", "default");
  mkdirSync(fixDir, { recursive: true });
  writeFileSync(join(fixDir, "package.json"), JSON.stringify(spec.manifest, null, 2));
  writeFileSync(join(fixDir, "config.json"), JSON.stringify(spec.config, null, 2));
  writeFileSync(join(fixDir, "licenses.json"), JSON.stringify(spec.licenses, null, 2));

  // act needs the workspace to be a git repo so checkout has something to act on.
  execSync(
    [
      "git init -q",
      "git -c user.email=t@t -c user.name=t add -A",
      "git -c user.email=t@t -c user.name=t commit -q -m 'fixture'",
    ].join(" && "),
    { cwd: tmp },
  );
  return tmp;
}

function appendActResult(name: string, output: string, exit: number): void {
  const banner = `\n${"=".repeat(72)}\nCASE: ${name} (act exit=${exit})\n${"=".repeat(72)}\n`;
  appendFileSync(ACT_RESULT_PATH, banner + output + "\n");
}

beforeAll(() => {
  // Reset act-result.txt at the start of each suite run so it reflects this run only.
  writeFileSync(ACT_RESULT_PATH, `act test run ${new Date().toISOString()}\n`);
});

describe("workflow pipeline (act)", () => {
  for (const spec of cases) {
    test(
      `case ${spec.name}: matches expected output`,
      () => {
        const tmp = setupTempRepo(spec);
        try {
          const r = spawnSync(
            "act",
            [
              "push",
              "--rm",
              "--pull=false",
              "-W",
              ".github/workflows/dependency-license-checker.yml",
            ],
            { cwd: tmp, encoding: "utf8", maxBuffer: 64 * 1024 * 1024 },
          );
          const combined = `STDOUT:\n${r.stdout}\nSTDERR:\n${r.stderr}`;
          appendActResult(spec.name, combined, r.status ?? -1);

          // 1. act exited successfully.
          expect(r.status).toBe(0);

          // 2. Both jobs reported success.
          //    act prints "Job succeeded" once per job.
          const successCount = (combined.match(/Job succeeded/g) ?? []).length;
          expect(successCount).toBeGreaterThanOrEqual(2);

          // 3. Expected substrings present in stdout.
          for (const needle of spec.expectedSubstrings) {
            expect(combined).toContain(needle);
          }
        } finally {
          rmSync(tmp, { recursive: true, force: true });
        }
      },
      600_000,
    );
  }
});
