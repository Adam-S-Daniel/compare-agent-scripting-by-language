// End-to-end workflow tests via `act`. Each case sets up an isolated temp git
// repo with the project files plus per-case fixtures, then runs `act push`
// inside it. Output is appended to act-result.txt with delimiters; assertions
// verify exact expected values, not just that "something" was printed.
//
// Structure tests (parsing the YAML, running actionlint) run inline first so
// failures are fast and don't waste a 30–90s `act` invocation.
import { describe, expect, test, beforeAll } from "bun:test";
import { mkdtempSync, mkdirSync, writeFileSync, cpSync, rmSync, existsSync, appendFileSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";

const projectRoot = new URL("..", import.meta.url).pathname.replace(/\/$/, "");
const workflowPath = join(projectRoot, ".github/workflows/dependency-license-checker.yml");
const actResultPath = join(projectRoot, "act-result.txt");

// Reset the act-result file once before any case runs so reruns start fresh.
beforeAll(() => {
  writeFileSync(actResultPath, `# act-result.txt — generated ${new Date().toISOString()}\n\n`);
});

describe("workflow structure", () => {
  const yaml = readFileSync(workflowPath, "utf8");

  test("file exists and is non-empty", () => {
    expect(yaml.length).toBeGreaterThan(0);
  });

  test("declares the expected triggers", () => {
    expect(yaml).toMatch(/^on:/m);
    expect(yaml).toContain("push:");
    expect(yaml).toContain("pull_request:");
    expect(yaml).toContain("workflow_dispatch:");
    expect(yaml).toContain("schedule:");
  });

  test("references actions/checkout@v4 and actions/upload-artifact@v4", () => {
    expect(yaml).toContain("actions/checkout@v4");
    expect(yaml).toContain("actions/upload-artifact@v4");
  });

  test("references the script that exists in this repo", () => {
    expect(yaml).toContain("src/cli.ts");
    expect(existsSync(join(projectRoot, "src/cli.ts"))).toBe(true);
  });

  test("declares restrictive permissions", () => {
    expect(yaml).toContain("contents: read");
  });

  test("actionlint passes", () => {
    const proc = Bun.spawnSync(["actionlint", workflowPath]);
    expect(proc.exitCode).toBe(0);
  });
});

// --- act test harness -----------------------------------------------------

interface ActCase {
  name: string;
  packageJson: object;
  policy: object;
  licenses: Record<string, string | null>;
  allowViolations: boolean;
  expectedExitCode: string;
  expectedSummary: string;
  expectedLines: string[];
}

const cases: ActCase[] = [
  {
    name: "mixed-licenses",
    packageJson: {
      name: "demo",
      dependencies: { "left-pad": "1.3.0", "evil-lib": "2.0.0", "mystery-pkg": "0.1.0" },
      devDependencies: { "test-utils": "5.0.0" },
    },
    policy: { allow: ["MIT", "Apache-2.0", "BSD-3-Clause"], deny: ["GPL-3.0", "AGPL-3.0"] },
    licenses: { "left-pad": "MIT", "evil-lib": "GPL-3.0", "mystery-pkg": null, "test-utils": "Apache-2.0" },
    allowViolations: true,
    expectedExitCode: "1",
    expectedSummary: "total=4 approved=2 denied=1 unknown=1",
    expectedLines: [
      "APPROVED left-pad@1.3.0  license=MIT",
      "DENIED   evil-lib@2.0.0  license=GPL-3.0",
      "UNKNOWN  mystery-pkg@0.1.0  license=unknown",
      "APPROVED test-utils@5.0.0  license=Apache-2.0",
    ],
  },
  {
    name: "all-approved",
    packageJson: {
      name: "clean",
      dependencies: { "left-pad": "1.3.0", "test-utils": "5.0.0" },
    },
    policy: { allow: ["MIT", "Apache-2.0"], deny: ["GPL-3.0"] },
    licenses: { "left-pad": "MIT", "test-utils": "Apache-2.0" },
    allowViolations: false,
    expectedExitCode: "0",
    expectedSummary: "total=2 approved=2 denied=0 unknown=0",
    expectedLines: [
      "APPROVED left-pad@1.3.0  license=MIT",
      "APPROVED test-utils@5.0.0  license=Apache-2.0",
    ],
  },
  {
    name: "all-denied",
    packageJson: {
      name: "bad",
      dependencies: { "evil-lib": "2.0.0", "another-bad": "1.0.0" },
    },
    policy: { allow: ["MIT"], deny: ["GPL-3.0", "AGPL-3.0"] },
    licenses: { "evil-lib": "GPL-3.0", "another-bad": "AGPL-3.0" },
    allowViolations: true,
    expectedExitCode: "1",
    expectedSummary: "total=2 approved=0 denied=2 unknown=0",
    expectedLines: [
      "DENIED   evil-lib@2.0.0  license=GPL-3.0",
      "DENIED   another-bad@1.0.0  license=AGPL-3.0",
    ],
  },
];

// Stage the project files we need under tmp/. We deliberately exclude
// node_modules and the act-result.txt so the temp repo is small and clean.
function stageRepo(dest: string, c: ActCase) {
  for (const dir of ["src", "tests", ".github"]) {
    cpSync(join(projectRoot, dir), join(dest, dir), { recursive: true });
  }
  for (const file of ["package.json", "tsconfig.json", ".actrc"]) {
    cpSync(join(projectRoot, file), join(dest, file));
  }
  // Per-case fixtures.
  mkdirSync(join(dest, "fixtures"), { recursive: true });
  writeFileSync(join(dest, "fixtures/package.json"), JSON.stringify(c.packageJson, null, 2));
  writeFileSync(join(dest, "fixtures/policy.json"), JSON.stringify(c.policy, null, 2));
  writeFileSync(join(dest, "fixtures/licenses.json"), JSON.stringify(c.licenses, null, 2));
}

function gitInit(dir: string) {
  const opts = { cwd: dir, env: { ...process.env, GIT_AUTHOR_NAME: "act", GIT_AUTHOR_EMAIL: "act@test", GIT_COMMITTER_NAME: "act", GIT_COMMITTER_EMAIL: "act@test" } };
  for (const args of [
    ["git", "init", "-q", "-b", "main"],
    ["git", "add", "-A"],
    ["git", "-c", "user.email=act@test", "-c", "user.name=act", "commit", "-q", "-m", "init"],
  ]) {
    const r = Bun.spawnSync(args, opts);
    if (r.exitCode !== 0) throw new Error(`git failed: ${args.join(" ")}: ${new TextDecoder().decode(r.stderr)}`);
  }
}

function runAct(dir: string, allowViolations: boolean): { code: number; output: string } {
  const args = ["act", "push", "--rm"];
  if (allowViolations) args.push("--env", "ALLOW_VIOLATIONS=true");
  const proc = Bun.spawnSync(args, { cwd: dir, env: process.env });
  const output = new TextDecoder().decode(proc.stdout) + new TextDecoder().decode(proc.stderr);
  return { code: proc.exitCode ?? -1, output };
}

describe("act push", () => {
  for (const c of cases) {
    test(
      `case: ${c.name}`,
      async () => {
        const dir = mkdtempSync(join(tmpdir(), `act-${c.name}-`));
        try {
          stageRepo(dir, c);
          gitInit(dir);
          const { code, output } = runAct(dir, c.allowViolations);

          appendFileSync(
            actResultPath,
            `\n===== CASE: ${c.name} (exit=${code}) =====\n${output}\n`,
          );

          // 1. act exited 0 (job succeeded overall)
          expect(code).toBe(0);
          // 2. job-success marker
          expect(output).toMatch(/Job succeeded/);
          // 3. compliance exit code from our script
          expect(output).toContain(`compliance_exit=${c.expectedExitCode}`);
          // 4. summary line — exact counts
          expect(output).toContain(c.expectedSummary);
          // 5. each expected per-dep line appears verbatim
          for (const line of c.expectedLines) {
            expect(output).toContain(line);
          }
        } finally {
          rmSync(dir, { recursive: true, force: true });
        }
      },
      300_000,
    );
  }
});
