import { describe, it, expect } from "bun:test";
import { execSync } from "child_process";
import * as fs from "fs";

describe("Integration tests with JSON config files", () => {
  it("should read simple config and output valid matrix", () => {
    const output = execSync(
      "bun run index.ts fixtures/simple-config.json",
      { encoding: "utf-8" }
    );

    const matrix = JSON.parse(output);

    expect(matrix.include).toBeDefined();
    expect(matrix.include.length).toBe(4);
    expect(matrix.include[0]).toHaveProperty("os");
    expect(matrix.include[0]).toHaveProperty("nodeVersion");
  });

  it("should read config with excludes", () => {
    const output = execSync(
      "bun run index.ts fixtures/with-excludes.json",
      { encoding: "utf-8" }
    );

    const matrix = JSON.parse(output);

    expect(matrix.include.length).toBe(5); // 3 OS × 2 versions - 1 excluded
    expect(matrix.exclude).toBeDefined();
    expect(matrix.exclude.length).toBe(1);
  });

  it("should read config with features and options", () => {
    const output = execSync(
      "bun run index.ts fixtures/with-features.json",
      { encoding: "utf-8" }
    );

    const matrix = JSON.parse(output);

    expect(matrix.include.length).toBe(2); // 1 OS × 1 version × 2 features
    expect(matrix.maxParallel).toBe(4);
    expect(matrix.failFast).toBe(true);
  });

  it("should fail gracefully on missing file", () => {
    try {
      execSync("bun run index.ts fixtures/nonexistent.json", {
        encoding: "utf-8",
      });
      // Should not reach here
      expect(true).toBe(false);
    } catch (error: any) {
      expect(error.status).toBe(1);
    }
  });

  it("should fail gracefully on invalid JSON", () => {
    // Create a temp file with invalid JSON
    const tempFile = "/tmp/invalid.json";
    fs.writeFileSync(tempFile, "{ invalid json }");

    try {
      execSync(`bun run index.ts ${tempFile}`, { encoding: "utf-8" });
      expect(true).toBe(false);
    } catch (error: any) {
      expect(error.status).toBe(1);
    } finally {
      fs.unlinkSync(tempFile);
    }
  });
});
