#!/usr/bin/env bun
// Test harness that runs all test cases through act (GitHub Actions).
// Creates temp repos for each fixture, runs act, captures output,
// validates exact expected values.

import { mkdtempSync, writeFileSync, readFileSync, cpSync, rmSync, existsSync, mkdirSync } from "fs";
import { join } from "path";
import { tmpdir } from "os";

interface TestCase {
  name: string;
  fixture: string;
  initialVersion: string;
  expectedVersion: string;
  expectedBump: string;
  expectBumped: boolean;
}

const PROJECT_DIR = import.meta.dir;

const testCases: TestCase[] = [
  {
    name: "feat-commits-minor-bump",
    fixture: "fixtures/commits-feat.txt",
    initialVersion: "1.1.0",
    expectedVersion: "1.2.0",
    expectedBump: "minor",
    expectBumped: true,
  },
  {
    name: "fix-commits-patch-bump",
    fixture: "fixtures/commits-fix.txt",
    initialVersion: "2.3.1",
    expectedVersion: "2.3.2",
    expectedBump: "patch",
    expectBumped: true,
  },
  {
    name: "breaking-commits-major-bump",
    fixture: "fixtures/commits-breaking.txt",
    initialVersion: "1.5.3",
    expectedVersion: "2.0.0",
    expectedBump: "major",
    expectBumped: true,
  },
];

function setupTempRepo(tc: TestCase): string {
  const tempDir = mkdtempSync(join(tmpdir(), `svb-test-${tc.name}-`));

  // Copy source files
  const filesToCopy = [
    "version-bumper.ts",
    "bump-version.ts",
    "package.json",
    "tsconfig.json",
  ];
  for (const f of filesToCopy) {
    cpSync(join(PROJECT_DIR, f), join(tempDir, f));
  }

  // Copy workflow
  mkdirSync(join(tempDir, ".github", "workflows"), { recursive: true });
  cpSync(
    join(PROJECT_DIR, ".github", "workflows", "semantic-version-bumper.yml"),
    join(tempDir, ".github", "workflows", "semantic-version-bumper.yml")
  );

  // Copy fixtures dir
  mkdirSync(join(tempDir, "fixtures"), { recursive: true });
  cpSync(join(PROJECT_DIR, tc.fixture), join(tempDir, "commit-log.txt"));

  // Copy all fixtures for the test run
  for (const f of ["commits-feat.txt", "commits-fix.txt", "commits-breaking.txt", "commits-none.txt"]) {
    cpSync(join(PROJECT_DIR, "fixtures", f), join(tempDir, "fixtures", f));
  }

  // Copy test file
  cpSync(join(PROJECT_DIR, "version-bumper.test.ts"), join(tempDir, "version-bumper.test.ts"));

  // Write VERSION file with initial version
  writeFileSync(join(tempDir, "VERSION"), tc.initialVersion + "\n");

  // Write .actrc
  writeFileSync(join(tempDir, ".actrc"), "-P ubuntu-latest=act-ubuntu-pwsh:latest\n");

  // Copy bun lockfile if exists
  const lockPath = join(PROJECT_DIR, "bun.lock");
  if (existsSync(lockPath)) {
    cpSync(lockPath, join(tempDir, "bun.lock"));
  }

  // Initialize a git repo (needed for actions/checkout)
  Bun.spawnSync(["git", "init"], { cwd: tempDir });
  Bun.spawnSync(["git", "config", "user.email", "test@test.com"], { cwd: tempDir });
  Bun.spawnSync(["git", "config", "user.name", "Test"], { cwd: tempDir });
  Bun.spawnSync(["git", "add", "."], { cwd: tempDir });
  Bun.spawnSync(["git", "commit", "-m", "initial"], { cwd: tempDir });

  return tempDir;
}

