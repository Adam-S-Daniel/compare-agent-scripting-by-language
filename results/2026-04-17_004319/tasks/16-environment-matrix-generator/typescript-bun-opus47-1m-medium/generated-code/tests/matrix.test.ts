import { describe, test, expect } from "bun:test";
import { generateMatrix, type MatrixConfig } from "../src/matrix";

describe("generateMatrix", () => {
  test("generates cartesian product of axes", () => {
    const config: MatrixConfig = {
      axes: { os: ["ubuntu", "macos"], node: ["18", "20"] },
    };
    const result = generateMatrix(config);
    expect(result.matrix.include).toHaveLength(4);
    expect(result.matrix.include).toContainEqual({ os: "ubuntu", node: "18" });
    expect(result.matrix.include).toContainEqual({ os: "macos", node: "20" });
  });

  test("applies extra include entries", () => {
    const config: MatrixConfig = {
      axes: { os: ["ubuntu"], node: ["20"] },
      include: [{ os: "windows", node: "20", experimental: true }],
    };
    const result = generateMatrix(config);
    expect(result.matrix.include).toHaveLength(2);
    expect(result.matrix.include).toContainEqual({
      os: "windows",
      node: "20",
      experimental: true,
    });
  });

  test("applies exclude rules", () => {
    const config: MatrixConfig = {
      axes: { os: ["ubuntu", "macos"], node: ["18", "20"] },
      exclude: [{ os: "macos", node: "18" }],
    };
    const result = generateMatrix(config);
    expect(result.matrix.include).toHaveLength(3);
    expect(result.matrix.include).not.toContainEqual({
      os: "macos",
      node: "18",
    });
  });

  test("passes through max-parallel and fail-fast", () => {
    const config: MatrixConfig = {
      axes: { os: ["ubuntu"] },
      maxParallel: 4,
      failFast: false,
    };
    const result = generateMatrix(config);
    expect(result.matrix["max-parallel"]).toBe(4);
    expect(result.matrix["fail-fast"]).toBe(false);
  });

  test("throws when matrix exceeds maxSize", () => {
    const config: MatrixConfig = {
      axes: { a: ["1", "2", "3"], b: ["x", "y", "z"] },
      maxSize: 5,
    };
    expect(() => generateMatrix(config)).toThrow(/exceeds maximum size/);
  });

  test("throws on empty axes", () => {
    const config: MatrixConfig = { axes: {} };
    expect(() => generateMatrix(config)).toThrow(/at least one axis/);
  });

  test("throws on empty axis values", () => {
    const config: MatrixConfig = { axes: { os: [] } };
    expect(() => generateMatrix(config)).toThrow(/must have at least one value/);
  });

  test("merges feature flags into every combo", () => {
    const config: MatrixConfig = {
      axes: { os: ["ubuntu", "macos"] },
      features: { coverage: true, lint: false },
    };
    const result = generateMatrix(config);
    for (const entry of result.matrix.include) {
      expect(entry.coverage).toBe(true);
      expect(entry.lint).toBe(false);
    }
  });

  test("deduplicates entries that match include already produced", () => {
    const config: MatrixConfig = {
      axes: { os: ["ubuntu"], node: ["20"] },
      include: [{ os: "ubuntu", node: "20" }],
    };
    const result = generateMatrix(config);
    expect(result.matrix.include).toHaveLength(1);
  });
});
