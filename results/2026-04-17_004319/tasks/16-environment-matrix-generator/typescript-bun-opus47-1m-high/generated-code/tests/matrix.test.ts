// Red/green TDD tests for the environment matrix generator.
// Each `describe` block corresponds to a distinct capability added during TDD.
import { describe, test, expect } from "bun:test";
import { generateMatrix, MatrixConfigError } from "../src/matrix";

describe("cartesian product over axes", () => {
  test("expands two axes into all combinations", () => {
    const out = generateMatrix({
      axes: {
        os: ["ubuntu-latest", "windows-latest"],
        node: ["18", "20"],
      },
    });

    expect(out.total).toBe(4);
    expect(out.strategy.matrix.include).toEqual([
      { os: "ubuntu-latest", node: "18" },
      { os: "ubuntu-latest", node: "20" },
      { os: "windows-latest", node: "18" },
      { os: "windows-latest", node: "20" },
    ]);
  });

  test("single axis yields one entry per value", () => {
    const out = generateMatrix({ axes: { os: ["ubuntu-latest"] } });
    expect(out.total).toBe(1);
    expect(out.strategy.matrix.include).toEqual([{ os: "ubuntu-latest" }]);
  });

  test("three axes multiply correctly", () => {
    const out = generateMatrix({
      axes: { a: [1, 2], b: ["x", "y"], c: [true, false] },
    });
    expect(out.total).toBe(8);
  });
});

describe("exclude rules", () => {
  test("removes combinations that match all exclude keys", () => {
    const out = generateMatrix({
      axes: {
        os: ["ubuntu-latest", "windows-latest"],
        node: ["18", "20"],
      },
      exclude: [{ os: "windows-latest", node: "18" }],
    });

    expect(out.total).toBe(3);
    expect(out.strategy.matrix.include).not.toContainEqual({
      os: "windows-latest",
      node: "18",
    });
  });

  test("partial exclude key matches all combinations sharing that value", () => {
    const out = generateMatrix({
      axes: { os: ["ubuntu-latest", "windows-latest"], node: ["18", "20"] },
      exclude: [{ os: "windows-latest" }],
    });
    expect(out.total).toBe(2);
    expect(
      out.strategy.matrix.include.every((c) => c.os === "ubuntu-latest"),
    ).toBe(true);
  });
});

describe("include rules", () => {
  test("appends an entry that is not in the cartesian product", () => {
    const out = generateMatrix({
      axes: { os: ["ubuntu-latest"], node: ["18"] },
      include: [{ os: "macos-latest", node: "21", experimental: true }],
    });

    expect(out.total).toBe(2);
    expect(out.strategy.matrix.include).toContainEqual({
      os: "macos-latest",
      node: "21",
      experimental: true,
    });
  });

  test("extends matching combinations with extra fields", () => {
    // GitHub semantics: an include entry whose keys all match an existing
    // combination, and whose extra keys don't conflict, adds those extras.
    const out = generateMatrix({
      axes: { os: ["ubuntu-latest", "windows-latest"], node: ["18", "20"] },
      include: [{ os: "ubuntu-latest", extra: "yes" }],
    });

    expect(out.total).toBe(4);
    const ubuntu = out.strategy.matrix.include.filter(
      (c) => c.os === "ubuntu-latest",
    );
    expect(ubuntu.length).toBe(2);
    for (const c of ubuntu) expect(c.extra).toBe("yes");
  });
});

describe("strategy metadata", () => {
  test("defaults fail-fast to true and max-parallel to null", () => {
    const out = generateMatrix({ axes: { os: ["ubuntu-latest"] } });
    expect(out.strategy["fail-fast"]).toBe(true);
    expect(out.strategy["max-parallel"]).toBeNull();
  });

  test("propagates failFast and maxParallel", () => {
    const out = generateMatrix({
      axes: { os: ["ubuntu-latest"] },
      failFast: false,
      maxParallel: 3,
    });
    expect(out.strategy["fail-fast"]).toBe(false);
    expect(out.strategy["max-parallel"]).toBe(3);
  });
});

describe("validation", () => {
  test("throws MatrixConfigError when total exceeds maxSize", () => {
    expect(() =>
      generateMatrix({
        axes: { a: [1, 2, 3], b: [1, 2, 3] },
        maxSize: 4,
      }),
    ).toThrow(MatrixConfigError);
  });

  test("rejects negative maxParallel", () => {
    expect(() =>
      generateMatrix({
        axes: { os: ["ubuntu-latest"] },
        maxParallel: -1,
      }),
    ).toThrow(MatrixConfigError);
  });

  test("rejects empty axes", () => {
    expect(() => generateMatrix({ axes: {} })).toThrow(MatrixConfigError);
  });

  test("rejects axis with zero values", () => {
    expect(() => generateMatrix({ axes: { os: [] } })).toThrow(
      MatrixConfigError,
    );
  });
});
