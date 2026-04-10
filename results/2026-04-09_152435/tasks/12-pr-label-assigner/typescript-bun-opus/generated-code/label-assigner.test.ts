/**
 * TDD tests for PR Label Assigner
 *
 * Red/Green/Refactor methodology:
 * - Each describe block represents a TDD cycle
 * - Tests were written first (red), then code to pass (green), then refactored
 */

import { describe, test, expect } from "bun:test";
import {
  globToRegex,
  matchesGlob,
  assignLabels,
  type LabelConfig,
  type LabelRule,
} from "./label-assigner";

// --- TDD Cycle 1: Glob pattern matching ---

describe("globToRegex", () => {
  // RED: wrote these tests before implementing globToRegex
  test("converts simple wildcard * to match non-slash chars", () => {
    const re = globToRegex("*.ts");
    expect(re.test("index.ts")).toBe(true);
    expect(re.test("foo.ts")).toBe(true);
    expect(re.test("src/foo.ts")).toBe(false); // * should not cross /
  });

  test("converts ** to match across directories", () => {
    const re = globToRegex("docs/**");
    expect(re.test("docs/readme.md")).toBe(true);
    expect(re.test("docs/api/ref.md")).toBe(true);
    expect(re.test("src/docs/readme.md")).toBe(false);
  });

  test("converts **/ prefix to match zero or more directories", () => {
    const re = globToRegex("**/test.ts");
    expect(re.test("test.ts")).toBe(true);
    expect(re.test("src/test.ts")).toBe(true);
    expect(re.test("a/b/test.ts")).toBe(true);
  });

  test("handles *.test.* pattern", () => {
    const re = globToRegex("*.test.*");
    expect(re.test("foo.test.ts")).toBe(true);
    expect(re.test("bar.test.js")).toBe(true);
    expect(re.test("foo.ts")).toBe(false);
    // Should not cross directories
    expect(re.test("src/foo.test.ts")).toBe(false);
  });

  test("handles ? single character wildcard", () => {
    const re = globToRegex("src/?.ts");
    expect(re.test("src/a.ts")).toBe(true);
    expect(re.test("src/ab.ts")).toBe(false);
  });
});

describe("matchesGlob", () => {
  // GREEN: matchesGlob wraps globToRegex for convenience
  test("returns true for matching paths", () => {
    expect(matchesGlob("docs/guide.md", "docs/**")).toBe(true);
    expect(matchesGlob("src/api/routes.ts", "src/api/**")).toBe(true);
  });

  test("returns false for non-matching paths", () => {
    expect(matchesGlob("src/index.ts", "docs/**")).toBe(false);
    expect(matchesGlob("test.js", "src/**")).toBe(false);
  });
});

// --- TDD Cycle 2: Basic label assignment ---

describe("assignLabels - basic", () => {
  const basicConfig: LabelConfig = {
    rules: [
      { pattern: "docs/**", label: "documentation", priority: 1 },
      { pattern: "src/api/**", label: "api", priority: 2 },
      { pattern: "src/**", label: "core", priority: 3 },
    ],
  };

  // RED: wrote these tests before implementing assignLabels
  test("assigns correct label for a single docs file", () => {
    const result = assignLabels(["docs/readme.md"], basicConfig);
    expect(result.finalLabels).toContain("documentation");
    expect(result.fileResults[0].matchedLabels).toContain("documentation");
  });

  test("assigns correct label for an api file", () => {
    const result = assignLabels(["src/api/users.ts"], basicConfig);
    expect(result.finalLabels).toContain("api");
    expect(result.finalLabels).toContain("core"); // also matches src/**
  });

  test("returns empty results for empty file list", () => {
    const result = assignLabels([], basicConfig);
    expect(result.finalLabels).toEqual([]);
    expect(result.fileResults).toEqual([]);
  });
});

// --- TDD Cycle 3: Multiple labels per file ---

describe("assignLabels - multiple labels per file", () => {
  const multiConfig: LabelConfig = {
    rules: [
      { pattern: "**/*.test.ts", label: "tests", priority: 1 },
      { pattern: "src/api/**", label: "api", priority: 2 },
      { pattern: "src/**", label: "core", priority: 3 },
    ],
  };

  test("a test file in api dir gets both tests and api labels", () => {
    const result = assignLabels(["src/api/users.test.ts"], multiConfig);
    expect(result.finalLabels).toContain("tests");
    expect(result.finalLabels).toContain("api");
    expect(result.finalLabels).toContain("core");
  });

  test("multiple files accumulate distinct labels", () => {
    const result = assignLabels(
      ["src/api/users.ts", "src/utils/helpers.ts"],
      multiConfig
    );
    expect(result.finalLabels).toContain("api");
    expect(result.finalLabels).toContain("core");
    expect(result.finalLabels).not.toContain("tests");
  });
});

