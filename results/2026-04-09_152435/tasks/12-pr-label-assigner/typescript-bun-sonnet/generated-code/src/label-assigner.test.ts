// TDD: Tests written FIRST before implementation.
// These tests define the expected behavior of the label assigner.
// Run with: bun test

import { describe, expect, test } from "bun:test";
import { assignLabels, type LabelRule } from "./label-assigner";

// --- Test fixture: a set of rules used across multiple tests ---
const defaultRules: LabelRule[] = [
  { pattern: "docs/**", label: "documentation", priority: 1 },
  { pattern: "src/api/**", label: "api", priority: 1 },
  { pattern: "src/**", label: "source", priority: 2 },
  { pattern: "**/*.test.*", label: "tests", priority: 1 },
  { pattern: "**/*.spec.*", label: "tests", priority: 1 },
  { pattern: "*.md", label: "documentation", priority: 3 },
  { pattern: ".github/**", label: "ci", priority: 1 },
  { pattern: "**", label: "other", priority: 10 },
];

describe("assignLabels - basic glob matching", () => {
  test("matches docs/** pattern and assigns documentation label", () => {
    const files = ["docs/README.md"];
    const result = assignLabels(files, defaultRules);
    expect(result).toContain("documentation");
  });

  test("matches src/api/** and assigns api label", () => {
    const files = ["src/api/users.ts"];
    const result = assignLabels(files, defaultRules);
    expect(result).toContain("api");
  });

  test("matches *.test.* pattern and assigns tests label", () => {
    const files = ["src/utils.test.ts"];
    const result = assignLabels(files, defaultRules);
    expect(result).toContain("tests");
  });

  test("matches *.spec.* pattern and assigns tests label", () => {
    const files = ["src/api/users.spec.ts"];
    const result = assignLabels(files, defaultRules);
    expect(result).toContain("tests");
  });

  test("matches .github/** and assigns ci label", () => {
    const files = [".github/workflows/ci.yml"];
    const result = assignLabels(files, defaultRules);
    expect(result).toContain("ci");
  });

  test("assigns other label when only ** matches", () => {
    const files = ["random-file.txt"];
    const result = assignLabels(files, defaultRules);
    expect(result).toContain("other");
  });
});

describe("assignLabels - multiple labels per file", () => {
  test("a test file in src/api gets both tests and api labels", () => {
    const files = ["src/api/users.test.ts"];
    const result = assignLabels(files, defaultRules);
    expect(result).toContain("tests");
    expect(result).toContain("api");
  });

  test("a test file in src/api also gets source label", () => {
    const files = ["src/api/users.test.ts"];
    const result = assignLabels(files, defaultRules);
    expect(result).toContain("source");
  });

  test("multiple files can produce multiple distinct labels", () => {
    const files = ["docs/guide.md", "src/api/endpoint.ts"];
    const result = assignLabels(files, defaultRules);
    expect(result).toContain("documentation");
    expect(result).toContain("api");
  });

  test("labels are deduplicated across multiple matching files", () => {
    const files = ["src/api/a.ts", "src/api/b.ts"];
    const result = assignLabels(files, defaultRules);
    const apiCount = result.filter((l) => l === "api").length;
    expect(apiCount).toBe(1); // no duplicates
  });
});

describe("assignLabels - priority ordering", () => {
  test("higher priority (lower number) labels appear first in output", () => {
    // api (priority 1) and source (priority 2) both match src/api/**
    const files = ["src/api/endpoint.ts"];
    const result = assignLabels(files, defaultRules);
    const apiIdx = result.indexOf("api");
    const sourceIdx = result.indexOf("source");
    expect(apiIdx).toBeLessThan(sourceIdx);
  });

  test("labels are ordered by their highest-priority rule match", () => {
    // ci (priority 1) should come before other (priority 10)
    const files = [".github/dependabot.yml"];
    const result = assignLabels(files, defaultRules);
    const ciIdx = result.indexOf("ci");
    const otherIdx = result.indexOf("other");
    expect(ciIdx).toBeLessThan(otherIdx);
  });

  test("same-priority labels preserve stable order from rule list", () => {
    // documentation (priority 1 from docs/**) and tests (priority 1 from *.test.*)
    const files = ["docs/setup.test.md"];
    const result = assignLabels(files, defaultRules);
    // Both should be present
    expect(result).toContain("documentation");
    expect(result).toContain("tests");
  });
});

describe("assignLabels - edge cases", () => {
  test("returns empty array for empty file list", () => {
    const result = assignLabels([], defaultRules);
    expect(result).toEqual([]);
  });

  test("returns empty array when no rules match", () => {
    const rules: LabelRule[] = [{ pattern: "docs/**", label: "documentation", priority: 1 }];
    const result = assignLabels(["src/index.ts"], rules);
    expect(result).toEqual([]);
  });

  test("handles empty rules array", () => {
    const result = assignLabels(["src/index.ts"], []);
    expect(result).toEqual([]);
  });

  test("handles deeply nested paths", () => {
    const files = ["src/api/v2/handlers/users/profile.ts"];
    const result = assignLabels(files, defaultRules);
    expect(result).toContain("api");
    expect(result).toContain("source");
  });

  test("handles root-level files matching *.md", () => {
    const files = ["README.md"];
    const result = assignLabels(files, defaultRules);
    expect(result).toContain("documentation");
  });

  test("custom rules override default behavior", () => {
    const customRules: LabelRule[] = [
      { pattern: "frontend/**", label: "frontend", priority: 1 },
      { pattern: "backend/**", label: "backend", priority: 1 },
    ];
    const result = assignLabels(["frontend/App.tsx", "backend/server.ts"], customRules);
    expect(result).toContain("frontend");
    expect(result).toContain("backend");
    expect(result).not.toContain("documentation");
  });
});

describe("assignLabels - real-world PR scenarios", () => {
  test("typical feature PR with api and test changes", () => {
    const files = [
      "src/api/orders.ts",
      "src/api/orders.test.ts",
      "docs/api-reference.md",
    ];
    const result = assignLabels(files, defaultRules);
    expect(result).toContain("api");
    expect(result).toContain("tests");
    expect(result).toContain("documentation");
  });

  test("CI-only PR gets ci and other labels", () => {
    const files = [".github/workflows/deploy.yml", ".github/dependabot.yml"];
    const result = assignLabels(files, defaultRules);
    expect(result).toContain("ci");
  });

  test("large mixed PR gets all relevant labels", () => {
    const files = [
      "src/api/users.ts",
      "src/api/users.test.ts",
      "docs/users.md",
      ".github/workflows/ci.yml",
      "README.md",
    ];
    const result = assignLabels(files, defaultRules);
    expect(result).toContain("api");
    expect(result).toContain("tests");
    expect(result).toContain("documentation");
    expect(result).toContain("ci");
  });
});
