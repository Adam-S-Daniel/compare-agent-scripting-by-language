// Integration harness: every test case runs through act (GitHub Actions).
// For each case, we rewrite fixtures/rules.json + default FILES_JSON in the
// workflow, commit to a temp git repo, invoke `act push --rm`, and assert the
// LABELS= line in the output matches the expected value exactly.

import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { mkdtempSync, rmSync, mkdirSync, cpSync, writeFileSync, appendFileSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const PROJECT_ROOT = join(import.meta.dir, "..");
const ACT_RESULT = join(PROJECT_ROOT, "act-result.txt");

interface Case {
  name: string;
  filesJson: string;
  expectedLabels: string[];
  rules?: unknown;
}

const defaultRules = [
  { pattern: "docs/**", label: "documentation" },
  { pattern: "src/api/**", label: "api", priority: 10 },
  { pattern: "src/**", label: "source" },
  { pattern: "**/*.test.*", label: "tests", priority: 5 },
  { pattern: "*.md", label: "documentation" },
  { pattern: ".github/**", label: "ci" },
];

const cases: Case[] = [
  {
    name: "docs-and-api",
    filesJson: JSON.stringify(["src/api/users.ts", "docs/readme.md"]),
    expectedLabels: ["api", "source", "documentation"],
  },
  {
    name: "test-files",
    filesJson: JSON.stringify(["src/foo.test.ts", "src/bar.ts"]),
    expectedLabels: ["tests", "source"],
  },
  {
    name: "no-matches",
    filesJson: JSON.stringify(["random.xyz", "another.unknown"]),
    expectedLabels: [],
  },
];

function sh(cmd: string, args: string[], cwd: string, timeoutMs = 300_000) {
  return spawnSync(cmd, args, { cwd, encoding: "utf8", timeout: timeoutMs });
}

function setupRepo(caseDef: Case): string {
  const tmp = mkdtempSync(join(tmpdir(), "pr-label-"));
  // copy project files (excluding .git, node_modules, act-result.txt)
  const skip = new Set([".git", "node_modules", "act-result.txt"]);
  cpSync(PROJECT_ROOT, tmp, {
    recursive: true,
    filter: (src) => {
      const name = src.split("/").pop() || "";
      return !skip.has(name);
    },
  });

  // overwrite rules fixture with this case's rules (or default)
  writeFileSync(
    join(tmp, "fixtures/rules.json"),
    JSON.stringify(caseDef.rules ?? defaultRules, null, 2),
  );

  // rewrite the workflow so FILES_JSON default contains this case's input.
  // Using a YAML literal avoids any shell escaping.
  const wf = `name: PR Label Assigner
on:
  push:
permissions:
  contents: read
jobs:
  unit-tests:
    name: Unit tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: oven-sh/setup-bun@v2
        with:
          bun-version: latest
      - run: bun test src/
  assign-labels:
    name: Assign labels
    runs-on: ubuntu-latest
    needs: unit-tests
    steps:
      - uses: actions/checkout@v4
      - uses: oven-sh/setup-bun@v2
        with:
          bun-version: latest
      - name: Run label assigner
        run: bun run src/cli.ts --rules fixtures/rules.json --files-json '${caseDef.filesJson.replace(/'/g, "'\\''")}'
`;
  mkdirSync(join(tmp, ".github/workflows"), { recursive: true });
  writeFileSync(join(tmp, ".github/workflows/pr-label-assigner.yml"), wf);

  // init git
  sh("git", ["init", "-q", "-b", "main"], tmp);
  sh("git", ["config", "user.email", "t@t"], tmp);
  sh("git", ["config", "user.name", "t"], tmp);
  sh("git", ["add", "-A"], tmp);
  sh("git", ["commit", "-q", "-m", "init"], tmp);
  return tmp;
}

beforeAll(() => {
  // Reset act-result.txt
  writeFileSync(ACT_RESULT, "");
});

describe("act integration", () => {
  for (const c of cases) {
    test(`case: ${c.name}`, () => {
      const repo = setupRepo(c);
      try {
        const res = sh("act", ["push", "--rm", "--pull=false"], repo, 600_000);
        const combined = (res.stdout ?? "") + "\n---STDERR---\n" + (res.stderr ?? "");

        appendFileSync(
          ACT_RESULT,
          `\n===== CASE: ${c.name} =====\nexit=${res.status}\n${combined}\n`,
        );

        expect(res.status).toBe(0);
        // Both jobs succeeded
        const succeededCount = (combined.match(/Job succeeded/g) ?? []).length;
        expect(succeededCount).toBeGreaterThanOrEqual(2);

        // Extract LABELS= line from the output and compare exactly
        const m = combined.match(/LABELS=(\[.*\])/);
        expect(m).not.toBeNull();
        const actual = JSON.parse(m![1]!);
        expect(actual).toEqual(c.expectedLabels);
      } finally {
        rmSync(repo, { recursive: true, force: true });
      }
    }, 600_000);
  }
});

afterAll(() => {
  // Sanity: act-result.txt must exist and be non-empty
  if (!existsSync(ACT_RESULT)) {
    throw new Error("act-result.txt was not created");
  }
});
