// End-to-end test harness.
//
// Runs each test case through the GitHub Actions workflow via `act`, captures
// output to act-result.txt, and asserts on exact expected values. Also verifies
// workflow structure (actionlint + textual inspection of the YAML).
//
// Usage:  bun run test-harness.ts
// Requires: act, docker, actionlint on PATH.
import {
  existsSync,
  mkdtempSync,
  readFileSync,
  writeFileSync,
  cpSync,
  rmSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";

const PROJECT_ROOT = resolve(import.meta.dir);
const WORKFLOW_PATH = join(PROJECT_ROOT, ".github/workflows/dependency-license-checker.yml");
const ACT_RESULT = join(PROJECT_ROOT, "act-result.txt");

interface TestCase {
  name: string;
  manifest: string; // path relative to project root
  expected: {
    total: number;
    approved: number;
    denied: number;
    unknown: number;
    mustContain: string[];
  };
}

const CASES: TestCase[] = [
  {
    name: "all-approved",
    manifest: "fixtures/all-approved.package.json",
    expected: {
      total: 3,
      approved: 3,
      denied: 0,
      unknown: 0,
      mustContain: [
        "[APPROVED] lodash@^4.17.21 — MIT",
        "[APPROVED] express@4.18.2 — MIT",
        "[APPROVED] typescript@^5.0.0 — Apache-2.0",
      ],
    },
  },
  {
    name: "mixed",
    manifest: "fixtures/mixed.package.json",
    expected: {
      total: 4,
      approved: 1,
      denied: 1,
      unknown: 2,
      mustContain: [
        "[APPROVED] lodash@^4.17.21 — MIT",
        "[DENIED] bad-lib@1.0.0 — GPL-3.0",
        "[UNKNOWN] fancy-lib@2.0.0 — CC-BY-4.0",
        "[UNKNOWN] missing-lib@0.1.0 — N/A",
      ],
    },
  },
  {
    name: "requirements",
    manifest: "fixtures/requirements.txt",
    expected: {
      total: 3,
      approved: 3,
      denied: 0,
      unknown: 0,
      mustContain: [
        "[APPROVED] requests@2.31.0 — Apache-2.0",
        "[APPROVED] flask@2.0.0 — BSD-3-Clause",
        "[APPROVED] numpy@1.24 — BSD-3-Clause",
      ],
    },
  },
];

interface Failure {
  test: string;
  message: string;
}
const failures: Failure[] = [];

function fail(test: string, message: string): void {
  failures.push({ test, message });
  console.error(`FAIL [${test}] ${message}`);
}

function pass(test: string): void {
  console.log(`PASS [${test}]`);
}

function assert(cond: boolean, test: string, message: string): void {
  if (cond) pass(test);
  else fail(test, message);
}

// ---------- Workflow structure tests ----------

function runActionlint(): void {
  const r = spawnSync("actionlint", [WORKFLOW_PATH], { encoding: "utf8" });
  assert(
    r.status === 0,
    "actionlint",
    `actionlint exited ${r.status}: ${r.stdout}${r.stderr}`,
  );
}

function checkWorkflowStructure(): void {
  const yaml = readFileSync(WORKFLOW_PATH, "utf8");
  // Trigger sanity.
  assert(/\n\s*push:/.test(yaml), "workflow: push trigger", "missing push trigger");
  assert(
    /\n\s*pull_request:/.test(yaml),
    "workflow: pull_request trigger",
    "missing pull_request trigger",
  );
  assert(/\n\s*workflow_dispatch:/.test(yaml), "workflow: workflow_dispatch", "missing workflow_dispatch");
  assert(/\n\s*schedule:/.test(yaml), "workflow: schedule", "missing schedule");
  // Job sanity.
  assert(/\n\s*test:\s*\n/.test(yaml), "workflow: test job", "missing test job");
  assert(/\n\s*license-check:\s*\n/.test(yaml), "workflow: license-check job", "missing license-check job");
  assert(/needs:\s*test/.test(yaml), "workflow: job dependency", "license-check must need test");
  // Action + script references.
  assert(/actions\/checkout@v4/.test(yaml), "workflow: checkout@v4", "missing checkout@v4");
  assert(/bun test/.test(yaml), "workflow: runs bun test", "workflow must run bun test");
  assert(/src\/cli\.ts/.test(yaml), "workflow: references cli.ts", "workflow must reference src/cli.ts");
  // Permissions.
  assert(/permissions:\s*\n\s*contents:\s*read/.test(yaml), "workflow: read perms", "missing contents: read");
  // Referenced files must exist.
  for (const p of ["src/cli.ts", "src/checker.ts", "fixtures/license-config.json", "fixtures/mock-licenses.json"]) {
    assert(existsSync(join(PROJECT_ROOT, p)), `file exists: ${p}`, `missing file ${p}`);
  }
}

// ---------- act runner ----------

function setupTempRepo(fixtureManifestRel: string): string {
  const dir = mkdtempSync(join(tmpdir(), "dlc-act-"));
  // Copy project files needed for the workflow to run.
  for (const item of ["src", "fixtures", ".github", "package.json", "tsconfig.json", ".actrc"]) {
    const src = join(PROJECT_ROOT, item);
    if (existsSync(src)) cpSync(src, join(dir, item), { recursive: true });
  }
  // git init (act requires a git context).
  spawnSync("git", ["init", "-q", "-b", "main"], { cwd: dir });
  spawnSync("git", ["-c", "user.email=t@t", "-c", "user.name=t", "add", "."], { cwd: dir });
  spawnSync(
    "git",
    ["-c", "user.email=t@t", "-c", "user.name=t", "commit", "-q", "-m", "init"],
    { cwd: dir },
  );
  // Record the chosen manifest in an env file act will pick up.
  writeFileSync(
    join(dir, ".act.env"),
    `MANIFEST_PATH=${fixtureManifestRel}\n` +
      `CONFIG_PATH=fixtures/license-config.json\n` +
      `LICENSES_PATH=fixtures/mock-licenses.json\n`,
  );
  return dir;
}

function runActCase(tc: TestCase): { stdout: string; code: number } {
  const repo = setupTempRepo(tc.manifest);
  const args = ["push", "--rm", "--env-file", ".act.env"];
  const r = spawnSync("act", args, {
    cwd: repo,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
    timeout: 10 * 60 * 1000,
  });
  const combined = (r.stdout || "") + "\n--- STDERR ---\n" + (r.stderr || "");
  // Clean up the temp repo — keep the harness footprint small.
  try {
    rmSync(repo, { recursive: true, force: true });
  } catch {}
  return { stdout: combined, code: r.status ?? -1 };
}

function assertOutput(tc: TestCase, out: string, code: number): void {
  const ctx = `act:${tc.name}`;
  assert(code === 0, ctx + ":exit", `act exit code ${code} (want 0)`);
  // Job success line printed by act.
  assert(/Job succeeded/.test(out), ctx + ":job-succeeded", "missing 'Job succeeded' in act output");
  // Both jobs must show a success line. act prints one per job, so count.
  const successCount = (out.match(/Job succeeded/g) || []).length;
  assert(successCount >= 2, ctx + ":all-jobs-succeeded", `only ${successCount} 'Job succeeded' lines (want >=2)`);
  // Summary counts.
  assert(
    out.includes(`Total dependencies: ${tc.expected.total}`),
    ctx + ":total",
    `expected Total dependencies: ${tc.expected.total}`,
  );
  assert(
    out.includes(`Approved: ${tc.expected.approved}`),
    ctx + ":approved",
    `expected Approved: ${tc.expected.approved}`,
  );
  assert(
    out.includes(`Denied:   ${tc.expected.denied}`),
    ctx + ":denied",
    `expected Denied:   ${tc.expected.denied}`,
  );
  assert(
    out.includes(`Unknown:  ${tc.expected.unknown}`),
    ctx + ":unknown",
    `expected Unknown:  ${tc.expected.unknown}`,
  );
  // Line-level expectations.
  for (const needle of tc.expected.mustContain) {
    assert(out.includes(needle), `${ctx}:line:${needle}`, `missing expected line: ${needle}`);
  }
}

// ---------- main ----------

async function main(): Promise<void> {
  // Reset the act-result.txt artifact.
  writeFileSync(ACT_RESULT, `# act-result.txt — generated ${new Date().toISOString()}\n`);

  runActionlint();
  checkWorkflowStructure();

  for (const tc of CASES) {
    console.log(`\n=== Running act for case: ${tc.name} (${tc.manifest}) ===`);
    const { stdout, code } = runActCase(tc);
    const header = `\n\n========== CASE: ${tc.name} (manifest=${tc.manifest}) exit=${code} ==========\n`;
    const fd = require("node:fs");
    fd.appendFileSync(ACT_RESULT, header + stdout + "\n");
    assertOutput(tc, stdout, code);
  }

  console.log("\n---- SUMMARY ----");
  if (failures.length === 0) {
    console.log("All assertions passed.");
    process.exit(0);
  } else {
    console.error(`${failures.length} assertion(s) failed:`);
    for (const f of failures) console.error(`  - [${f.test}] ${f.message}`);
    process.exit(1);
  }
}

main().catch((err: Error) => {
  console.error("Harness crashed:", err);
  process.exit(1);
});