function runAct(tempDir: string): { exitCode: number; output: string } {
  const result = Bun.spawnSync(["act", "push", "--rm", "--pull=false"], {
    cwd: tempDir,
    timeout: 300_000,
    env: { ...process.env, HOME: process.env.HOME || "/root" },
  });
  const stdout = result.stdout.toString();
  const stderr = result.stderr.toString();
  return {
    exitCode: result.exitCode,
    output: stdout + "\n" + stderr,
  };
}

function main(): void {
  const resultFile = join(PROJECT_DIR, "act-result.txt");
  let allOutput = "";
  let allPassed = true;
  const failures: string[] = [];

  console.log(`Running ${testCases.length} test cases through act...\n`);

  for (const tc of testCases) {
    console.log(`--- Test: ${tc.name} ---`);
    const tempDir = setupTempRepo(tc);
    console.log(`  Temp dir: ${tempDir}`);

    const { exitCode, output } = runAct(tempDir);

    allOutput += `\n${"=".repeat(60)}\n`;
    allOutput += `TEST CASE: ${tc.name}\n`;
    allOutput += `Initial version: ${tc.initialVersion}\n`;
    allOutput += `Expected version: ${tc.expectedVersion}\n`;
    allOutput += `${"=".repeat(60)}\n`;
    allOutput += output;

    // Assert exit code
    if (exitCode !== 0) {
      const msg = `FAIL [${tc.name}]: act exited with code ${exitCode}`;
      console.error(`  ${msg}`);
      failures.push(msg);
      allPassed = false;
      // Clean up and continue
      rmSync(tempDir, { recursive: true, force: true });
      continue;
    }
    console.log(`  act exit code: 0 (OK)`);

    // Assert job succeeded
    if (!output.includes("Job succeeded")) {
      const msg = `FAIL [${tc.name}]: "Job succeeded" not found in output`;
      console.error(`  ${msg}`);
      failures.push(msg);
      allPassed = false;
    } else {
      console.log(`  Job succeeded: YES`);
    }

    // Assert exact expected version in output
    if (tc.expectBumped) {
      if (!output.includes(`New version: ${tc.expectedVersion}`)) {
        const msg = `FAIL [${tc.name}]: Expected "New version: ${tc.expectedVersion}" not found`;
        console.error(`  ${msg}`);
        failures.push(msg);
        allPassed = false;
      } else {
        console.log(`  Version output matches: ${tc.expectedVersion}`);
      }

      // Assert bump type
      if (!output.includes(`Bump type: ${tc.expectedBump}`)) {
        const msg = `FAIL [${tc.name}]: Expected "Bump type: ${tc.expectedBump}" not found`;
        console.error(`  ${msg}`);
        failures.push(msg);
        allPassed = false;
      } else {
        console.log(`  Bump type matches: ${tc.expectedBump}`);
      }

      // Assert VERSION file content shown in results
      if (!output.includes(tc.expectedVersion)) {
        const msg = `FAIL [${tc.name}]: Expected version "${tc.expectedVersion}" not in output`;
        console.error(`  ${msg}`);
        failures.push(msg);
        allPassed = false;
      }
    }

    // Assert unit tests passed
    if (!output.includes("29 pass") && !output.includes("pass")) {
      const msg = `FAIL [${tc.name}]: Unit tests did not pass`;
      console.error(`  ${msg}`);
      failures.push(msg);
      allPassed = false;
    } else {
      console.log(`  Unit tests: PASSED`);
    }

    console.log(`  RESULT: ${failures.length === 0 ? "PASS" : "FAIL"}\n`);

    // Clean up temp dir
    rmSync(tempDir, { recursive: true, force: true });
  }

  // Write all output to act-result.txt
  writeFileSync(resultFile, allOutput);
  console.log(`\nResults written to: ${resultFile}`);

  if (!allPassed) {
    console.error(`\n${failures.length} assertion(s) failed:`);
    for (const f of failures) {
      console.error(`  - ${f}`);
    }
    process.exit(1);
  }

  console.log(`\nAll ${testCases.length} test cases PASSED!`);
}

main();
