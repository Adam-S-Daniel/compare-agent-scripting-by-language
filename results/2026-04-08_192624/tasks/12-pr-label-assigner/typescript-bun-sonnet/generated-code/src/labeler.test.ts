/**
 * Tests for PR Label Assigner
 * TDD approach: tests written BEFORE implementation
 */

import { describe, it, expect } from "bun:test";
import { assignLabels, type LabelRule, type LabelResult } from "./labeler";

// --- Test fixtures ---

const DEFAULT_RULES: LabelRule[] = [
  { pattern: "docs/**", label: "documentation", priority: 10 },
  { pattern: "src/api/**", label: "api", priority: 20 },
  { pattern: "src/**", label: "source", priority: 15 },
  { pattern: "**/*.test.*", label: "tests", priority: 30 },
  { pattern: "**/*.spec.*", label: "tests", priority: 30 },
  { pattern: ".github/**", label: "ci/cd", priority: 25 },
  { pattern: "*.md", label: "documentation", priority: 5 },
  { pattern: "src/api/auth/**", label: "security", priority: 35 },
];

// --- Test suite ---

describe("assignLabels", () => {
  // RED: Basic documentation label
  it("assigns 'documentation' label for docs/** files", () => {
    const files = ["docs/getting-started.md", "docs/api/reference.md"];
    const result = assignLabels(files, DEFAULT_RULES);
    expect(result.labels).toContain("documentation");
  });

  // RED: API label from src/api path
  it("assigns 'api' label for src/api/** files", () => {
    const files = ["src/api/users.ts"];
    const result = assignLabels(files, DEFAULT_RULES);
    expect(result.labels).toContain("api");
  });

  // RED: Multiple labels per file
  it("assigns multiple labels when a file matches multiple rules", () => {
    const files = ["src/api/users.ts"];
    const result = assignLabels(files, DEFAULT_RULES);
    // matches src/api/** (api) and src/** (source)
    expect(result.labels).toContain("api");
    expect(result.labels).toContain("source");
  });

  // RED: Test files get 'tests' label
  it("assigns 'tests' label for *.test.* files", () => {
    const files = ["src/api/users.test.ts"];
    const result = assignLabels(files, DEFAULT_RULES);
    expect(result.labels).toContain("tests");
  });

  // RED: spec files also get 'tests' label
  it("assigns 'tests' label for *.spec.* files", () => {
    const files = ["src/components/Button.spec.tsx"];
    const result = assignLabels(files, DEFAULT_RULES);
    expect(result.labels).toContain("tests");
  });

  // RED: Multiple files produce union of labels
  it("returns union of labels from all files", () => {
    const files = ["docs/readme.md", "src/api/users.ts"];
    const result = assignLabels(files, DEFAULT_RULES);
    expect(result.labels).toContain("documentation");
    expect(result.labels).toContain("api");
    expect(result.labels).toContain("source");
  });

  // RED: No duplicates in label set
  it("deduplicates labels", () => {
    const files = ["docs/a.md", "docs/b.md", "*.md"];
    const result = assignLabels(files, DEFAULT_RULES);
    const docCount = result.labels.filter((l) => l === "documentation").length;
    expect(docCount).toBe(1);
  });

  // RED: Empty file list returns no labels
  it("returns empty labels for empty file list", () => {
    const result = assignLabels([], DEFAULT_RULES);
    expect(result.labels).toHaveLength(0);
  });

  // RED: No rules returns no labels
  it("returns empty labels when no rules provided", () => {
    const files = ["src/api/users.ts"];
    const result = assignLabels(files, []);
    expect(result.labels).toHaveLength(0);
  });

  // RED: Markdown files at root
  it("assigns 'documentation' label for root *.md files", () => {
    const files = ["README.md", "CHANGELOG.md"];
    const result = assignLabels(files, DEFAULT_RULES);
    expect(result.labels).toContain("documentation");
  });

  // RED: CI/CD label for .github/** files
  it("assigns 'ci/cd' label for .github/** files", () => {
    const files = [".github/workflows/ci.yml"];
    const result = assignLabels(files, DEFAULT_RULES);
    expect(result.labels).toContain("ci/cd");
  });

  // RED: Priority ordering — higher priority rules listed first in matchedRules
  it("returns matchedRules sorted by priority descending", () => {
    const files = ["src/api/auth/login.ts"];
    const result = assignLabels(files, DEFAULT_RULES);
    // security (35) > api (20) > source (15)
    const priorities = result.matchedRules.map((r) => r.priority);
    for (let i = 1; i < priorities.length; i++) {
      expect(priorities[i - 1]).toBeGreaterThanOrEqual(priorities[i]);
    }
  });

  // RED: Security label for auth files
  it("assigns 'security' label for src/api/auth/** files", () => {
    const files = ["src/api/auth/login.ts"];
    const result = assignLabels(files, DEFAULT_RULES);
    expect(result.labels).toContain("security");
  });

  // RED: Files with no match produce no labels
  it("produces no labels for unmatched files", () => {
    const simpleRules: LabelRule[] = [
      { pattern: "docs/**", label: "documentation", priority: 10 },
    ];
    const files = ["src/main.ts"];
    const result = assignLabels(files, simpleRules);
    expect(result.labels).toHaveLength(0);
  });

  // RED: matchedRules tracks which rules fired
  it("tracks which rules were matched", () => {
    const files = ["src/api/users.ts"];
    const result = assignLabels(files, DEFAULT_RULES);
    const matchedLabels = result.matchedRules.map((r) => r.label);
    expect(matchedLabels).toContain("api");
    expect(matchedLabels).toContain("source");
  });

  // RED: matchedFiles shows per-file breakdown
  it("tracks matched files per rule", () => {
    const files = ["docs/a.md", "src/api/users.ts"];
    const result = assignLabels(files, DEFAULT_RULES);
    expect(result.matchedFiles).toBeDefined();
    const docsEntry = result.matchedFiles.find(
      (e) => e.file === "docs/a.md"
    );
    expect(docsEntry?.labels).toContain("documentation");
  });

  // RED: conflicting rules — only highest-priority label when conflict flag is set
  it("supports conflict resolution: highest priority wins when exclusive=true", () => {
    const conflictRules: LabelRule[] = [
      { pattern: "src/**", label: "source", priority: 10 },
      { pattern: "src/api/**", label: "api", priority: 20, exclusive: true },
    ];
    const files = ["src/api/users.ts"];
    const result = assignLabels(files, conflictRules);
    // With exclusive=true on 'api', 'source' should be suppressed for this file
    expect(result.labels).toContain("api");
    expect(result.labels).not.toContain("source");
  });
});

