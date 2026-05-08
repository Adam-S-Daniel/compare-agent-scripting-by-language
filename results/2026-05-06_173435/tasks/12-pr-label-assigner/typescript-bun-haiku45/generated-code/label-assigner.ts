import { minimatch } from "minimatch";
import { readFileSync } from "fs";

// Type definitions for clarity
export interface LabelRule {
  pattern: string;
  labels: string[];
  priority?: number; // Lower number = higher priority
}

export interface LabelConfig {
  rules: LabelRule[];
}

// Main function: assign labels to files based on matching rules
export function assignLabels(
  files: string[],
  rules: LabelRule[]
): string[] {
  const labelsSet = new Set<string>();

  for (const file of files) {
    for (const rule of rules) {
      // Use minimatch for glob pattern matching
      if (minimatch(file, rule.pattern)) {
        rule.labels.forEach((label) => labelsSet.add(label));
      }
    }
  }

  return Array.from(labelsSet).sort();
}

// Load configuration from a JSON file
export function loadConfig(filePath: string): LabelConfig {
  try {
    const content = readFileSync(filePath, "utf-8");
    const config = JSON.parse(content);

    // Validate config structure
    if (!config.rules || !Array.isArray(config.rules)) {
      throw new Error("Config must have a 'rules' array");
    }

    // Validate each rule
    for (const rule of config.rules) {
      if (!rule.pattern || !rule.labels || !Array.isArray(rule.labels)) {
        throw new Error("Each rule must have 'pattern' and 'labels' array");
      }
    }

    return config as LabelConfig;
  } catch (error) {
    if (error instanceof Error) {
      throw new Error(`Failed to load config from ${filePath}: ${error.message}`);
    }
    throw error;
  }
}

// Wrapper function for PR workflows
export function getLabelsForPR(
  changedFiles: string[],
  rules: LabelRule[]
): string[] {
  return assignLabels(changedFiles, rules);
}
