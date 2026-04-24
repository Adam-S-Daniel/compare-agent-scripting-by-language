// Core label assignment logic: maps changed file paths to PR labels via glob rules.
import { Glob } from "bun";

export interface LabelRule {
  pattern: string; // glob pattern (e.g. "docs/**", "**/*.test.*")
  label: string;   // label to apply when pattern matches
  priority: number; // higher numbers take precedence in output ordering
}

export interface LabelConfig {
  rules: LabelRule[];
}

// assignLabels matches each changed file against configured rules and returns
// the deduplicated set of labels, ordered by priority descending then alphabetically.
export function assignLabels(files: string[], config: LabelConfig): string[] {
  // Track the highest priority at which each label was matched
  const labelPriority = new Map<string, number>();

  for (const file of files) {
    for (const rule of config.rules) {
      const glob = new Glob(rule.pattern);
      if (glob.match(file)) {
        const current = labelPriority.get(rule.label) ?? -Infinity;
        if (rule.priority > current) {
          labelPriority.set(rule.label, rule.priority);
        }
      }
    }
  }

  // Sort: highest priority first; ties broken alphabetically for stable output
  return Array.from(labelPriority.entries())
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .map(([label]) => label);
}