describe("assignLabels - mock PR scenarios", () => {
  it("typical frontend PR: styles and components", () => {
    const rules: LabelRule[] = [
      { pattern: "src/components/**", label: "frontend", priority: 10 },
      { pattern: "**/*.css", label: "styles", priority: 10 },
      { pattern: "**/*.test.*", label: "tests", priority: 20 },
    ];
    const files = [
      "src/components/Button.tsx",
      "src/components/Button.css",
      "src/components/Button.test.tsx",
    ];
    const result = assignLabels(files, rules);
    expect(result.labels).toContain("frontend");
    expect(result.labels).toContain("styles");
    expect(result.labels).toContain("tests");
  });

  it("infrastructure PR: only infra files", () => {
    const rules: LabelRule[] = [
      { pattern: "infra/**", label: "infrastructure", priority: 10 },
      { pattern: "terraform/**", label: "infrastructure", priority: 10 },
    ];
    const files = ["terraform/main.tf", "terraform/variables.tf"];
    const result = assignLabels(files, rules);
    expect(result.labels).toEqual(["infrastructure"]);
  });

  it("mixed PR with docs, api, and tests", () => {
    const files = [
      "docs/api-reference.md",
      "src/api/endpoints.ts",
      "src/api/endpoints.test.ts",
    ];
    const result = assignLabels(files, DEFAULT_RULES);
    expect(result.labels).toContain("documentation");
    expect(result.labels).toContain("api");
    expect(result.labels).toContain("tests");
    expect(result.labels).toContain("source");
  });
});
