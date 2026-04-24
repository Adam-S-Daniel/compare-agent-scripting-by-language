// TDD: tests written first (red), then implementation (green), then refactor.
import { describe, test, expect } from "bun:test";
import { assignLabels, type LabelRule, type LabelConfig } from "./labeler";

// Default config used across most tests
const defaultConfig: LabelConfig = {
  rules: [
    { pattern: "docs/**", label: "documentation", priority: 10 },
    { pattern: "*.md", label: "documentation", priority: 10 },
    { pattern: "src/api/**", label: "api", priority: 8 },
    { pattern: "**/*.test.*", label: "tests", priority: 9 },
    { pattern: "src/**", label: "frontend", priority: 5 },
  ],
};

describe("assignLabels - basic cases", () => {
  test("returns empty array for empty file list", () => {
    const result = assignLabels([], defaultConfig);
    expect(result).toEqual([]);
  });

  test("returns empty array when no rules match", () => {
    const result = assignLabels(["some/unknown/path.xyz"], defaultConfig);
    expect(result).toEqual([]);
  });

  test("applies documentation label for docs/ files", () => {
    const files = ["docs/README.md", "docs/api/overview.md"];
    const result = assignLabels(files, defaultConfig);
    expect(result).toContain("documentation");
  });

  test("applies api label for src/api/ files", () => {
    const files = ["src/api/users.ts"];
    const result = assignLabels(files, defaultConfig);
    expect(result).toContain("api");
  });

  test("applies tests label for .test. files", () => {
    const files = ["src/utils.test.ts"];
    const result = assignLabels(files, defaultConfig);
    expect(result).toContain("tests");
  });

  test("applies documentation label for root .md files", () => {
    const files = ["README.md"];
    const result = assignLabels(files, defaultConfig);
    expect(result).toContain("documentation");
  });

  test("applies frontend label for src/ files", () => {
    const files = ["src/components/Button.ts"];
    const result = assignLabels(files, defaultConfig);
    expect(result).toContain("frontend");
  });
});

describe("assignLabels - multiple labels", () => {
  test("applies multiple labels for multiple files from different dirs", () => {
    const files = ["docs/guide.md", "src/api/users.ts", "src/utils.test.ts"];
    const result = assignLabels(files, defaultConfig);
    expect(result).toContain("documentation");
    expect(result).toContain("api");
    expect(result).toContain("tests");
  });

  test("applies multiple labels from single file matching multiple rules", () => {
    // src/api/users.test.ts matches: api (8), tests (9), frontend (5)
    const files = ["src/api/users.test.ts"];
    const result = assignLabels(files, defaultConfig);
    expect(result).toContain("api");
    expect(result).toContain("tests");
    expect(result).toContain("frontend");
  });

  test("deduplicates labels when multiple files match same rule", () => {
    const files = ["docs/guide.md", "docs/api.md", "README.md"];
    const result = assignLabels(files, defaultConfig);
    const docCount = result.filter((l) => l === "documentation").length;
    expect(docCount).toBe(1);
  });
});

describe("assignLabels - priority ordering", () => {
  test("orders labels by priority descending", () => {
    // docs match: documentation(10); src/api match: api(8); src match: frontend(5)
    const files = ["docs/guide.md", "src/api/users.ts", "src/Button.ts"];
    const result = assignLabels(files, defaultConfig);
    const docIdx = result.indexOf("documentation");
    const apiIdx = result.indexOf("api");
    const frontendIdx = result.indexOf("frontend");
    expect(docIdx).toBeLessThan(apiIdx);
    expect(apiIdx).toBeLessThan(frontendIdx);
  });

  test("higher priority rule wins label ordering when same file matches multiple", () => {
    // src/api/users.ts matches api(8) and frontend(5)
    const files = ["src/api/users.ts"];
    const result = assignLabels(files, defaultConfig);
    const apiIdx = result.indexOf("api");
    const frontendIdx = result.indexOf("frontend");
    expect(apiIdx).toBeLessThan(frontendIdx);
  });

  test("labels at same priority are sorted alphabetically for stability", () => {
    const config: LabelConfig = {
      rules: [
        { pattern: "*.ts", label: "typescript", priority: 5 },
        { pattern: "*.ts", label: "code", priority: 5 },
      ],
    };
    const result = assignLabels(["index.ts"], config);
    expect(result[0]).toBe("code");
    expect(result[1]).toBe("typescript");
  });
});

describe("assignLabels - glob pattern support", () => {
  test("supports ** glob for deep directory matching", () => {
    const files = ["docs/nested/deep/file.md"];
    const result = assignLabels(files, defaultConfig);
    expect(result).toContain("documentation");
  });

  test("supports *.ext pattern for extension matching", () => {
    const files = ["myfile.test.js"];
    const result = assignLabels(files, defaultConfig);
    expect(result).toContain("tests");
  });

  test("does not apply label when pattern does not match", () => {
    const files = ["src/api/users.ts"];
    const result = assignLabels(files, defaultConfig);
    expect(result).not.toContain("documentation");
  });
});

describe("assignLabels - custom configs", () => {
  test("works with empty rules config", () => {
    const result = assignLabels(["src/app.ts"], { rules: [] });
    expect(result).toEqual([]);
  });

  test("works with single rule", () => {
    const config: LabelConfig = {
      rules: [{ pattern: "**/*.ts", label: "typescript", priority: 1 }],
    };
    const result = assignLabels(["src/app.ts", "test/app.test.ts"], config);
    expect(result).toEqual(["typescript"]);
  });

  test("handles large number of files efficiently", () => {
    const files = Array.from({ length: 100 }, (_, i) => `src/file${i}.ts`);
    const result = assignLabels(files, defaultConfig);
    expect(result).toContain("frontend");
  });
});
