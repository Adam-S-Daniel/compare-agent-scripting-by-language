import { describe, expect, test } from "bun:test";
import { generateMatrix } from "./matrix";

describe("generateMatrix", () => {
  test("produces cartesian product of axes", () => {
    const out = generateMatrix({
      axes: { os: ["ubuntu-latest", "macos-latest"], node: [18, 20] },
    });
    expect(out.combinations).toHaveLength(4);
    expect(out.matrix).toEqual({
      os: ["ubuntu-latest", "macos-latest"],
      node: [18, 20],
    });
  });

  test("excludes combos matching exclude rules", () => {
    const out = generateMatrix({
      axes: { os: ["ubuntu-latest", "windows-latest"], node: [18, 20] },
      exclude: [{ os: "windows-latest", node: 18 }],
    });
    expect(out.combinations).toHaveLength(3);
    expect(
      out.combinations.find(
        (c) => c.os === "windows-latest" && c.node === 18,
      ),
    ).toBeUndefined();
  });

  test("include extends matching combos with extra fields", () => {
    const out = generateMatrix({
      axes: { os: ["ubuntu-latest"], node: [18, 20] },
      include: [{ node: 20, experimental: true }],
    });
    const n20 = out.combinations.find((c) => c.node === 20);
    expect(n20?.experimental).toBe(true);
    const n18 = out.combinations.find((c) => c.node === 18);
    expect(n18?.experimental).toBeUndefined();
  });

  test("include with new combo adds standalone entry", () => {
    const out = generateMatrix({
      axes: { os: ["ubuntu-latest"], node: [18] },
      include: [{ os: "macos-latest", node: 21 }],
    });
    expect(out.combinations).toHaveLength(2);
    expect(
      out.combinations.find((c) => c.os === "macos-latest" && c.node === 21),
    ).toBeDefined();
  });

  test("maxParallel and failFast propagate", () => {
    const out = generateMatrix({
      axes: { os: ["ubuntu-latest"] },
      maxParallel: 2,
      failFast: false,
    });
    expect(out["max-parallel"]).toBe(2);
    expect(out["fail-fast"]).toBe(false);
  });

  test("maxSize violation throws", () => {
    expect(() =>
      generateMatrix({
        axes: { os: ["a", "b", "c"], node: [1, 2, 3] },
        maxSize: 5,
      }),
    ).toThrow(/exceeds maximum/);
  });

  test("feature flags axis supported", () => {
    const out = generateMatrix({
      axes: { os: ["ubuntu-latest"], tls: [true, false] },
    });
    expect(out.combinations).toHaveLength(2);
  });

  test("empty matrix after exclude throws", () => {
    expect(() =>
      generateMatrix({
        axes: { os: ["ubuntu-latest"] },
        exclude: [{ os: "ubuntu-latest" }],
      }),
    ).toThrow(/empty/);
  });

  test("missing axes throws", () => {
    expect(() =>
      // @ts-expect-error intentional
      generateMatrix({ axes: {} }),
    ).toThrow();
  });

  test("invalid maxParallel throws", () => {
    expect(() =>
      generateMatrix({ axes: { os: ["ubuntu-latest"] }, maxParallel: 0 }),
    ).toThrow(/positive integer/);
  });
});
