import { describe, test, expect } from "bun:test";
import { assignLabels, type LabelRule } from "./labeler";

describe("assignLabels", () => {
  test("returns empty set when no files match", () => {
    const rules: LabelRule[] = [{ pattern: "docs/**", label: "documentation" }];
    expect(assignLabels([], rules)).toEqual([]);
    expect(assignLabels(["src/main.ts"], rules)).toEqual([]);
  });

  test("matches single file to a label via glob", () => {
    const rules: LabelRule[] = [{ pattern: "docs/**", label: "documentation" }];
    expect(assignLabels(["docs/intro.md"], rules)).toEqual(["documentation"]);
  });

  test("matches multiple files contributing the same label (deduplicated)", () => {
    const rules: LabelRule[] = [{ pattern: "docs/**", label: "documentation" }];
    expect(
      assignLabels(["docs/a.md", "docs/b.md", "docs/nested/c.md"], rules),
    ).toEqual(["documentation"]);
  });

  test("a single file can match multiple rules and get multiple labels", () => {
    const rules: LabelRule[] = [
      { pattern: "src/api/**", label: "api" },
      { pattern: "**/*.test.*", label: "tests" },
    ];
    const labels = assignLabels(["src/api/users.test.ts"], rules);
    expect(labels.sort()).toEqual(["api", "tests"]);
  });

  test("priority ordering: higher priority rule wins when rules conflict on same label slot", () => {
    // Conflict semantics: rules sharing the same `group` produce at most one label per file —
    // the highest-priority matching rule wins. Rules with no group never conflict.
    const rules: LabelRule[] = [
      { pattern: "src/api/**", label: "api", group: "area", priority: 10 },
      { pattern: "src/**", label: "backend", group: "area", priority: 1 },
    ];
    expect(assignLabels(["src/api/users.ts"], rules)).toEqual(["api"]);
    expect(assignLabels(["src/core/util.ts"], rules)).toEqual(["backend"]);
  });

  test("combines grouped conflict resolution with ungrouped labels", () => {
    const rules: LabelRule[] = [
      { pattern: "src/api/**", label: "api", group: "area", priority: 10 },
      { pattern: "src/**", label: "backend", group: "area", priority: 1 },
      { pattern: "**/*.test.*", label: "tests" },
    ];
    const labels = assignLabels(["src/api/users.test.ts"], rules);
    expect(labels.sort()).toEqual(["api", "tests"]);
  });

  test("supports simple *.ext glob at root", () => {
    const rules: LabelRule[] = [{ pattern: "*.md", label: "markdown" }];
    expect(assignLabels(["README.md"], rules)).toEqual(["markdown"]);
    expect(assignLabels(["docs/nested.md"], rules)).toEqual([]);
  });

  test("output labels are sorted deterministically", () => {
    const rules: LabelRule[] = [
      { pattern: "docs/**", label: "zeta" },
      { pattern: "src/**", label: "alpha" },
    ];
    expect(assignLabels(["docs/a.md", "src/b.ts"], rules)).toEqual([
      "alpha",
      "zeta",
    ]);
  });

  test("throws on an invalid rule (empty pattern or empty label)", () => {
    expect(() =>
      assignLabels(["x.ts"], [{ pattern: "", label: "bad" }]),
    ).toThrow(/pattern/);
    expect(() =>
      assignLabels(["x.ts"], [{ pattern: "**", label: "" }]),
    ).toThrow(/label/);
  });
});
