// TDD test suite for environment matrix generator
// Red/green cycle: each describe block tests one piece of functionality

import { describe, it, expect } from "bun:test";
import { generateMatrix, cartesianProduct } from "./matrix-generator";
import type { MatrixConfig } from "./matrix-generator";

// --- Test 1 (RED): basic Cartesian product ---
describe("cartesianProduct", () => {
  it("returns empty array for empty dimensions", () => {
    expect(cartesianProduct({})).toEqual([{}]);
  });

  it("returns single-key combos for one dimension", () => {
    const result = cartesianProduct({ os: ["ubuntu", "windows"] });
    expect(result).toHaveLength(2);
    expect(result).toContainEqual({ os: "ubuntu" });
    expect(result).toContainEqual({ os: "windows" });
  });

  it("generates 4 combinations for 2x2 dimensions", () => {
    const result = cartesianProduct({
      os: ["ubuntu", "windows"],
      "node-version": ["18", "20"],
    });
    expect(result).toHaveLength(4);
    expect(result).toContainEqual({ os: "ubuntu", "node-version": "18" });
    expect(result).toContainEqual({ os: "ubuntu", "node-version": "20" });
    expect(result).toContainEqual({ os: "windows", "node-version": "18" });
    expect(result).toContainEqual({ os: "windows", "node-version": "20" });
  });

  it("generates 12 combinations for 2x3x2 dimensions", () => {
    const result = cartesianProduct({
      os: ["ubuntu", "windows"],
      "node-version": ["18", "20", "22"],
      "python-version": ["3.10", "3.11"],
    });
    expect(result).toHaveLength(12);
  });
});

// --- Test 2 (RED): generateMatrix basic structure ---
describe("generateMatrix - basic output", () => {
  it("returns matrix with same dimensions as input", () => {
    const config: MatrixConfig = {
      dimensions: {
        os: ["ubuntu-latest", "windows-latest"],
        "node-version": ["18", "20"],
      },
    };
    const result = generateMatrix(config);
    expect(result.matrix.os).toEqual(["ubuntu-latest", "windows-latest"]);
    expect(result.matrix["node-version"]).toEqual(["18", "20"]);
  });

  it("counts combinations correctly for 2x2 matrix", () => {
    const config: MatrixConfig = {
      dimensions: {
        os: ["ubuntu-latest", "windows-latest"],
        "node-version": ["18", "20"],
      },
    };
    const result = generateMatrix(config);
    expect(result.combinations).toBe(4);
    expect(result.valid).toBe(true);
  });

  it("passes max-parallel and fail-fast through to output", () => {
    const config: MatrixConfig = {
      dimensions: { os: ["ubuntu-latest"] },
      maxParallel: 3,
      failFast: true,
    };
    const result = generateMatrix(config);
    expect(result.maxParallel).toBe(3);
    expect(result.failFast).toBe(true);
  });
});

// --- Test 3 (RED): exclude rules ---
describe("generateMatrix - exclude rules", () => {
  it("removes combinations matching exclude rule", () => {
    const config: MatrixConfig = {
      dimensions: {
        os: ["ubuntu-latest", "windows-latest", "macos-latest"],
        "node-version": ["18", "20"],
      },
      exclude: [{ os: "macos-latest", "node-version": "18" }],
    };
    const result = generateMatrix(config);
    // 3x2 = 6, minus 1 = 5
    expect(result.combinations).toBe(5);
    expect(result.valid).toBe(true);
  });

  it("removes multiple combinations with multiple exclude rules", () => {
    const config: MatrixConfig = {
      dimensions: {
        os: ["ubuntu-latest", "windows-latest"],
        "node-version": ["18", "20"],
      },
      exclude: [
        { os: "windows-latest", "node-version": "18" },
        { os: "windows-latest", "node-version": "20" },
      ],
    };
    const result = generateMatrix(config);
    // 2x2 = 4, minus 2 = 2
    expect(result.combinations).toBe(2);
  });

  it("excludes matrix entry still has exclude array in output", () => {
    const config: MatrixConfig = {
      dimensions: { os: ["ubuntu-latest"] },
      exclude: [{ os: "windows-latest" }],
    };
    const result = generateMatrix(config);
    expect(result.matrix.exclude).toEqual([{ os: "windows-latest" }]);
  });
});

