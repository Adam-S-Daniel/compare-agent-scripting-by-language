// Orchestrates `act push --rm` for each test case.
//
// For each case it:
//   1. Creates a fresh temp git repo.
//   2. Copies project files + that case's fixture + policy.
//   3. Runs `act push --rm` inside the temp repo.
//   4. Appends delimited output to ./act-result.txt.
//
// Limited to exactly 3 act runs total.
import { spawnSync } from "node:child_process";
import { mkdtempSync, cpSync, writeFileSync, appendFileSync, mkdirSync, existsSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

interface Case {
  name: string;
  artifacts: unknown[];
  policy: Record<string, unknown>;
}

const NOW = "2026-04-17T00:00:00Z";

const cases: Case[] = [
  {
    name: "max-age",
    artifacts: [
      { id: "a", name: "build-output", sizeBytes: 100, createdAt: "2026-04-07T00:00:00Z", workflowRunId: "w1" },
      { id: "b", name: "test-report", sizeBytes: 200, createdAt: "2026-03-08T00:00:00Z", workflowRunId: "w1" },
    ],
    policy: { maxAgeDays: 30 },
  },
  {
    name: "keep-latest",
    artifacts: [
      { id: "a", name: "x", sizeBytes: 100, createdAt: "2026-04-16T00:00:00Z", workflowRunId: "w1" },
      { id: "b", name: "x", sizeBytes: 100, createdAt: "2026-04-15T00:00:00Z", workflowRunId: "w1" },
      { id: "c", name: "x", sizeBytes: 100, createdAt: "2026-04-14T00:00:00Z", workflowRunId: "w1" },
      { id: "d", name: "x", sizeBytes: 100, createdAt: "2026-04-13T00:00:00Z", workflowRunId: "w1" },
    ],
    policy: { keepLatestPerWorkflow: 2 },
  },
  {
    name: "size-budget",
    artifacts: [
      { id: "a", name: "x", sizeBytes: 500, createdAt: "2026-04-16T00:00:00Z", workflowRunId: "w1" },
      { id: "b", name: "x", sizeBytes: 500, createdAt: "2026-04-15T00:00:00Z", workflowRunId: "w1" },
      { id: "c", name: "x", sizeBytes: 500, createdAt: "2026-04-14T00:00:00Z", workflowRunId: "w1" },
    ],
    policy: { maxTotalSizeBytes: 1000 },
  },
];

const projectRoot = process.cwd();
const resultFile = join(projectRoot, "act-result.txt");
// Truncate prior results.
writeFileSync(resultFile, `# act-result.txt generated ${new Date().toISOString()}\n`);

const filesToCopy = [
  "cleanup.ts",
  "cleanup.test.ts",
  "harness.test.ts",
  "package.json",
  ".actrc",
];

let allOk = true;

for (const c of cases) {
  const tmp = mkdtempSync(join(tmpdir(), `act-case-${c.name}-`));
  try {
    // Copy core files.
    for (const f of filesToCopy) {
      if (existsSync(join(projectRoot, f))) {
        cpSync(join(projectRoot, f), join(tmp, f));
      }
    }
    // Workflow dir.
    mkdirSync(join(tmp, ".github/workflows"), { recursive: true });
    cpSync(
      join(projectRoot, ".github/workflows/artifact-cleanup-script.yml"),
      join(tmp, ".github/workflows/artifact-cleanup-script.yml"),
    );
    // Fixtures for this case.
    mkdirSync(join(tmp, "fixtures"), { recursive: true });
    writeFileSync(join(tmp, "fixtures/artifacts.json"), JSON.stringify(c.artifacts, null, 2));
    writeFileSync(join(tmp, "fixtures/policy.json"), JSON.stringify(c.policy));

    // Init git repo — act requires one.
    spawnSync("git", ["init", "-q", "-b", "main"], { cwd: tmp });
    spawnSync("git", ["config", "user.email", "t@t"], { cwd: tmp });
    spawnSync("git", ["config", "user.name", "t"], { cwd: tmp });
    spawnSync("git", ["add", "."], { cwd: tmp });
    spawnSync("git", ["commit", "-q", "-m", "init"], { cwd: tmp });

    appendFileSync(resultFile, `\n\n==================== CASE:${c.name} ====================\n`);

    // Patch NOW_ISO into the workflow to guarantee deterministic output —
    // safer than re-writing the whole file.
    const wfPath = join(tmp, ".github/workflows/artifact-cleanup-script.yml");
    const wf = require("node:fs").readFileSync(wfPath, "utf8") as string;
    require("node:fs").writeFileSync(
      wfPath,
      wf.replace('NOW_ISO: "2026-04-17T00:00:00Z"', `NOW_ISO: "${NOW}"`),
    );

    const run = spawnSync(
      "act",
      ["push", "--rm", "--pull=false"],
      { cwd: tmp, encoding: "utf8", maxBuffer: 20 * 1024 * 1024 },
    );
    const combined = (run.stdout ?? "") + "\n--- STDERR ---\n" + (run.stderr ?? "");
    appendFileSync(resultFile, combined);
    appendFileSync(resultFile, `\n\nCASE:${c.name} ACT_EXIT=${run.status}\n`);
    if (run.status !== 0) {
      allOk = false;
      console.error(`[${c.name}] act exited ${run.status}`);
    } else {
      console.log(`[${c.name}] OK`);
    }
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
}

if (!allOk) {
  console.error("One or more act runs failed — see act-result.txt");
  process.exit(1);
}
console.log(`Wrote ${resultFile}`);
