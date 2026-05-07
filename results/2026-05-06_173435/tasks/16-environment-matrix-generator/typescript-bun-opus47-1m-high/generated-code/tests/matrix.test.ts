// Red-green-refactor TDD tests for the environment matrix generator.
// We grow the spec one piece at a time: cartesian product, include, exclude,
// max-parallel/fail-fast pass-through, and max-size validation.

import { describe, expect, test } from "bun:test";
import { generateMatrix, MatrixError, type MatrixConfig } from "../src/matrix";

describe("generateMatrix - cartesian product", () => {
  test("produces the cartesian product of all axes", () => {
    const config: MatrixConfig = {
      axes: {
        os: ["ubuntu-latest", "macos-latest"],
        node: ["18", "20"],
      },
    };
    const result = generateMatrix(config);

    // 2 OS x 2 node versions = 4 combinations
    expect(result.matrix.include).toHaveLength(4);
    expect(result.matrix.include).toContainEqual({ os: "ubuntu-latest", node: "18" });
    expect(result.matrix.include).toContainEqual({ os: "ubuntu-latest", node: "20" });
    expect(result.matrix.include).toContainEqual({ os: "macos-latest", node: "18" });
    expect(result.matrix.include).toContainEqual({ os: "macos-latest", node: "20" });
  });

  test("supports a third axis (feature flags)", () => {
    const config: MatrixConfig = {
      axes: {
        os: ["ubuntu-latest"],
        node: ["20"],
        feature: ["a", "b", "c"],
      },
    };
    const result = generateMatrix(config);
    expect(result.matrix.include).toHaveLength(3);
  });

  test("returns empty include when an axis is empty", () => {
    const config: MatrixConfig = {
      axes: { os: [], node: ["20"] },
    };
    const result = generateMatrix(config);
    expect(result.matrix.include).toEqual([]);
  });

  test("rejects an empty axes map", () => {
    expect(() => generateMatrix({ axes: {} })).toThrow(MatrixError);
  });
});

describe("generateMatrix - include rule", () => {
  test("appends extra combinations declared via include", () => {
    const config: MatrixConfig = {
      axes: { os: ["ubuntu-latest"], node: ["20"] },
      include: [{ os: "windows-latest", node: "20", experimental: true }],
    };
    const result = generateMatrix(config);
    expect(result.matrix.include).toHaveLength(2);
    expect(result.matrix.include).toContainEqual({
      os: "windows-latest",
      node: "20",
      experimental: true,
    });
  });

  test("does not duplicate an include that matches an existing combo", () => {
    const config: MatrixConfig = {
      axes: { os: ["ubuntu-latest"], node: ["20"] },
      include: [{ os: "ubuntu-latest", node: "20" }],
    };
    const result = generateMatrix(config);
    expect(result.matrix.include).toHaveLength(1);
  });
});

describe("generateMatrix - exclude rule", () => {
  test("removes combinations matching all exclude keys", () => {
    const config: MatrixConfig = {
      axes: {
        os: ["ubuntu-latest", "macos-latest"],
        node: ["18", "20"],
      },
      exclude: [{ os: "macos-latest", node: "18" }],
    };
    const result = generateMatrix(config);
    expect(result.matrix.include).toHaveLength(3);
    expect(result.matrix.include).not.toContainEqual({
      os: "macos-latest",
      node: "18",
    });
  });

  test("partial exclude (one key) removes everything matching that key", () => {
    const config: MatrixConfig = {
      axes: {
        os: ["ubuntu-latest", "macos-latest"],
        node: ["18", "20"],
      },
      exclude: [{ os: "macos-latest" }],
    };
    const result = generateMatrix(config);
    expect(result.matrix.include).toHaveLength(2);
    expect(result.matrix.include.every((c) => c.os === "ubuntu-latest")).toBe(true);
  });
});

describe("generateMatrix - strategy options", () => {
  test("passes max-parallel and fail-fast through to the strategy block", () => {
    const config: MatrixConfig = {
      axes: { os: ["ubuntu-latest"], node: ["20"] },
      maxParallel: 4,
      failFast: false,
    };
    const result = generateMatrix(config);
    expect(result.maxParallel).toBe(4);
    expect(result.failFast).toBe(false);
  });

  test("fail-fast defaults to true (GitHub default)", () => {
    const config: MatrixConfig = {
      axes: { os: ["ubuntu-latest"], node: ["20"] },
    };
    const result = generateMatrix(config);
    expect(result.failFast).toBe(true);
  });
});

describe("generateMatrix - max-size validation", () => {
  test("throws MatrixError when matrix exceeds max-size", () => {
    const config: MatrixConfig = {
      axes: {
        os: ["ubuntu-latest", "macos-latest", "windows-latest"],
        node: ["16", "18", "20"],
      },
      maxSize: 5,
    };
    expect(() => generateMatrix(config)).toThrow(/exceeds max-size/);
  });

  test("accepts a matrix exactly at max-size", () => {
    const config: MatrixConfig = {
      axes: { os: ["ubuntu-latest"], node: ["18", "20"] },
      maxSize: 2,
    };
    const result = generateMatrix(config);
    expect(result.matrix.include).toHaveLength(2);
  });

  test("GitHub's hard ceiling of 256 jobs is enforced when no maxSize given", () => {
    // 257 combinations - over GitHub's documented 256-job ceiling.
    const big = Array.from({ length: 257 }, (_, i) => String(i));
    expect(() =>
      generateMatrix({ axes: { n: big } }),
    ).toThrow(/256/);
  });
});

describe("generateMatrix - error messages", () => {
  test("MatrixError includes a meaningful message", () => {
    try {
      generateMatrix({ axes: {} });
      throw new Error("expected throw");
    } catch (err) {
      expect(err).toBeInstanceOf(MatrixError);
      expect((err as MatrixError).message).toMatch(/at least one axis/i);
    }
  });
});
