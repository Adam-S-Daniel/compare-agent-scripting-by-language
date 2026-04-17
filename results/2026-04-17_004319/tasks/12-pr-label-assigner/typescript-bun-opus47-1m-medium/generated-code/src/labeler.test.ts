import { describe, expect, test } from "bun:test";
import { matchGlob, assignLabels, type LabelRule } from "./labeler.ts";

describe("matchGlob", () => {
  test("** matches any depth", () => {
    expect(matchGlob("docs/**", "docs/a/b/c.md")).toBe(true);
    expect(matchGlob("docs/**", "docs/")).toBe(true);
    expect(matchGlob("docs/**", "src/a.ts")).toBe(false);
  });

  test("* matches a single path segment", () => {
    expect(matchGlob("src/*.ts", "src/a.ts")).toBe(true);
    expect(matchGlob("src/*.ts", "src/a/b.ts")).toBe(false);
  });

  test("*.test.* matches test files", () => {
    expect(matchGlob("*.test.*", "foo.test.ts")).toBe(true);
    expect(matchGlob("**/*.test.*", "a/b/foo.test.ts")).toBe(true);
    expect(matchGlob("*.test.*", "foo.ts")).toBe(false);
  });

  test("exact literal path", () => {
    expect(matchGlob("README.md", "README.md")).toBe(true);
    expect(matchGlob("README.md", "docs/README.md")).toBe(false);
  });
});

describe("assignLabels", () => {
  const rules: LabelRule[] = [
    { pattern: "docs/**", label: "documentation" },
    { pattern: "src/api/**", label: "api", priority: 10 },
    { pattern: "src/**", label: "source" },
    { pattern: "**/*.test.*", label: "tests", priority: 5 },
  ];

  test("assigns label for a single matching file", () => {
    expect(assignLabels(["docs/readme.md"], rules)).toEqual(["documentation"]);
  });

  test("multiple rules can match one file (source + api)", () => {
    const result = assignLabels(["src/api/users.ts"], rules);
    // priority ordering: higher priority first
    expect(result).toEqual(["api", "source"]);
  });

  test("deduplicates labels across files", () => {
    const result = assignLabels(
      ["src/api/users.ts", "src/api/posts.ts"],
      rules,
    );
    expect(result).toEqual(["api", "source"]);
  });

  test("test file gets tests + source labels", () => {
    const result = assignLabels(["src/foo.test.ts"], rules);
    expect(result).toContain("tests");
    expect(result).toContain("source");
  });

  test("no matches yields empty label set", () => {
    expect(assignLabels(["random.xyz"], rules)).toEqual([]);
  });

  test("priority ordering places high-priority labels first", () => {
    const result = assignLabels(
      ["src/api/users.ts", "src/foo.test.ts", "docs/a.md"],
      rules,
    );
    // api(10), tests(5), source(0), documentation(0)
    expect(result.indexOf("api")).toBeLessThan(result.indexOf("tests"));
    expect(result.indexOf("tests")).toBeLessThan(result.indexOf("source"));
  });

  test("throws on invalid rule (missing pattern)", () => {
    expect(() =>
      // @ts-expect-error intentional
      assignLabels(["a.ts"], [{ label: "x" }]),
    ).toThrow(/pattern/);
  });
});