// --- Test 4 (RED): include rules ---
describe("generateMatrix - include rules", () => {
  it("adds new combination for include with non-existent dimension value", () => {
    const config: MatrixConfig = {
      dimensions: {
        os: ["ubuntu-latest", "windows-latest"],
        "node-version": ["18", "20"],
      },
      include: [{ os: "ubuntu-latest", "node-version": "22", experimental: "true" }],
    };
    const result = generateMatrix(config);
    // 2x2 = 4, + 1 new include (22 not in dimensions) = 5
    expect(result.combinations).toBe(5);
  });

  it("does NOT add extra job for include that augments existing combo", () => {
    const config: MatrixConfig = {
      dimensions: {
        os: ["ubuntu-latest", "windows-latest"],
        "node-version": ["18", "20"],
      },
      include: [{ os: "ubuntu-latest", "node-version": "18", extra: "value" }],
    };
    const result = generateMatrix(config);
    // 2x2 = 4, include matches existing (ubuntu,18) so just augments it, no new job
    expect(result.combinations).toBe(4);
  });

  it("include array appears in matrix output", () => {
    const config: MatrixConfig = {
      dimensions: { os: ["ubuntu-latest"] },
      include: [{ os: "macos-latest", "node-version": "22" }],
    };
    const result = generateMatrix(config);
    expect(result.matrix.include).toEqual([{ os: "macos-latest", "node-version": "22" }]);
  });
});

// --- Test 5 (RED): max-size validation ---
describe("generateMatrix - max-size validation", () => {
  it("valid=true when combinations <= maxSize", () => {
    const config: MatrixConfig = {
      dimensions: {
        os: ["ubuntu-latest", "windows-latest"],
        "node-version": ["18", "20"],
      },
      maxSize: 4,
    };
    const result = generateMatrix(config);
    expect(result.valid).toBe(true);
    expect(result.errors).toBeUndefined();
  });

  it("valid=false and error message when combinations exceed maxSize", () => {
    const config: MatrixConfig = {
      dimensions: {
        os: ["ubuntu-latest", "windows-latest"],
        "node-version": ["18", "20", "22"],
        "python-version": ["3.10", "3.11", "3.12"],
      },
      maxSize: 5,
    };
    const result = generateMatrix(config);
    // 2x3x3 = 18, exceeds maxSize=5
    expect(result.valid).toBe(false);
    expect(result.errors).toBeDefined();
    expect(result.errors![0]).toContain("18");
    expect(result.errors![0]).toContain("5");
  });

  it("uses default maxSize of 256 when not specified", () => {
    const config: MatrixConfig = {
      dimensions: {
        os: ["ubuntu-latest"],
        "node-version": ["18"],
      },
    };
    const result = generateMatrix(config);
    expect(result.valid).toBe(true);
  });
});

// --- Test 6 (RED): edge cases ---
describe("generateMatrix - edge cases", () => {
  it("handles single dimension with one value", () => {
    const config: MatrixConfig = {
      dimensions: { os: ["ubuntu-latest"] },
    };
    const result = generateMatrix(config);
    expect(result.combinations).toBe(1);
    expect(result.valid).toBe(true);
  });

  it("handles empty dimensions object", () => {
    const config: MatrixConfig = {
      dimensions: {},
    };
    const result = generateMatrix(config);
    expect(result.combinations).toBe(0);
  });

  it("excludes that match no existing combo have no effect", () => {
    const config: MatrixConfig = {
      dimensions: { os: ["ubuntu-latest"] },
      exclude: [{ os: "windows-latest" }],
    };
    const result = generateMatrix(config);
    expect(result.combinations).toBe(1);
  });
});
