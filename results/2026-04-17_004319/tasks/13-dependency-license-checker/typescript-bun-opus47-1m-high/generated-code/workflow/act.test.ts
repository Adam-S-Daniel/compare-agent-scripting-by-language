// End-to-end test harness: runs the GitHub Actions workflow in act for
// three fixture variants. Each case overrides `fixtures/manifest.json`
// and `fixtures/policy.json` with known-good inputs, runs `act push --rm`,
// and asserts on exact strings in the captured output. All act output is
// appended to act-result.txt at the repo root.
//
// We copy the project into a temp directory so each case gets a clean git
// repository — act requires the working directory to be a git repo. Only
// one `act push` invocation per case (no retries) to stay within the 3-run
// budget.

import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { cpSync, existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const repoRoot = join(import.meta.dir, "..");
const actResultPath = join(repoRoot, "act-result.txt");

interface TestCase {
  name: string;
  manifest: object;
  policy: object;
  // Exact substrings that must appear in the stdout+stderr capture.
  expect: string[];
}

const cases: TestCase[] = [
  {
    name: "all-approved",
    manifest: {
      name: "demo",
      version: "1.0.0",
      dependencies: { lodash: "4.17.21" },
    },
    policy: {
      allow: ["MIT"],
      deny: ["GPL-3.0"],
      licenses: { lodash: "MIT" },
    },
    expect: [
      "Total dependencies: 1",
      "Approved: 1",
      "Denied: 0",
      "Unknown: 0",
      "| lodash | 4.17.21 | MIT | approved |",
      "Job succeeded",
    ],
  },
  {
    name: "mixed",
    manifest: {
      name: "demo",
      version: "1.0.0",
      dependencies: { lodash: "4.17.21", "bad-pkg": "2.0.0" },
      devDependencies: { "mystery-pkg": "3.0.0" },
    },
    policy: {
      allow: ["MIT"],
      deny: ["GPL-3.0"],
      licenses: { lodash: "MIT", "bad-pkg": "GPL-3.0" },
    },
    expect: [
      "Total dependencies: 3",
      "Approved: 1",
      "Denied: 1",
      "Unknown: 1",
      "| lodash | 4.17.21 | MIT | approved |",
      "| bad-pkg | 2.0.0 | GPL-3.0 | denied |",
      "| mystery-pkg | 3.0.0 | UNKNOWN | unknown |",
      "Job succeeded",
    ],
  },
  {
    name: "empty-manifest",
    manifest: { name: "empty", version: "0.0.1" },
    policy: { allow: ["MIT"], deny: ["GPL-3.0"], licenses: {} },
    expect: [
      "Total dependencies: 0",
      "Approved: 0",
      "Denied: 0",
      "Unknown: 0",
      "No dependencies found.",
      "Job succeeded",
    ],
  },
];

// Prepare a temp directory by copying the whole project (minus noise)
// and writing the test-case fixtures on top.
function prepareCaseDir(tc: TestCase): string {
  const dir = mkdtempSync(join(tmpdir(), `license-act-${tc.name}-`));
  cpSync(repoRoot, dir, {
    recursive: true,
    filter: (src) => {
      const rel = src.slice(repoRoot.length);
      // Skip anything that would bloat the copy or collide with a fresh
      // git history — we'll `git init` a new repo in the temp dir.
      if (rel.includes("/node_modules")) return false;
      if (rel.includes("/.git/")) return false;
      if (rel === "/.git") return false;
      if (rel === "/act-result.txt") return false;
      return true;
    },
  });
  writeFileSync(join(dir, "fixtures/manifest.json"), JSON.stringify(tc.manifest, null, 2));
  writeFileSync(join(dir, "fixtures/policy.json"), JSON.stringify(tc.policy, null, 2));
  // act requires a git repo in the working directory.
  const gitInit = spawnSync("bash", [
    "-c",
    [
      "git init -q -b main",
      "git -c user.email=t@t -c user.name=t add -A",
      "git -c user.email=t@t -c user.name=t commit -q -m seed",
    ].join(" && "),
  ], { cwd: dir, encoding: "utf8" });
  if (gitInit.status !== 0) {
    throw new Error(`git init failed: ${gitInit.stderr}`);
  }
  return dir;
}

function runAct(dir: string): { output: string; exitCode: number } {
  const r = spawnSync(
    "act",
    [
      "push",
      "--rm",
      // Use the locally-built act-ubuntu-pwsh image — don't try to pull
      // from Docker Hub where it doesn't exist.
      "--pull=false",
      "-P",
      "ubuntu-latest=act-ubuntu-pwsh:latest",
      "-W",
      ".github/workflows/dependency-license-checker.yml",
    ],
    { cwd: dir, encoding: "utf8", maxBuffer: 50 * 1024 * 1024 },
  );
  const output = (r.stdout ?? "") + (r.stderr ?? "");
  return { output, exitCode: r.status ?? -1 };
}

const dirs: string[] = [];

beforeAll(() => {
  // Truncate any prior result file so this run's output is self-contained.
  writeFileSync(actResultPath, "");
});

afterAll(() => {
  for (const d of dirs) rmSync(d, { recursive: true, force: true });
});

describe("workflow runs successfully via act for each fixture case", () => {
  for (const tc of cases) {
    test(
      `case: ${tc.name}`,
      () => {
        const dir = prepareCaseDir(tc);
        dirs.push(dir);
        const { output, exitCode } = runAct(dir);

        // Append the case's output to act-result.txt with a clear header.
        const banner = `\n========== CASE: ${tc.name} (exit=${exitCode}) ==========\n`;
        const existing = existsSync(actResultPath) ? readFileSync(actResultPath, "utf8") : "";
        writeFileSync(actResultPath, existing + banner + output + "\n");

        expect(exitCode).toBe(0);
        for (const needle of tc.expect) {
          expect(output).toContain(needle);
        }
      },
      // act can easily take a minute or two per case; give it room.
      10 * 60 * 1000,
    );
  }
});
