// Act test harness: runs the GitHub Actions workflow via act and verifies exact output values.
// Usage: bun run run-tests.ts

import { mkdtempSync, cpSync, writeFileSync, appendFileSync, rmSync, existsSync } from "fs";
import { join } from "path";
import { tmpdir } from "os";
import { spawnSync } from "child_process";

const WORKSPACE = import.meta.dir;
const ACT_RESULT = join(WORKSPACE, "act-result.txt");

// ── Expected output values ────────────────────────────────────────────────────
// These are exact strings that must appear in the act output for the test to pass.

interface Assertion {
  label: string;
  needle: string;
}

const ASSERTIONS: Assertion[] = [
  // TC1: max-age policy deletes 2 old artifacts totalling 3 MB
  { label: "TC1 bun tests pass",            needle: "23 pass"                              },
  { label: "TC1 deleted count",             needle: "Artifacts deleted:  2"                },
  { label: "TC1 space reclaimed",           needle: "Space reclaimed:    3145728 bytes (3.00 MB)" },
  // TC2: keep-latest-N deletes 2 oldest deploy-workflow artifacts; 2048 bytes reclaimed
  { label: "TC2 deleted count",             needle: "Artifacts deleted:  2"                },
  { label: "TC2 space reclaimed",           needle: "Space reclaimed:    2048 bytes (0.00 MB)" },
  // TC3: max-total-size deletes 1 artifact (3 MB) to bring total under 5 MB
  { label: "TC3 deleted count",             needle: "Artifacts deleted:  1"                },
  { label: "TC3 space reclaimed (same val)",needle: "Space reclaimed:    3145728 bytes (3.00 MB)" },
  // Job-level success indicator
  { label: "Job succeeded",                 needle: "Job succeeded"                        },
];

// ── Helpers ───────────────────────────────────────────────────────────────────

function log(msg: string) {
  console.log(msg);
}

function fail(msg: string): never {
  console.error(`FAIL: ${msg}`);
  process.exit(1);
}

function copyProjectFiles(destDir: string) {
  const filesToCopy = [
    "artifact-cleanup.ts",
    "artifact-cleanup.test.ts",
    ".actrc",
    "fixtures",
    ".github",
  ];

  for (const item of filesToCopy) {
    const src = join(WORKSPACE, item);
    const dst = join(destDir, item);
    if (!existsSync(src)) {
      throw new Error(`Source path does not exist: ${src}`);
    }
    cpSync(src, dst, { recursive: true });
  }
}

function gitInitAndCommit(repoDir: string) {
  const run = (cmd: string, args: string[]) => {
    const result = spawnSync(cmd, args, { cwd: repoDir, encoding: "utf8" });
    if (result.error) throw result.error;
    return result;
  };

  run("git", ["init"]);
  run("git", ["config", "user.email", "test@example.com"]);
  run("git", ["config", "user.name", "Test"]);
  run("git", ["add", "-A"]);
  run("git", ["commit", "-m", "test: artifact cleanup script"]);
}

// ── Main ──────────────────────────────────────────────────────────────────────

log("=== Act test harness for artifact-cleanup-script ===");
log("");

// Reset act-result.txt
writeFileSync(ACT_RESULT, `=== ACT TEST RUN: artifact-cleanup-script ===\nDate: ${new Date().toISOString()}\n\n`);

// Create temp repo
let tempDir: string;
try {
  tempDir = mkdtempSync(join(tmpdir(), "artifact-cleanup-act-"));
  log(`Temp repo: ${tempDir}`);
  copyProjectFiles(tempDir);
  gitInitAndCommit(tempDir);
} catch (e) {
  fail(`Failed to set up temp repo: ${(e as Error).message}`);
}

// ── Run act ───────────────────────────────────────────────────────────────────

log("\nRunning: act push --rm");
log("(this may take 60-90s for Docker container startup)\n");

const actResult = spawnSync(
  "act",
  ["push", "--rm", "--pull=false"],
  {
    cwd: tempDir!,
    encoding: "utf8",
    timeout: 300_000, // 5 minutes
  }
);

const actOutput = (actResult.stdout ?? "") + (actResult.stderr ?? "");

// Save full output to act-result.txt
appendFileSync(
  ACT_RESULT,
  [
    "--- BEGIN ACT OUTPUT ---",
    actOutput,
    `--- END ACT OUTPUT (exit code: ${actResult.status}) ---`,
    "",
  ].join("\n")
);

log(`Act exit code: ${actResult.status}`);
log(`Output saved to: ${ACT_RESULT}`);

// Clean up temp dir
try {
  rmSync(tempDir!, { recursive: true, force: true });
} catch {
  // non-fatal
}

// ── Assertions ────────────────────────────────────────────────────────────────

log("\n=== Assertions ===");

let passed = 0;
let failed = 0;

// Exit code must be 0
if (actResult.status !== 0) {
  log(`FAIL [exit code] expected 0, got ${actResult.status}`);
  log("\n--- Act output (last 100 lines) ---");
  const lines = actOutput.split("\n");
  log(lines.slice(-100).join("\n"));
  failed++;
} else {
  log("PASS [exit code = 0]");
  passed++;
}

// Check each expected string
for (const { label, needle } of ASSERTIONS) {
  if (actOutput.includes(needle)) {
    log(`PASS [${label}] found: "${needle}"`);
    passed++;
  } else {
    log(`FAIL [${label}] missing: "${needle}"`);
    failed++;
  }
}

log(`\n=== Results: ${passed} passed, ${failed} failed ===`);

appendFileSync(
  ACT_RESULT,
  [
    "--- ASSERTION RESULTS ---",
    `Exit code: ${actResult.status === 0 ? "PASS" : "FAIL"}`,
    ...ASSERTIONS.map(({ label, needle }) =>
      `${actOutput.includes(needle) ? "PASS" : "FAIL"} [${label}]: "${needle}"`
    ),
    `Total: ${passed} passed, ${failed} failed`,
    "",
  ].join("\n")
);

if (failed > 0) {
  process.exit(1);
}
