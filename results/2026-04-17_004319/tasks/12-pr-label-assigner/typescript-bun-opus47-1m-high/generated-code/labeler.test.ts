// Test suite for the PR label assigner.
// Follows red/green TDD: each describe block was written before its implementation.
import { describe, expect, test } from "bun:test";
import {
  matchGlob,
  assignLabels,
  parseRules,
  type Rule,
} from "./labeler.ts";

describe("matchGlob", () => {
  // Minimal glob engine: * (no /), ** (any including /), ? (single char)

  test("literal path matches itself", () => {
    expect(matchGlob("README.md", "README.md")).toBe(true);
  });

  test("literal path does not match a different string", () => {
    expect(matchGlob("README.md", "LICENSE")).toBe(false);
  });

  test("* matches a single path segment without slashes", () => {
    expect(matchGlob("foo.md", "*.md")).toBe(true);
    expect(matchGlob("foo/bar.md", "*.md")).toBe(false);
  });

  test("** matches any number of segments including slashes", () => {
    expect(matchGlob("docs/intro.md", "docs/**")).toBe(true);
    expect(matchGlob("docs/a/b/c.md", "docs/**")).toBe(true);
    expect(matchGlob("src/foo.ts", "docs/**")).toBe(false);
  });

  test("**/ at the start matches zero or more leading directories", () => {
    expect(matchGlob("a/b/c.test.ts", "**/*.test.*")).toBe(true);
    expect(matchGlob("x.test.js", "**/*.test.*")).toBe(true);
  });

  test("? matches exactly one character", () => {
    expect(matchGlob("a.md", "?.md")).toBe(true);
    expect(matchGlob("ab.md", "?.md")).toBe(false);
  });

  test("dot and plus are treated as literal characters", () => {
    expect(matchGlob("file+1.txt", "file+1.txt")).toBe(true);
    expect(matchGlob("file.txt", "file.txt")).toBe(true);
    expect(matchGlob("fileXtxt", "file.txt")).toBe(false);
  });
});

describe("parseRules", () => {
  // parseRules turns a declarative JSON config into an internal Rule[] form.
  test("parses a simple rule list", () => {
    const json = JSON.stringify({
      rules: [
        { label: "docs", patterns: ["docs/**", "*.md"] },
        { label: "api", patterns: ["src/api/**"], priority: 10 },
      ],
    });
    const rules = parseRules(json);
    expect(rules).toHaveLength(2);
    expect(rules[0]!.label).toBe("docs");
    expect(rules[0]!.patterns).toEqual(["docs/**", "*.md"]);
    expect(rules[0]!.priority).toBe(0); // default
    expect(rules[1]!.priority).toBe(10);
  });

  test("throws a clear error on invalid JSON", () => {
    expect(() => parseRules("{not json")).toThrow(/invalid json/i);
  });

  test("throws when rules array is missing", () => {
    expect(() => parseRules("{}")).toThrow(/missing.*rules/i);
  });

  test("throws when a rule has no label", () => {
    expect(() =>
      parseRules(JSON.stringify({ rules: [{ patterns: ["a"] }] })),
    ).toThrow(/label/i);
  });

  test("throws when a rule has no patterns", () => {
    expect(() =>
      parseRules(JSON.stringify({ rules: [{ label: "x" }] })),
    ).toThrow(/patterns/i);
  });
});

describe("assignLabels", () => {
  const rules: Rule[] = [
    { label: "documentation", patterns: ["docs/**", "*.md"], priority: 0 },
    { label: "api", patterns: ["src/api/**"], priority: 0 },
    { label: "tests", patterns: ["**/*.test.*"], priority: 0 },
  ];

  test("returns an empty set when no files are given", () => {
    expect(assignLabels([], rules)).toEqual([]);
  });

  test("applies a single label when files match one rule", () => {
    expect(assignLabels(["docs/intro.md"], rules)).toEqual(["documentation"]);
  });

  test("applies multiple labels when different files match different rules", () => {
    const labels = assignLabels(
      ["docs/intro.md", "src/api/users.ts", "src/foo.test.ts"],
      rules,
    );
    expect(labels.sort()).toEqual(["api", "documentation", "tests"].sort());
  });

  test("a single file can match multiple rules (multiple labels)", () => {
    // README.md matches *.md (documentation); also add rule for root-level files
    const multiRules: Rule[] = [
      { label: "documentation", patterns: ["*.md"], priority: 0 },
      { label: "root", patterns: ["*"], priority: 0 },
    ];
    const labels = assignLabels(["README.md"], multiRules);
    expect(labels.sort()).toEqual(["documentation", "root"]);
  });

  test("deduplicates labels across files", () => {
    const labels = assignLabels(
      ["docs/a.md", "docs/b.md", "docs/c.md"],
      rules,
    );
    expect(labels).toEqual(["documentation"]);
  });

  test("returns labels in priority order (highest priority first)", () => {
    const prioritized: Rule[] = [
      { label: "low", patterns: ["*.ts"], priority: 1 },
      { label: "high", patterns: ["*.ts"], priority: 10 },
      { label: "medium", patterns: ["*.ts"], priority: 5 },
    ];
    expect(assignLabels(["a.ts"], prioritized)).toEqual([
      "high",
      "medium",
      "low",
    ]);
  });

  test("breaks priority ties by label name for stable output", () => {
    const tied: Rule[] = [
      { label: "zeta", patterns: ["*.ts"], priority: 5 },
      { label: "alpha", patterns: ["*.ts"], priority: 5 },
    ];
    expect(assignLabels(["a.ts"], tied)).toEqual(["alpha", "zeta"]);
  });

  test("files that match no rule contribute no labels (not an error)", () => {
    expect(assignLabels(["src/lib/foo.ts"], rules)).toEqual([]);
  });
});
