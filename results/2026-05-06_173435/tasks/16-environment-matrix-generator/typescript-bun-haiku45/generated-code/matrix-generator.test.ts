import { describe, it, expect } from "bun:test";
import { generateMatrix, MatrixConfig, MatrixResult } from "./matrix-generator";

describe("Matrix Generator - TDD Tests", () => {
  // Test 1: Basic matrix generation with single OS and language version
  it("should generate basic matrix from simple config", () => {
    const config: MatrixConfig = {
      os: ["ubuntu-latest"],
      language: ["node@18"],
      maxParallel: 10,
      failFast: false,
    };

    const result = generateMatrix(config);

    expect(result.matrix.include).toHaveLength(1);
    expect(result.matrix.include[0]).toEqual({
      os: "ubuntu-latest",
      language: "node@18",
    });
    expect(result.matrix.maxParallel).toBe(10);
    expect(result.matrix.failFast).toBe(false);
  });

  // Test 2: Cartesian product of multiple options
  it("should create cartesian product of OS and language versions", () => {
    const config: MatrixConfig = {
      os: ["ubuntu-latest", "macos-latest"],
      language: ["node@18", "node@20"],
      maxParallel: 5,
      failFast: false,
    };

    const result = generateMatrix(config);

    expect(result.matrix.include).toHaveLength(4);
    expect(result.matrix.include).toContainEqual({
      os: "ubuntu-latest",
      language: "node@18",
    });
    expect(result.matrix.include).toContainEqual({
      os: "macos-latest",
      language: "node@20",
    });
  });

  // Test 3: Feature flags as additional dimensions
  it("should include feature flags in matrix", () => {
    const config: MatrixConfig = {
      os: ["ubuntu-latest"],
      language: ["node@18"],
      features: ["esm", "cjs"],
      maxParallel: 10,
      failFast: false,
    };

    const result = generateMatrix(config);

    expect(result.matrix.include).toHaveLength(2);
    expect(result.matrix.include).toContainEqual({
      os: "ubuntu-latest",
      language: "node@18",
      feature: "esm",
    });
    expect(result.matrix.include).toContainEqual({
      os: "ubuntu-latest",
      language: "node@18",
      feature: "cjs",
    });
  });

  // Test 4: Exclude rules
  it("should respect exclude rules", () => {
    const config: MatrixConfig = {
      os: ["ubuntu-latest", "windows-latest"],
      language: ["node@18", "node@20"],
      exclude: [{ os: "windows-latest", language: "node@18" }],
      maxParallel: 10,
      failFast: false,
    };

    const result = generateMatrix(config);

    expect(result.matrix.include).toHaveLength(3);
    const excluded = result.matrix.include.find(
      (item) => item.os === "windows-latest" && item.language === "node@18"
    );
    expect(excluded).toBeUndefined();
  });

  // Test 5: Include rules
  it("should respect include rules to add custom combinations", () => {
    const config: MatrixConfig = {
      os: ["ubuntu-latest"],
      language: ["node@18"],
      include: [{ os: "windows-latest", language: "node@18", special: "true" }],
      maxParallel: 10,
      failFast: false,
    };

    const result = generateMatrix(config);

    expect(result.matrix.include).toHaveLength(2);
    const special = result.matrix.include.find(
      (item) => item.special === "true"
    );
    expect(special).toEqual({
      os: "windows-latest",
      language: "node@18",
      special: "true",
    });
  });

  // Test 6: Matrix size validation
  it("should validate matrix does not exceed max size", () => {
    const config: MatrixConfig = {
      os: ["ubuntu-latest", "macos-latest", "windows-latest"],
      language: ["node@16", "node@18", "node@20"],
      maxSize: 5,
      maxParallel: 10,
      failFast: false,
    };

    const result = generateMatrix(config);

    expect(result.error).toBeDefined();
    expect(result.error).toContain("exceeds maximum matrix size");
  });

  // Test 7: Fail-fast and maxParallel configuration
  it("should set fail-fast and maxParallel correctly", () => {
    const config: MatrixConfig = {
      os: ["ubuntu-latest"],
      language: ["node@18"],
      maxParallel: 3,
      failFast: true,
    };

    const result = generateMatrix(config);

    expect(result.matrix.failFast).toBe(true);
    expect(result.matrix.maxParallel).toBe(3);
  });

  // Test 8: Empty or missing arrays should use defaults
  it("should handle missing optional arrays gracefully", () => {
    const config: MatrixConfig = {
      os: ["ubuntu-latest"],
      language: ["node@18"],
      maxParallel: 10,
      failFast: false,
    };

    const result = generateMatrix(config);

    expect(result.error).toBeUndefined();
    expect(result.matrix.include).toHaveLength(1);
  });

  // Test 9: Complex scenario with features and excludes
  it("should handle complex scenario with features, excludes, and includes", () => {
    const config: MatrixConfig = {
      os: ["ubuntu-latest", "macos-latest"],
      language: ["node@18", "node@20"],
      features: ["esm"],
      exclude: [{ os: "macos-latest", language: "node@18" }],
      include: [{ os: "windows-latest", language: "node@20", feature: "esm" }],
      maxParallel: 10,
      failFast: false,
    };

    const result = generateMatrix(config);

    // Should have: 2 OS * 2 langs * 1 feature - 1 exclude + 1 include = 4
    expect(result.matrix.include.length).toBe(4);
    expect(
      result.matrix.include.some((item) => item.os === "windows-latest")
    ).toBe(true);
    expect(
      result.matrix.include.some(
        (item) => item.os === "macos-latest" && item.language === "node@18"
      )
    ).toBe(false);
  });

  // Test 10: JSON output is valid
  it("should output valid JSON", () => {
    const config: MatrixConfig = {
      os: ["ubuntu-latest"],
      language: ["node@18"],
      maxParallel: 10,
      failFast: false,
    };

    const result = generateMatrix(config);
    const json = JSON.stringify(result.matrix);

    expect(typeof json).toBe("string");
    expect(() => JSON.parse(json)).not.toThrow();
  });
});
