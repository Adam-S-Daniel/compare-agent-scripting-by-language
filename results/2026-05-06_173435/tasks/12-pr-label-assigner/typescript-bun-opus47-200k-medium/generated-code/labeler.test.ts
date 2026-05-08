import { describe, expect, test } from "bun:test";
import { assignLabels, type LabelRule } from "./labeler";

// Tests follow red/green TDD - each test isolates one behavior of the labeler.
describe("assignLabels", () => {
  test("returns empty set when no files match any rule", () => {
    const rules: LabelRule[] = [{ label: "docs", patterns: ["docs/**"] }];
    expect(assignLabels(["src/foo.ts"], rules)).toEqual([]);
  });

  test("matches a simple glob pattern", () => {
    const rules: LabelRule[] = [{ label: "docs", patterns: ["docs/**"] }];
    expect(assignLabels(["docs/readme.md"], rules)).toEqual(["docs"]);
  });

  test("supports multiple labels for one file when multiple rules match", () => {
    const rules: LabelRule[] = [
      { label: "api", patterns: ["src/api/**"] },
      { label: "tests", patterns: ["**/*.test.*"] },
    ];
    const result = assignLabels(["src/api/users.test.ts"], rules);
    expect(result.sort()).toEqual(["api", "tests"]);
  });

  test("deduplicates labels across multiple files", () => {
    const rules: LabelRule[] = [{ label: "docs", patterns: ["docs/**"] }];
    expect(assignLabels(["docs/a.md", "docs/b.md"], rules)).toEqual(["docs"]);
  });

  test("supports multiple patterns per rule (any match)", () => {
    const rules: LabelRule[] = [
      { label: "config", patterns: ["*.yml", "*.yaml", "*.json"] },
    ];
    expect(assignLabels(["package.json"], rules)).toEqual(["config"]);
    expect(assignLabels(["ci.yml"], rules)).toEqual(["config"]);
  });

  test("orders labels by priority (lower number = higher priority, comes first)", () => {
    const rules: LabelRule[] = [
      { label: "tests", patterns: ["**/*.test.*"], priority: 10 },
      { label: "api", patterns: ["src/api/**"], priority: 1 },
    ];
    const result = assignLabels(["src/api/users.test.ts"], rules);
    expect(result).toEqual(["api", "tests"]);
  });

  test("rules without priority sort after rules with priority, in declaration order", () => {
    const rules: LabelRule[] = [
      { label: "z", patterns: ["**/*"] },
      { label: "a", patterns: ["**/*"] },
      { label: "first", patterns: ["**/*"], priority: 0 },
    ];
    expect(assignLabels(["x.ts"], rules)).toEqual(["first", "z", "a"]);
  });

  test("throws on empty file list with a clear error message", () => {
    expect(() => assignLabels([], [])).toThrow(/at least one file/i);
  });

  test("throws when a rule has no patterns", () => {
    expect(() =>
      assignLabels(["a.ts"], [{ label: "bad", patterns: [] }]),
    ).toThrow(/at least one pattern/i);
  });

  test("ignores leading ./ in file paths", () => {
    const rules: LabelRule[] = [{ label: "src", patterns: ["src/**"] }];
    expect(assignLabels(["./src/index.ts"], rules)).toEqual(["src"]);
  });
});
