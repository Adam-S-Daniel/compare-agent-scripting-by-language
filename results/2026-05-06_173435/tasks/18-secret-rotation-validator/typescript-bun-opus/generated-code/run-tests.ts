import { existsSync, mkdtempSync, readFileSync, writeFileSync, cpSync, mkdirSync, rmSync } from "fs";
import { join, resolve } from "path";
import { tmpdir } from "os";
import { spawnSync } from "child_process";

const projectDir = resolve(import.meta.dir);
const resultLines: string[] = [];
let failCount = 0;
let passCount = 0;

function log(msg: string): void {
  console.log(msg);
  resultLines.push(msg);
}

function assert(condition: boolean, message: string): void {
  if (!condition) {
    log(`  FAIL: ${message}`);
    failCount++;
  } else {
    log(`  PASS: ${message}`);
    passCount++;
  }
}

function extractBetweenMarkers(output: string, startMarker: string, endMarker: string): string {
  const lines = output.split("\n");
  let capturing = false;
  const captured: string[] = [];
  for (const line of lines) {
    if (line.includes(startMarker)) {
      capturing = true;
      continue;
    }
    if (line.includes(endMarker)) {
      capturing = false;
      continue;
    }
    if (capturing) {
      const pipeMatch = line.match(/\|\s?(.*)/);
      if (pipeMatch) {
        captured.push(pipeMatch[1]);
      }
    }
  }
  return captured.join("\n");
}

// ── Phase 1: Workflow structure tests ──
log("=== PHASE 1: WORKFLOW STRUCTURE TESTS ===");

const workflowPath = join(projectDir, ".github/workflows/secret-rotation-validator.yml");
assert(existsSync(workflowPath), "Workflow file exists at .github/workflows/secret-rotation-validator.yml");

const wf = readFileSync(workflowPath, "utf-8");
assert(wf.includes("on:"), "Workflow has 'on:' trigger block");
assert(wf.includes("push"), "Workflow triggers on push");
assert(wf.includes("pull_request"), "Workflow triggers on pull_request");
assert(wf.includes("workflow_dispatch"), "Workflow has workflow_dispatch trigger");
assert(wf.includes("schedule"), "Workflow has schedule trigger");
assert(/cron:/.test(wf), "Workflow has cron expression");
assert(wf.includes("jobs:"), "Workflow has jobs section");
assert(wf.includes("runs-on:"), "Workflow specifies runs-on");
assert(wf.includes("actions/checkout@v4"), "Workflow uses actions/checkout@v4");
assert(wf.includes("bun test"), "Workflow runs bun test");
assert(wf.includes("bun run main.ts"), "Workflow references main.ts script");
assert(wf.includes("--config fixtures/test-secrets.json"), "Workflow references fixtures/test-secrets.json");
assert(wf.includes("--format json"), "Workflow runs JSON format output");
assert(wf.includes("--format markdown"), "Workflow runs Markdown format output");

assert(existsSync(join(projectDir, "main.ts")), "main.ts exists");
assert(existsSync(join(projectDir, "validator.ts")), "validator.ts exists");
assert(existsSync(join(projectDir, "formatter.ts")), "formatter.ts exists");
assert(existsSync(join(projectDir, "types.ts")), "types.ts exists");
assert(existsSync(join(projectDir, "fixtures/test-secrets.json")), "fixtures/test-secrets.json exists");
assert(existsSync(join(projectDir, "validator.test.ts")), "validator.test.ts exists");
assert(existsSync(join(projectDir, "formatter.test.ts")), "formatter.test.ts exists");

// ── Phase 2: actionlint validation ──
log("\n=== PHASE 2: ACTIONLINT VALIDATION ===");

const lintResult = spawnSync("actionlint", [workflowPath], { encoding: "utf-8" });
assert(
  lintResult.status === 0,
  `actionlint exits with code 0 (got ${lintResult.status})`
);
if (lintResult.status !== 0) {
  log(`  actionlint output:\n${lintResult.stdout}\n${lintResult.stderr}`);
}

// ── Phase 3: act integration tests ──
log("\n=== PHASE 3: ACT INTEGRATION TESTS ===");

