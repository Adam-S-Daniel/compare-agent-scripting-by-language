// Act test harness — runs each test fixture through the GitHub Actions workflow via act
// Asserts on exact expected output values. Saves all output to act-result.txt.

import { spawnSync } from "child_process";
import { writeFileSync, readFileSync, mkdirSync, rmSync, existsSync, copyFileSync } from "fs";
import { join } from "path";

const ROOT = join(import.meta.dir);
const ACT_RESULT_FILE = join(ROOT, "act-result.txt");

// Clear previous results
writeFileSync(ACT_RESULT_FILE, "");

interface TestCase {
  name: string;
  initialVersion: string;
  gitLog: string;
  expectedNewVersion: string;
  expectedBumpType: string;
}

const testCases: TestCase[] = [
  {
    name: "patch-bump-fix-commits",
    initialVersion: "1.2.3",
    gitLog: [
      "abc1234 fix: resolve null pointer in parser",
      "abc1235 fix: handle empty string input",
    ].join("\n"),
    expectedNewVersion: "1.2.4",
    expectedBumpType: "patch",
  },
  {
    name: "minor-bump-feat-commits",
    initialVersion: "1.1.0",
    gitLog: [
      "def1234 feat: add support for pre-release versions",
      "def1235 fix: correct semver comparison",
    ].join("\n"),
    expectedNewVersion: "1.2.0",
    expectedBumpType: "minor",
  },
  {
    name: "major-bump-breaking-change",
    initialVersion: "2.3.1",
    gitLog: [
      "ghi1234 feat!: redesign API surface",
      "ghi1235 feat: add new flags",
    ].join("\n"),
    expectedNewVersion: "3.0.0",
    expectedBumpType: "major",
  },
];

// Static workflow that reads commits from commits.txt in the repo
const TEST_WORKFLOW = `name: Semantic Version Bumper

on:
  push:
    branches:
      - main
      - master
  workflow_dispatch:

permissions:
  contents: write

jobs:
  test:
    name: Run Tests
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Bun
        uses: oven-sh/setup-bun@v2
        with:
          bun-version: latest

      - name: Install dependencies
        run: bun install

      - name: Run unit tests
        run: bun test src/version-bumper.test.ts

  bump-version:
    name: Bump Version
    runs-on: ubuntu-latest
    needs: test
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Bun
        uses: oven-sh/setup-bun@v2
        with:
          bun-version: latest

      - name: Install dependencies
        run: bun install

      - name: Run semantic version bump
        id: bump
        run: |
          OUTPUT=$(bun run src/main.ts version.txt commits.txt)
          echo "$OUTPUT"
          NEW_VERSION=$(echo "$OUTPUT" | grep "^New version:" | awk '{print $NF}')
          BUMP_TYPE=$(echo "$OUTPUT" | grep "^Bump type:" | awk '{print $NF}')
          echo "new_version=\${NEW_VERSION}" >> "$GITHUB_OUTPUT"
          echo "bump_type=\${BUMP_TYPE}" >> "$GITHUB_OUTPUT"

      - name: Print new version
        run: |
          echo "Version bump complete"
          echo "New version: \${{ steps.bump.outputs.new_version }}"
          echo "Bump type: \${{ steps.bump.outputs.bump_type }}"
`;

function appendToResults(content: string) {
  const existing = readFileSync(ACT_RESULT_FILE, "utf8");
  writeFileSync(ACT_RESULT_FILE, existing + content);
}