// --- TDD Cycle 4: Priority ordering ---

describe("assignLabels - priority ordering", () => {
  const priorityConfig: LabelConfig = {
    rules: [
      { pattern: "src/**", label: "core", priority: 3 },
      { pattern: "src/api/**", label: "api", priority: 1 },
      { pattern: "docs/**", label: "documentation", priority: 2 },
    ],
  };

  test("final labels are sorted by priority (lowest number first)", () => {
    const result = assignLabels(
      ["src/api/routes.ts", "docs/guide.md"],
      priorityConfig
    );
    // api (1) should come before documentation (2) which comes before core (3)
    expect(result.finalLabels).toEqual(["api", "documentation", "core"]);
  });

  test("maxLabels limits output to highest priority labels", () => {
    const config: LabelConfig = {
      ...priorityConfig,
      maxLabels: 2,
    };
    const result = assignLabels(
      ["src/api/routes.ts", "docs/guide.md"],
      config
    );
    // Only keep top 2 by priority
    expect(result.finalLabels).toEqual(["api", "documentation"]);
    expect(result.finalLabels).not.toContain("core");
  });
});

// --- TDD Cycle 5: Error handling ---

describe("assignLabels - error handling", () => {
  test("throws on missing rules", () => {
    expect(() =>
      assignLabels(["file.ts"], { rules: [] })
    ).toThrow("at least one rule");
  });

  test("throws on empty pattern", () => {
    expect(() =>
      assignLabels(["file.ts"], {
        rules: [{ pattern: "", label: "x", priority: 0 }],
      })
    ).toThrow("pattern must not be empty");
  });

  test("throws on empty label", () => {
    expect(() =>
      assignLabels(["file.ts"], {
        rules: [{ pattern: "*.ts", label: "", priority: 0 }],
      })
    ).toThrow("label must not be empty");
  });

  test("throws on negative priority", () => {
    expect(() =>
      assignLabels(["file.ts"], {
        rules: [{ pattern: "*.ts", label: "x", priority: -1 }],
      })
    ).toThrow("non-negative number");
  });
});

// --- TDD Cycle 6: Realistic fixture ---

describe("assignLabels - realistic PR scenario", () => {
  // Simulates a typical PR config
  const realisticConfig: LabelConfig = {
    rules: [
      { pattern: "docs/**", label: "documentation", priority: 1 },
      { pattern: "src/api/**", label: "api", priority: 2 },
      { pattern: "**/*.test.*", label: "tests", priority: 3 },
      { pattern: "**/*.spec.*", label: "tests", priority: 3 },
      { pattern: "src/**", label: "core", priority: 4 },
      { pattern: ".github/**", label: "ci", priority: 5 },
      { pattern: "*.md", label: "documentation", priority: 6 },
      { pattern: "package.json", label: "dependencies", priority: 7 },
    ],
  };

  // Mock file list simulating a real PR
  const mockPRFiles = [
    "src/api/users.ts",
    "src/api/users.test.ts",
    "src/utils/format.ts",
    "docs/api-reference.md",
    "package.json",
    "README.md",
  ];

  test("assigns all expected labels for a realistic PR", () => {
    const result = assignLabels(mockPRFiles, realisticConfig);
    expect(result.finalLabels).toContain("documentation");
    expect(result.finalLabels).toContain("api");
    expect(result.finalLabels).toContain("tests");
    expect(result.finalLabels).toContain("core");
    expect(result.finalLabels).toContain("dependencies");
  });

  test("per-file results are correct", () => {
    const result = assignLabels(mockPRFiles, realisticConfig);
    const apiFile = result.fileResults.find(
      (f) => f.file === "src/api/users.ts"
    );
    expect(apiFile?.matchedLabels).toContain("api");
    expect(apiFile?.matchedLabels).toContain("core");

    const testFile = result.fileResults.find(
      (f) => f.file === "src/api/users.test.ts"
    );
    expect(testFile?.matchedLabels).toContain("tests");
    expect(testFile?.matchedLabels).toContain("api");

    const readmeFile = result.fileResults.find(
      (f) => f.file === "README.md"
    );
    expect(readmeFile?.matchedLabels).toContain("documentation");
  });

  test("labels are ordered by priority", () => {
    const result = assignLabels(mockPRFiles, realisticConfig);
    const docIdx = result.finalLabels.indexOf("documentation");
    const apiIdx = result.finalLabels.indexOf("api");
    const testsIdx = result.finalLabels.indexOf("tests");
    const coreIdx = result.finalLabels.indexOf("core");
    // documentation(1) < api(2) < tests(3) < core(4)
    expect(docIdx).toBeLessThan(apiIdx);
    expect(apiIdx).toBeLessThan(testsIdx);
    expect(testsIdx).toBeLessThan(coreIdx);
  });
});
