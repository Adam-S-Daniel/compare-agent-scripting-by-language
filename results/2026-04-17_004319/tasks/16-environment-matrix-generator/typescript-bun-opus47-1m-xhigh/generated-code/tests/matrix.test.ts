// Unit tests for the environment matrix generator.
// Using Bun's built-in test runner. Red/green TDD: each test was written first
// to fail, then the implementation was added to make it pass.

import { describe, expect, test } from "bun:test";
import {
  generateMatrix,
  MatrixConfig,
  MatrixResult,
  MatrixError,
} from "../src/matrix.ts";

describe("generateMatrix - basic cross product", () => {
  test("expands a single dimension into one combination per value", () => {
    const config: MatrixConfig = {
      dimensions: { os: ["ubuntu-latest", "windows-latest"] },
    };
    const result: MatrixResult = generateMatrix(config);
    expect(result.matrix.include).toEqual([
      { os: "ubuntu-latest" },
      { os: "windows-latest" },
    ]);
    expect(result.totalSize).toBe(2);
  });

  test("expands multiple dimensions into the full cartesian product", () => {
    const config: MatrixConfig = {
      dimensions: {
        os: ["ubuntu-latest", "windows-latest"],
        node: [18, 20],
      },
    };
    const result = generateMatrix(config);
    // Order: last dimension varies fastest
    expect(result.matrix.include).toEqual([
      { os: "ubuntu-latest", node: 18 },
      { os: "ubuntu-latest", node: 20 },
      { os: "windows-latest", node: 18 },
      { os: "windows-latest", node: 20 },
    ]);
    expect(result.totalSize).toBe(4);
  });

  test("supports boolean feature flag dimensions", () => {
    const config: MatrixConfig = {
      dimensions: {
        os: ["ubuntu-latest"],
        experimental: [true, false],
      },
    };
    const result = generateMatrix(config);
    expect(result.matrix.include).toEqual([
      { os: "ubuntu-latest", experimental: true },
      { os: "ubuntu-latest", experimental: false },
    ]);
  });

  test("returns an empty matrix when dimensions is empty", () => {
    const config: MatrixConfig = { dimensions: {} };
    const result = generateMatrix(config);
    expect(result.matrix.include).toEqual([]);
    expect(result.totalSize).toBe(0);
  });
});

describe("generateMatrix - exclude rules", () => {
  test("removes combinations matching an exclude rule", () => {
    const config: MatrixConfig = {
      dimensions: {
        os: ["ubuntu-latest", "windows-latest"],
        node: [18, 20],
      },
      exclude: [{ os: "windows-latest", node: 18 }],
    };
    const result = generateMatrix(config);
    expect(result.matrix.include).toEqual([
      { os: "ubuntu-latest", node: 18 },
      { os: "ubuntu-latest", node: 20 },
      { os: "windows-latest", node: 20 },
    ]);
    expect(result.totalSize).toBe(3);
  });

  test("partial exclude matches all combos with those keys", () => {
    // Excluding just {os: windows-latest} removes all windows entries.
    const config: MatrixConfig = {
      dimensions: {
        os: ["ubuntu-latest", "windows-latest"],
        node: [18, 20],
      },
      exclude: [{ os: "windows-latest" }],
    };
    const result = generateMatrix(config);
    expect(result.matrix.include).toEqual([
      { os: "ubuntu-latest", node: 18 },
      { os: "ubuntu-latest", node: 20 },
    ]);
  });
});

describe("generateMatrix - include rules", () => {
  test("adds extra combinations that include specifies", () => {
    const config: MatrixConfig = {
      dimensions: { os: ["ubuntu-latest"], node: [20] },
      include: [{ os: "macos-latest", node: 20 }],
    };
    const result = generateMatrix(config);
    expect(result.matrix.include).toEqual([
      { os: "ubuntu-latest", node: 20 },
      { os: "macos-latest", node: 20 },
    ]);
    expect(result.totalSize).toBe(2);
  });

  test("include can augment an existing combination with extra keys", () => {
    // Matches GitHub Actions semantics: when an include entry matches an
    // existing combo on all its overlapping keys, the extra keys are merged
    // into that combo instead of creating a new one.
    const config: MatrixConfig = {
      dimensions: { os: ["ubuntu-latest", "windows-latest"], node: [20] },
      include: [{ os: "ubuntu-latest", extra: "flag" }],
    };
    const result = generateMatrix(config);
    expect(result.matrix.include).toEqual([
      { os: "ubuntu-latest", node: 20, extra: "flag" },
      { os: "windows-latest", node: 20 },
    ]);
  });

  test("include applied after exclude", () => {
    const config: MatrixConfig = {
      dimensions: { os: ["ubuntu-latest", "windows-latest"], node: [18, 20] },
      exclude: [{ os: "windows-latest" }],
      include: [{ os: "windows-latest", node: 20 }],
    };
    const result = generateMatrix(config);
    // Windows/20 was excluded, then re-added by include as a new standalone.
    expect(result.matrix.include).toEqual([
      { os: "ubuntu-latest", node: 18 },
      { os: "ubuntu-latest", node: 20 },
      { os: "windows-latest", node: 20 },
    ]);
  });
});

