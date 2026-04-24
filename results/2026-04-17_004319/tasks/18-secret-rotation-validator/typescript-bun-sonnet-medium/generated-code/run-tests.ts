// Test harness: runs each test case through act and verifies output.
// Workflow structure checks run first (fast), then act runs (slow, max 3).
import { execSync, spawnSync } from "child_process";
import {
  mkdtempSync,
  writeFileSync,
  mkdirSync,
  rmSync,
  appendFileSync,
  readFileSync,
  existsSync,
} from "fs";
import { cpSync } from "fs";
import { tmpdir } from "os";
import { join } from "path";

const PROJECT_DIR = import.meta.dir;
const ACT_RESULT_FILE = join(PROJECT_DIR, "act-result.txt");
const WORKFLOW_FILE = join(PROJECT_DIR, ".github/workflows/secret-rotation-validator.yml");

// ─── Helpers ─────────────────────────────────────────────────────────────────
function pass(msg: string): void {
  console.log(`  ✓ ${msg}`);
}

function fail(msg: string): never {
  console.error(`  ✗ ${msg}`);
  process.exit(1);
}

function assertContains(haystack: string, needle: string, label: string): void {
  if (!haystack.includes(needle)) {
    fail(`${label}: expected to find '${needle}' in output`);
  }
  pass(`${label}: found '${needle}'`);
}

// ─── Workflow structure tests (no act, instant) ───────────────────────────────
console.log("\n=== Workflow Structure Tests ===");

// 1. Workflow file exists
if (!existsSync(WORKFLOW_FILE)) fail("Workflow file does not exist");
pass("Workflow file exists");

const workflowContent = readFileSync(WORKFLOW_FILE, "utf8");

// 2. Triggers
assertContains(workflowContent, "push:", "Trigger: push");
assertContains(workflowContent, "pull_request:", "Trigger: pull_request");
assertContains(workflowContent, "schedule:", "Trigger: schedule");
assertContains(workflowContent, "workflow_dispatch:", "Trigger: workflow_dispatch");

// 3. Required job/steps
assertContains(workflowContent, "actions/checkout@v4", "Step: checkout v4");
assertContains(workflowContent, "oven-sh/setup-bun@v2", "Step: setup-bun v2");
assertContains(workflowContent, "bun test", "Step: bun test");
assertContains(workflowContent, "bun run src/main.ts", "Step: main script");

// 4. Referenced script files exist
const scriptRef = "src/main.ts";
if (!existsSync(join(PROJECT_DIR, scriptRef))) fail(`Referenced script not found: ${scriptRef}`);
pass(`Script file exists: ${scriptRef}`);

const fixtureRef = "fixtures/sample-secrets.json";
if (!existsSync(join(PROJECT_DIR, fixtureRef))) fail(`Fixture not found: ${fixtureRef}`);
pass(`Fixture file exists: ${fixtureRef}`);

// 5. actionlint passes
const lintResult = spawnSync("actionlint", [WORKFLOW_FILE], { encoding: "utf8" });
if (lintResult.status !== 0) {
  fail(`actionlint failed:\n${lintResult.stdout}${lintResult.stderr}`);
}
pass("actionlint passes");

console.log("\nAll workflow structure tests passed.\n");

// ─── Test case definitions ────────────────────────────────────────────────────
interface TestCase {
  name: string;
  fixture: object;
  expected: { expired: number; warning: number; ok: number };
}

// Fixture date math (reference date: 2026-04-19):
// mixed:   DB_PASSWORD 100d old/90d policy=EXPIRED, API_KEY 84d/90d=WARNING(6d left),
//          JWT_SECRET 30d/90d=OK, OAUTH_TOKEN 49d/30d=EXPIRED  → expired=2,warning=1,ok=1
// all-ok:  SECRET_A 18d/90d, SECRET_B 9d/90d, SECRET_C 4d/30d → expired=0,warning=0,ok=3
const testCases: TestCase[] = [
  {
    name: "mixed-secrets",
    fixture: {
      referenceDate: "2026-04-19",
      warningWindowDays: 7,
      secrets: [
        { name: "DB_PASSWORD", lastRotated: "2026-01-09", rotationPolicyDays: 90, requiredBy: ["api-service", "worker-service"] },
        { name: "API_KEY",     lastRotated: "2026-01-25", rotationPolicyDays: 90, requiredBy: ["frontend-service"] },
        { name: "JWT_SECRET",  lastRotated: "2026-03-20", rotationPolicyDays: 90, requiredBy: ["auth-service"] },
        { name: "OAUTH_TOKEN", lastRotated: "2026-03-01", rotationPolicyDays: 30, requiredBy: ["oauth-service"] },
      ],
    },
    expected: { expired: 2, warning: 1, ok: 1 },
  },
  {
    name: "all-ok-secrets",
    fixture: {
      referenceDate: "2026-04-19",
      warningWindowDays: 7,
      secrets: [
        { name: "SECRET_A", lastRotated: "2026-04-01", rotationPolicyDays: 90, requiredBy: ["service-a"] },
        { name: "SECRET_B", lastRotated: "2026-04-10", rotationPolicyDays: 90, requiredBy: ["service-b"] },
        { name: "SECRET_C", lastRotated: "2026-04-15", rotationPolicyDays: 30, requiredBy: ["service-c"] },
      ],
    },
    expected: { expired: 0, warning: 0, ok: 3 },
  },
];

