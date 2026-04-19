import { describe, it, expect } from "bun:test";

// Test 1: Basic matrix generation from OS and version options
describe("Basic matrix generation", () => {
  it("should generate a matrix from OS and version options", async () => {
    // This test will fail because generateMatrix doesn't exist yet
    const { generateMatrix } = await import("./matrix-generator");

    const config = {
      os: ["ubuntu-22.04", "macos-14"],
      nodeVersion: ["18", "20"],
    };

    const matrix = generateMatrix(config);

    expect(matrix).toBeDefined();
    expect(Array.isArray(matrix.include)).toBe(true);
    expect(matrix.include.length).toBe(4); // 2 OS × 2 versions
  });
});

// Test 2: Matrix with include rules
describe("Include rules", () => {
  it("should add include rules to the matrix", async () => {
    const { generateMatrix } = await import("./matrix-generator");

    const config = {
      os: ["ubuntu-22.04"],
      nodeVersion: ["18"],
      include: [
        { os: "windows-2022", nodeVersion: "18", label: "windows-test" }
      ],
    };

    const matrix = generateMatrix(config);

    expect(matrix.include.length).toBe(2); // 1 base + 1 include
    expect(matrix.include[1].label).toBe("windows-test");
  });
});

// Test 3: Matrix with exclude rules
describe("Exclude rules", () => {
  it("should exclude combinations from the matrix", async () => {
    const { generateMatrix } = await import("./matrix-generator");

    const config = {
      os: ["ubuntu-22.04", "macos-14"],
      nodeVersion: ["18", "20"],
      exclude: [
        { os: "macos-14", nodeVersion: "18" }
      ],
    };

    const matrix = generateMatrix(config);

    expect(matrix.include.length).toBe(3); // 4 - 1 excluded
    expect(matrix.exclude).toBeDefined();
    expect(matrix.exclude.length).toBe(1);
  });
});

// Test 4: Max-parallel configuration
describe("Max-parallel configuration", () => {
  it("should include max-parallel in the matrix", async () => {
    const { generateMatrix } = await import("./matrix-generator");

    const config = {
      os: ["ubuntu-22.04"],
      nodeVersion: ["18"],
      maxParallel: 2,
    };

    const matrix = generateMatrix(config);

    expect(matrix.maxParallel).toBe(2);
  });
});

// Test 5: Fail-fast configuration
describe("Fail-fast configuration", () => {
  it("should include fail-fast in the matrix", async () => {
    const { generateMatrix } = await import("./matrix-generator");

    const config = {
      os: ["ubuntu-22.04"],
      nodeVersion: ["18"],
      failFast: false,
    };

    const matrix = generateMatrix(config);

    expect(matrix.failFast).toBe(false);
  });
});

// Test 6: Matrix size validation
describe("Matrix size validation", () => {
  it("should fail if matrix exceeds maxSize", async () => {
    const { generateMatrix } = await import("./matrix-generator");

    const config = {
      os: ["ubuntu-22.04", "macos-14", "windows-2022"],
      nodeVersion: ["16", "18", "20", "21"],
      maxSize: 5,
    };

    expect(() => generateMatrix(config)).toThrow();
  });
});

// Test 7: Feature flags as matrix dimension
describe("Feature flags", () => {
  it("should generate matrix with feature flags", async () => {
    const { generateMatrix } = await import("./matrix-generator");

    const config = {
      os: ["ubuntu-22.04"],
      nodeVersion: ["18"],
      features: ["default", "experimental"],
    };

    const matrix = generateMatrix(config);

    expect(matrix.include.length).toBe(2); // 1 OS × 1 version × 2 features
  });
});

// Test 8: Empty config should produce single entry matrix
describe("Edge cases", () => {
  it("should handle empty config", async () => {
    const { generateMatrix } = await import("./matrix-generator");

    const config = {
      os: ["ubuntu-22.04"],
    };

    const matrix = generateMatrix(config);

    expect(matrix.include.length).toBeGreaterThan(0);
  });

  it("should validate all required combinations are present", async () => {
    const { generateMatrix } = await import("./matrix-generator");

    const config = {
      os: ["ubuntu-22.04", "macos-14"],
      nodeVersion: ["18", "20"],
    };

    const matrix = generateMatrix(config);

    const combinations = matrix.include.map((item: any) =>
      `${item.os}-${item.nodeVersion}`
    );

    expect(combinations).toContain("ubuntu-22.04-18");
    expect(combinations).toContain("ubuntu-22.04-20");
    expect(combinations).toContain("macos-14-18");
    expect(combinations).toContain("macos-14-20");
  });
});