function runActTestCase(tc: TestCase): { success: boolean; output: string } {
  const tmpDir = join(ROOT, `tmp-act-${tc.name}`);

  try {
    mkdirSync(tmpDir, { recursive: true });
    mkdirSync(join(tmpDir, "src"), { recursive: true });
    mkdirSync(join(tmpDir, ".github/workflows"), { recursive: true });

    // Copy source files
    const filesToCopy = [
      "src/version-bumper.ts",
      "src/version-bumper.test.ts",
      "src/fixtures.ts",
      "src/types.ts",
      "src/main.ts",
      "package.json",
      "tsconfig.json",
    ];

    for (const f of filesToCopy) {
      const src = join(ROOT, f);
      const dst = join(tmpDir, f);
      if (existsSync(src)) {
        copyFileSync(src, dst);
      }
    }

    if (existsSync(join(ROOT, "bun.lockb"))) {
      copyFileSync(join(ROOT, "bun.lockb"), join(tmpDir, "bun.lockb"));
    }

    // Write fixture data for this test case
    writeFileSync(join(tmpDir, "version.txt"), tc.initialVersion + "\n");
    writeFileSync(join(tmpDir, "commits.txt"), tc.gitLog + "\n");

    // Write the static workflow (no dynamic YAML generation)
    writeFileSync(join(tmpDir, ".github/workflows/semantic-version-bumper.yml"), TEST_WORKFLOW);

    // Copy .actrc
    copyFileSync(join(ROOT, ".actrc"), join(tmpDir, ".actrc"));

    // Initialize git repo
    spawnSync("git", ["init"], { cwd: tmpDir });
    spawnSync("git", ["config", "user.email", "test@test.com"], { cwd: tmpDir });
    spawnSync("git", ["config", "user.name", "Test"], { cwd: tmpDir });
    spawnSync("git", ["add", "."], { cwd: tmpDir });
    spawnSync("git", ["commit", "-m", "chore: initial commit"], { cwd: tmpDir });

    // Run act
    const actResult = spawnSync(
      "act",
      ["push", "--rm", "--no-cache-server", "--pull=false"],
      {
        cwd: tmpDir,
        encoding: "utf8",
        timeout: 300000,
      }
    );

    const output = (actResult.stdout || "") + (actResult.stderr || "");

    return {
      success: actResult.status === 0,
      output,
    };
  } finally {
    rmSync(tmpDir, { recursive: true, force: true });
  }
}

let allPassed = true;

for (const tc of testCases) {
  console.log(`\n${"=".repeat(60)}`);
  console.log(`Running test case: ${tc.name}`);
  console.log(`  Initial version: ${tc.initialVersion}`);
  console.log(`  Expected new version: ${tc.expectedNewVersion}`);
  console.log(`  Expected bump type: ${tc.expectedBumpType}`);

  const delimiter = `\n${"=".repeat(60)}\nTEST CASE: ${tc.name}\nInitial: ${tc.initialVersion} -> Expected: ${tc.expectedNewVersion} (${tc.expectedBumpType})\n${"=".repeat(60)}\n`;
  appendToResults(delimiter);

  const { success, output } = runActTestCase(tc);
  appendToResults(output);

  if (!success) {
    console.error(`  FAIL: act exited non-zero for ${tc.name}`);
    appendToResults(`\nFAIL: act exited non-zero\n`);
    allPassed = false;
    continue;
  }

  if (!output.includes("Job succeeded")) {
    console.error(`  FAIL: 'Job succeeded' not found in act output for ${tc.name}`);
    appendToResults(`\nFAIL: 'Job succeeded' not found\n`);
    allPassed = false;
    continue;
  }

  if (!output.includes(tc.expectedNewVersion)) {
    console.error(`  FAIL: expected version ${tc.expectedNewVersion} not found in output`);
    appendToResults(`\nFAIL: expected version ${tc.expectedNewVersion} not found\n`);
    allPassed = false;
    continue;
  }

  if (!output.includes(tc.expectedBumpType)) {
    console.error(`  FAIL: expected bump type ${tc.expectedBumpType} not found in output`);
    appendToResults(`\nFAIL: expected bump type ${tc.expectedBumpType} not found\n`);
    allPassed = false;
    continue;
  }

  console.log(`  PASS: version=${tc.expectedNewVersion}, bump=${tc.expectedBumpType}, Job succeeded`);
  appendToResults(`\nPASS: version=${tc.expectedNewVersion}, bump=${tc.expectedBumpType}, Job succeeded\n`);
}

console.log(`\n${"=".repeat(60)}`);
if (allPassed) {
  console.log("ALL TEST CASES PASSED");
  appendToResults("\n" + "=".repeat(60) + "\nALL TEST CASES PASSED\n");
} else {
  console.error("SOME TEST CASES FAILED — see act-result.txt for details");
  appendToResults("\n" + "=".repeat(60) + "\nSOME TEST CASES FAILED\n");
  process.exit(1);
}
