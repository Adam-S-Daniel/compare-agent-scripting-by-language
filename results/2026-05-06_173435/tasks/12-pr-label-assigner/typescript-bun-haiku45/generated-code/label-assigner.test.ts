import { describe, it, expect, beforeEach, afterEach } from "bun:test";
import { assignLabels, loadConfig, getLabelsForPR } from "./label-assigner";
import { existsSync, unlinkSync } from "fs";

describe("Label Assigner - Basic Functionality", () => {
  it("should assign a single label to a file matching a simple path rule", () => {
    const rules = [
      { pattern: "docs/**", labels: ["documentation"] }
    ];
    const files = ["docs/README.md"];

    const result = assignLabels(files, rules);

    expect(result).toEqual(["documentation"]);
  });

  it("should assign multiple labels to a single file matching multiple rules", () => {
    const rules = [
      { pattern: "docs/**", labels: ["documentation"] },
      { pattern: "**/*.md", labels: ["markdown"] }
    ];
    const files = ["docs/README.md"];

    const result = assignLabels(files, rules);

    expect(result).toEqual(["documentation", "markdown"]);
  });

  it("should handle multiple files with different matching rules", () => {
    const rules = [
      { pattern: "src/api/**", labels: ["api"] },
      { pattern: "src/ui/**", labels: ["ui"] }
    ];
    const files = ["src/api/users.ts", "src/ui/components.tsx"];

    const result = assignLabels(files, rules);

    expect(result).toEqual(["api", "ui"]);
  });

  it("should return empty array when no files match any rules", () => {
    const rules = [
      { pattern: "docs/**", labels: ["documentation"] }
    ];
    const files = ["src/index.ts"];

    const result = assignLabels(files, rules);

    expect(result).toEqual([]);
  });

  it("should handle glob patterns with asterisks", () => {
    const rules = [
      { pattern: "*.test.ts", labels: ["tests"] }
    ];
    const files = ["utils.test.ts", "helpers.test.ts"];

    const result = assignLabels(files, rules);

    expect(result).toEqual(["tests"]);
  });

  it("should deduplicate labels across multiple matching rules", () => {
    const rules = [
      { pattern: "src/**", labels: ["code"] },
      { pattern: "**/*.ts", labels: ["code", "typescript"] }
    ];
    const files = ["src/index.ts"];

    const result = assignLabels(files, rules);

    expect(result).toEqual(["code", "typescript"]);
  });

  it("should handle priority ordering when rules conflict", () => {
    const rules = [
      { pattern: "src/**", labels: ["lowpriority"], priority: 10 },
      { pattern: "src/important/**", labels: ["highpriority"], priority: 1 }
    ];
    const files = ["src/important/config.ts"];

    const result = assignLabels(files, rules);

    // Both rules match, so both labels should be included
    // Priority affects which label "wins" when there's conflict
    expect(result).toContain("highpriority");
  });
});

describe("Label Assigner - Configuration Loading", () => {
  const testConfigFile = "test-label-config.json";

  afterEach(() => {
    if (existsSync(testConfigFile)) {
      unlinkSync(testConfigFile);
    }
  });

  it("should load configuration from a JSON file", () => {
    const configContent = {
      rules: [
        { pattern: "docs/**", labels: ["documentation"] },
        { pattern: "src/api/**", labels: ["api"] }
      ]
    };
    Bun.write(testConfigFile, JSON.stringify(configContent));

    const config = loadConfig(testConfigFile);

    expect(config.rules).toHaveLength(2);
    expect(config.rules[0].pattern).toBe("docs/**");
  });

  it("should handle missing config file gracefully", () => {
    expect(() => loadConfig("nonexistent.json")).toThrow();
  });

  it("should validate config structure", () => {
    const invalidConfig = { invalid: "structure" };
    Bun.write(testConfigFile, JSON.stringify(invalidConfig));

    expect(() => loadConfig(testConfigFile)).toThrow();
  });
});

describe("Label Assigner - PR Workflow", () => {
  it("should process a complete PR workflow with config and files", () => {
    const config = {
      rules: [
        { pattern: "docs/**", labels: ["documentation"] },
        { pattern: "src/api/**", labels: ["api"] },
        { pattern: "src/ui/**", labels: ["ui"] },
        { pattern: "*.test.ts", labels: ["tests"] }
      ]
    };

    const changedFiles = [
      "docs/API.md",
      "src/api/users.ts",
      "src/ui/Button.tsx",
      "utils.test.ts"
    ];

    const labels = getLabelsForPR(changedFiles, config.rules);

    expect(labels).toContain("documentation");
    expect(labels).toContain("api");
    expect(labels).toContain("ui");
    expect(labels).toContain("tests");
  });
});
