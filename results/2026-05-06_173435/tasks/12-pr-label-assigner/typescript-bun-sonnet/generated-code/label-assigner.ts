// PR Label Assigner
// Assigns GitHub PR labels based on configurable glob-pattern rules.
// Rules are evaluated in priority order (lower number = higher priority).
// All matching rules contribute their labels; output is deduplicated and sorted.

export interface LabelRule {
  /** Glob pattern to match against changed file paths (e.g., "docs/", ".test.") */
  pattern: string;
  /** Label to apply when the pattern matches */
  label: string;
  /** Lower number = higher priority. Priority only affects evaluation order;
   *  all matching rules always contribute their labels. */
  priority: number;
}

export interface LabelConfig {
  rules: LabelRule[];
}

/**
 * Assigns labels to a PR based on changed file paths and a config.
 * Returns a sorted, deduplicated array of label strings.
 */
export function assignLabels(files: string[], config: LabelConfig): string[] {
  if (files.length === 0 || config.rules.length === 0) {
    return [];
  }

  // Evaluate rules in priority order (lower number first)
  const sortedRules = [...config.rules].sort((a, b) => a.priority - b.priority);
  const labelSet = new Set<string>();

  for (const file of files) {
    for (const rule of sortedRules) {
      const glob = new Bun.Glob(rule.pattern);
      if (glob.match(file)) {
        labelSet.add(rule.label);
      }
    }
  }

  return Array.from(labelSet).sort();
}

// Default configuration covering common project patterns
export const DEFAULT_CONFIG: LabelConfig = {
  rules: [
    { pattern: "docs/**", label: "documentation", priority: 1 },
    { pattern: "*.md", label: "documentation", priority: 1 },
    { pattern: "src/api/**", label: "api", priority: 2 },
    { pattern: "**/*.test.*", label: "tests", priority: 3 },
    { pattern: "**/*.spec.*", label: "tests", priority: 3 },
    { pattern: ".github/**", label: "ci/cd", priority: 4 },
  ],
};

// Demo mode: run with fixture inputs and print parseable results
if (import.meta.main) {
  const fixtures: Array<{ name: string; files: string[] }> = [
    { name: "docs-only", files: ["docs/README.md", "docs/api.md"] },
    { name: "mixed-docs-api", files: ["docs/README.md", "src/api/routes.ts"] },
    { name: "test-files", files: ["src/utils.test.ts", "src/api.test.ts"] },
    { name: "multi-label-single-file", files: ["src/api/routes.test.ts"] },
    { name: "no-match", files: ["random/file.txt", "build/output.bin"] },
    { name: "ci-files", files: [".github/workflows/ci.yml", ".github/dependabot.yml"] },
  ];

  console.log("=== PR Label Assigner Demo ===");
  for (const fixture of fixtures) {
    const labels = assignLabels(fixture.files, DEFAULT_CONFIG);
    const labelStr = labels.length > 0 ? labels.join(",") : "(none)";
    console.log(`[FIXTURE:${fixture.name}] LABELS: ${labelStr}`);
  }
  console.log("=== End Demo ===");
}
