// TDD tests for the environment matrix generator.
// Written BEFORE the implementation — each test starts red, then we make it green.

import { describe, it, expect } from "bun:test";
import { generateMatrix, type MatrixConfig } from "./matrix-generator";

// ── RED PHASE 1: Basic matrix generation ──────────────────────────────────────
describe("generateMatrix - basic cartesian product", () => {
  it("generates os x node version matrix with correct strategy shape", () => {
    const config: MatrixConfig = {
      os: ["ubuntu-latest", "windows-latest"],
      language_versions: { node: ["18", "20"] },
      max_size: 10,
    };
    const result = generateMatrix(config);

    // The strategy.matrix should expose the axis arrays GitHub Actions expects
    expect(result.strategy.matrix.os).toEqual(["ubuntu-latest", "windows-latest"]);
    expect(result.strategy.matrix.node).toEqual(["18", "20"]);
    // fail-fast defaults to true
    expect(result.strategy["fail-fast"]).toBe(true);
    // max-parallel not set when not provided
    expect(result.strategy["max-parallel"]).toBeUndefined();
  });

  it("computes correct number of combinations (2 OS x 2 node = 4)", () => {
    const config: MatrixConfig = {
      os: ["ubuntu-latest", "windows-latest"],
      language_versions: { node: ["18", "20"] },
      max_size: 10,
    };
    const result = generateMatrix(config);
    // combinationCount is provided for validation / informational purposes
    expect(result.combinationCount).toBe(4);
  });

  it("supports fail_fast and max_parallel overrides", () => {
    const config: MatrixConfig = {
      os: ["ubuntu-latest"],
      language_versions: { node: ["20"] },
      fail_fast: false,
      max_parallel: 3,
      max_size: 10,
    };
    const result = generateMatrix(config);
    expect(result.strategy["fail-fast"]).toBe(false);
    expect(result.strategy["max-parallel"]).toBe(3);
  });
});

// ── RED PHASE 2: Feature flags ────────────────────────────────────────────────
describe("generateMatrix - feature flags", () => {
  it("includes feature flag dimensions in the matrix", () => {
    const config: MatrixConfig = {
      os: ["ubuntu-latest"],
      language_versions: { node: ["20"] },
      feature_flags: { experimental: [true, false] },
      max_size: 10,
    };
    const result = generateMatrix(config);
    expect(result.strategy.matrix.experimental).toEqual([true, false]);
    // 1 OS x 1 node x 2 flags = 2 combinations
    expect(result.combinationCount).toBe(2);
  });
});

// ── RED PHASE 3: Include / Exclude rules ──────────────────────────────────────
describe("generateMatrix - include/exclude rules", () => {
  it("passes include entries through to the matrix", () => {
    const config: MatrixConfig = {
      os: ["ubuntu-latest", "windows-latest"],
      language_versions: { node: ["18", "20"] },
      include: [{ os: "ubuntu-latest", node: "22", experimental: true }],
      max_size: 10,
    };
    const result = generateMatrix(config);
    expect(result.strategy.matrix.include).toEqual([
      { os: "ubuntu-latest", node: "22", experimental: true },
    ]);
  });

  it("passes exclude entries through to the matrix", () => {
    const config: MatrixConfig = {
      os: ["ubuntu-latest", "windows-latest"],
      language_versions: { node: ["18", "20"] },
      exclude: [{ os: "windows-latest", node: "18" }],
      max_size: 10,
    };
    const result = generateMatrix(config);
    expect(result.strategy.matrix.exclude).toEqual([
      { os: "windows-latest", node: "18" },
    ]);
    // Base combos = 4, minus 1 excluded = 3
    expect(result.combinationCount).toBe(3);
  });

  it("handles both include and exclude together", () => {
    const config: MatrixConfig = {
      os: ["ubuntu-latest", "windows-latest"],
      language_versions: { node: ["18", "20"] },
      include: [{ os: "ubuntu-latest", node: "22", experimental: true }],
      exclude: [{ os: "windows-latest", node: "18" }],
      max_parallel: 3,
      fail_fast: false,
      max_size: 10,
    };
    const result = generateMatrix(config);
    expect(result.strategy.matrix.include).toBeDefined();
    expect(result.strategy.matrix.exclude).toBeDefined();
    expect(result.strategy["max-parallel"]).toBe(3);
    expect(result.strategy["fail-fast"]).toBe(false);
    // 4 base - 1 excluded = 3, plus 1 include = 4 effective jobs
    expect(result.combinationCount).toBe(4);
  });
});

// ── RED PHASE 4: Max size validation ─────────────────────────────────────────
describe("generateMatrix - max size validation", () => {
  it("throws when the effective matrix size exceeds max_size", () => {
    const config: MatrixConfig = {
      os: ["ubuntu-latest", "windows-latest", "macos-latest"],
      language_versions: { node: ["16", "18", "20", "22"] },
      feature_flags: { experimental: [true, false] },
      max_size: 10, // 3 x 4 x 2 = 24, exceeds 10
    };
    expect(() => generateMatrix(config)).toThrow(
      /exceeds maximum/
    );
  });

  it("accepts matrix exactly at max_size", () => {
    const config: MatrixConfig = {
      os: ["ubuntu-latest", "windows-latest"],
      language_versions: { node: ["18", "20"] },
      max_size: 4, // exactly 2 x 2 = 4
    };
    expect(() => generateMatrix(config)).not.toThrow();
    const result = generateMatrix(config);
    expect(result.combinationCount).toBe(4);
  });

  it("uses a default max_size of 256 when not specified", () => {
    const config: MatrixConfig = {
      os: ["ubuntu-latest"],
      language_versions: { node: ["20"] },
    };
    expect(() => generateMatrix(config)).not.toThrow();
  });
});

// ── RED PHASE 5: Edge cases ───────────────────────────────────────────────────
describe("generateMatrix - edge cases", () => {
  it("handles config with no OS (only language versions)", () => {
    const config: MatrixConfig = {
      language_versions: { python: ["3.10", "3.11", "3.12"] },
      max_size: 10,
    };
    const result = generateMatrix(config);
    expect(result.strategy.matrix.python).toEqual(["3.10", "3.11", "3.12"]);
    expect(result.combinationCount).toBe(3);
  });

  it("handles multiple language version axes", () => {
    const config: MatrixConfig = {
      language_versions: { node: ["18", "20"], python: ["3.11"] },
      max_size: 10,
    };
    const result = generateMatrix(config);
    expect(result.strategy.matrix.node).toEqual(["18", "20"]);
    expect(result.strategy.matrix.python).toEqual(["3.11"]);
    expect(result.combinationCount).toBe(2);
  });
});
