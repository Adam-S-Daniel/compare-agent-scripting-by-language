import { minimize } from "bun:utils";

// Type definitions
export interface LabelRule {
  pattern: string;
  labels: string[];
  priority: number;
}

export interface AssignedLabels {
  file: string;
  labels: string[];
}

// Convert glob pattern to regex
function globToRegex(glob: string): RegExp {
  // Escape special regex chars except * and ?
  let pattern = glob
    .replace(/[.+^${}()|[\]\\]/g, "\\$&")
    .replace(/\*/g, ".*")
    .replace(/\?/g, ".");

  // Anchor pattern
  return new RegExp(`^${pattern}$`);
}

// Check if a file matches a glob pattern
function matchesPattern(filePath: string, pattern: string): boolean {
  const regex = globToRegex(pattern);
  return regex.test(filePath);
}

// Main function: assign labels to files based on rules
export function assignLabels(
  filePaths: string[],
  rules: LabelRule[]
): string[] {
  const labelSet = new Set<string>();

  // For each file, find matching rules
  for (const filePath of filePaths) {
    const matchedRules = rules.filter((rule) =>
      matchesPattern(filePath, rule.pattern)
    );

    // Add labels from matching rules
    for (const rule of matchedRules) {
      for (const label of rule.labels) {
        labelSet.add(label);
      }
    }
  }

  // Convert set to sorted array for consistent output
  return Array.from(labelSet).sort();
}

// Function to get detailed label assignments per file
export function assignLabelsDetailed(
  filePaths: string[],
  rules: LabelRule[]
): AssignedLabels[] {
  const result: AssignedLabels[] = [];

  for (const filePath of filePaths) {
    const labels = new Set<string>();
    const matchedRules = rules.filter((rule) =>
      matchesPattern(filePath, rule.pattern)
    );

    for (const rule of matchedRules) {
      for (const label of rule.labels) {
        labels.add(label);
      }
    }

    if (labels.size > 0) {
      result.push({
        file: filePath,
        labels: Array.from(labels).sort(),
      });
    }
  }

  return result;
}
