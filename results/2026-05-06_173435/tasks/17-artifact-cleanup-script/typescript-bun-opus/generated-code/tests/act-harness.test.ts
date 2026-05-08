import { describe, test, expect, beforeAll } from "bun:test";
import { readFileSync, existsSync } from "fs";
import * as yaml from "js-yaml";
import * as path from "path";

const PROJECT_ROOT = path.resolve(import.meta.dir, "..");
const WORKFLOW_PATH = path.join(PROJECT_ROOT, ".github/workflows/artifact-cleanup-script.yml");
const ACT_RESULT_PATH = path.join(PROJECT_ROOT, "act-result.txt");

describe("workflow structure tests", () => {
  let workflow: Record<string, unknown>;

  beforeAll(() => {
    const raw = readFileSync(WORKFLOW_PATH, "utf-8");
    workflow = yaml.load(raw) as Record<string, unknown>;
  });

  test("workflow has expected triggers", () => {
    const on = workflow["on"] as Record<string, unknown>;
    expect(on).toBeDefined();
    expect(on["push"]).toBeDefined();
    expect(on["pull_request"]).toBeDefined();
    expect(on["schedule"]).toBeDefined();
    expect(on["workflow_dispatch"]).toBeDefined();
  });

  test("workflow has cleanup job", () => {
    const jobs = workflow["jobs"] as Record<string, unknown>;
    expect(jobs["cleanup"]).toBeDefined();
  });

  test("workflow references correct script files", () => {
    expect(existsSync(path.join(PROJECT_ROOT, "src/index.ts"))).toBe(true);
    expect(existsSync(path.join(PROJECT_ROOT, "src/cleanup.ts"))).toBe(true);
    expect(existsSync(path.join(PROJECT_ROOT, "src/types.ts"))).toBe(true);
    expect(existsSync(path.join(PROJECT_ROOT, "tests/fixtures/max-age.json"))).toBe(true);
    expect(existsSync(path.join(PROJECT_ROOT, "tests/fixtures/keep-latest-n.json"))).toBe(true);
    expect(existsSync(path.join(PROJECT_ROOT, "tests/fixtures/max-size.json"))).toBe(true);
    expect(existsSync(path.join(PROJECT_ROOT, "tests/fixtures/combined-policy.json"))).toBe(true);
  });

  test("workflow steps reference src/index.ts", () => {
    const jobs = workflow["jobs"] as Record<string, Record<string, unknown>>;
    const steps = jobs["cleanup"]["steps"] as Array<Record<string, string>>;
    const scriptSteps = steps.filter((s) => s.run && s.run.includes("src/index.ts"));
    expect(scriptSteps.length).toBeGreaterThanOrEqual(4);
  });

  test("actionlint passes", () => {
    const result = Bun.spawnSync(["actionlint", WORKFLOW_PATH]);
    expect(result.exitCode).toBe(0);
  });
});

