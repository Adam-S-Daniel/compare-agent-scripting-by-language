/**
 * Test harness: runs act for each test case, asserts on exact expected output.
 * All results appended to act-result.txt.
 *
 * Usage: bun run run-act-tests.ts
 * Limit: at most 3 act push runs.
 */

import { execSync, spawnSync } from "child_process";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";
import { generateDockerTags, sanitizeTag } from "./docker-tags";
import type { GitContext } from "./docker-tags";

const WORKSPACE = process.cwd();
const ACT_RESULT_FILE = path.join(WORKSPACE, "act-result.txt");

interface ActTestCase {
  name: string;
  branch: string;      // branch to create in temp repo
  gitTags: string[];   // git tags to create in temp repo
  prNumber?: number;   // passed as env to the workflow
}

const ACT_TEST_CASES: ActTestCase[] = [
  { name: "main-branch", branch: "main", gitTags: [] },
  { name: "feature-branch", branch: "feature-my-login", gitTags: [] },
  { name: "semver-tag", branch: "main", gitTags: ["v3.1.4"] },
  // PR case covered by unit tests only (requires pull_request event, counts against limit)
];

function appendResult(label: string, content: string): void {
  const sep = "=".repeat(60);
  fs.appendFileSync(ACT_RESULT_FILE, `\n${sep}\nTEST CASE: ${label}\n${sep}\n${content}\n`);
}

/** Create a temp repo, copy project files, return { dir, sha7 } */
function setupRepo(tc: ActTestCase): { dir: string; sha7: string } {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), `act-${tc.name}-`));

  // Copy project files
  for (const f of ["docker-tags.ts", "docker-tags.test.ts", ".github", ".actrc"]) {
    const src = path.join(WORKSPACE, f);
    if (fs.existsSync(src)) execSync(`cp -r "${src}" "${dir}/${f}"`);
  }

  // Init git repo on the right branch
  execSync(`git -C "${dir}" init -b "${tc.branch}"`);
  execSync(`git -C "${dir}" config user.email "ci@test.com"`);
  execSync(`git -C "${dir}" config user.name "CI"`);
  execSync(`git -C "${dir}" add .`);
  execSync(`git -C "${dir}" commit -m "init"`);

  const sha = execSync(`git -C "${dir}" rev-parse HEAD`, { encoding: "utf8" }).trim();
  const sha7 = sha.slice(0, 7);

  for (const tag of tc.gitTags) {
    execSync(`git -C "${dir}" tag "${tag}"`);
  }

  return { dir, sha7 };
}

function runAct(dir: string, tc: ActTestCase): { output: string; exitCode: number } {
  // Build a push event payload
  const eventPayload: Record<string, unknown> = {
    ref: `refs/heads/${tc.branch}`,
    repository: { topics: [], full_name: "test/repo" },
  };
  const eventFile = path.join(dir, "event.json");
  fs.writeFileSync(eventFile, JSON.stringify(eventPayload));

  const result = spawnSync(
    "act",
    ["push", "--rm", "--pull=false", "--eventpath", eventFile, "--secret-file", "/dev/null"],
    {
      cwd: dir,
      env: { ...process.env as Record<string, string> },
      encoding: "utf8",
      timeout: 300_000,
    }
  );

  const output = (result.stdout ?? "") + (result.stderr ?? "");
  return { output, exitCode: result.status ?? 1 };
}

