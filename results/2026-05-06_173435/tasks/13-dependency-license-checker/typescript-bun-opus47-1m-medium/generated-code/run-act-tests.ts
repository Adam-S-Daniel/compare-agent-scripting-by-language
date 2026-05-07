// Test harness: drives every test case through the GitHub Actions workflow
// using `act push --rm`. For each case we:
//   1. Build a temp git repo seeded with the project files plus the case's
//      fixture data (manifest + license-config).
//   2. Run `act push --rm`, capturing its stdout/stderr.
//   3. Append the captured output to `act-result.txt` (cumulative artifact).
//   4. Assert exit code == 0, "Job succeeded" appears, and the rendered
//      license report matches the case's exact expected substrings.
//
// Limit: at most 3 `act push` invocations (one per case).

import { mkdtempSync, mkdirSync, cpSync, writeFileSync, rmSync, existsSync, appendFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { spawnSync } from "node:child_process";

interface FixtureFile {
  path: string;
  content: string;
}

interface TestCase {
  name: string;
  fixtures: FixtureFile[];
  // Override env vars passed to act (and thus to the workflow).
  env?: Record<string, string>;
  expectedSubstrings: string[];
  // Substrings that MUST NOT appear (negative assertion).
  forbiddenSubstrings?: string[];
}

const projectDir = import.meta.dir;
const resultFile = join(projectDir, "act-result.txt");
// Reset cumulative log at the start of the run.
writeFileSync(resultFile, "");

const PROJECT_FILES = [
  "package.json",
  "tsconfig.json",
  "checker.ts",
  "checker.test.ts",
  ".github",
  ".actrc",
];

function setupCaseRepo(tc: TestCase): string {
  const dir = mkdtempSync(join(tmpdir(), `lic-${tc.name}-`));
  // Seed with a clean copy of project files needed by the workflow.
  for (const f of PROJECT_FILES) {
    const src = join(projectDir, f);
    if (!existsSync(src)) continue;
    cpSync(src, join(dir, f), { recursive: true });
  }
  // Apply the case's fixture overrides last so they win.
  for (const fx of tc.fixtures) {
    const target = join(dir, fx.path);
    mkdirSync(join(target, ".."), { recursive: true });
    writeFileSync(target, fx.content);
  }
  // act needs a git repo to drive `push`.
  spawnSync("git", ["init", "-q", "-b", "main"], { cwd: dir });
  spawnSync("git", ["config", "user.email", "t@t"], { cwd: dir });
  spawnSync("git", ["config", "user.name", "t"], { cwd: dir });
  spawnSync("git", ["add", "-A"], { cwd: dir });
  spawnSync("git", ["commit", "-q", "-m", "fixture"], { cwd: dir });
  return dir;
}

function runAct(repoDir: string, env: Record<string, string> = {}): { code: number; out: string } {
  // --pull=false: the act image is a locally built tag (act-ubuntu-pwsh)
  // that doesn't exist in any registry; act would otherwise force-pull and fail.
  const args = ["push", "--rm", "--pull=false"];
  for (const [k, v] of Object.entries(env)) {
    args.push("--env", `${k}=${v}`);
  }
  const r = spawnSync("act", args, {
    cwd: repoDir,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
  });
  return { code: r.status ?? -1, out: (r.stdout ?? "") + (r.stderr ?? "") };
}

const allowConfig = JSON.stringify({
  allow: ["MIT", "Apache-2.0", "BSD-3-Clause"],
  deny: ["GPL-3.0", "Proprietary"],
});

const cases: TestCase[] = [
  {
    name: "all-approved-package-json",
    fixtures: [
      {
        path: "package.json",
        content: JSON.stringify({
          name: "fixture",
          module: "checker.ts",
          type: "module",
          private: true,
          devDependencies: { "@types/bun": "latest" },
          // Workflow scans these via the CLI; lookup is the embedded fixture map.
          dependencies: { lodash: "^4.17.21", react: "18.0.0" },
        }, null, 2),
      },
      { path: "license-config.json", content: allowConfig },
    ],
    expectedSubstrings: [
      "lodash@4.17.21 [MIT] => APPROVED",
      "react@18.0.0 [MIT] => APPROVED",
      // @types/bun has no license entry in the fixture map → unknown.
      "@types/bun@latest [UNKNOWN] => UNKNOWN",
      "approved=2 denied=0 unknown=1",
      "Job succeeded",
    ],
    forbiddenSubstrings: ["DENIED"],
  },
  {
    name: "denied-package-json",
    fixtures: [
      {
        path: "package.json",
        content: JSON.stringify({
          name: "fixture",
          module: "checker.ts",
          type: "module",
          private: true,
          dependencies: { lodash: "^4.17.21", "evil-pkg": "1.0.0" },
        }, null, 2),
      },
      { path: "license-config.json", content: allowConfig },
    ],
    expectedSubstrings: [
      "lodash@4.17.21 [MIT] => APPROVED",
      "evil-pkg@1.0.0 [GPL-3.0] => DENIED",
      "approved=1 denied=1 unknown=0",
      "Job succeeded",
    ],
  },
  {
    name: "requirements-txt",
    fixtures: [
      {
        path: "requirements.txt",
        content: "# fixture\nrequests==2.31.0\npandas>=2.0\nleft-pad\n",
      },
      { path: "license-config.json", content: allowConfig },
    ],
    env: { MANIFEST_PATH: "requirements.txt" },
    expectedSubstrings: [
      "requests@2.31.0 [Apache-2.0] => APPROVED",
      "pandas@2.0 [BSD-3-Clause] => APPROVED",
      "left-pad@* [WTFPL] => UNKNOWN",
      "approved=2 denied=0 unknown=1",
      "Job succeeded",
    ],
    forbiddenSubstrings: ["DENIED"],
  },
];

let failed = 0;
for (const tc of cases) {
  console.log(`\n▶ Running act case: ${tc.name}`);
  const dir = setupCaseRepo(tc);
  let code = -1;
  let out = "";
  try {
    ({ code, out } = runAct(dir, tc.env));
  } finally {
    // Always log, even on throws.
    appendFileSync(
      resultFile,
      `\n========== CASE: ${tc.name} (exit=${code}) ==========\n${out}\n`
    );
    rmSync(dir, { recursive: true, force: true });
  }

  const errors: string[] = [];
  if (code !== 0) errors.push(`act exit code was ${code}, expected 0`);
  for (const s of tc.expectedSubstrings) {
    if (!out.includes(s)) errors.push(`missing expected substring: "${s}"`);
  }
  for (const s of tc.forbiddenSubstrings ?? []) {
    if (out.includes(s)) errors.push(`unexpected substring present: "${s}"`);
  }

  if (errors.length === 0) {
    console.log(`  ✓ ${tc.name}`);
  } else {
    failed += 1;
    console.log(`  ✗ ${tc.name}`);
    for (const e of errors) console.log(`     - ${e}`);
  }
}

console.log(
  `\n${failed === 0 ? "ALL ACT CASES PASSED" : `${failed} ACT CASE(S) FAILED`}`
);
process.exit(failed === 0 ? 0 : 1);
