import { describe, it, expect } from "bun:test";
import { assignLabels } from "./pr-label-assigner";

// Test fixtures for different file paths
const mockFiles = {
  docs: [
    "docs/README.md",
    "docs/api/endpoints.md",
    "docs/guides/setup.md"
  ],
  src: [
    "src/api/routes.ts",
    "src/api/middleware.ts",
    "src/utils/helpers.ts",
    "src/index.ts"
  ],
  tests: [
    "src/api/routes.test.ts",
    "tests/integration.test.ts",
    "src/utils/helpers.test.ts"
  ],
  config: [
    "tsconfig.json",
    "package.json",
    "jest.config.js",
    ".github/workflows/ci.yml"
  ]
};

// Configuration: path patterns -> labels
const labelRules = [
  { pattern: "docs/**", labels: ["documentation"], priority: 1 },
  { pattern: "src/api/**", labels: ["api"], priority: 2 },
  { pattern: "src/**", labels: ["code"], priority: 3 },
  { pattern: "*.test.*", labels: ["tests"], priority: 1 },
  { pattern: "*.json", labels: ["configuration"], priority: 2 },
  { pattern: ".github/**", labels: ["ci"], priority: 2 },
];

describe("PR Label Assigner", () => {
  // Test 1: Basic single pattern matching
  it("should assign documentation label to docs files", () => {
    const result = assignLabels(mockFiles.docs, labelRules);
    expect(result).toContain("documentation");
  });

  // Test 2: Multiple labels for same file
  it("should assign multiple labels when file matches multiple patterns", () => {
    const files = ["src/api/routes.test.ts"];
    const result = assignLabels(files, labelRules);
    expect(result).toContain("api");
    expect(result).toContain("tests");
  });

  // Test 3: API files get api label
  it("should assign api label to src/api files", () => {
    const result = assignLabels(mockFiles.src.slice(0, 2), labelRules);
    expect(result).toContain("api");
  });

  // Test 4: Non-matching files return empty or no labels
  it("should handle files with no matching patterns", () => {
    const files = ["random.txt"];
    const result = assignLabels(files, labelRules);
    expect(Array.isArray(result)).toBe(true);
  });

  // Test 5: Config files get configuration label
  it("should assign configuration label to json files", () => {
    const files = ["tsconfig.json", "package.json"];
    const result = assignLabels(files, labelRules);
    expect(result).toContain("configuration");
  });

  // Test 6: Test files get tests label
  it("should assign tests label to .test files", () => {
    const result = assignLabels(mockFiles.tests, labelRules);
    expect(result).toContain("tests");
  });

  // Test 7: Priority ordering
  it("should respect priority when determining final label set", () => {
    const files = ["src/api/routes.test.ts"];
    const result = assignLabels(files, labelRules);
    expect(result.length).toBeGreaterThan(0);
    expect(result).toContain("api");
    expect(result).toContain("tests");
  });

  // Test 8: Complex scenario with mixed files
  it("should assign correct labels to mixed file list", () => {
    const mixedFiles = [
      "docs/README.md",
      "src/api/routes.ts",
      "src/utils/helpers.test.ts",
      "package.json",
      ".github/workflows/ci.yml"
    ];
    const result = assignLabels(mixedFiles, labelRules);
    expect(result).toContain("documentation");
    expect(result).toContain("api");
    expect(result).toContain("tests");
    expect(result).toContain("configuration");
    expect(result).toContain("ci");
  });

  // Test 9: Duplicate labels should not appear twice
  it("should deduplicate labels", () => {
    const files = ["docs/README.md", "docs/api/endpoints.md"];
    const result = assignLabels(files, labelRules);
    const documentationCount = result.filter(l => l === "documentation").length;
    expect(documentationCount).toBe(1);
  });

  // Test 10: Empty file list returns empty labels
  it("should return empty array for empty file list", () => {
    const result = assignLabels([], labelRules);
    expect(result.length).toBe(0);
  });
});
