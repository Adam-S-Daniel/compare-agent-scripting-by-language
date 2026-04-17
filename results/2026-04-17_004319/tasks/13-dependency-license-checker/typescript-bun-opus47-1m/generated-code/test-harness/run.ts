#!/usr/bin/env bun
// Act-driven test harness.
//
// For each test case:
//   1. Build a fresh temp git repo containing this project PLUS the
//      case-specific fixture files (package.json, policy.json, licenses.json).
//   2. Run `act push --rm`, capture stdout+stderr, append to act-result.txt.
//   3. Assert act exit code is 0, every job ended with "Job succeeded",
//      and the ASSERT: lines the workflow prints match the expected values
//      exactly (approved/denied/unknown/total/exit).
//
// Total act runs: one per case. We keep the case list tight (3 cases) to
// respect the "at most 3 act push runs" budget from the task spec.

import { spawn, spawnSync } from "node:child_process";
import { mkdtempSync, cpSync, rmSync, writeFileSync, readFileSync, existsSync, appendFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const projectRoot = dirname(fileURLToPath(import.meta.url)) + "/..";
const actResultFile = join(projectRoot, "act-result.txt");

// Reset the output artifact at the start of a fresh run.
if (existsSync(actResultFile)) rmSync(actResultFile);
writeFileSync(actResultFile, `# act-result.txt — generated ${new Date().toISOString()}\n\n`);

interface TestCase {
  name: string;
  description: string;
  manifest: object;
  policy: object;
  licenses: object;
  expect: {
    approved: number;
    denied: number;
    unknown: number;
    total: number;
    exit: number;
  };
}

// Three cases exercise the three possible outcomes: all-approved,
// mixed-with-denied, and all-unknown. Together they hit every status
// branch and both exit-code branches (0 and 2).
const CASES: TestCase[] = [
  {
    name: "all-approved",
    description: "Every dep has a license on the allow list; exit code 0.",
    manifest: {
      name: "app-green",
      version: "1.0.0",
      dependencies: { "lodash": "^4.17.21", "chalk": "~5.3.0" },
    },
    policy: { allow: ["MIT", "Apache-2.0"], deny: ["GPL-3.0"] },
    licenses: { "lodash": "MIT", "chalk": "MIT" },
    expect: { approved: 2, denied: 0, unknown: 0, total: 2, exit: 0 },
  },
  {
    name: "mixed-with-denied",
    description: "One approved, one denied, one unknown; exit code 2.",
    manifest: {
      name: "app-mixed",
      version: "1.0.0",
      dependencies: { "lodash": "^4.17.21", "evil-gpl": "1.0.0" },
      devDependencies: { "mystery-unknown": "0.1.0" },
    },
    policy: { allow: ["MIT"], deny: ["GPL-3.0"] },
    licenses: { "lodash": "MIT", "evil-gpl": "GPL-3.0" }, // mystery omitted
    expect: { approved: 1, denied: 1, unknown: 1, total: 3, exit: 2 },
  },
  {
    name: "all-unknown",
    description: "No dep's license is on the allow list; all marked unknown; exit 0.",
    manifest: {
      name: "app-unknown",
      version: "1.0.0",
      dependencies: { "foo": "1.0.0", "bar": "2.0.0" },
    },
    // Policy with an empty allow list — still valid, but nothing can be approved.
    policy: { allow: [], deny: ["GPL-3.0"] },
    licenses: { "foo": "ISC", "bar": "WTFPL" },
    expect: { approved: 0, denied: 0, unknown: 2, total: 2, exit: 0 },
  },
];

// Items to copy from the project root into each temp workspace.
// We skip node_modules, .git, and prior artifacts to keep the copy small.
const COPY_ENTRIES = [
  "src",
  "tests",                 // included so `bun test` inside the job still works
  ".github",
  ".actrc",
  "package.json",
  "tsconfig.json",
  "bun.lockb",
  "bun.lock",
];

function buildTempRepo(tc: TestCase): string {
  const tmp = mkdtempSync(join(tmpdir(), `licchk-act-${tc.name}-`));
  for (const entry of COPY_ENTRIES) {
    const src = join(projectRoot, entry);
    if (!existsSync(src)) continue;
    cpSync(src, join(tmp, entry), { recursive: true });
  }
  // Write case-specific fixtures, overwriting the defaults we copied.
  const fixtureDir = join(tmp, "fixtures");
  cpSync(join(projectRoot, "fixtures"), fixtureDir, { recursive: true });
  writeFileSync(join(fixtureDir, "package.json"), JSON.stringify(tc.manifest, null, 2));
  writeFileSync(join(fixtureDir, "policy.json"), JSON.stringify(tc.policy, null, 2));
  writeFileSync(join(fixtureDir, "licenses.json"), JSON.stringify(tc.licenses, null, 2));

  // act push requires a git repo with at least one commit.
  const run = (cmd: string, args: string[]) => {
    const r = spawnSync(cmd, args, { cwd: tmp, stdio: "pipe", encoding: "utf8" });
    if (r.status !== 0) {
      throw new Error(`${cmd} ${args.join(" ")} failed: ${r.stderr || r.stdout}`);
    }
  };
  run("git", ["init", "-q", "-b", "main"]);
  run("git", ["config", "user.email", "harness@example.invalid"]);
  run("git", ["config", "user.name", "Harness"]);
  run("git", ["add", "-A"]);
  run("git", ["commit", "-q", "-m", `fixture: ${tc.name}`]);
  return tmp;
}

function runAct(cwd: string): Promise<{ code: number; output: string }> {
  return new Promise((resolve) => {
    // --pull=false avoids a forced `docker pull` of the custom
    // act-ubuntu-pwsh image, which only exists locally and is not
    // reachable from Docker Hub. Without it, act fails at "Set up job".
    const child = spawn("act", ["push", "--rm", "--pull=false"], { cwd, env: process.env });
    let out = "";
    child.stdout.on("data", (d) => { out += d.toString(); });
    child.stderr.on("data", (d) => { out += d.toString(); });
    child.on("close", (code) => resolve({ code: code ?? -1, output: out }));
  });
}

interface Failure { case: string; reason: string; }

function assertCase(tc: TestCase, actCode: number, output: string): Failure[] {
  const failures: Failure[] = [];
  if (actCode !== 0) {
    failures.push({ case: tc.name, reason: `act exited ${actCode}, expected 0` });
  }
  if (!/Job succeeded/.test(output)) {
    failures.push({ case: tc.name, reason: `no "Job succeeded" marker in act output` });
  }
  // Each ASSERT line is: ASSERT:<key>=<value>. act prefixes lines
  // with container/step metadata so we grep for the pattern anywhere on the line.
  const keys: Array<keyof TestCase["expect"]> = ["approved", "denied", "unknown", "total", "exit"];
  for (const key of keys) {
    const expected = String(tc.expect[key]);
    const re = new RegExp(`ASSERT:${key}=${expected}(?!\\d)`);
    if (!re.test(output)) {
      // Include the actual value we saw (if any) for a helpful diagnostic.
      const seen = output.match(new RegExp(`ASSERT:${key}=(\\S+)`));
      const seenVal = seen ? seen[1] : "<missing>";
      failures.push({
        case: tc.name,
        reason: `${key}: expected ${expected}, got ${seenVal}`,
      });
    }
  }
  return failures;
}

function delimiter(title: string, char = "="): string {
  const bar = char.repeat(72);
  return `\n${bar}\n${title}\n${bar}\n`;
}

async function main(): Promise<number> {
  // Optional case filter so we can verify one case without burning a
  // full 3x act-run cycle. Usage: `bun run test-harness/run.ts <name>`.
  const filter = process.argv[2];
  const selected = filter ? CASES.filter((c) => c.name === filter) : CASES;
  if (filter && selected.length === 0) {
    console.error(`[harness] no case matches filter: ${filter}`);
    return 1;
  }
  const allFailures: Failure[] = [];
  for (const tc of selected) {
    console.log(`\n[harness] running case: ${tc.name} — ${tc.description}`);
    const tmp = buildTempRepo(tc);
    try {
      const { code, output } = await runAct(tmp);
      appendFileSync(actResultFile, delimiter(`CASE: ${tc.name}  (act exit=${code})`));
      appendFileSync(actResultFile, output);
      appendFileSync(actResultFile, delimiter(`END CASE: ${tc.name}`, "-"));
      const failures = assertCase(tc, code, output);
      if (failures.length === 0) {
        console.log(`[harness] PASS: ${tc.name}`);
      } else {
        console.log(`[harness] FAIL: ${tc.name}`);
        for (const f of failures) console.log(`  - ${f.reason}`);
      }
      allFailures.push(...failures);
    } finally {
      // Keep the temp repo if an assertion failed, so the user can inspect;
      // clean otherwise.
      if (allFailures.filter((f) => f.case === tc.name).length === 0) {
        rmSync(tmp, { recursive: true, force: true });
      } else {
        console.log(`[harness] (kept temp repo for inspection: ${tmp})`);
      }
    }
  }

  // Summary block at the bottom of the artifact.
  const summary = allFailures.length === 0
    ? `ALL ${selected.length} CASES PASSED`
    : `FAILURES:\n${allFailures.map((f) => `  ${f.case}: ${f.reason}`).join("\n")}`;
  appendFileSync(actResultFile, delimiter("HARNESS SUMMARY"));
  appendFileSync(actResultFile, summary + "\n");

  console.log(`\n[harness] artifact written to: ${actResultFile}`);
  if (allFailures.length > 0) {
    console.log(`[harness] ${allFailures.length} assertion(s) failed`);
    return 1;
  }
  console.log(`[harness] all ${selected.length} cases passed`);
  return 0;
}

// Verify act + git are available up front so we fail fast.
for (const tool of ["act", "git"]) {
  const r = spawnSync(tool, ["--version"], { encoding: "utf8" });
  if (r.status !== 0) {
    console.error(`[harness] required tool not found on PATH: ${tool}`);
    process.exit(127);
  }
}

// Sanity-check that the workflow pipes through the ASSERT-emitting helper.
// We reference its filename rather than the literal ASSERT: string since
// the actual ASSERT lines come from that helper at runtime.
const workflow = readFileSync(join(projectRoot, ".github/workflows/dependency-license-checker.yml"), "utf8");
if (!workflow.includes("summaryAsserts.ts")) {
  console.error("[harness] workflow does not invoke summaryAsserts.ts — refusing to run.");
  process.exit(1);
}

const rc = await main();
process.exit(rc);
