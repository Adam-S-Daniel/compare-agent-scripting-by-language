/**
 * Tests for the PR label assigner.
 *
 * TDD approach: each describe block was added red-first — write failing test,
 * implement minimum code to pass, then move on. Order below mirrors the order
 * the tests were written.
 */
import { describe, expect, test } from "bun:test";
import { assignLabels, matchGlob, type LabelRule } from "../src/labeler.ts";

describe("matchGlob", () => {
  test("matches exact path", () => {
    expect(matchGlob("README.md", "README.md")).toBe(true);
    expect(matchGlob("README.md", "LICENSE")).toBe(false);
  });

  test("matches single-segment wildcard *", () => {
    expect(matchGlob("foo.test.ts", "*.test.ts")).toBe(true);
    expect(matchGlob("src/foo.test.ts", "*.test.ts")).toBe(false);
  });

  test("matches recursive wildcard **", () => {
    expect(matchGlob("docs/intro.md", "docs/**")).toBe(true);
    expect(matchGlob("docs/api/v1/index.md", "docs/**")).toBe(true);
    expect(matchGlob("src/docs.md", "docs/**")).toBe(false);
  });

  test("matches mid-path recursive wildcard", () => {
    expect(matchGlob("src/api/users.ts", "src/api/**")).toBe(true);
    expect(matchGlob("src/util.ts", "src/api/**")).toBe(false);
  });

  test("matches *.ext anywhere via **/*.ext", () => {
    expect(matchGlob("a/b/c/foo.test.ts", "**/*.test.ts")).toBe(true);
    expect(matchGlob("foo.test.ts", "**/*.test.ts")).toBe(true);
    expect(matchGlob("foo.ts", "**/*.test.ts")).toBe(false);
  });

  test("matches character class brackets", () => {
    expect(matchGlob("file1.txt", "file[0-9].txt")).toBe(true);
    expect(matchGlob("filea.txt", "file[0-9].txt")).toBe(false);
  });
});

describe("assignLabels — basic single-rule mapping", () => {
  test("assigns label when path matches rule", () => {
    const rules: LabelRule[] = [{ label: "documentation", patterns: ["docs/**"] }];
    const labels = assignLabels(["docs/readme.md"], rules);
    expect(labels).toEqual(["documentation"]);
  });

  test("returns empty list when nothing matches", () => {
    const rules: LabelRule[] = [{ label: "documentation", patterns: ["docs/**"] }];
    expect(assignLabels(["src/index.ts"], rules)).toEqual([]);
  });
});

describe("assignLabels — multiple labels per file", () => {
  test("a single file can contribute multiple labels via different rules", () => {
    const rules: LabelRule[] = [
      { label: "api", patterns: ["src/api/**"] },
      { label: "tests", patterns: ["**/*.test.ts"] },
    ];
    // src/api/users.test.ts matches BOTH rules
    const labels = assignLabels(["src/api/users.test.ts"], rules);
    expect(labels.sort()).toEqual(["api", "tests"]);
  });

  test("union across files, deduplicated", () => {
    const rules: LabelRule[] = [
      { label: "api", patterns: ["src/api/**"] },
      { label: "documentation", patterns: ["docs/**"] },
    ];
    const labels = assignLabels(
      ["src/api/a.ts", "src/api/b.ts", "docs/x.md"],
      rules,
    );
    expect(labels.sort()).toEqual(["api", "documentation"]);
  });

  test("multiple patterns within a single rule both match", () => {
    const rules: LabelRule[] = [
      { label: "tests", patterns: ["**/*.test.ts", "**/*.spec.ts"] },
    ];
    expect(assignLabels(["a.test.ts"], rules)).toEqual(["tests"]);
    expect(assignLabels(["a.spec.ts"], rules)).toEqual(["tests"]);
  });
});

describe("assignLabels — priority ordering", () => {
  // Priority semantics: when multiple rules match, output is sorted by
  // priority (lowest number = highest priority, i.e. 1 comes before 2).
  // Rules without an explicit priority sort after those with one, in
  // declaration order. This makes output deterministic and easy to read.
  test("sorts matched labels by ascending priority", () => {
    const rules: LabelRule[] = [
      { label: "tests", patterns: ["**/*.test.ts"], priority: 10 },
      { label: "api", patterns: ["src/api/**"], priority: 1 },
    ];
    const labels = assignLabels(["src/api/users.test.ts"], rules);
    expect(labels).toEqual(["api", "tests"]);
  });

  test("rules without priority follow priortized rules in declaration order", () => {
    const rules: LabelRule[] = [
      { label: "no-prio-second", patterns: ["**/*"] },
      { label: "no-prio-first", patterns: ["**/*"] },
      { label: "with-prio", patterns: ["**/*"], priority: 5 },
    ];
    const labels = assignLabels(["foo.txt"], rules);
    // priority-5 first, then unprioritized in declaration order
    expect(labels).toEqual(["with-prio", "no-prio-second", "no-prio-first"]);
  });
});

describe("assignLabels — exclude (negation) patterns", () => {
  // A rule may declare an `exclude` list; if any exclude pattern matches a
  // file, that file does NOT contribute to the rule's label even if its
  // include patterns match. Useful for "src/** but not src/vendor/**".
  test("excludes files that match exclude pattern", () => {
    const rules: LabelRule[] = [
      {
        label: "source",
        patterns: ["src/**"],
        exclude: ["src/vendor/**"],
      },
    ];
    expect(assignLabels(["src/foo.ts"], rules)).toEqual(["source"]);
    expect(assignLabels(["src/vendor/lib.ts"], rules)).toEqual([]);
  });
});

describe("assignLabels — error handling", () => {
  test("throws on empty label string", () => {
    expect(() =>
      assignLabels(["a.ts"], [{ label: "", patterns: ["**/*"] }]),
    ).toThrow(/label must be a non-empty string/);
  });

  test("throws on rule with no patterns", () => {
    expect(() =>
      assignLabels(["a.ts"], [{ label: "x", patterns: [] }]),
    ).toThrow(/at least one pattern/);
  });

  test("throws on non-array changedFiles", () => {
    expect(() =>
      // intentional bad input — runtime guard
      assignLabels("not-an-array" as unknown as string[], []),
    ).toThrow(/changedFiles must be an array/);
  });
});
