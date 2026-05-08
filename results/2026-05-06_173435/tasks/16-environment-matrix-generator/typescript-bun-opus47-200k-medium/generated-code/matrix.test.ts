import { describe, expect, test } from "bun:test";
import { generateMatrix, type MatrixConfig } from "./matrix";

describe("generateMatrix", () => {
  test("generates cartesian product of axes", () => {
    const config: MatrixConfig = {
      axes: {
        os: ["ubuntu-latest", "windows-latest"],
        node: ["18", "20"],
      },
    };
    const result = generateMatrix(config);
    expect(result.include).toHaveLength(4);
    expect(result.include).toContainEqual({ os: "ubuntu-latest", node: "18" });
    expect(result.include).toContainEqual({ os: "ubuntu-latest", node: "20" });
    expect(result.include).toContainEqual({ os: "windows-latest", node: "18" });
    expect(result.include).toContainEqual({ os: "windows-latest", node: "20" });
  });

  test("handles three axes", () => {
    const config: MatrixConfig = {
      axes: {
        os: ["linux", "mac"],
        node: ["20"],
        feature: ["a", "b"],
      },
    };
    const result = generateMatrix(config);
    expect(result.include).toHaveLength(4);
  });

  test("applies include rules to add extra entries", () => {
    const config: MatrixConfig = {
      axes: { os: ["linux"], node: ["20"] },
      include: [{ os: "windows", node: "18", experimental: true }],
    };
    const result = generateMatrix(config);
    expect(result.include).toHaveLength(2);
    expect(result.include).toContainEqual({
      os: "windows",
      node: "18",
      experimental: true,
    });
  });

  test("include rule augments matching entry with extra fields", () => {
    const config: MatrixConfig = {
      axes: { os: ["linux", "mac"], node: ["20"] },
      include: [{ os: "linux", flag: "extra" }],
    };
    const result = generateMatrix(config);
    expect(result.include).toHaveLength(2);
    expect(result.include).toContainEqual({ os: "linux", node: "20", flag: "extra" });
    expect(result.include).toContainEqual({ os: "mac", node: "20" });
  });

  test("applies exclude rules to remove matching entries", () => {
    const config: MatrixConfig = {
      axes: { os: ["linux", "windows"], node: ["18", "20"] },
      exclude: [{ os: "windows", node: "18" }],
    };
    const result = generateMatrix(config);
    expect(result.include).toHaveLength(3);
    expect(result.include).not.toContainEqual({ os: "windows", node: "18" });
  });

  test("preserves max-parallel and fail-fast settings", () => {
    const config: MatrixConfig = {
      axes: { os: ["linux"] },
      maxParallel: 4,
      failFast: false,
    };
    const result = generateMatrix(config);
    expect(result["max-parallel"]).toBe(4);
    expect(result["fail-fast"]).toBe(false);
  });

  test("throws when matrix exceeds maxSize", () => {
    const config: MatrixConfig = {
      axes: { os: ["a", "b", "c"], node: ["1", "2", "3"] },
      maxSize: 5,
    };
    expect(() => generateMatrix(config)).toThrow(/exceeds maximum size/);
  });

  test("throws on empty axes", () => {
    const config: MatrixConfig = { axes: {} };
    expect(() => generateMatrix(config)).toThrow(/at least one axis/);
  });

  test("throws when an axis is empty", () => {
    const config: MatrixConfig = { axes: { os: [] } };
    expect(() => generateMatrix(config)).toThrow(/empty/);
  });

  test("output JSON has expected structure", () => {
    const config: MatrixConfig = {
      axes: { os: ["linux"], node: ["20"] },
      maxParallel: 2,
      failFast: true,
    };
    const result = generateMatrix(config);
    const json = JSON.stringify(result);
    const parsed = JSON.parse(json);
    expect(parsed.include).toBeArray();
    expect(parsed["max-parallel"]).toBe(2);
    expect(parsed["fail-fast"]).toBe(true);
  });

  test("excludes apply before includes", () => {
    const config: MatrixConfig = {
      axes: { os: ["linux", "windows"], node: ["18", "20"] },
      exclude: [{ os: "windows" }],
      include: [{ os: "mac", node: "20" }],
    };
    const result = generateMatrix(config);
    // 4 - 2 (windows excluded) + 1 (mac added) = 3
    expect(result.include).toHaveLength(3);
    expect(result.include.find((e) => e.os === "windows")).toBeUndefined();
    expect(result.include).toContainEqual({ os: "mac", node: "20" });
  });
});
