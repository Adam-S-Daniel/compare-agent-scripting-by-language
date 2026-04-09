// matrix-generator.test.ts
// TDD: RED -> GREEN -> REFACTOR
// Tests for the GitHub Actions environment matrix generator.
// Write failing tests first, then implement to make them pass.

import { describe, test, expect } from "bun:test";
import { generateMatrix } from "./matrix-generator";

// ============================================================
// RED: First failing test — basic cartesian product generation
// ============================================================
describe("generateMatrix - basic cartesian product", () => {
  test("generates matrix with a single dimension", () => {
    const result = generateMatrix({
      matrix: { os: ["ubuntu-latest", "windows-latest"] },
    });
    expect(result.matrix.os).toEqual(["ubuntu-latest", "windows-latest"]);
    // Default fail-fast must be false (GitHub Actions default)
    expect(result["fail-fast"]).toBe(false);
    // No max-parallel unless specified
    expect(result["max-parallel"]).toBeUndefined();
  });

  test("generates matrix preserving all dimensions", () => {
    const result = generateMatrix({
      matrix: {
        os: ["ubuntu-latest", "windows-latest"],
        "node-version": ["18", "20"],
      },
    });
    expect(result.matrix.os).toEqual(["ubuntu-latest", "windows-latest"]);
    expect(result.matrix["node-version"]).toEqual(["18", "20"]);
    expect(result["fail-fast"]).toBe(false);
  });

  test("handles empty matrix dimensions gracefully", () => {
    const result = generateMatrix({ matrix: {} });
    expect(result.matrix).toEqual({});
    expect(result["fail-fast"]).toBe(false);
  });
});

// ============================================================
// RED: Include rules
// ============================================================
describe("generateMatrix - include rules", () => {
  test("adds include entries to the matrix output", () => {
    const result = generateMatrix({
      matrix: { os: ["ubuntu-latest"], "node-version": ["18"] },
      include: [{ os: "macos-latest", "node-version": "20" }],
    });
    expect(result.matrix["include"]).toEqual([
      { os: "macos-latest", "node-version": "20" },
    ]);
  });

  test("does not add include key when include array is empty", () => {
    const result = generateMatrix({
      matrix: { os: ["ubuntu-latest"] },
      include: [],
    });
    expect(result.matrix["include"]).toBeUndefined();
  });

  test("supports multiple include entries", () => {
    const result = generateMatrix({
      matrix: { os: ["ubuntu-latest"] },
      include: [
        { os: "macos-latest", feature: "arm64" },
        { os: "windows-latest", feature: "experimental" },
      ],
    });
    expect(result.matrix["include"]).toHaveLength(2);
  });
});

// ============================================================
// RED: Exclude rules
// ============================================================
describe("generateMatrix - exclude rules", () => {
  test("adds exclude entries to the matrix output", () => {
    const result = generateMatrix({
      matrix: {
        os: ["ubuntu-latest", "windows-latest"],
        "node-version": ["18", "20"],
      },
      exclude: [{ os: "windows-latest", "node-version": "18" }],
    });
    expect(result.matrix["exclude"]).toEqual([
      { os: "windows-latest", "node-version": "18" },
    ]);
  });

  test("does not add exclude key when exclude array is empty", () => {
    const result = generateMatrix({
      matrix: { os: ["ubuntu-latest"] },
      exclude: [],
    });
    expect(result.matrix["exclude"]).toBeUndefined();
  });

  test("reduces the effective matrix size via excludes", () => {
    // 3 os × 2 node = 6 base, exclude 1 = 5 effective
    // maxSize 5 should succeed; maxSize 4 should fail
    expect(() =>
      generateMatrix({
        matrix: {
          os: ["ubuntu-latest", "windows-latest", "macos-latest"],
          "node-version": ["18", "20"],
        },
        exclude: [{ os: "windows-latest", "node-version": "18" }],
        maxSize: 5,
      })
    ).not.toThrow();
  });
});

// ============================================================
// RED: max-parallel configuration
// ============================================================
describe("generateMatrix - max-parallel", () => {
  test("sets max-parallel in output when specified", () => {
    const result = generateMatrix({
      matrix: { os: ["ubuntu-latest", "windows-latest"] },
      maxParallel: 2,
    });
    expect(result["max-parallel"]).toBe(2);
  });

  test("omits max-parallel key when not specified", () => {
    const result = generateMatrix({ matrix: { os: ["ubuntu-latest"] } });
    expect(result["max-parallel"]).toBeUndefined();
  });

  test("accepts max-parallel of 1 (fully sequential)", () => {
    const result = generateMatrix({
      matrix: { os: ["ubuntu-latest", "windows-latest"] },
      maxParallel: 1,
    });
    expect(result["max-parallel"]).toBe(1);
  });
});

