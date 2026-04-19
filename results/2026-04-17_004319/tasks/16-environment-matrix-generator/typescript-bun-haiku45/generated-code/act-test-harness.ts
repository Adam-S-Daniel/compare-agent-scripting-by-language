// Test harness that executes the workflow via act and validates results
import { execSync } from "child_process";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";

interface TestCase {
  name: string;
  fixture: string;
  expectedMatrixSize?: number;
}

const testCases: TestCase[] = [
  {
    name: "Simple config (2 OS × 2 versions)",
    fixture: "fixtures/simple-config.json",
    expectedMatrixSize: 4,
  },
  {
    name: "Config with excludes (3 OS × 2 versions - 1 excluded = 5)",
    fixture: "fixtures/with-excludes.json",
    expectedMatrixSize: 5,
  },
  {
    name: "Config with features (1 OS × 1 version × 2 features)",
    fixture: "fixtures/with-features.json",
    expectedMatrixSize: 2,
  },
];

function runActTest(): void {
  const results: string[] = [];
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "act-test-"));

  try {
    // Copy all project files to temp directory
    execSync(`cp -r . "${tempDir}/project"`, { stdio: "pipe" });

    // Initialize git repo
    execSync("git init", { cwd: `${tempDir}/project`, stdio: "pipe" });
    execSync('git config user.email "test@example.com"', {
      cwd: `${tempDir}/project`,
      stdio: "pipe",
    });
    execSync('git config user.name "Test User"', {
      cwd: `${tempDir}/project`,
      stdio: "pipe",
    });
    execSync("git add -A", { cwd: `${tempDir}/project`, stdio: "pipe" });
    execSync('git commit -m "Initial commit"', {
      cwd: `${tempDir}/project`,
      stdio: "pipe",
    });

    results.push("=== ACT TEST HARNESS ===\n");
    results.push(`Test directory: ${tempDir}/project\n`);
    results.push(`Timestamp: ${new Date().toISOString()}\n`);
    results.push("\n");

    // Run act push
    results.push("=== RUNNING ACT WORKFLOW ===\n");

    try {
      const actOutput = execSync("act push --rm -v 2>&1", {
        cwd: `${tempDir}/project`,
        encoding: "utf-8",
        stdio: "pipe",
      });

      results.push(actOutput);

      // Verify success
      if (actOutput.includes("Job succeeded")) {
        results.push("\n✓ Act workflow completed successfully\n");
      } else {
        results.push("\n⚠ Act workflow output does not contain 'Job succeeded'\n");
      }
    } catch (error: any) {
      results.push(
        `\nError running act: ${error.message}\n${error.stdout || ""}\n`
      );
      process.exit(1);
    }

    // Test matrix generation with fixtures
    results.push("\n=== MATRIX GENERATION TESTS ===\n");

    for (const testCase of testCases) {
      results.push(`\nTest: ${testCase.name}\n`);
      results.push(`Fixture: ${testCase.fixture}\n`);

      try {
        const matrixOutput = execSync(
          `bun run index.ts ${testCase.fixture}`,
          {
            cwd: `${tempDir}/project`,
            encoding: "utf-8",
            stdio: "pipe",
          }
        );

        const matrix = JSON.parse(matrixOutput);
        const matrixSize = matrix.include?.length || 0;

        results.push(`Matrix size: ${matrixSize}\n`);

        if (
          testCase.expectedMatrixSize !== undefined &&
          matrixSize === testCase.expectedMatrixSize
        ) {
          results.push("✓ Matrix size matches expected\n");
        } else if (testCase.expectedMatrixSize !== undefined) {
          results.push(
            `⚠ Expected size ${testCase.expectedMatrixSize}, got ${matrixSize}\n`
          );
        }

        // Show first few entries
        if (matrix.include && matrix.include.length > 0) {
          results.push(`First entry: ${JSON.stringify(matrix.include[0])}\n`);
        }

        results.push("---\n");
      } catch (error: any) {
        results.push(`✗ Error: ${error.message}\n`);
        results.push("---\n");
      }
    }

    // Save results
    const resultContent = results.join("");
    fs.writeFileSync("act-result.txt", resultContent);

    results.push("\n=== FINAL VERIFICATION ===\n");
    results.push(
      `Results saved to: ${path.resolve("act-result.txt")}\n`
    );
    results.push(`Total output size: ${resultContent.length} bytes\n`);

    console.log(resultContent);
  } finally {
    // Cleanup
    try {
      execSync(`rm -rf "${tempDir}"`, { stdio: "pipe" });
    } catch {
      // Ignore cleanup errors
    }
  }
}

// Run the test
runActTest();
