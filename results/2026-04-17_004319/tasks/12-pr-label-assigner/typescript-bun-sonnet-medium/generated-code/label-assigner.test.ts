// TDD tests for PR label assigner
// Red/green cycle: write failing test, then implement minimum code to pass

import { describe, test, expect } from "bun:test";
import { assignLabels, LabelRule, LabelConfig } from "./label-assigner";

describe("assignLabels - basic glob matching", () => {
  test("matches docs/** pattern to documentation label", () => {
    const config: LabelConfig = {
      rules: [{ pattern: "docs/**", label: "documentation", priority: 1 }],
    };
    const files = ["docs/README.md", "docs/api/guide.md"];
    const result = assignLabels(files, config);
    expect(result).toContain("documentation");
  });

  test("returns empty set when no files match", () => {
    const config: LabelConfig = {
      rules: [{ pattern: "docs/**", label: "documentation", priority: 1 }],
    };
    const files = ["src/index.ts", "src/utils.ts"];
    const result = assignLabels(files, config);
    expect(result).toHaveLength(0);
  });

  test("matches src/api/** to api label", () => {
    const config: LabelConfig = {
      rules: [{ pattern: "src/api/**", label: "api", priority: 1 }],
    };
    const files = ["src/api/routes.ts", "src/api/handlers/auth.ts"];
    const result = assignLabels(files, config);
    expect(result).toContain("api");
  });
});

describe("assignLabels - test file patterns", () => {
  test("matches *.test.* pattern to tests label", () => {
    const config: LabelConfig = {
      rules: [{ pattern: "**/*.test.*", label: "tests", priority: 1 }],
    };
    const files = ["src/utils.test.ts", "src/api/handler.test.ts"];
    const result = assignLabels(files, config);
    expect(result).toContain("tests");
  });

  test("matches *.spec.* pattern to tests label", () => {
    const config: LabelConfig = {
      rules: [{ pattern: "**/*.spec.*", label: "tests", priority: 1 }],
    };
    const files = ["src/utils.spec.ts"];
    const result = assignLabels(files, config);
    expect(result).toContain("tests");
  });
});

describe("assignLabels - multiple labels", () => {
  test("assigns multiple labels when multiple rules match", () => {
    const config: LabelConfig = {
      rules: [
        { pattern: "docs/**", label: "documentation", priority: 1 },
        { pattern: "src/api/**", label: "api", priority: 2 },
      ],
    };
    const files = ["docs/README.md", "src/api/routes.ts"];
    const result = assignLabels(files, config);
    expect(result).toContain("documentation");
    expect(result).toContain("api");
  });

  test("returns unique labels (no duplicates)", () => {
    const config: LabelConfig = {
      rules: [{ pattern: "src/**", label: "source", priority: 1 }],
    };
    const files = ["src/index.ts", "src/utils.ts", "src/api/routes.ts"];
    const result = assignLabels(files, config);
    const sourceCount = result.filter((l) => l === "source").length;
    expect(sourceCount).toBe(1);
  });
});

describe("assignLabels - priority ordering", () => {
  test("higher priority rules take precedence for conflicting labels", () => {
    // When two rules match same file, higher priority rule label wins
    // (i.e., if both rules map to same label bucket, we use highest priority)
    const config: LabelConfig = {
      rules: [
        { pattern: "src/**", label: "backend", priority: 1 },
        { pattern: "src/api/**", label: "api", priority: 2 }, // higher priority
      ],
    };
    const files = ["src/api/routes.ts"];
    const result = assignLabels(files, config);
    // Both rules match, both labels should be present
    expect(result).toContain("backend");
    expect(result).toContain("api");
  });

  test("labels are sorted by priority (highest first)", () => {
    const config: LabelConfig = {
      rules: [
        { pattern: "docs/**", label: "documentation", priority: 1 },
        { pattern: "src/**", label: "source", priority: 3 },
        { pattern: "**/*.test.*", label: "tests", priority: 2 },
      ],
    };
    const files = ["docs/guide.md", "src/utils.ts", "src/utils.test.ts"];
    const result = assignLabels(files, config);
    // All three labels should be present
    expect(result).toContain("documentation");
    expect(result).toContain("source");
    expect(result).toContain("tests");
    // Labels should be sorted by descending priority
    const sourceIdx = result.indexOf("source");
    const testsIdx = result.indexOf("tests");
    const docsIdx = result.indexOf("documentation");
    expect(sourceIdx).toBeLessThan(testsIdx);
    expect(testsIdx).toBeLessThan(docsIdx);
  });
});

describe("assignLabels - edge cases", () => {
  test("handles empty file list", () => {
    const config: LabelConfig = {
      rules: [{ pattern: "docs/**", label: "documentation", priority: 1 }],
    };
    const result = assignLabels([], config);
    expect(result).toHaveLength(0);
  });

  test("handles empty rules", () => {
    const config: LabelConfig = { rules: [] };
    const files = ["src/index.ts"];
    const result = assignLabels(files, config);
    expect(result).toHaveLength(0);
  });

  test("matches root-level files with * pattern", () => {
    const config: LabelConfig = {
      rules: [{ pattern: "*.md", label: "docs-root", priority: 1 }],
    };
    const files = ["README.md", "CHANGELOG.md"];
    const result = assignLabels(files, config);
    expect(result).toContain("docs-root");
  });

  test("handles invalid glob pattern gracefully", () => {
    const config: LabelConfig = {
      rules: [{ pattern: "[invalid", label: "bad", priority: 1 }],
    };
    const files = ["src/index.ts"];
    // Should not throw, just skip invalid patterns
    expect(() => assignLabels(files, config)).not.toThrow();
  });
});

describe("assignLabels - fixture: full PR scenario", () => {
  const prConfig: LabelConfig = {
    rules: [
      { pattern: "docs/**", label: "documentation", priority: 1 },
      { pattern: "src/api/**", label: "api", priority: 3 },
      { pattern: "**/*.test.*", label: "tests", priority: 2 },
      { pattern: "src/**", label: "source", priority: 1 },
      { pattern: ".github/**", label: "ci", priority: 4 },
    ],
  };

  test("mixed PR with docs, api, and test files", () => {
    const files = [
      "docs/api-guide.md",
      "src/api/users.ts",
      "src/api/users.test.ts",
      "src/utils.ts",
    ];
    const result = assignLabels(files, prConfig);
    expect(result).toContain("documentation");
    expect(result).toContain("api");
    expect(result).toContain("tests");
    expect(result).toContain("source");
  });

  test("CI-only PR", () => {
    const files = [".github/workflows/ci.yml", ".github/dependabot.yml"];
    const result = assignLabels(files, prConfig);
    expect(result).toContain("ci");
    expect(result).not.toContain("documentation");
    expect(result).not.toContain("api");
  });
});