const tmpDir = mkdtempSync(join(tmpdir(), "secret-rotation-act-"));
log(`  Temp directory: ${tmpDir}`);

const filesToCopy = [
  "types.ts",
  "validator.ts",
  "formatter.ts",
  "main.ts",
  "validator.test.ts",
  "formatter.test.ts",
  "fixtures/test-secrets.json",
  ".github/workflows/secret-rotation-validator.yml",
];

for (const file of filesToCopy) {
  const src = join(projectDir, file);
  const dest = join(tmpDir, file);
  mkdirSync(join(dest, ".."), { recursive: true });
  cpSync(src, dest);
}

writeFileSync(join(tmpDir, ".actrc"), "-P ubuntu-latest=act-ubuntu-pwsh:latest\n");

const gitEnv = {
  ...process.env,
  GIT_AUTHOR_NAME: "test",
  GIT_COMMITTER_NAME: "test",
  GIT_AUTHOR_EMAIL: "test@test.com",
  GIT_COMMITTER_EMAIL: "test@test.com",
};

spawnSync("git", ["init"], { cwd: tmpDir, env: gitEnv });
spawnSync("git", ["add", "."], { cwd: tmpDir, env: gitEnv });
spawnSync("git", ["commit", "-m", "initial"], { cwd: tmpDir, env: gitEnv });

log("  Running act push --rm (this may take a few minutes)...");
const actResult = spawnSync("act", ["push", "--rm", "--pull=false"], {
  cwd: tmpDir,
  encoding: "utf-8",
  timeout: 300_000,
});

const actOutput = (actResult.stdout || "") + "\n" + (actResult.stderr || "");

log(`  act exit code: ${actResult.status}`);

const actResultPath = join(projectDir, "act-result.txt");
writeFileSync(
  actResultPath,
  `=== ACT RUN: Secret Rotation Validator ===\nExit code: ${actResult.status}\n\n${actOutput}\n`
);
log(`  Saved act output to act-result.txt (${actOutput.length} chars)`);

assert(actResult.status === 0, "act push exits with code 0");

assert(actOutput.includes("Job succeeded"), "act output shows 'Job succeeded'");

// Check bun test results are visible
assert(actOutput.includes("pass"), "act output shows tests passing");
assert(!/[1-9]\d* fail/.test(actOutput), "act output shows no test failures");

// ── Parse JSON output ──
log("\n=== PHASE 4: JSON OUTPUT ASSERTIONS ===");

const jsonContent = extractBetweenMarkers(actOutput, "JSON_OUTPUT_START", "JSON_OUTPUT_END");
let jsonParsed = false;

if (jsonContent.trim()) {
  try {
    const report = JSON.parse(jsonContent);
    jsonParsed = true;

    assert(report.generatedAt === "2026-05-07", "JSON generatedAt is '2026-05-07'");
    assert(report.warningWindowDays === 14, "JSON warningWindowDays is 14");

    assert(report.summary.total === 4, "JSON summary.total is 4");
    assert(report.summary.expired === 1, "JSON summary.expired is 1");
    assert(report.summary.warning === 1, "JSON summary.warning is 1");
    assert(report.summary.ok === 2, "JSON summary.ok is 2");

    const db = report.secrets.find((s: any) => s.name === "DB_PASSWORD");
    assert(db !== undefined, "JSON contains DB_PASSWORD secret");
    assert(db?.urgency === "expired", "JSON DB_PASSWORD urgency is 'expired'");
    assert(db?.daysSinceRotation === 843, "JSON DB_PASSWORD daysSinceRotation is 843");
    assert(db?.daysUntilExpiry === -753, "JSON DB_PASSWORD daysUntilExpiry is -753");
    assert(db?.expiryDate === "2024-04-14", "JSON DB_PASSWORD expiryDate is '2024-04-14'");

    const jwt = report.secrets.find((s: any) => s.name === "JWT_SECRET");
    assert(jwt !== undefined, "JSON contains JWT_SECRET secret");
    assert(jwt?.urgency === "warning", "JSON JWT_SECRET urgency is 'warning'");
    assert(jwt?.daysUntilExpiry === 13, "JSON JWT_SECRET daysUntilExpiry is 13");
    assert(jwt?.expiryDate === "2026-05-20", "JSON JWT_SECRET expiryDate is '2026-05-20'");

    const api = report.secrets.find((s: any) => s.name === "API_KEY");
    assert(api !== undefined, "JSON contains API_KEY secret");
    assert(api?.urgency === "ok", "JSON API_KEY urgency is 'ok'");
    assert(api?.daysUntilExpiry === 208, "JSON API_KEY daysUntilExpiry is 208");

    const slack = report.secrets.find((s: any) => s.name === "SLACK_WEBHOOK");
    assert(slack !== undefined, "JSON contains SLACK_WEBHOOK secret");
    assert(slack?.urgency === "ok", "JSON SLACK_WEBHOOK urgency is 'ok'");
    assert(slack?.daysUntilExpiry === 174, "JSON SLACK_WEBHOOK daysUntilExpiry is 174");

    // Check sort order: expired, warning, ok
    assert(
      report.secrets[0].urgency === "expired" &&
        report.secrets[1].urgency === "warning" &&
        report.secrets[2].urgency === "ok" &&
        report.secrets[3].urgency === "ok",
      "JSON secrets sorted by urgency (expired, warning, ok)"
    );
  } catch (e: any) {
    assert(false, `JSON output is valid JSON: ${e.message}`);
  }
} else {
  assert(false, "JSON output found between markers in act output");
}

