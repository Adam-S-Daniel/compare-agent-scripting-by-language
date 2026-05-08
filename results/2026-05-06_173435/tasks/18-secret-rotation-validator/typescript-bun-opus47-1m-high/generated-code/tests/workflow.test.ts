// End-to-end workflow validation:
// 1) Parse the YAML and assert the workflow's structural shape.
// 2) Run actionlint and require a clean exit.
// 3) Run `act push --rm` against three fixture cases (mixed / all-ok /
//    all-expired). Each case runs in a fresh temp git repo seeded with the
//    project files + that fixture, asserts exit 0, captures output to
//    act-result.txt, and asserts on EXACT expected values from the workflow's
//    `ROTATION_SUMMARY ...` sentinel line.
//
// Heads up: act runs are slow (~30-90s each). Three cases ≈ a few minutes.

import { describe, expect, test, beforeAll } from "bun:test";
import {
  cpSync,
  existsSync,
  mkdtempSync,
  readFileSync,
  writeFileSync,
  appendFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { spawnSync } from "node:child_process";
import YAML from "yaml";

const ROOT = join(import.meta.dir, "..");
const WORKFLOW_PATH = join(ROOT, ".github", "workflows", "secret-rotation-validator.yml");
const ACT_RESULT_PATH = join(ROOT, "act-result.txt");

interface Case {
  id: string;
  fixture: string; // path under fixtures/
  expected: { expired: number; warning: number; ok: number };
  // Optional substring assertions on the rendered markdown report.
  expectedMarkdownContains: string[];
  expectedJsonContains: string[];
}

const CASES: Case[] = [
  {
    id: "mixed",
    fixture: "fixtures/case-mixed.json",
    expected: { expired: 1, warning: 1, ok: 1 },
    expectedMarkdownContains: [
      "## Expired (1)",
      "## Warning (1)",
      "## OK (1)",
      "| stripe_api_key | 2025-10-01 | 128 | billing-svc, checkout-svc |",
      "| datadog_api_key | 2026-02-20 | 14 | observability |",
      "| sendgrid_api_key | 2026-04-15 | 38 | notifications |",
    ],
    expectedJsonContains: [
      '"expired": 1',
      '"warning": 1',
      '"ok": 1',
      '"name": "stripe_api_key"',
      '"daysUntilExpiry": -128',
    ],
  },
  {
    id: "all-ok",
    fixture: "fixtures/case-all-ok.json",
    expected: { expired: 0, warning: 0, ok: 2 },
    expectedMarkdownContains: [
      "## Expired (0)",
      "## Warning (0)",
      "## OK (2)",
      "| fresh_token_a | 2026-05-01 | 359 | svc-a |",
      "| fresh_token_b | 2026-04-20 | 163 | svc-b, svc-c |",
    ],
    expectedJsonContains: [
      '"expired": 0',
      '"warning": 0',
      '"ok": 2',
    ],
  },
  {
    id: "all-expired",
    fixture: "fixtures/case-all-expired.json",
    expected: { expired: 3, warning: 0, ok: 0 },
    expectedMarkdownContains: [
      "## Expired (3)",
      "## Warning (0)",
      "## OK (0)",
      "| ancient_aws_key | 2024-01-01 |",
      "| ancient_github_pat | 2024-06-15 |",
      "| ancient_pagerduty | 2025-01-10 |",
    ],
    expectedJsonContains: [
      '"expired": 3',
      '"name": "ancient_aws_key"',
      '"name": "ancient_github_pat"',
      '"name": "ancient_pagerduty"',
    ],
  },
];

// Truncate the act-result.txt artifact at the start of the test session so each
// run produces a clean, append-only log.
beforeAll(() => {
  writeFileSync(ACT_RESULT_PATH, "");
});

describe("workflow YAML structure", () => {
  test("declares the expected triggers, permissions, jobs and steps", () => {
    const raw = readFileSync(WORKFLOW_PATH, "utf8");
    const wf = YAML.parse(raw) as {
      name: string;
      // YAML "on" parses as a string key (not boolean) when quoted/lowercased
      on: Record<string, unknown>;
      permissions: Record<string, string>;
      env: Record<string, string>;
      jobs: Record<string, { "runs-on": string; steps: Array<{ name?: string; uses?: string; run?: string }> }>;
    };

    expect(wf.name).toBe("Secret Rotation Validator");

    // Triggers — push, pull_request, schedule, workflow_dispatch
    const triggers = Object.keys(wf.on);
    expect(triggers).toEqual(expect.arrayContaining(["push", "pull_request", "schedule", "workflow_dispatch"]));

    // Permissions — least-privilege contents:read
    expect(wf.permissions).toEqual({ contents: "read" });

    // Single job named "validate" running on ubuntu-latest
    expect(Object.keys(wf.jobs)).toEqual(["validate"]);
    const validate = wf.jobs.validate!;
    expect(validate["runs-on"]).toBe("ubuntu-latest");

    // Steps: checkout + setup-bun + install + tests + json + md + summary + enforce
    const stepNames = validate.steps.map((s) => s.name).filter(Boolean);
    expect(stepNames).toEqual(
      expect.arrayContaining([
        "Check out repository",
        "Set up Bun",
        "Install dependencies",
        "Run unit tests",
        "Generate JSON report",
        "Generate Markdown report",
        "Emit summary line for harness",
        "Enforce rotation policy",
      ]),
    );

    // Pinned action references exist
    const usesValues = validate.steps.map((s) => s.uses).filter((u): u is string => Boolean(u));
    expect(usesValues).toEqual(
      expect.arrayContaining(["actions/checkout@v4", "oven-sh/setup-bun@v2"]),
    );
  });

  test("references files that exist in the repo", () => {
    expect(existsSync(join(ROOT, "src", "cli.ts"))).toBe(true);
    expect(existsSync(join(ROOT, "src", "classify.ts"))).toBe(true);
    expect(existsSync(join(ROOT, "src", "format.ts"))).toBe(true);
    expect(existsSync(join(ROOT, "secrets.json"))).toBe(true);
    expect(existsSync(join(ROOT, "package.json"))).toBe(true);
    for (const c of CASES) {
      expect(existsSync(join(ROOT, c.fixture))).toBe(true);
    }
  });
});

describe("actionlint", () => {
  test("reports no errors", () => {
    const r = spawnSync("actionlint", [WORKFLOW_PATH], { encoding: "utf8" });
    if (r.status !== 0) {
      // Surface actionlint output so failures are debuggable from CI logs.
      console.error("actionlint stdout:\n" + r.stdout);
      console.error("actionlint stderr:\n" + r.stderr);
    }
    expect(r.status).toBe(0);
  });
});

// Set up a temp git repo with the project files + a specific fixture as
// secrets.json. Returns the path to the temp repo.
function buildCaseRepo(fixtureRel: string): string {
  const dir = mkdtempSync(join(tmpdir(), "secret-rot-act-"));

  // Copy required files. Skip node_modules and .git from the source.
  const filesToCopy = [
    "package.json",
    "bun.lock",
    "tsconfig.json",
    "src",
    "tests",
    "fixtures",
    ".github",
    ".actrc",
  ];
  for (const f of filesToCopy) {
    const from = join(ROOT, f);
    if (!existsSync(from)) continue;
    cpSync(from, join(dir, f), { recursive: true });
  }

  // Replace secrets.json with the fixture's contents so the workflow reads it.
  const fixturePath = join(ROOT, fixtureRel);
  cpSync(fixturePath, join(dir, "secrets.json"));

  // Initialize a git repo so `act push` works.
  const sh = (args: string[]) =>
    spawnSync("git", args, { cwd: dir, encoding: "utf8" });
  sh(["init", "-b", "main"]);
  sh(["config", "user.email", "test@example.com"]);
  sh(["config", "user.name", "Test"]);
  sh(["add", "."]);
  sh(["commit", "-m", "fixture commit"]);

  return dir;
}

function appendDelimited(caseId: string, output: string): void {
  const banner = `\n========================================\n=== act push case: ${caseId}\n========================================\n`;
  appendFileSync(ACT_RESULT_PATH, banner + output + "\n");
}

interface ActResult {
  status: number;
  combined: string;
}

function runAct(repoDir: string): ActResult {
  // Use the same custom image declared in .actrc. --rm cleans containers up.
  const r = spawnSync("act", ["push", "--rm"], {
    cwd: repoDir,
    encoding: "utf8",
    // Generous timeout; act + container start can be slow on first pull.
    timeout: 10 * 60 * 1000,
    maxBuffer: 50 * 1024 * 1024,
  });
  return {
    status: r.status ?? -1,
    combined: `[stdout]\n${r.stdout ?? ""}\n[stderr]\n${r.stderr ?? ""}\n`,
  };
}

function parseSummary(combined: string): { expired: number; warning: number; ok: number } | null {
  const m = combined.match(/ROTATION_SUMMARY expired=(\d+) warning=(\d+) ok=(\d+)/);
  if (!m) return null;
  return {
    expired: Number(m[1]),
    warning: Number(m[2]),
    ok: Number(m[3]),
  };
}

describe("act push (end-to-end)", () => {
  // Run all three cases SEQUENTIALLY in a single test so docker / act doesn't
  // get hit by parallel invocations and so act-result.txt grows in a
  // deterministic order.
  test(
    "runs the workflow successfully on every fixture and produces expected output",
    () => {
      for (const c of CASES) {
        const repo = buildCaseRepo(c.fixture);
        const result = runAct(repo);
        appendDelimited(c.id, result.combined);

        if (result.status !== 0) {
          console.error(`act exited ${result.status} for case ${c.id}`);
          console.error(result.combined.slice(-4000));
        }

        expect(result.status).toBe(0);
        expect(result.combined).toContain("Job succeeded");

        const summary = parseSummary(result.combined);
        expect(summary).not.toBeNull();
        expect(summary).toEqual(c.expected);

        for (const fragment of c.expectedMarkdownContains) {
          expect(result.combined).toContain(fragment);
        }
        for (const fragment of c.expectedJsonContains) {
          expect(result.combined).toContain(fragment);
        }
      }
    },
    30 * 60 * 1000,
  );

  test("act-result.txt exists and contains all three case banners", () => {
    expect(existsSync(ACT_RESULT_PATH)).toBe(true);
    const contents = readFileSync(ACT_RESULT_PATH, "utf8");
    for (const c of CASES) {
      expect(contents).toContain(`=== act push case: ${c.id}`);
    }
  });
});
