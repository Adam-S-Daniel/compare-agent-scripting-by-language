import { describe, expect, test } from "bun:test";
import { assignLabels, type Config } from "../../pr-label-assigner.ts";

// TDD: start from the smallest behaviours and grow outward.
// Each test in this file targets one rule of the public assignLabels API.

describe("assignLabels", () => {
  test("returns no labels for an empty file list", () => {
    const config: Config = {
      rules: [{ label: "documentation", patterns: ["docs/**"] }],
    };
    expect(assignLabels(config, [])).toEqual([]);
  });

  test("applies a single label when one file matches one rule", () => {
    const config: Config = {
      rules: [{ label: "documentation", patterns: ["docs/**"] }],
    };
    expect(assignLabels(config, ["docs/intro.md"])).toEqual(["documentation"]);
  });

  test("applies multiple labels when one file matches several rules", () => {
    const config: Config = {
      rules: [
        { label: "api", patterns: ["src/api/**"] },
        { label: "tests", patterns: ["**/*.test.*"] },
      ],
    };
    const out = assignLabels(config, ["src/api/users.test.ts"]);
    expect(out.sort()).toEqual(["api", "tests"]);
  });

  test("deduplicates labels across multiple files matching the same rule", () => {
    const config: Config = {
      rules: [{ label: "documentation", patterns: ["docs/**", "*.md"] }],
    };
    const out = assignLabels(config, ["docs/a.md", "docs/b.md", "README.md"]);
    expect(out).toEqual(["documentation"]);
  });

  test("returns no labels when nothing matches", () => {
    const config: Config = {
      rules: [{ label: "documentation", patterns: ["docs/**"] }],
    };
    expect(assignLabels(config, ["src/foo.ts", "Makefile"])).toEqual([]);
  });

  test("supports multiple patterns in a single rule (OR semantics)", () => {
    const config: Config = {
      rules: [
        {
          label: "ci",
          patterns: [".github/workflows/**", "**/*.yml", "Dockerfile"],
        },
      ],
    };
    expect(assignLabels(config, ["Dockerfile"])).toEqual(["ci"]);
    expect(assignLabels(config, [".github/workflows/foo.yml"])).toEqual(["ci"]);
    expect(assignLabels(config, ["k8s/deploy.yaml"])).toEqual([]);
  });

  test("output is sorted by priority desc, then label name asc", () => {
    const config: Config = {
      rules: [
        { label: "tests", patterns: ["**/*.test.*"], priority: 5 },
        { label: "api", patterns: ["src/api/**"], priority: 20 },
        { label: "documentation", patterns: ["docs/**"], priority: 20 },
      ],
    };
    const out = assignLabels(config, [
      "src/api/users.ts",
      "docs/readme.md",
      "src/api/users.test.ts",
    ]);
    // priority: api=20, documentation=20, tests=5 -> alphabetical within same priority
    expect(out).toEqual(["api", "documentation", "tests"]);
  });

  test("exclusive group keeps only the highest-priority winner", () => {
    const config: Config = {
      rules: [
        { label: "size/small", patterns: ["small/**"], priority: 1 },
        { label: "size/large", patterns: ["large/**"], priority: 10 },
        { label: "tests", patterns: ["**/*.test.*"], priority: 5 },
      ],
      exclusiveGroups: [{ labels: ["size/small", "size/large"] }],
    };
    const out = assignLabels(config, [
      "small/a.ts",
      "large/b.ts",
      "x.test.ts",
    ]);
    // size/large beats size/small; tests is unaffected
    expect(out).toEqual(["size/large", "tests"]);
  });

  test("exclusive group with ties: alphabetical tiebreak among winners", () => {
    const config: Config = {
      rules: [
        { label: "size/small", patterns: ["small/**"], priority: 5 },
        { label: "size/large", patterns: ["large/**"], priority: 5 },
      ],
      exclusiveGroups: [{ labels: ["size/small", "size/large"] }],
    };
    const out = assignLabels(config, ["small/a.ts", "large/b.ts"]);
    expect(out).toEqual(["size/large"]);
  });
});