describe("generateMatrix - strategy fields", () => {
  test("propagates fail-fast setting", () => {
    const config: MatrixConfig = {
      dimensions: { os: ["ubuntu-latest"] },
      failFast: false,
    };
    const result = generateMatrix(config);
    expect(result["fail-fast"]).toBe(false);
  });

  test("propagates max-parallel setting", () => {
    const config: MatrixConfig = {
      dimensions: { os: ["ubuntu-latest", "windows-latest"] },
      maxParallel: 2,
    };
    const result = generateMatrix(config);
    expect(result["max-parallel"]).toBe(2);
  });

  test("omits strategy fields when not set", () => {
    const config: MatrixConfig = { dimensions: { os: ["ubuntu-latest"] } };
    const result = generateMatrix(config);
    expect(result["fail-fast"]).toBeUndefined();
    expect(result["max-parallel"]).toBeUndefined();
  });
});

describe("generateMatrix - validation", () => {
  test("throws MatrixError when matrix exceeds maxSize", () => {
    const config: MatrixConfig = {
      dimensions: {
        os: ["a", "b", "c"],
        node: [1, 2, 3],
        arch: ["x", "y", "z"],
      },
      maxSize: 10,
    };
    expect(() => generateMatrix(config)).toThrow(MatrixError);
    try {
      generateMatrix(config);
    } catch (err) {
      expect(err).toBeInstanceOf(MatrixError);
      expect((err as Error).message).toContain("27");
      expect((err as Error).message).toContain("10");
    }
  });

  test("maxSize counts final matrix after excludes and includes", () => {
    const config: MatrixConfig = {
      dimensions: { os: ["a", "b"], node: [1, 2] },
      exclude: [{ os: "a", node: 1 }],
      maxSize: 3,
    };
    // Final size is 3, equal to the limit — should not throw.
    const result = generateMatrix(config);
    expect(result.totalSize).toBe(3);
  });

  test("rejects a non-positive maxParallel", () => {
    const config: MatrixConfig = {
      dimensions: { os: ["a"] },
      maxParallel: 0,
    };
    expect(() => generateMatrix(config)).toThrow(MatrixError);
  });

  test("rejects an empty dimension value list", () => {
    const config: MatrixConfig = { dimensions: { os: [] } };
    expect(() => generateMatrix(config)).toThrow(MatrixError);
  });

  test("rejects non-array dimension values with a clear message", () => {
    // Force a bad shape past the type system to exercise runtime validation.
    const bad = { dimensions: { os: "ubuntu-latest" } } as unknown as MatrixConfig;
    expect(() => generateMatrix(bad)).toThrow(MatrixError);
  });
});

describe("generateMatrix - complex fixture", () => {
  test("combines OS, language versions, feature flags with all options", () => {
    const config: MatrixConfig = {
      dimensions: {
        os: ["ubuntu-latest", "windows-latest"],
        node: [18, 20],
        experimental: [false],
      },
      exclude: [{ os: "windows-latest", node: 18 }],
      include: [{ os: "macos-latest", node: 20, experimental: true }],
      maxParallel: 4,
      failFast: false,
      maxSize: 50,
    };
    const result = generateMatrix(config);
    expect(result.matrix.include).toEqual([
      { os: "ubuntu-latest", node: 18, experimental: false },
      { os: "ubuntu-latest", node: 20, experimental: false },
      { os: "windows-latest", node: 20, experimental: false },
      { os: "macos-latest", node: 20, experimental: true },
    ]);
    expect(result.totalSize).toBe(4);
    expect(result["fail-fast"]).toBe(false);
    expect(result["max-parallel"]).toBe(4);
  });
});
