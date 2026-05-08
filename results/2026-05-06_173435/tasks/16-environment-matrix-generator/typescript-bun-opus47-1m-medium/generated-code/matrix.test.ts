// Tests for the build-matrix generator. Written before the implementation
// to follow red/green TDD: each describe block pinned new behavior, the test
// failed, then `generateMatrix` was extended just enough to pass.
import { describe, expect, test } from "bun:test";
import { generateMatrix, MatrixError, type MatrixConfig } from "./matrix";

describe("generateMatrix - cartesian product", () => {
  test("expands a single axis", () => {
    const result = generateMatrix({ axes: { os: ["linux", "mac"] } });
    expect(result.combinations).toEqual([{ os: "linux" }, { os: "mac" }]);
    expect(result.total).toBe(2);
  });

  test("expands the cartesian product of multiple axes", () => {
    const result = generateMatrix({
      axes: { os: ["linux", "mac"], node: ["18", "20"] },
    });
    expect(result.combinations).toEqual([
      { os: "linux", node: "18" },
      { os: "linux", node: "20" },
      { os: "mac", node: "18" },
      { os: "mac", node: "20" },
    ]);
    expect(result.total).toBe(4);
  });

  test("preserves boolean and number axis values", () => {
    const result = generateMatrix({
      axes: { node: [18, 20], experimental: [false, true] },
    });
    expect(result.total).toBe(4);
    expect(result.combinations[0]).toEqual({ node: 18, experimental: false });
  });
});

describe("generateMatrix - exclude rules", () => {
  test("removes combinations matching an exclude rule", () => {
    const result = generateMatrix({
      axes: { os: ["linux", "mac"], node: ["18", "20"] },
      exclude: [{ os: "mac", node: "18" }],
    });
    expect(result.combinations).toEqual([
      { os: "linux", node: "18" },
      { os: "linux", node: "20" },
      { os: "mac", node: "20" },
    ]);
    expect(result.total).toBe(3);
  });

  test("partial exclude rule strips every matching row", () => {
    const result = generateMatrix({
      axes: { os: ["linux", "mac"], node: ["18", "20"] },
      exclude: [{ os: "mac" }],
    });
    expect(result.combinations).toEqual([
      { os: "linux", node: "18" },
      { os: "linux", node: "20" },
    ]);
  });
});

describe("generateMatrix - include rules", () => {
  test("appends extra combinations that aren't in the product", () => {
    const result = generateMatrix({
      axes: { os: ["linux"], node: ["18"] },
      include: [{ os: "windows", node: "20", experimental: true }],
    });
    expect(result.combinations).toEqual([
      { os: "linux", node: "18" },
      { os: "windows", node: "20", experimental: true },
    ]);
  });

  test("merges extra keys onto matching base combinations without duplicating", () => {
    // GitHub semantics: an include whose keys all match an existing combo
    // augments it with the remaining keys instead of adding a new row.
    const result = generateMatrix({
      axes: { os: ["linux", "mac"], node: ["18", "20"] },
      include: [{ os: "linux", node: "20", extra: "yes" }],
    });
    expect(result.total).toBe(4);
    expect(result.combinations).toContainEqual({
      os: "linux",
      node: "20",
      extra: "yes",
    });
  });
});

describe("generateMatrix - validation", () => {
  test("throws when matrix exceeds maxSize", () => {
    expect(() =>
      generateMatrix({
        axes: { a: [1, 2, 3], b: [1, 2, 3] },
        maxSize: 5,
      }),
    ).toThrow(MatrixError);
  });

  test("throws on empty axis", () => {
    expect(() => generateMatrix({ axes: { os: [] } })).toThrow(MatrixError);
  });

  test("throws when no axes provided", () => {
    expect(() => generateMatrix({ axes: {} })).toThrow(MatrixError);
  });
});

describe("generateMatrix - GitHub Actions output shape", () => {
  test("output object has matrix, max-parallel, fail-fast", () => {
    const config: MatrixConfig = {
      axes: { os: ["linux"], node: ["20"] },
      maxParallel: 2,
      failFast: false,
    };
    const result = generateMatrix(config);
    expect(result["max-parallel"]).toBe(2);
    expect(result["fail-fast"]).toBe(false);
    expect(result.matrix).toEqual({ os: ["linux"], node: ["20"] });
  });

  test("max-parallel and fail-fast omitted when not configured", () => {
    const result = generateMatrix({ axes: { os: ["linux"] } });
    expect(result["max-parallel"]).toBeUndefined();
    expect(result["fail-fast"]).toBeUndefined();
  });

  test("emits include/exclude back into matrix when present", () => {
    const result = generateMatrix({
      axes: { os: ["linux"] },
      include: [{ os: "windows" }],
      exclude: [{ os: "mac" }],
    });
    expect(result.matrix.include).toEqual([{ os: "windows" }]);
    expect(result.matrix.exclude).toEqual([{ os: "mac" }]);
  });
});
