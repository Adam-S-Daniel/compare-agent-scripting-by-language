// End-to-end act harness: for each test case, set up a temp git repo with
// the project plus the case's fixture + assertion, run `act push --rm`, and
// append the output to act-result.txt. Asserts exit code 0 and a
// "Job succeeded" line for every case.
import { spawnSync } from "node:child_process";
import {
  cpSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  rmSync,
  writeFileSync,
  appendFileSync,
  readFileSync,
} from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

interface Case {
  name: string;
  dir: string;
}

const cases: Case[] = [
  { name: "mixed", dir: "cases/case-mixed" },
  { name: "all-ok", dir: "cases/case-all-ok" },
  { name: "all-expired", dir: "cases/case-all-expired" },
];

const PROJECT_ROOT = process.cwd();
const ACT_RESULT = join(PROJECT_ROOT, "act-result.txt");
writeFileSync(ACT_RESULT, `act harness run at ${new Date().toISOString()}\n`);

function run(cmd: string, args: string[], cwd: string): { status: number; output: string } {
  const r = spawnSync(cmd, args, { cwd, encoding: "utf8" });
  return {
    status: r.status ?? -1,
    output: (r.stdout ?? "") + (r.stderr ?? ""),
  };
}

function stageCase(c: Case): string {
  const work = mkdtempSync(join(tmpdir(), `sec-rot-${c.name}-`));
  // Copy the whole project, excluding throwaway dirs.
  cpSync(PROJECT_ROOT, work, {
    recursive: true,
    filter: (src) => {
      const rel = src.slice(PROJECT_ROOT.length);
      if (rel.includes("/.git/") || rel.endsWith("/.git")) return false;
      if (rel.includes("/node_modules")) return false;
      if (rel.includes("/act-result.txt")) return false;
      return true;
    },
  });
  // Override fixture + assertions for the case.
  cpSync(join(PROJECT_ROOT, c.dir, "secrets.json"), join(work, "fixtures/secrets.json"));
  cpSync(
    join(PROJECT_ROOT, c.dir, "assert-report.ts"),
    join(work, "scripts/assert-report.ts"),
  );
  // Init a git repo (act requires one).
  run("git", ["init", "-q", "-b", "main"], work);
  run("git", ["config", "user.email", "ci@example.com"], work);
  run("git", ["config", "user.name", "CI"], work);
  run("git", ["add", "."], work);
  const commit = run("git", ["commit", "-q", "-m", `case ${c.name}`], work);
  if (commit.status !== 0) {
    console.error(commit.output);
    throw new Error(`git commit failed for case ${c.name}`);
  }
  return work;
}

let overallOk = true;
for (const c of cases) {
  console.log(`\n=== Running act for case: ${c.name} ===`);
  const work = stageCase(c);
  // --pull=false: use the locally built act-ubuntu-pwsh image (not on any registry).
  const actArgs = [
    "push",
    "--rm",
    "--pull=false",
    "-W",
    ".github/workflows/secret-rotation-validator.yml",
  ];
  const r = run("act", actArgs, work);

  const delim = `\n========== CASE: ${c.name} (exit=${r.status}) ==========\n`;
  appendFileSync(ACT_RESULT, delim + r.output + "\n");

  const jobSucceeded = r.output.includes("Job succeeded");
  const caseOk = r.status === 0 && jobSucceeded;
  if (!caseOk) {
    overallOk = false;
    console.error(
      `case ${c.name} FAILED: exit=${r.status}, jobSucceeded=${jobSucceeded}`,
    );
  } else {
    console.log(`case ${c.name} OK`);
  }
  // Leave workdir on failure for inspection, otherwise clean up.
  if (caseOk) rmSync(work, { recursive: true, force: true });
  else console.error(`  workspace left at: ${work}`);
}

if (!existsSync(ACT_RESULT)) {
  console.error("act-result.txt missing");
  process.exit(2);
}
const size = readFileSync(ACT_RESULT, "utf8").length;
console.log(`\nact-result.txt size: ${size} bytes`);

if (!overallOk) {
  console.error("One or more act cases failed.");
  process.exit(1);
}
console.log("All act cases passed.");
