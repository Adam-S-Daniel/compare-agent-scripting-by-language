// TDD: unit tests for PR label assignment logic.
// Tests are written FIRST (red), then the implementation makes them pass (green).

import { describe, test, expect } from "bun:test";
import { assignLabels, matchesPattern } from "./pr-label-assigner";
import type { LabelConfig } from "./pr-label-assigner";

// ── Fixture: default label rules config used across most tests ────────────────
const defaultConfig: LabelConfig = {
  rules: [
    { pattern: "docs/**", label: "documentation", priority: 10 },
    { pattern: "src/api/**", label: "api", priority: 5 },
    { pattern: "**/*.test.*", label: "tests", priority: 3 },
    { pattern: "src/**", label: "source", priority: 1 },
  ],
};

// ── matchesPattern ────────────────────────────────────────────────────────────
describe("matchesPattern", () => {
  test("docs/** matches docs/readme.md", () => {
    expect(matchesPattern("docs/readme.md", "docs/**")).toBe(true);
  });

  test("docs/** matches nested docs/api/overview.md", () => {
    expect(matchesPattern("docs/api/overview.md", "docs/**")).toBe(true);
  });

  test("docs/** does not match src/readme.md", () => {
    expect(matchesPattern("src/readme.md", "docs/**")).toBe(false);
  });

  test("**/*.test.* matches src/api/users.test.ts", () => {
    expect(matchesPattern("src/api/users.test.ts", "**/*.test.*")).toBe(true);
  });

  test("**/*.test.* matches deeply nested test file", () => {
    expect(matchesPattern("src/core/utils/helper.test.js", "**/*.test.*")).toBe(true);
  });

  test("**/*.test.* does not match src/api/users.ts", () => {
    expect(matchesPattern("src/api/users.ts", "**/*.test.*")).toBe(false);
  });

  test("src/api/** matches src/api/users.ts", () => {
    expect(matchesPattern("src/api/users.ts", "src/api/**")).toBe(true);
  });

  test("src/api/** does not match src/core/utils.ts", () => {
    expect(matchesPattern("src/core/utils.ts", "src/api/**")).toBe(false);
  });

  test("*.md matches top-level README.md", () => {
    expect(matchesPattern("README.md", "*.md")).toBe(true);
  });
});

// ── assignLabels ──────────────────────────────────────────────────────────────
describe("assignLabels", () => {
  test("returns empty labels when no files match any rule", () => {
    const result = assignLabels(["random/unmatched.xyz"], defaultConfig);
    expect(result.labels).toEqual([]);
  });

  test("matches a single rule: docs file gets documentation label", () => {
    const result = assignLabels(["docs/readme.md"], defaultConfig);
    expect(result.labels).toContain("documentation");
  });

  test("matches multiple rules for one file: src/api file gets api and source", () => {
    const result = assignLabels(["src/api/users.ts"], defaultConfig);
    expect(result.labels).toContain("api");
    expect(result.labels).toContain("source");
  });

  test("assigns tests label for test files", () => {
    const result = assignLabels(["src/api/users.test.ts"], defaultConfig);
    expect(result.labels).toContain("tests");
  });

  test("collects labels across multiple files without duplicates", () => {
    const files = ["docs/readme.md", "docs/guide.md"];
    const result = assignLabels(files, defaultConfig);
    // Should have exactly one 'documentation' label, not two
    expect(result.labels.filter((l) => l === "documentation").length).toBe(1);
  });

  test("multiple files trigger multiple labels", () => {
    const files = ["docs/readme.md", "src/api/users.ts"];
    const result = assignLabels(files, defaultConfig);
    expect(result.labels).toContain("documentation");
    expect(result.labels).toContain("api");
    expect(result.labels).toContain("source");
  });

  test("labels sorted by priority (highest first)", () => {
    // documentation(10) > api(5) > tests(3) > source(1)
    const files = ["docs/readme.md", "src/api/users.test.ts"];
    const result = assignLabels(files, defaultConfig);
    const docIdx = result.labels.indexOf("documentation");
    const apiIdx = result.labels.indexOf("api");
    const testIdx = result.labels.indexOf("tests");
    expect(docIdx).toBeLessThan(apiIdx);
    expect(apiIdx).toBeLessThan(testIdx);
  });

  test("fileMatches tracks which labels each file received", () => {
    const result = assignLabels(["docs/readme.md"], defaultConfig);
    expect(result.fileMatches["docs/readme.md"]).toContain("documentation");
  });

  test("empty file list returns empty labels", () => {
    const result = assignLabels([], defaultConfig);
    expect(result.labels).toEqual([]);
    expect(result.fileMatches).toEqual({});
  });

  test("handles config with no rules gracefully", () => {
    const result = assignLabels(["docs/readme.md"], { rules: [] });
    expect(result.labels).toEqual([]);
  });

  // Priority ordering: when two rules match the same file, both labels are included
  // but sorted by their priority
  test("priority ordering: higher priority label appears first", () => {
    const config: LabelConfig = {
      rules: [
        { pattern: "src/**", label: "source", priority: 1 },
        { pattern: "src/api/**", label: "api", priority: 5 },
      ],
    };
    const result = assignLabels(["src/api/users.ts"], config);
    expect(result.labels[0]).toBe("api");
    expect(result.labels[1]).toBe("source");
  });

  test("labels with same priority are sorted alphabetically", () => {
    const config: LabelConfig = {
      rules: [
        { pattern: "src/**", label: "source", priority: 5 },
        { pattern: "src/api/**", label: "api", priority: 5 },
      ],
    };
    const result = assignLabels(["src/api/users.ts"], config);
    // Same priority -> alphabetical: api < source
    expect(result.labels[0]).toBe("api");
    expect(result.labels[1]).toBe("source");
  });
});

// ── Full scenario: simulate a real PR ────────────────────────────────────────
describe("real PR simulation", () => {
  test("PR touching docs, api, and tests produces correct label set", () => {
    const files = [
      "docs/readme.md",
      "src/api/users.ts",
      "src/api/users.test.ts",
      "src/core/config.ts",
    ];
    const result = assignLabels(files, defaultConfig);
    // All four labels should be present
    expect(result.labels).toContain("documentation");
    expect(result.labels).toContain("api");
    expect(result.labels).toContain("tests");
    expect(result.labels).toContain("source");
    // documentation (priority 10) is first
    expect(result.labels[0]).toBe("documentation");
  });
});
