#!/usr/bin/env bun
/**
 * Test runner for GitHub Actions workflow using act
 * Creates temporary git repos with test fixtures and runs the workflow
 */

import { mkdir, rm, writeFile, readFile } from "fs/promises";
import { join } from "path";
import { spawnSync } from "child_process";

interface TestCase {
  name: string;
  fixtureFile: string;
  initialVersion: string;
  expectedVersion: string;
}

const testCases: TestCase[] = [
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

async function setupTestRepo(
  testDir: string,
  initialVersion: string,
  commits: string[]
): Promise<void> {
  // Initialize git repo
  spawnSync("git", ["init"], { cwd: testDir, stdio: "pipe" });
  spawnSync("git", ["config", "user.email", "test@example.com"], {
    cwd: testDir,
    stdio: "pipe",
  });
  spawnSync("git", ["config", "user.name", "Test User"], {
    cwd: testDir,
    stdio: "pipe",
  });

  // Copy project files
  const projectFiles = [
    "package.json",
    "tsconfig.json",
    "bun.lockb",
    "src/version.ts",
    "src/bumper.ts",
    "src/commits.ts",
    "src/changelog.ts",
    "src/files.ts",
    "src/index.ts",
    "src/git.ts",
    ".github/workflows/semantic-version-bumper.yml",
    "version.test.ts",
    "bumper.test.ts",
    "commits.test.ts",
    "changelog.test.ts",
    "files.test.ts",
  ];

  for (const file of projectFiles) {
    const src = join(process.cwd(), file);
    const dest = join(testDir, file);
    try {
      const content = await readFile(src, "utf-8");
      const destDir = dest.substring(0, dest.lastIndexOf("/"));
      await mkdir(destDir, { recursive: true });
      await writeFile(dest, content);
    } catch (e) {
      console.warn(`Warning: Could not copy ${file}: ${e}`);
    }
  }

  // Create/update package.json with initial version
  const pkgPath = join(testDir, "package.json");
  const pkgContent = await readFile(pkgPath, "utf-8");
  const pkg = JSON.parse(pkgContent);
  pkg.version = initialVersion;
  await writeFile(pkgPath, JSON.stringify(pkg, null, 2) + "\n");

  // Create initial commit with files
  spawnSync("git", ["add", "."], { cwd: testDir, stdio: "pipe" });
  spawnSync("git", ["commit", "-m", "Initial commit"], {
    cwd: testDir,
    stdio: "pipe",
  });

  // Create commits from fixture
  for (const commit of commits) {
    if (commit.trim()) {
      spawnSync("git", ["commit", "--allow-empty", "-m", commit], {
        cwd: testDir,
        stdio: "pipe",
      });
    }
  }
}

async function runActWorkflow(testDir: string): Promise<string> {
  const result = spawnSync("act", ["push", "--rm"], {
    cwd: testDir,
    encoding: "utf-8",
  });

  return result.stdout || "";
}

async function runTests(): Promise<void> {
  const resultsFile = "act-result.txt";
  const allResults: string[] = [];

  console.log("Running act workflow tests...\n");

  for (const testCase of testCases) {
    console.log(`Running: ${testCase.name}`);

    const testDir = `/tmp/act-test-${Date.now()}`;
    try {
      // Read commits from fixture
      const commitsContent = await readFile(testCase.fixtureFile, "utf-8");
      const commits = commitsContent
        .split("\n")
        .filter((line) => line.trim() && !line.startsWith("BREAKING"));

      // Setup test repo
      await mkdir(testDir, { recursive: true });
      await setupTestRepo(testDir, testCase.initialVersion, commits);

      // Run workflow
      console.log(`  Setting up test repo at ${testDir}`);
      const output = await runActWorkflow(testDir);

      // Check results
      const passed =
        output.includes("Job succeeded") && output.includes(testCase.expectedVersion);

      // Record results
      allResults.push(`\n${"=".repeat(70)}`);
      allResults.push(`Test: ${testCase.name}`);
      allResults.push(`Initial Version: ${testCase.initialVersion}`);
      allResults.push(`Expected Version: ${testCase.expectedVersion}`);
      allResults.push(`Result: ${passed ? "✓ PASS" : "✗ FAIL"}`);
      allResults.push(`${"=".repeat(70)}`);
      allResults.push(output);

      console.log(`  Result: ${passed ? "✓ PASS" : "✗ FAIL"}`);
    } catch (error) {
      console.error(`  Error: ${error}`);
      allResults.push(`\nError in ${testCase.name}: ${error}`);
    } finally {
      // Cleanup
      try {
        await rm(testDir, { recursive: true, force: true });
      } catch (e) {
        console.warn(`Could not clean up ${testDir}`);
      }
    }
  }

  // Save results to file
  await writeFile(resultsFile, allResults.join("\n"));
  console.log(`\nResults saved to ${resultsFile}`);
}

// Run tests
runTests().catch((error) => {
  console.error("Test runner failed:", error);
  process.exit(1);
});