// ============================================================
// RED: fail-fast configuration
// ============================================================
describe("generateMatrix - fail-fast", () => {
  test("sets fail-fast to true when specified", () => {
    const result = generateMatrix({
      matrix: { os: ["ubuntu-latest"] },
      failFast: true,
    });
    expect(result["fail-fast"]).toBe(true);
  });

  test("sets fail-fast to false when explicitly false", () => {
    const result = generateMatrix({
      matrix: { os: ["ubuntu-latest"] },
      failFast: false,
    });
    expect(result["fail-fast"]).toBe(false);
  });

  test("defaults fail-fast to false when not specified", () => {
    const result = generateMatrix({ matrix: { os: ["ubuntu-latest"] } });
    expect(result["fail-fast"]).toBe(false);
  });
});

// ============================================================
// RED: Matrix size validation
// ============================================================
describe("generateMatrix - size validation", () => {
  test("throws when cartesian product exceeds default limit of 256", () => {
    // 3 × 5 × 4 × 5 = 300 — exceeds 256
    expect(() =>
      generateMatrix({
        matrix: {
          os: ["ubuntu", "windows", "macos"],
          "node-version": ["14", "16", "18", "20", "22"],
          arch: ["x64", "arm64", "x86", "arm"],
          build: ["debug", "release", "staging", "canary", "nightly"],
        },
      })
    ).toThrow("exceeds maximum allowed size");
  });

  test("throws when matrix exceeds a custom maxSize", () => {
    // 3 combinations, maxSize 2 → should throw
    expect(() =>
      generateMatrix({
        matrix: { os: ["ubuntu-latest", "windows-latest", "macos-latest"] },
        maxSize: 2,
      })
    ).toThrow("exceeds maximum allowed size");
  });

  test("accepts matrix at exactly the maxSize limit", () => {
    expect(() =>
      generateMatrix({
        matrix: { os: ["ubuntu-latest", "windows-latest"] },
        maxSize: 2,
      })
    ).not.toThrow();
  });

  test("counts new-combination includes in size calculation", () => {
    // base: 1 combo, 2 includes that each introduce a new combination = 3 total
    // maxSize 2 should throw
    expect(() =>
      generateMatrix({
        matrix: { os: ["ubuntu-latest"] },
        include: [
          { os: "windows-latest", extra: "val1" },
          { os: "macos-latest", extra: "val2" },
        ],
        maxSize: 2,
      })
    ).toThrow("exceeds maximum allowed size");
  });

  test("does not count matching includes as additional jobs", () => {
    // include matches existing combo (ubuntu-latest), just adds a property → still 1 job
    expect(() =>
      generateMatrix({
        matrix: { os: ["ubuntu-latest"] },
        include: [{ os: "ubuntu-latest", extra: "val" }],
        maxSize: 1,
      })
    ).not.toThrow();
  });
});

// ============================================================
// RED: Complete output format (GitHub Actions strategy object)
// ============================================================
describe("generateMatrix - full strategy output format", () => {
  test("produces correct GitHub Actions strategy structure", () => {
    const result = generateMatrix({
      matrix: {
        os: ["ubuntu-latest", "windows-latest"],
        "node-version": ["18", "20"],
      },
      include: [{ os: "macos-latest", "node-version": "20" }],
      exclude: [{ os: "windows-latest", "node-version": "18" }],
      maxParallel: 4,
      failFast: true,
    });

    expect(result).toMatchObject({
      matrix: {
        os: ["ubuntu-latest", "windows-latest"],
        "node-version": ["18", "20"],
        include: [{ os: "macos-latest", "node-version": "20" }],
        exclude: [{ os: "windows-latest", "node-version": "18" }],
      },
      "max-parallel": 4,
      "fail-fast": true,
    });
  });

  test("produces valid JSON-serializable output", () => {
    const result = generateMatrix({
      matrix: { os: ["ubuntu-latest"], language: ["python", "node"] },
      failFast: false,
      maxParallel: 3,
    });
    // Should round-trip through JSON without errors
    const json = JSON.stringify(result);
    const parsed = JSON.parse(json);
    expect(parsed["fail-fast"]).toBe(false);
    expect(parsed["max-parallel"]).toBe(3);
  });
});