assert(jsonParsed, "JSON output was successfully parsed and validated");

// ── Parse Markdown output ──
log("\n=== PHASE 5: MARKDOWN OUTPUT ASSERTIONS ===");

const mdContent = extractBetweenMarkers(actOutput, "MARKDOWN_OUTPUT_START", "MARKDOWN_OUTPUT_END");

assert(mdContent.includes("Secret Rotation Report"), "Markdown contains 'Secret Rotation Report' title");
assert(
  mdContent.includes("Generated: 2026-05-07 | Warning Window: 14 days"),
  "Markdown contains generation metadata line"
);
assert(mdContent.includes("| Expired | 1 |"), "Markdown summary shows Expired = 1");
assert(mdContent.includes("| Warning | 1 |"), "Markdown summary shows Warning = 1");
assert(mdContent.includes("| OK | 2 |"), "Markdown summary shows OK = 2");
assert(mdContent.includes("| **Total** | **4** |"), "Markdown summary shows Total = 4");

assert(mdContent.includes("## Expired"), "Markdown has Expired section");
assert(
  mdContent.includes("| DB_PASSWORD | 2024-01-15 | 90 | 2024-04-14 | 753 | api-server, worker |"),
  "Markdown Expired row for DB_PASSWORD with 753 days overdue"
);

assert(mdContent.includes("## Warning"), "Markdown has Warning section");
assert(
  mdContent.includes("| JWT_SECRET | 2026-04-20 | 30 | 2026-05-20 | 13 | auth-service |"),
  "Markdown Warning row for JWT_SECRET with 13 days until expiry"
);

assert(mdContent.includes("## OK"), "Markdown has OK section");
assert(
  mdContent.includes("| API_KEY | 2025-12-01 | 365 | 2026-12-01 | 208 | frontend |"),
  "Markdown OK row for API_KEY with 208 days until expiry"
);
assert(
  mdContent.includes("| SLACK_WEBHOOK | 2026-05-01 | 180 | 2026-10-28 | 174 | notification-service |"),
  "Markdown OK row for SLACK_WEBHOOK with 174 days until expiry"
);

// ── Cleanup ──
rmSync(tmpDir, { recursive: true, force: true });

// ── Final summary ──
log("\n========================================");
log(`  Total: ${passCount + failCount} | Passed: ${passCount} | Failed: ${failCount}`);
log("========================================");

if (failCount > 0) {
  writeFileSync(actResultPath, readFileSync(actResultPath, "utf-8") + "\n\n" + resultLines.join("\n") + "\n");
  process.exit(1);
} else {
  writeFileSync(actResultPath, readFileSync(actResultPath, "utf-8") + "\n\n" + resultLines.join("\n") + "\n");
  log("All tests passed!");
}
