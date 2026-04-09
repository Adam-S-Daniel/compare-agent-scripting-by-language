// Tests for the GitHub Actions workflow:
// 1. Workflow YAML structure validation
// 2. actionlint validation
// 3. End-to-end act execution

import { describe, test, expect, beforeAll } from "bun:test";
import { readFile, mkdtemp, rm, cp, writeFile } from "fs/promises";
import { tmpdir } from "os";
import { join } from "path";
import YAML from "js-yaml";

const WORKFLOW_PATH = join(import.meta.dir, ".github/workflows/semantic-version-bumper.yml");
const PROJECT_DIR = import.meta.dir;

// ─── Workflow structure tests ────────────────────────────────────────

describe("workflow YAML structure", () => {
  let workflow: any;

  beforeAll(async () => {
    const raw = await readFile(WORKFLOW_PATH, "utf-8");
    workflow = YAML.load(raw);
  });

  test("has the expected name", () => {
    expect(workflow.name).toBe("Semantic Version Bumper");
  });

  test("triggers on push to main/master", () => {
    expect(workflow.on.push.branches).toContain("main");
    expect(workflow.on.push.branches).toContain("master");
  });

  test("triggers on pull_request", () => {
    expect(workflow.on.pull_request).toBeDefined();
  });

  test("triggers on workflow_dispatch", () => {
    expect(workflow.on.workflow_dispatch).toBeDefined();
  });

  test("has test and bump jobs", () => {
    expect(workflow.jobs.test).toBeDefined();
    expect(workflow.jobs.bump).toBeDefined();
  });

  test("bump job depends on test job", () => {
    expect(workflow.jobs.bump.needs).toBe("test");
  });

  test("test job uses actions/checkout@v4", () => {
    const checkoutStep = workflow.jobs.test.steps.find(
      (s: any) => s.uses && s.uses.startsWith("actions/checkout@")
    );
    expect(checkoutStep).toBeDefined();
    expect(checkoutStep.uses).toBe("actions/checkout@v4");
  });

  test("test job sets up bun", () => {
    const bunStep = workflow.jobs.test.steps.find(
      (s: any) => s.uses && s.uses.startsWith("oven-sh/setup-bun@")
    );
    expect(bunStep).toBeDefined();
  });

  test("bump job runs version bumper script", () => {
    const bumperStep = workflow.jobs.bump.steps.find(
      (s: any) => s.run && s.run.includes("bump.ts")
    );
    expect(bumperStep).toBeDefined();
  });

  test("referenced script files exist", async () => {
    const { existsSync } = await import("fs");
    expect(existsSync(join(PROJECT_DIR, "bump.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_DIR, "version-bumper.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_DIR, "version-bumper.test.ts"))).toBe(true);
  });
});

// ─── actionlint validation ───────────────────────────────────────────

describe("actionlint", () => {
  test("workflow passes actionlint", async () => {
    const proc = Bun.spawn(["actionlint", WORKFLOW_PATH], {
      stdout: "pipe",
      stderr: "pipe",
    });
    const stderr = await new Response(proc.stderr).text();
    const code = await proc.exited;
    if (code !== 0) {
      console.error("actionlint errors:", stderr);
    }
    expect(code).toBe(0);
  });
});

// ─── act execution test ─────────────────────────────────────────────

describe("act execution", () => {
  test("workflow runs successfully with act push", async () => {
    // Create a temp directory to serve as a fresh git repo
    const tempDir = await mkdtemp(join(tmpdir(), "act-test-"));

    try {
      // Copy project files into temp dir
      const filesToCopy = [
        "package.json",
        "bun.lock",
        "tsconfig.json",
        ".gitignore",
        "version-bumper.ts",
        "version-bumper.test.ts",
        "bump.ts",
      ];
      for (const file of filesToCopy) {
        await cp(join(PROJECT_DIR, file), join(tempDir, file)).catch(() => {});
      }
      // Copy directories
      await cp(join(PROJECT_DIR, "fixtures"), join(tempDir, "fixtures"), { recursive: true });
      await cp(join(PROJECT_DIR, ".github"), join(tempDir, ".github"), { recursive: true });
      // Copy node_modules so bun install --frozen-lockfile works
      await cp(join(PROJECT_DIR, "node_modules"), join(tempDir, "node_modules"), { recursive: true });

      // Reset package.json version to 1.0.0 for deterministic output
      const pkgPath = join(tempDir, "package.json");
      const pkg = JSON.parse(await readFile(pkgPath, "utf-8"));
      pkg.version = "1.0.0";
      await writeFile(pkgPath, JSON.stringify(pkg, null, 2) + "\n");

      // Initialize git repo
      const gitInit = Bun.spawn(
        ["bash", "-c", `cd "${tempDir}" && git init && git add -A && git commit -m "test"`],
        { stdout: "pipe", stderr: "pipe", env: { ...process.env, GIT_AUTHOR_NAME: "test", GIT_AUTHOR_EMAIL: "test@test.com", GIT_COMMITTER_NAME: "test", GIT_COMMITTER_EMAIL: "test@test.com" } }
      );
      await gitInit.exited;

      // Run act push
      const actProc = Bun.spawn(
        ["act", "push", "--rm", "-P", "ubuntu-latest=catthehacker/ubuntu:act-latest"],
        {
          cwd: tempDir,
          stdout: "pipe",
          stderr: "pipe",
          env: { ...process.env },
        }
      );
      const stdout = await new Response(actProc.stdout).text();
      const stderr = await new Response(actProc.stderr).text();
      const actOutput = stdout + "\n" + stderr;
      const exitCode = await actProc.exited;

      // Save output to act-result.txt in the project directory
      await writeFile(join(PROJECT_DIR, "act-result.txt"), actOutput);

      // Debug: if act failed, show the output
      if (exitCode !== 0) {
        console.error("act output:\n", actOutput.slice(-3000));
      }

      // Assert act succeeded
      expect(exitCode).toBe(0);

      // Assert both jobs succeeded
      expect(actOutput).toContain("Job succeeded");

      // Assert the bumper produced the correct output.
      // The fixture commits are: feat + fix + feat(api) → minor bump → 1.0.0 → 1.1.0
      expect(actOutput).toContain("current_version=1.0.0");
      expect(actOutput).toContain("new_version=1.1.0");
      expect(actOutput).toContain("bump_type=minor");

      // Verify the changelog was printed
      expect(actOutput).toContain("## 1.1.0");
      expect(actOutput).toContain("### Features");

    } finally {
      await rm(tempDir, { recursive: true, force: true });
    }
  }, 300000); // 5 min timeout for docker
});
