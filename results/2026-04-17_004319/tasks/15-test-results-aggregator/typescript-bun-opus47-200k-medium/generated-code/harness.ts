#!/usr/bin/env bun
// End-to-end harness: runs the workflow through `act` for each test case,
// appends all output to act-result.txt, and asserts exact expected values.
//
// Usage: bun run harness.ts
// Exit code is 0 iff every case passed every assertion.

import { existsSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const ROOT = import.meta.dir;
const ACT_RESULTS = join(ROOT, "act-result.txt");

interface ActCase {
  name: string;
  fixtures: Record<string, string>;
  contains: string[];
  kv: Record<string, string>;
}

const cases: ActCase[] = [
  {
    name: "no-flaky-all-pass",
    fixtures: {
      "a.xml": `<?xml version="1.0"?><testsuites><testsuite name="s" tests="2" time="1.0"><testcase classname="c" name="x" time="0.5"/><testcase classname="c" name="y" time="0.5"/></testsuite></testsuites>`,
      "b.json": JSON.stringify({
        tests: [
          { name: "c.x", status: "passed", duration: 0.4 },
          { name: "c.y", status: "passed", duration: 0.4 },
        ],
      }),
    },
    contains: ["Test Results: PASSED", "_None detected._"],
    kv: {
      AGG_PASSED: "4",
      AGG_FAILED: "0",
      AGG_SKIPPED: "0",
      AGG_TOTAL: "4",
      AGG_FLAKY: "0",
      AGG_FLAKY_NAMES: "",
    },
  },
  {
    name: "flaky-detected",
    fixtures: {
      "run1.xml": `<?xml version="1.0"?><testsuites><testsuite name="s" tests="2" time="1.0"><testcase classname="c" name="stable" time="0.1"/><testcase classname="c" name="wobble" time="0.2"><failure message="x">x</failure></testcase></testsuite></testsuites>`,
      "run2.json": JSON.stringify({
        tests: [
          { name: "c.stable", status: "passed", duration: 0.1 },
          { name: "c.wobble", status: "passed", duration: 0.2 },
        ],
      }),
    },
    contains: ["Test Results: FAILED", "Flaky Tests", "c.wobble"],
    kv: {
      AGG_PASSED: "3",
      AGG_FAILED: "1",
      AGG_SKIPPED: "0",
      AGG_TOTAL: "4",
      AGG_FLAKY: "1",
      AGG_FLAKY_NAMES: "c.wobble",
    },
  },
  {
    name: "with-skipped-and-failure",
    fixtures: {
      "only.xml": `<?xml version="1.0"?><testsuites><testsuite name="s" tests="3" time="1.0"><testcase classname="c" name="ok" time="0.1"/><testcase classname="c" name="later" time="0.0"><skipped/></testcase><testcase classname="c" name="bad" time="0.2"><failure message="x">x</failure></testcase></testsuite></testsuites>`,
    },
    contains: ["Test Results: FAILED", "Skipped | 1"],
    kv: {
      AGG_PASSED: "1",
      AGG_FAILED: "1",
      AGG_SKIPPED: "1",
      AGG_TOTAL: "3",
      AGG_FLAKY: "0",
      AGG_FLAKY_NAMES: "",
    },
  },
];

function setupRepo(repo: string): void {
  const cmd = `set -e
    cp "${ROOT}/aggregator.ts" "${ROOT}/aggregator.test.ts" "${ROOT}/cli.ts" "${ROOT}/package.json" "${ROOT}/tsconfig.json" "${repo}/"
    mkdir -p "${repo}/.github/workflows" "${repo}/fixtures"
    cp "${ROOT}/.github/workflows/test-results-aggregator.yml" "${repo}/.github/workflows/"
    [ -f "${ROOT}/bun.lock" ] && cp "${ROOT}/bun.lock" "${repo}/" || true
    [ -f "${ROOT}/.actrc" ] && cp "${ROOT}/.actrc" "${repo}/" || true
    cd "${repo}"
    git init -q
    git config user.email ci@example.com
    git config user.name ci
    git add -A
    git commit -q -m initial`;
  const r = spawnSync("bash", ["-c", cmd], { encoding: "utf8" });
  if (r.status !== 0) {
    throw new Error(`repo setup failed: ${r.stdout}\n${r.stderr}`);
  }
}

async function runCase(c: ActCase): Promise<{ pass: boolean; reasons: string[]; output: string }> {
  const repo = mkdtempSync(join(tmpdir(), `agg-${c.name}-`));
  const reasons: string[] = [];
  try {
    setupRepo(repo);
    for (const [name, body] of Object.entries(c.fixtures)) {
      await Bun.write(join(repo, "fixtures", name), body);
    }
    spawnSync("bash", ["-c", `cd "${repo}" && git add -A && git commit -q -m fixtures`], {
      encoding: "utf8",
    });

    const r = spawnSync("act", ["push", "--rm", "--pull=false"], {
      cwd: repo,
      encoding: "utf8",
      timeout: 10 * 60 * 1000,
      maxBuffer: 32 * 1024 * 1024,
    });
    const output = (r.stdout ?? "") + (r.stderr ?? "");

    if (r.status !== 0) reasons.push(`act exit code ${r.status}, expected 0`);
    if (!output.includes("Job succeeded")) reasons.push(`missing "Job succeeded"`);
    for (const s of c.contains) {
      if (!output.includes(s)) reasons.push(`output missing expected substring: ${JSON.stringify(s)}`);
    }
    for (const [k, v] of Object.entries(c.kv)) {
      const line = `${k}=${v}`;
      if (!output.includes(line)) reasons.push(`output missing exact line: ${line}`);
    }

    return { pass: reasons.length === 0, reasons, output };
  } finally {
    rmSync(repo, { recursive: true, force: true });
  }
}

async function main(): Promise<number> {
  await Bun.write(ACT_RESULTS, "");
  let allPassed = true;
  for (const c of cases) {
    console.log(`\n=== running case: ${c.name} ===`);
    const { pass, reasons, output } = await runCase(c);
    const header = `\n===== CASE: ${c.name} (pass=${pass}) =====\n`;
    const prev = existsSync(ACT_RESULTS) ? readFileSync(ACT_RESULTS, "utf8") : "";
    await Bun.write(ACT_RESULTS, prev + header + output);
    if (pass) {
      console.log(`PASS: ${c.name}`);
    } else {
      allPassed = false;
      console.error(`FAIL: ${c.name}`);
      for (const r of reasons) console.error(`  - ${r}`);
    }
  }
  console.log(`\nact-result.txt written to ${ACT_RESULTS}`);
  return allPassed ? 0 : 1;
}

process.exit(await main());
