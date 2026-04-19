import { describe, it, expect } from "bun:test";
import { execSync } from "child_process";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";

describe("Workflow Execution Tests", () => {
  it("should pass actionlint validation", () => {
    try {
      const output = execSync(
        "actionlint .github/workflows/environment-matrix-generator.yml",
        { encoding: "utf-8", stdio: "pipe" }
      );
      expect(output.length).toBeGreaterThanOrEqual(0);
    } catch (error: any) {
      throw new Error(`actionlint failed: ${error.message}`);
    }
  });

  it("should have required workflow files", () => {
    expect(fs.existsSync(".github/workflows/environment-matrix-generator.yml")).toBe(true);
  });

  it("should have required source files", () => {
    expect(fs.existsSync("index.ts")).toBe(true);
    expect(fs.existsSync("matrix-generator.ts")).toBe(true);
    expect(fs.existsSync("package.json")).toBe(true);
  });

  it("should have test fixtures", () => {
    expect(fs.existsSync("fixtures/simple-config.json")).toBe(true);
    expect(fs.existsSync("fixtures/with-excludes.json")).toBe(true);
    expect(fs.existsSync("fixtures/with-features.json")).toBe(true);
  });

  it("should run workflow successfully via act", () => {
    const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "act-workflow-test-"));
    const projectDir = path.join(tempDir, "project");

    try {
      // Copy project to temp directory
      execSync(`cp -r . "${projectDir}"`, { stdio: "pipe" });

      // Initialize git repo
      execSync("git init", { cwd: projectDir, stdio: "pipe" });
      execSync('git config user.email "test@example.com"', {
        cwd: projectDir,
        stdio: "pipe",
      });
      execSync('git config user.name "Test User"', {
        cwd: projectDir,
        stdio: "pipe",
      });
      execSync("git add -A", { cwd: projectDir, stdio: "pipe" });
      execSync('git commit -m "Initial commit"', {
        cwd: projectDir,
        stdio: "pipe",
      });

      // Run act and capture output
      let actOutput = "";
      try {
        actOutput = execSync("act push --rm -v 2>&1", {
          cwd: projectDir,
          encoding: "utf-8",
          stdio: "pipe",
          timeout: 150000,
        });
      } catch (error: any) {
        actOutput = error.stdout || error.message;
      }

      // Save output to act-result.txt in the workspace root
      const outputPath = path.join(process.cwd(), "act-result.txt");
      fs.writeFileSync(
        outputPath,
        `=== GITHUB ACTIONS WORKFLOW TEST ===\nTimestamp: ${new Date().toISOString()}\n\n` +
        `=== WORKFLOW EXECUTION OUTPUT ===\n${actOutput}\n\n` +
        `=== VERIFICATION ===\n` +
        `Output saved to: ${outputPath}\n` +
        `Total size: ${actOutput.length} bytes\n`
      );

      // Verify workflow completed successfully
      expect(actOutput).toContain("generate-matrix");

      // Check for success indicators
      const hasSuccess = actOutput.includes("Success") ||
                        actOutput.includes("✅") ||
                        actOutput.includes("pass");
      expect(hasSuccess).toBe(true);

      // Verify matrix generation happened
      expect(actOutput).toMatch(/Matrix/i);
      expect(actOutput).toMatch(/include/);

    } finally {
      // Cleanup
      try {
        execSync(`rm -rf "${tempDir}"`, { stdio: "pipe" });
      } catch {
        // Ignore cleanup errors
      }
    }
  });

  it("should generate correct matrix output", () => {
    // Test simple config
    const simpleOutput = execSync(
      "bun run index.ts fixtures/simple-config.json",
      { encoding: "utf-8", stdio: "pipe" }
    );
    const simpleMatrix = JSON.parse(simpleOutput);
    expect(simpleMatrix.include.length).toBe(4);

    // Test excludes
    const excludesOutput = execSync(
      "bun run index.ts fixtures/with-excludes.json",
      { encoding: "utf-8", stdio: "pipe" }
    );
    const excludesMatrix = JSON.parse(excludesOutput);
    expect(excludesMatrix.include.length).toBe(5);
    expect(excludesMatrix.exclude).toBeDefined();

    // Test features
    const featuresOutput = execSync(
      "bun run index.ts fixtures/with-features.json",
      { encoding: "utf-8", stdio: "pipe" }
    );
    const featuresMatrix = JSON.parse(featuresOutput);
    expect(featuresMatrix.maxParallel).toBe(4);
    expect(featuresMatrix.failFast).toBe(true);
  });
});
