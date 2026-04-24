// act-harness.ts
// --------------
// Runs every test case end-to-end through the real GitHub Actions workflow
// via `act push --rm`. For each case it:
//   1. creates a throwaway copy of this project in a tmp dir
//   2. initialises a git repo (act needs one)
//   3. writes an env file that overrides START_VERSION/FIXTURE/EXPECTED_*
//   4. runs `act push --rm` with that env file
//   5. appends the raw act output to act-result.txt (with a clear delimiter)
//   6. asserts on exit code, expected-value lines, and "Job succeeded"
//
// Run with: bun run act-harness.ts
//
// Limits itself to exactly 3 act invocations per the task constraints.

import { spawnSync } from "node:child_process";
import { cpSync, existsSync, mkdtempSync, rmSync, writeFileSync, appendFileSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

interface TestCase {
  name: string;
  startVersion: string;
  fixture: string;
  expectedVersion: string;
  expectedBump: "major" | "minor" | "patch" | "none";
}

const CASES: TestCase[] = [
  {
    name: "feat-commit-minor-bump",
    startVersion: "1.1.0",
    fixture: "fixtures/minor.txt",
    expectedVersion: "1.2.0",
    expectedBump: "minor",
  },
  {
    name: "fix-commit-patch-bump",
    startVersion: "1.0.0",
    fixture: "fixtures/patch.txt",
    expectedVersion: "1.0.1",
    expectedBump: "patch",
  },
  {
    name: "breaking-change-major-bump",
    startVersion: "1.4.7",
    fixture: "fixtures/major.txt",
    expectedVersion: "2.0.0",
    expectedBump: "major",
  },
];

const PROJECT_ROOT = resolve(import.meta.dir);
const RESULT_FILE = join(PROJECT_ROOT, "act-result.txt");

function sh(cmd: string, args: string[], cwd: string) {
  // Inherit stdio off so we can capture output; we echo ourselves.
  const r = spawnSync(cmd, args, { cwd, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
  return r;
}

function setupTempRepo(tc: TestCase): string {
  const dir = mkdtempSync(join(tmpdir(), `svb-act-${tc.name}-`));
  // Copy the entire project (excluding node_modules for speed; bun install re-runs inside act).
  // cpSync with filter keeps the tree tidy.
  cpSync(PROJECT_ROOT, dir, {
    recursive: true,
    filter: (src) => {
      const rel = src.slice(PROJECT_ROOT.length);
      if (rel.includes("/node_modules")) return false;
      if (rel.endsWith("/.git") || rel.includes("/.git/")) return false;
      if (rel.endsWith("act-result.txt")) return false;
      return true;
    },
  });

  // Seed a starting package.json.  The workflow overwrites this anyway but
  // having a valid file makes git happy.
  writeFileSync(
    join(dir, "package.json"),
    JSON.stringify({ name: "svb-under-test", version: tc.startVersion }, null, 2) + "\n"
  );

  // act needs a git repo to understand "push". Minimal init is enough.
  const runs: Array<{ cmd: string; args: string[] }> = [
    { cmd: "git", args: ["init", "-q", "-b", "main"] },
    { cmd: "git", args: ["config", "user.email", "harness@example.com"] },
    { cmd: "git", args: ["config", "user.name", "harness"] },
    { cmd: "git", args: ["config", "commit.gpgsign", "false"] },
    { cmd: "git", args: ["add", "-A"] },
    { cmd: "git", args: ["commit", "-q", "-m", "seed"] },
  ];
  for (const r of runs) {
    const out = sh(r.cmd, r.args, dir);
    if (out.status !== 0) {
      throw new Error(`git setup failed (${r.cmd} ${r.args.join(" ")}): ${out.stderr}`);
    }
  }

  // Env file consumed by act via --env-file. These override the values
  // baked into the workflow's `env:` block.
  const envLines = [
    `START_VERSION=${tc.startVersion}`,
    `FIXTURE=${tc.fixture}`,
    `EXPECTED_VERSION=${tc.expectedVersion}`,
    `EXPECTED_BUMP=${tc.expectedBump}`,
  ];
  writeFileSync(join(dir, ".act.env"), envLines.join("\n") + "\n");
  return dir;
}

function runOneCase(tc: TestCase, caseIndex: number): { ok: boolean; failures: string[] } {
  console.log(`\n=== case ${caseIndex + 1}/${CASES.length}: ${tc.name} ===`);
  const dir = setupTempRepo(tc);
  try {
    const args = [
      "push",
      "--rm",
      // Use the image already loaded in the local Docker daemon.
      // .actrc selects `act-ubuntu-pwsh:latest` which exists locally but
      // isn't in any registry; without --pull=false act errors out on
      // "pull access denied".
      "--pull=false",
      "--env-file",
      ".act.env",
      "-W",
      ".github/workflows/semantic-version-bumper.yml",
    ];
    console.log(`running: act ${args.join(" ")} (cwd=${dir})`);
    const r = spawnSync("act", args, { cwd: dir, encoding: "utf8" });
    const stdout = r.stdout ?? "";
    const stderr = r.stderr ?? "";
    const combined = stdout + (stderr ? "\n[stderr]\n" + stderr : "");

    // Append to act-result.txt with clear delimiter.
    const delimiter = [
      "",
      "================================================================",
      `CASE: ${tc.name}`,
      `EXPECTED_VERSION=${tc.expectedVersion}  EXPECTED_BUMP=${tc.expectedBump}`,
      `ACT_EXIT_CODE=${r.status}`,
      "================================================================",
      "",
    ].join("\n");
    appendFileSync(RESULT_FILE, delimiter + combined + "\n");

    const failures: string[] = [];

    if (r.status !== 0) failures.push(`act exited ${r.status}, expected 0`);

    // Workflow echoes "RESULT_OK NEW_VERSION=... BUMP_TYPE=..." when assertions pass.
    const okLine = `RESULT_OK NEW_VERSION=${tc.expectedVersion} BUMP_TYPE=${tc.expectedBump}`;
    if (!combined.includes(okLine)) {
      failures.push(`missing expected line: '${okLine}'`);
    }

    // Assert exact NEW_VERSION appears in output.
    const newVerLine = `NEW_VERSION=${tc.expectedVersion}`;
    if (!combined.includes(newVerLine)) {
      failures.push(`missing output line: '${newVerLine}'`);
    }
    const bumpLine = `BUMP_TYPE=${tc.expectedBump}`;
    if (!combined.includes(bumpLine)) {
      failures.push(`missing output line: '${bumpLine}'`);
    }

    // "Job succeeded" confirmation from act.
    if (!combined.includes("Job succeeded")) {
      failures.push("act did not report 'Job succeeded'");
    }

    if (failures.length === 0) {
      console.log(`PASS: ${tc.name}`);
      return { ok: true, failures: [] };
    }
    console.error(`FAIL: ${tc.name}`);
    for (const f of failures) console.error(`  - ${f}`);
    return { ok: false, failures };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

function main(): void {
  if (!existsSync(join(PROJECT_ROOT, ".github/workflows/semantic-version-bumper.yml"))) {
    throw new Error("workflow file not found; run from project root");
  }
  // Start fresh.
  writeFileSync(RESULT_FILE, `act harness results - ${new Date().toISOString()}\n`);

  let allOk = true;
  CASES.forEach((tc, i) => {
    const r = runOneCase(tc, i);
    if (!r.ok) allOk = false;
  });

  // Final summary appended to the results file for a reviewer's convenience.
  const summary = allOk
    ? `\n=== SUMMARY: ALL ${CASES.length} CASES PASSED ===\n`
    : `\n=== SUMMARY: FAILURES — see above ===\n`;
  appendFileSync(RESULT_FILE, summary);

  console.log(summary);
  console.log(`raw output written to ${RESULT_FILE} (${readFileSync(RESULT_FILE, "utf8").length} bytes)`);
  if (!allOk) process.exit(1);
}

main();