// ─── Act test runner ──────────────────────────────────────────────────────────
// Initialize (or overwrite) the results file
writeFileSync(ACT_RESULT_FILE, "# Act Test Results\n\n");

function setupTempRepo(tc: TestCase): string {
  const tmpDir = mkdtempSync(join(tmpdir(), "srv-"));

  // Copy source tree into temp repo
  for (const entry of ["src", "tests", "package.json", ".github", ".actrc"]) {
    const src = join(PROJECT_DIR, entry);
    cpSync(src, join(tmpDir, entry), { recursive: true });
  }

  // Write the test-case-specific fixture as the standard fixture file
  mkdirSync(join(tmpDir, "fixtures"), { recursive: true });
  writeFileSync(
    join(tmpDir, "fixtures", "sample-secrets.json"),
    JSON.stringify(tc.fixture, null, 2)
  );

  // Initialise a git repo so act has a valid push event
  execSync("git init -b main && git add -A && git commit -m 'ci'", {
    cwd: tmpDir,
    stdio: "pipe",
    env: {
      ...process.env,
      GIT_AUTHOR_NAME: "ci",
      GIT_AUTHOR_EMAIL: "ci@ci.invalid",
      GIT_COMMITTER_NAME: "ci",
      GIT_COMMITTER_EMAIL: "ci@ci.invalid",
    },
  });

  return tmpDir;
}

function runActTest(tc: TestCase): void {
  console.log(`=== Act test: ${tc.name} ===`);
  console.log(`Expected: expired=${tc.expected.expired} warning=${tc.expected.warning} ok=${tc.expected.ok}`);

  const tmpDir = setupTempRepo(tc);

  const result = spawnSync("act", ["push", "--rm", "--pull=false"], {
    cwd: tmpDir,
    encoding: "utf8",
    timeout: 180_000, // 3 minutes
    env: { ...process.env },
  });

  const output = (result.stdout ?? "") + (result.stderr ?? "");
  const exitCode = result.status ?? 1;

  // Persist output
  const divider = `\n${"=".repeat(60)}\nTest: ${tc.name} | Expected: expired=${tc.expected.expired} warning=${tc.expected.warning} ok=${tc.expected.ok}\n${"=".repeat(60)}\n`;
  appendFileSync(ACT_RESULT_FILE, divider + output + "\n");

  try {
    // Assert act exited 0
    if (exitCode !== 0) fail(`act exited with code ${exitCode}\nTail:\n${output.slice(-3000)}`);
    pass("act exited 0");

    // Assert job succeeded
    assertContains(output, "Job succeeded", "Job succeeded");

    // Assert exact expected summary values
    assertContains(output, `VALIDATOR_EXPIRED=${tc.expected.expired}`, `VALIDATOR_EXPIRED=${tc.expected.expired}`);
    assertContains(output, `VALIDATOR_WARNING=${tc.expected.warning}`, `VALIDATOR_WARNING=${tc.expected.warning}`);
    assertContains(output, `VALIDATOR_OK=${tc.expected.ok}`, `VALIDATOR_OK=${tc.expected.ok}`);

    console.log(`  → PASSED\n`);
  } finally {
    rmSync(tmpDir, { recursive: true, force: true });
  }
}

// ─── Run act tests ────────────────────────────────────────────────────────────
console.log("=== Act Tests (via GitHub Actions) ===\n");

for (const tc of testCases) {
  runActTest(tc);
}

console.log("All tests passed. Results saved to act-result.txt");
