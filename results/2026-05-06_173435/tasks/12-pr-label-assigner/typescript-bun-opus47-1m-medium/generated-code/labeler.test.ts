import { describe, test, expect } from "bun:test";
import { assignLabels, type LabelRule } from "./labeler";

describe("assignLabels", () => {
  test("returns empty set for no files", () => {
    expect(assignLabels([], [])).toEqual([]);
  });

  test("matches a simple glob and assigns its label", () => {
    const rules: LabelRule[] = [{ pattern: "docs/**", label: "documentation" }];
    expect(assignLabels(["docs/intro.md"], rules)).toEqual(["documentation"]);
  });

  test("returns multiple labels when different files match different rules", () => {
    const rules: LabelRule[] = [
      { pattern: "docs/**", label: "documentation" },
      { pattern: "src/api/**", label: "api" },
    ];
    const result = assignLabels(
      ["docs/a.md", "src/api/users.ts"],
      rules,
    );
    expect(result.sort()).toEqual(["api", "documentation"]);
  });

  test("a single file may receive multiple labels from multiple matching rules", () => {
    const rules: LabelRule[] = [
      { pattern: "src/api/**", label: "api" },
      { pattern: "**/*.ts", label: "typescript" },
    ];
    const result = assignLabels(["src/api/users.ts"], rules);
    expect(result.sort()).toEqual(["api", "typescript"]);
  });

  test("deduplicates labels across files", () => {
    const rules: LabelRule[] = [{ pattern: "**/*.test.*", label: "tests" }];
    const result = assignLabels(["a.test.ts", "b.test.ts"], rules);
    expect(result).toEqual(["tests"]);
  });

  test("priority ordering: when two rules conflict, higher-priority wins (lower wins suppressed)", () => {
    // 'priority' is descending: higher number = higher priority
    // When rules conflict (share an exclusion group), only the highest priority label is applied.
    const rules: LabelRule[] = [
      { pattern: "src/**", label: "source", priority: 1, group: "area" },
      { pattern: "src/api/**", label: "api", priority: 10, group: "area" },
    ];
    const result = assignLabels(["src/api/users.ts"], rules);
    expect(result).toEqual(["api"]);
  });

  test("rules in different groups don't conflict", () => {
    const rules: LabelRule[] = [
      { pattern: "src/**", label: "source", priority: 1, group: "area" },
      { pattern: "**/*.ts", label: "typescript", priority: 5, group: "language" },
    ];
    const result = assignLabels(["src/foo.ts"], rules);
    expect(result.sort()).toEqual(["source", "typescript"]);
  });

  test("output is sorted alphabetically and deterministic", () => {
    const rules: LabelRule[] = [
      { pattern: "**/*.ts", label: "zeta" },
      { pattern: "**/*.ts", label: "alpha" },
    ];
    expect(assignLabels(["x.ts"], rules)).toEqual(["alpha", "zeta"]);
  });

  test("invalid rule (empty pattern) throws meaningful error", () => {
    const rules = [{ pattern: "", label: "x" }] as LabelRule[];
    expect(() => assignLabels(["a.ts"], rules)).toThrow(/empty pattern/i);
  });

  test("invalid rule (empty label) throws meaningful error", () => {
    const rules = [{ pattern: "**/*", label: "" }] as LabelRule[];
    expect(() => assignLabels(["a.ts"], rules)).toThrow(/empty label/i);
  });
});