describe("act integration tests", () => {
  let actOutput: string;

  beforeAll(() => {
    // Run act in a temp git repo containing our project files
    const tmpDir = `/tmp/act-test-${Date.now()}`;
    Bun.spawnSync(["mkdir", "-p", tmpDir]);

    // Copy project files
    Bun.spawnSync(["bash", "-c", `cp -r "${PROJECT_ROOT}/src" "${tmpDir}/"`]);
    Bun.spawnSync(["bash", "-c", `cp -r "${PROJECT_ROOT}/tests" "${tmpDir}/"`]);
    Bun.spawnSync(["bash", "-c", `cp -r "${PROJECT_ROOT}/.github" "${tmpDir}/"`]);
    Bun.spawnSync(["bash", "-c", `cp "${PROJECT_ROOT}/package.json" "${tmpDir}/"`]);
    Bun.spawnSync(["bash", "-c", `cp "${PROJECT_ROOT}/bun.lock" "${tmpDir}/" 2>/dev/null; true`]);
    Bun.spawnSync(["bash", "-c", `cp "${PROJECT_ROOT}/tsconfig.json" "${tmpDir}/"`]);
    Bun.spawnSync(["bash", "-c", `cp "${PROJECT_ROOT}/.actrc" "${tmpDir}/"`]);

    // Init git repo
    Bun.spawnSync(["git", "init"], { cwd: tmpDir });
    Bun.spawnSync(["git", "add", "-A"], { cwd: tmpDir });
    Bun.spawnSync(["git", "-c", "user.email=test@test.com", "-c", "user.name=Test", "commit", "-m", "init"], { cwd: tmpDir });

    // Run act
    const actResult = Bun.spawnSync(
      ["act", "push", "--rm", "--pull=false"],
      {
        cwd: tmpDir,
        timeout: 300_000,
        env: { ...process.env, HOME: process.env.HOME },
      }
    );

    actOutput = actResult.stdout.toString() + "\n" + actResult.stderr.toString();

    // Write act output
    const delimiter = `\n${"=".repeat(60)}\n`;
    const header = `ACT RUN - ${new Date().toISOString()}${delimiter}`;
    Bun.spawnSync(["bash", "-c", `cat > "${ACT_RESULT_PATH}" << 'ACTEOF'\n${header}${actOutput}\nACTEOF`]);
    require("fs").writeFileSync(ACT_RESULT_PATH, header + actOutput);

    // Cleanup
    Bun.spawnSync(["rm", "-rf", tmpDir]);
  }, 600_000);

  test("act-result.txt exists", () => {
    expect(existsSync(ACT_RESULT_PATH)).toBe(true);
  });

  test("act exited successfully (Job succeeded)", () => {
    expect(actOutput).toContain("Job succeeded");
  });

  test("unit tests passed in workflow", () => {
    expect(actOutput).toContain("8 pass");
    expect(actOutput).toContain("0 fail");
  });

  // max-age fixture: with now=runtime, artifacts from March and Feb 2026 are >30 days old
  // build-output-old (2026-03-01) and test-coverage-old (2026-02-15) should be deleted
  test("max-age fixture: deletes 2 old artifacts, retains 2 recent", () => {
    expect(actOutput).toContain("build-output-old");
    expect(actOutput).toContain("test-coverage-old");
    expect(actOutput).toContain("exceeded max age of 30 days");
    // The output should show these 2 deleted and 2 retained
    expect(actOutput).toContain("Artifacts deleted: 2");
    expect(actOutput).toContain("Artifacts retained: 2");
  });

  // keep-latest-n fixture: wf-200 has 4 artifacts, keep 2 newest (artifact-3, artifact-4)
  // wf-300 has 1 artifact, kept. So 2 deleted, 3 retained.
  test("keep-latest-n fixture: deletes oldest 2 from wf-200, retains rest", () => {
    expect(actOutput).toContain("artifact-1");
    expect(actOutput).toContain("artifact-2");
    expect(actOutput).toContain("exceeds keep-latest-2 per workflow");
    expect(actOutput).toContain("Artifacts deleted: 2");
    expect(actOutput).toContain("Artifacts retained: 3");
  });

  // max-size fixture: total=16777216, budget=6291456
  // oldest (large, 10485760) deleted first. Remaining=6291456 which equals budget exactly.
  test("max-size fixture: deletes largest/oldest artifact to meet size budget", () => {
    expect(actOutput).toContain("large-artifact");
    expect(actOutput).toContain("total size exceeds budget of 6291456 bytes");
    // After deleting large-artifact (10MB), remaining = medium(5MB) + small(1MB) = 6MB
    expect(actOutput).toContain("Space reclaimed: 10.0 MB");
  });

  // combined-policy fixture: ancient (Jan) and old (Apr 1) are >30 days old -> deleted by age
  // r1,r2,r3 remain, all in wf-500. keep-latest-3: all 3 kept.
  // total = 3M+2M+2.5M = 7.5M > 7M budget, so r1 (oldest remaining) gets deleted.
  test("combined-policy fixture: applies all policies in correct order", () => {
    expect(actOutput).toContain("ancient-build");
    expect(actOutput).toContain("old-build");
    // r1 deleted by size budget
    expect(actOutput).toContain("recent-build-1");
    expect(actOutput).toContain("total size exceeds budget of 7000000 bytes");
  });

  test("all fixture runs show DRY RUN mode", () => {
    // All fixtures have dryRun: true
    expect(actOutput).toContain("DRY RUN");
  });
});
