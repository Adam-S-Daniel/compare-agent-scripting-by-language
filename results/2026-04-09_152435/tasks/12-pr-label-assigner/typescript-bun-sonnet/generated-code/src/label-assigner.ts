// PR Label Assigner - Core Module
// Assigns labels to a PR based on which files were changed, using configurable glob rules.
// Uses micromatch for glob pattern matching (supports **, *, ?, etc.)

import micromatch from "micromatch";

/** A rule mapping a glob pattern to a label with a priority level. */
export interface LabelRule {
  /** Glob pattern to match against changed file paths (e.g., "docs/**", "*.test.*") */
  pattern: string;
  /** Label to apply when the pattern matches */
  label: string;
  /**
   * Priority for ordering in the output. Lower number = higher priority = appears first.
   * When multiple rules match, labels are ordered by their best (lowest) priority match.
   */
  priority: number;
}

/** Configuration object holding all label rules. */
export interface LabelConfig {
  rules: LabelRule[];
}

/**
 * Assigns labels to a PR based on its changed file paths.
 *
 * Algorithm:
 * 1. For each rule, check if ANY changed file matches its glob pattern.
 * 2. Collect all matching rules, grouped by label.
 * 3. For each label, record the best (lowest) priority from all its matching rules.
 * 4. Deduplicate labels and sort by priority (ascending = highest priority first).
 *
 * @param files - List of changed file paths in the PR
 * @param rules - Label rules to apply
 * @returns Sorted, deduplicated list of labels to assign
 */
export function assignLabels(files: string[], rules: LabelRule[]): string[] {
  if (files.length === 0 || rules.length === 0) {
    return [];
  }

  // Track the best (lowest) priority for each label that matches
  const labelPriority = new Map<string, number>();

  for (const rule of rules) {
    // micromatch checks if any file in the list matches the pattern
    const hasMatch = micromatch(files, rule.pattern, { dot: true }).length > 0;

    if (hasMatch) {
      // Keep the highest-priority (lowest number) match for each label
      const existing = labelPriority.get(rule.label);
      if (existing === undefined || rule.priority < existing) {
        labelPriority.set(rule.label, rule.priority);
      }
    }
  }

  // Sort labels: primary key = priority (ascending), secondary key = label name (stable)
  return Array.from(labelPriority.entries())
    .sort((a, b) => a[1] - b[1] || a[0].localeCompare(b[0]))
    .map(([label]) => label);
}