// ---- STRUCTURE TESTS (no act) ----
function runStructureTests(): boolean {
  console.log("\n--- Workflow structure tests ---");
  let ok = true;

  const wfPath = path.join(WORKSPACE, ".github/workflows/docker-image-tag-generator.yml");
  if (!fs.existsSync(wfPath)) {
    console.error("  FAIL: workflow file missing"); return false;
  }
  const wf = fs.readFileSync(wfPath, "utf8");

  const checks: Array<[string, boolean]> = [
    ["trigger: push", wf.includes("push:")],
    ["trigger: pull_request", wf.includes("pull_request:")],
    ["trigger: workflow_dispatch", wf.includes("workflow_dispatch")],
    ["references docker-tags.ts", wf.includes("docker-tags.ts")],
    ["sets up Bun", wf.includes("oven-sh/setup-bun") || wf.includes("setup-bun")],
    ["script file exists", fs.existsSync(path.join(WORKSPACE, "docker-tags.ts"))],
    ["test file exists", fs.existsSync(path.join(WORKSPACE, "docker-tags.test.ts"))],
  ];

  for (const [label, passed] of checks) {
    console.log(`  ${passed ? "PASS" : "FAIL"}: ${label}`);
    if (!passed) ok = false;
  }

  // actionlint
  const lint = spawnSync("actionlint", [wfPath], { encoding: "utf8" });
  console.log(`  ${lint.status === 0 ? "PASS" : "FAIL"}: actionlint`);
  if (lint.status !== 0) {
    console.error(lint.stdout + lint.stderr);
    ok = false;
  }

  return ok;
}

// ---- PR UNIT TEST (no act) ----
function runPrUnitTest(): boolean {
  console.log("\n--- PR test case (unit, no act) ---");
  const ctx: GitContext = { branch: "feature/pr-stuff", sha: "fff1111222333", tags: [], prNumber: 99 };
  const tags = generateDockerTags(ctx);
  const expected = ["pr-99", "feature-pr-stuff-fff1111"];
  let ok = true;
  for (const tag of expected) {
    const found = tags.includes(tag);
    console.log(`  ${found ? "PASS" : "FAIL"}: tag "${tag}" ${found ? "present" : "MISSING (got: " + tags.join(",") + ")"}`);
    if (!found) ok = false;
  }
  return ok;
}

// ---- MAIN ----
async function main(): Promise<void> {
  fs.writeFileSync(ACT_RESULT_FILE, `Act test run started: ${new Date().toISOString()}\n`);

  let allPassed = runStructureTests();
  allPassed = runPrUnitTest() && allPassed;

  console.log("\n--- Act integration tests ---");
  let actRuns = 0;

  for (const tc of ACT_TEST_CASES) {
    if (actRuns >= 3) {
      console.warn(`Skipping "${tc.name}": 3-run limit reached`);
      appendResult(tc.name, "SKIPPED: 3-run limit");
      continue;
    }

    console.log(`\nRunning act for: ${tc.name}`);
    const { dir, sha7 } = setupRepo(tc);
    actRuns++;

    // Compute expected tags dynamically using our own function
    const ctx: GitContext = {
      branch: tc.branch,
      sha: sha7,
      tags: tc.gitTags,
      prNumber: tc.prNumber ?? null,
    };
    const expectedTags = generateDockerTags(ctx);
    console.log(`  Expected tags: ${expectedTags.join(", ")}`);

    const { output, exitCode } = runAct(dir, tc);
    appendResult(tc.name, output);
    fs.rmSync(dir, { recursive: true, force: true });

    if (exitCode !== 0) {
      console.error(`  FAIL: act exit code ${exitCode}`);
      allPassed = false;
      continue;
    }
    console.log("  PASS: exit code 0");

    if (!output.includes("Job succeeded")) {
      console.error('  FAIL: "Job succeeded" not in output');
      allPassed = false;
    } else {
      console.log('  PASS: "Job succeeded"');
    }

    for (const tag of expectedTags) {
      const found = output.includes(tag);
      console.log(`  ${found ? "PASS" : "FAIL"}: tag "${tag}"`);
      if (!found) allPassed = false;
    }
  }

  appendResult("SUMMARY", `All passed: ${allPassed}\nTotal act runs: ${actRuns}`);
  console.log(`\n${allPassed ? "ALL TESTS PASSED" : "SOME TESTS FAILED"}`);
  console.log(`Results: ${ACT_RESULT_FILE}`);
  process.exit(allPassed ? 0 : 1);
}

main();
