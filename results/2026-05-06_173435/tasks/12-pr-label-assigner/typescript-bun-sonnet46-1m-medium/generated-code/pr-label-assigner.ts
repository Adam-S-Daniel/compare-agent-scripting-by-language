// PR Label Assigner
//
// Reads a list of changed file paths and applies labels based on configurable
// glob pattern rules. Supports multiple labels per file and priority ordering.

import { minimatch } from "minimatch";
import * as fs from "fs";

// ── Types ─────────────────────────────────────────────────────────────────────

export interface LabelRule {
  pattern: string; // glob pattern, e.g. "docs/**" or "**/*.test.*"
  label: string;   // label to apply when pattern matches
  priority: number; // higher value = higher priority in output ordering
}

export interface LabelConfig {
  rules: LabelRule[];
}

export interface LabelResult {
  labels: string[];                      // unique labels, sorted by priority desc then name asc
  fileMatches: Record<string, string[]>; // file path -> list of matched labels
}

// ── Core functions ────────────────────────────────────────────────────────────

/**
 * Returns true if filePath matches the glob pattern.
 * Uses minimatch with dot-file support enabled.
 */
export function matchesPattern(filePath: string, pattern: string): boolean {
  return minimatch(filePath, pattern, { dot: true });
}

/**
 * Given a list of changed file paths and a label config, returns the set of
 * labels that should be applied to the PR, along with per-file match details.
 *
 * Priority ordering: labels matched by higher-priority rules appear first.
 * When two labels share the same priority, they are sorted alphabetically.
 */
export function assignLabels(files: string[], config: LabelConfig): LabelResult {
  const fileMatches: Record<string, string[]> = {};
  // Track the maximum priority at which each label was matched
  const labelMaxPriority: Map<string, number> = new Map();

  for (const file of files) {
    const matchedLabels: string[] = [];

    for (const rule of config.rules) {
      if (matchesPattern(file, rule.pattern)) {
        matchedLabels.push(rule.label);

        const current = labelMaxPriority.get(rule.label) ?? -Infinity;
        if (rule.priority > current) {
          labelMaxPriority.set(rule.label, rule.priority);
        }
      }
    }

    fileMatches[file] = matchedLabels;
  }

  // Sort labels: highest priority first, then alphabetically within same priority
  const labels = Array.from(labelMaxPriority.keys()).sort((a, b) => {
    const pa = labelMaxPriority.get(a)!;
    const pb = labelMaxPriority.get(b)!;
    if (pb !== pa) return pb - pa;
    return a.localeCompare(b);
  });

  return { labels, fileMatches };
}

// ── CLI entry point ───────────────────────────────────────────────────────────

if (import.meta.main) {
  const changedFilesPath = process.env["CHANGED_FILES_PATH"] ?? "changed-files.txt";
  const configPath = process.env["LABEL_RULES_PATH"] ?? "label-rules.json";

  if (!fs.existsSync(changedFilesPath)) {
    console.error(`Error: changed files list not found at '${changedFilesPath}'`);
    console.error("Set CHANGED_FILES_PATH env var or create changed-files.txt");
    process.exit(1);
  }

  if (!fs.existsSync(configPath)) {
    console.error(`Error: label rules config not found at '${configPath}'`);
    console.error("Set LABEL_RULES_PATH env var or create label-rules.json");
    process.exit(1);
  }

  let config: LabelConfig;
  try {
    config = JSON.parse(fs.readFileSync(configPath, "utf-8")) as LabelConfig;
  } catch (err) {
    console.error(`Error: failed to parse label rules config: ${(err as Error).message}`);
    process.exit(1);
  }

  if (!Array.isArray(config.rules)) {
    console.error("Error: label-rules.json must have a 'rules' array");
    process.exit(1);
  }

  const changedFiles = fs.readFileSync(changedFilesPath, "utf-8")
    .split("\n")
    .map((f) => f.trim())
    .filter((f) => f.length > 0);

  const result = assignLabels(changedFiles, config);

  console.log("=== PR Label Assigner Results ===");
  console.log(`Labels: ${result.labels.join(", ") || "(none)"}`);
  console.log("\nFile matches:");
  for (const [file, labels] of Object.entries(result.fileMatches)) {
    const display = labels.length > 0 ? labels.join(", ") : "(no match)";
    console.log(`  ${file}: ${display}`);
  }
  console.log("=== End Results ===");
}
