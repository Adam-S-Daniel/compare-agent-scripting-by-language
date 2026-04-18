// End-to-end: every test case runs through `act push` against a freshly
// built temp git repo. Act output is appended to act-result.txt in the
// project root. Each case asserts exact license-summary counts.
import { describe, test, expect, beforeAll } from "bun:test";
import {
  mkdtempSync,
  mkdirSync,
  writeFileSync,
  cpSync,
  appendFileSync,
  existsSync,
  rmSync,
} from "node:fs";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const projectRoot = resolve(import.meta.dir, "..");
const actResultFile = join(projectRoot, "act-result.txt");

interface TestCase {
  name: string;
  dependencies: Record<string, string>;
  licenses: Record<string, string>;
  expected: {
    total: number;
    approved: number;
    denied: number;
    unknown: number;
  };
}

const policy = {
  allow: ["MIT", "Apache-2.0", "BSD-3-Clause", "ISC"],
  deny: ["GPL-3.0", "AGPL-3.0"],
};

const cases: TestCase[] = [
  {
    name: "all-approved",
    dependencies: { lodash: "^4.17.0", express: "4.18.0" },
    licenses: { lodash: "MIT", express: "MIT" },
    expected: { total: 2, approved: 2, denied: 0, unknown: 0 },
  },
  {
    name: "has-denied",
    dependencies: { lodash: "^4.17.0", "bad-pkg": "1.0.0" },
    licenses: { lodash: "MIT", "bad-pkg": "GPL-3.0" },
    expected: { total: 2, approved: 1, denied: 1, unknown: 0 },
  },
  {
    name: "has-unknown",
    dependencies: { lodash: "^4.17.0", mystery: "0.1.0" },
    licenses: { lodash: "MIT", mystery: "WTFPL" },
    expected: { total: 2, approved: 1, denied: 0, unknown: 1 },
  },
];

// Build a throwaway git repo, drop the project source in, then write
// the test case's fixture data under test-case/ where the workflow
// expects it.
function buildRepo(tc: TestCase): string {
  const dir = mkdtempSync(join(tmpdir(), `license-check-${tc.name}-`));
  // Copy source files the workflow needs.
  for (const entry of [
    "src",
    "tests",
    "package.json",
    ".actrc",
    ".github",
  ]) {
    cpSync(join(projectRoot, entry), join(dir, entry), { recursive: true });
  }
  // Write fixture data.
  const caseDir = join(dir, "test-case");
  mkdirSync(caseDir, { recursive: true });
  writeFileSync(
    join(caseDir, "package.json"),
    JSON.stringify(
      { name: tc.name, version: "1.0.0", dependencies: tc.dependencies },
      null,
      2,
    ),
  );
  writeFileSync(join(caseDir, "policy.json"), JSON.stringify(policy, null, 2));
  writeFileSync(
    join(caseDir, "licenses.json"),
    JSON.stringify(tc.licenses, null, 2),
  );
  // act requires a git repo to compute event data.
  spawnSync("git", ["init", "-q", "-b", "main"], { cwd: dir });
  spawnSync("git", ["config", "user.email", "t@t"], { cwd: dir });
  spawnSync("git", ["config", "user.name", "t"], { cwd: dir });
  spawnSync("git", ["add", "-A"], { cwd: dir });
  spawnSync("git", ["commit", "-q", "-m", "init"], { cwd: dir });
  return dir;
}

function runAct(dir: string): { status: number; output: string } {
  const res = spawnSync("act", ["push", "--rm"], {
    cwd: dir,
    encoding: "utf8",
    env: process.env,
    // give the container plenty of time to install bun
    maxBuffer: 50 * 1024 * 1024,
  });
  const combined = (res.stdout ?? "") + "\n---STDERR---\n" + (res.stderr ?? "");
  return { status: res.status ?? -1, output: combined };
}

function extractSummary(out: string): {
  total: number;
  approved: number;
  denied: number;
  unknown: number;
} | null {
  const m = out.match(
    /LICENSE_SUMMARY total=(\d+) approved=(\d+) denied=(\d+) unknown=(\d+)/,
  );
  if (!m) return null;
  return {
    total: Number(m[1]),
    approved: Number(m[2]),
    denied: Number(m[3]),
    unknown: Number(m[4]),
  };
}

describe("workflow end-to-end via act", () => {
  beforeAll(() => {
    // Reset the artifact file at the start of the run so only this
    // session's output ends up in it.
    if (existsSync(actResultFile)) rmSync(actResultFile);
    writeFileSync(actResultFile, `act run started ${new Date().toISOString()}\n`);
  });

  for (const tc of cases) {
    test(
      `act push: ${tc.name}`,
      () => {
        const dir = buildRepo(tc);
        const { status, output } = runAct(dir);

        const delim = "\n" + "=".repeat(72) + "\n";
        appendFileSync(
          actResultFile,
          `${delim}CASE: ${tc.name}\nEXIT: ${status}\n${delim}${output}\n`,
        );

        expect(status).toBe(0);
        // Every act job should report success. "Job succeeded" appears
        // once per matrix job — we only have one.
        expect(output).toMatch(/Job succeeded/);

        const summary = extractSummary(output);
        expect(summary).not.toBeNull();
        expect(summary).toEqual(tc.expected);
      },
      300_000,
    );
  }
});
