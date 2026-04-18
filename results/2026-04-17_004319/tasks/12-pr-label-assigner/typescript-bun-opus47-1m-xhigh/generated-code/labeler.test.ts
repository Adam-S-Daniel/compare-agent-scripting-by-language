// Tests for the PR label assigner.
// TDD approach: each `test()` was written failing first, then implementation was
// added/refactored until green. See commit history for red/green cadence.

import { describe, expect, test } from "bun:test";
import { assignLabels, type LabelRule } from "./labeler";

describe("assignLabels - basic matching", () => {
  test("returns an empty label set when no files are given", () => {
    const rules: LabelRule[] = [{ pattern: "docs/**", label: "documentation" }];
    expect(assignLabels([], rules)).toEqual([]);
  });

  test("returns an empty label set when no rules match any file", () => {
    const rules: LabelRule[] = [{ pattern: "docs/**", label: "documentation" }];
    expect(assignLabels(["src/index.ts"], rules)).toEqual([]);
  });

  test("applies a label when a single file matches a simple glob", () => {
    const rules: LabelRule[] = [{ pattern: "docs/**", label: "documentation" }];
    expect(assignLabels(["docs/readme.md"], rules)).toEqual(["documentation"]);
  });

  test("applies a label for nested directory matches via **", () => {
    const rules: LabelRule[] = [{ pattern: "docs/**", label: "documentation" }];
    const files = ["docs/api/v1/reference.md", "docs/guides/setup.md"];
    expect(assignLabels(files, rules)).toEqual(["documentation"]);
  });

  test("deduplicates labels across multiple matching files", () => {
    const rules: LabelRule[] = [{ pattern: "docs/**", label: "documentation" }];
    const files = ["docs/a.md", "docs/b.md", "docs/c.md"];
    expect(assignLabels(files, rules)).toEqual(["documentation"]);
  });
});

describe("assignLabels - multiple rules and labels", () => {
  test("applies multiple labels when different files match different rules", () => {
    const rules: LabelRule[] = [
      { pattern: "docs/**", label: "documentation" },
      { pattern: "src/api/**", label: "api" },
    ];
    const files = ["docs/readme.md", "src/api/users.ts"];
    // Default order: since neither has an explicit priority, sort by label name.
    expect(assignLabels(files, rules)).toEqual(["api", "documentation"]);
  });

  test("a single file can pick up multiple labels from multiple rules", () => {
    const rules: LabelRule[] = [
      { pattern: "src/api/**", label: "api" },
      { pattern: "**/*.test.*", label: "tests" },
    ];
    // One file that matches both the api rule AND the tests rule
    expect(assignLabels(["src/api/users.test.ts"], rules)).toEqual([
      "api",
      "tests",
    ]);
  });

  test("supports suffix-style globs like *.test.*", () => {
    const rules: LabelRule[] = [{ pattern: "**/*.test.*", label: "tests" }];
    expect(assignLabels(["foo/bar/baz.test.ts"], rules)).toEqual(["tests"]);
  });
});

describe("assignLabels - priority ordering", () => {
  test("higher priority rules sort first in the output", () => {
    const rules: LabelRule[] = [
      { pattern: "docs/**", label: "documentation", priority: 1 },
      { pattern: "src/api/**", label: "api", priority: 10 },
      { pattern: "**/*.test.*", label: "tests", priority: 5 },
    ];
    const files = [
      "docs/readme.md",
      "src/api/users.ts",
      "src/api/users.test.ts",
    ];
    expect(assignLabels(files, rules)).toEqual([
      "api", // priority 10
      "tests", // priority 5
      "documentation", // priority 1
    ]);
  });

  test("undefined priority is treated as 0 (lowest)", () => {
    const rules: LabelRule[] = [
      { pattern: "docs/**", label: "documentation" }, // no priority
      { pattern: "src/**", label: "source", priority: 1 },
    ];
    const files = ["docs/readme.md", "src/index.ts"];
    expect(assignLabels(files, rules)).toEqual(["source", "documentation"]);
  });

  test("ties on priority break alphabetically by label name", () => {
    const rules: LabelRule[] = [
      { pattern: "docs/**", label: "zzz", priority: 1 },
      { pattern: "src/**", label: "aaa", priority: 1 },
    ];
    const files = ["docs/a.md", "src/a.ts"];
    expect(assignLabels(files, rules)).toEqual(["aaa", "zzz"]);
  });
});

describe("assignLabels - exclusive groups", () => {
  // Exclusive groups: when multiple rules in the same group match,
  // only the highest-priority rule wins. Typical use case: size labels
  // where you want "size/XL" but not also "size/L".
  test("only the highest priority rule in an exclusive group wins", () => {
    const rules: LabelRule[] = [
      { pattern: "**/*", label: "size/S", group: "size", priority: 1 },
      { pattern: "src/**", label: "size/M", group: "size", priority: 5 },
      { pattern: "src/api/**", label: "size/L", group: "size", priority: 10 },
    ];
    // src/api/users.ts matches all three; only size/L should survive.
    expect(assignLabels(["src/api/users.ts"], rules)).toEqual(["size/L"]);
  });

  test("exclusive groups don't affect labels outside the group", () => {
    const rules: LabelRule[] = [
      { pattern: "**/*", label: "size/S", group: "size", priority: 1 },
      { pattern: "src/**", label: "size/M", group: "size", priority: 5 },
      { pattern: "src/api/**", label: "api", priority: 10 },
    ];
    const out = assignLabels(["src/api/users.ts"], rules);
    // size/M wins within "size" group; "api" is ungrouped and also present.
    expect(out).toEqual(["api", "size/M"]);
  });
});

describe("assignLabels - error handling", () => {
  test("throws a helpful error when a rule has an invalid glob", () => {
    const rules = [{ pattern: "", label: "bad" }] as LabelRule[];
    expect(() => assignLabels(["foo.ts"], rules)).toThrow(
      /invalid rule: pattern must be a non-empty string/i,
    );
  });

  test("throws a helpful error when a rule is missing a label", () => {
    const rules = [{ pattern: "**/*", label: "" }] as LabelRule[];
    expect(() => assignLabels(["foo.ts"], rules)).toThrow(
      /invalid rule: label must be a non-empty string/i,
    );
  });

  test("throws a helpful error when rules is not an array", () => {
    expect(() => assignLabels(["foo.ts"], "not-an-array" as unknown as LabelRule[])).toThrow(
      /rules must be an array/i,
    );
  });
});

describe("loadRules - config file parsing", () => {
  test("parses a valid JSON config file", async () => {
    const { loadRules } = await import("./labeler");
    const tmp = `/tmp/rules-${Date.now()}.json`;
    await Bun.write(
      tmp,
      JSON.stringify({
        rules: [{ pattern: "docs/**", label: "documentation", priority: 1 }],
      }),
    );
    const rules = await loadRules(tmp);
    expect(rules).toEqual([
      { pattern: "docs/**", label: "documentation", priority: 1 },
    ]);
  });

  test("throws a helpful error when the config file does not exist", async () => {
    const { loadRules } = await import("./labeler");
    await expect(loadRules("/tmp/does-not-exist-xyz.json")).rejects.toThrow(
      /config file not found/i,
    );
  });

  test("throws a helpful error when the config file is malformed JSON", async () => {
    const { loadRules } = await import("./labeler");
    const tmp = `/tmp/rules-bad-${Date.now()}.json`;
    await Bun.write(tmp, "{not valid json");
    await expect(loadRules(tmp)).rejects.toThrow(/failed to parse config/i);
  });
});
