#!/usr/bin/env bun
/**
 * Validates the GitHub Actions workflow using act
 * This test ensures the workflow runs successfully and produces correct output
 */

import { mkdir, rm, writeFile, readFile, cp } from "fs/promises";
import { join } from "path";
import { spawnSync } from "child_process";
import { existsSync } from "fs";

const RESULTS_FILE = "act-result.txt";

async function copyProjectFiles(testDir: string): Promise<void> {
  const baseDir = process.cwd();

  const files = [
    "package.json",
    "tsconfig.json",
    "bun.lockb",
    ".github/workflows/semantic-version-bumper.yml",
    "version.test.ts",
    "bumper.test.ts",
    "commits.test.ts",
    "changelog.test.ts",
    "files.test.ts",
    "workflow.test.ts",
  ];

  const dirs = ["src", "fixtures"];

  // Copy individual files
  for (const file of files) {
    const src = join(baseDir, file);
    if (existsSync(src)) {
      const dest = join(testDir, file);
      const destDir = dest.substring(0, dest.lastIndexOf("/"));
      await mkdir(destDir, { recursive: true });
      await cp(src, dest, { recursive: true });
    }
  }

  // Copy directories
  for (const dir of dirs) {
    const src = join(baseDir, dir);
    if (existsSync(src)) {
      const dest = join(testDir, dir);
      await cp(src, dest, { recursive: true });
    }
  }
}

function initGitRepo(testDir: string): void {
  const commands = [
    ["git", "init", "-q"],
    ["git", "config", "user.email", "test@example.com"],
    ["git", "config", "user.name", "Test User"],
  ];

  for (const cmd of commands) {
    spawnSync(cmd[0], cmd.slice(1), { cwd: testDir, stdio: "pipe" });
  }
}

async function updateVersion(
  testDir: string,
  version: string
): Promise<void> {
  const pkgPath = join(testDir, "package.json");
  const content = await readFile(pkgPath, "utf-8");
  const pkg = JSON.parse(content);
  pkg.version = version;
  await writeFile(pkgPath, JSON.stringify(pkg, null, 2) + "\n");
}

function addCommits(testDir: string, commitMessages: string[]): void {
  // Stage all files
  spawnSync("git", ["add", "."], { cwd: testDir, stdio: "pipe" });

  // Create initial commit
  spawnSync("git", ["commit", "-q", "-m", "Initial commit"], {
    cwd: testDir,
    stdio: "pipe",
  });

  // Create commits from messages
  for (const msg of commitMessages) {
    if (msg.trim()) {
      spawnSync("git", ["commit", "-q", "--allow-empty", "-m", msg], {
        cwd: testDir,
        stdio: "pipe",
      });
    }
  }
}

async function runAct(testDir: string): Promise<string> {
  const result = spawnSync("act", ["push", "--rm"], {
    cwd: testDir,
    encoding: "utf-8",
    maxBuffer: 1024 * 1024 * 10,
  });

  return (result.stdout || "") + (result.stderr || "");
}

async function main(): Promise<void> {
  console.log("Validating GitHub Actions workflow with act...\n");

  const results: string[] = [];
  let testsPassed = 0;
  let testsFailed = 0;

  const testCases = [
    {
      name: "Patch version bump (fix commits)",
      fixtureFile: "fixtures/commits-patch.txt",
      initialVersion: "1.0.0",
      expectedVersion: "1.0.1",
    },
    {
      name: "Minor version bump (feat commits)",
      fixtureFile: "fixtures/commits-minor.txt",
      initialVersion: "1.0.0",
      expectedVersion: "1.1.0",
    },
    {
      name: "Major version bump (breaking commits)",
      fixtureFile: "fixtures/commits-major.txt",
      initialVersion: "1.0.0",
      expectedVersion: "2.0.0",
    },
  ];

  for (const testCase of testCases) {
    console.log(`Testing: ${testCase.name}`);

    const testDir = `/tmp/act-test-${Date.now()}-${Math.random()}`;

    try {
      // Setup
      await mkdir(testDir, { recursive: true });
      await copyProjectFiles(testDir);
      initGitRepo(testDir);
      await updateVersion(testDir, testCase.initialVersion);

      // Read fixture commits
      const fixtureContent = await readFile(
        join(process.cwd(), testCase.fixtureFile),
        "utf-8"
      );
      const commits = fixtureContent
        .split("\n")
        .filter((line) => line.trim() && !line.startsWith("BREAKING"));

      addCommits(testDir, commits);

      // Run workflow
      console.log(`  Running workflow...`);
      const output = await runAct(testDir);

      // Verify results
      const jobSucceeded = output.includes("Job succeeded");
      const hasExpectedVersion = output.includes(testCase.expectedVersion);

      const passed = jobSucceeded && hasExpectedVersion;

      // Record
      results.push(`\n${"=".repeat(75)}`);
      results.push(`Test: ${testCase.name}`);
      results.push(`Initial Version: ${testCase.initialVersion}`);
      results.push(`Expected Version: ${testCase.expectedVersion}`);
      results.push(
        `Job Status: ${jobSucceeded ? "succeeded" : "failed"}`
      );
      results.push(
        `Version Check: ${hasExpectedVersion ? "passed" : "failed"}`
      );
      results.push(`Result: ${passed ? "✓ PASS" : "✗ FAIL"}`);
      results.push(`${"=".repeat(75)}`);
      results.push(output);

      if (passed) {
        testsPassed++;
        console.log(`  ✓ PASS\n`);
      } else {
        testsFailed++;
        console.log(`  ✗ FAIL\n`);
        if (!jobSucceeded) {
          console.log(`    - Workflow job did not succeed`);
        }
        if (!hasExpectedVersion) {
          console.log(
            `    - Expected version "${testCase.expectedVersion}" not found in output`
          );
        }
      }
    } catch (error) {
      testsFailed++;
      console.log(`  ✗ ERROR: ${error}\n`);
      results.push(`\nError in ${testCase.name}: ${error}`);
    } finally {
      // Cleanup
      try {
        await rm(testDir, { recursive: true, force: true });
      } catch (e) {
        // Ignore cleanup errors
      }
    }
  }

  // Summary
  console.log(
    `\nTest Summary: ${testsPassed} passed, ${testsFailed} failed\n`
  );

  // Save results
  const resultsContent =
    `GitHub Actions Workflow Validation Results\n` +
    `Generated: ${new Date().toISOString()}\n` +
    `\nSummary: ${testsPassed} passed, ${testsFailed} failed\n` +
    results.join("\n");

  await writeFile(RESULTS_FILE, resultsContent);
  console.log(`Results saved to: ${RESULTS_FILE}`);

  process.exit(testsFailed > 0 ? 1 : 0);
}

main().catch((error) => {
  console.error("Validation failed:", error);
  process.exit(1);
});
