/**
 * PR Label Assigner
 *
 * Assigns labels to PRs based on changed file paths using configurable glob patterns.
 * Supports:
 *   - Glob patterns (docs/**, *.test.*, etc.)
 *   - Multiple labels per file (a file can match many rules)
 *   - Priority ordering (higher number = higher priority)
 *   - Exclusive rules (a higher-priority exclusive rule suppresses lower-priority matches)
 *   - Deduplication of labels across files
 */

// --- Types ---

/** A single mapping rule: glob pattern → label with priority */
export interface LabelRule {
  /** Glob pattern to match against file paths (e.g. "docs/**", "*.test.*") */
  pattern: string;
  /** Label to apply when the pattern matches */
  label: string;
  /**
   * Priority for conflict resolution. Higher number wins.
   * When two rules match, the one with higher priority is listed first.
   */
  priority: number;
  /**
   * If true, this rule is exclusive: when it matches a file, all lower-priority
   * rules for that same file are suppressed. Useful to prevent broad catch-all
   * labels when a more specific label applies.
   */
  exclusive?: boolean;
}

/** Per-file breakdown: which labels matched a specific file */
export interface FileMatch {
  file: string;
  labels: string[];
  matchedRules: LabelRule[];
}

/** Result returned by assignLabels */
export interface LabelResult {
  /** Deduplicated, unique set of all labels across all files */
  labels: string[];
  /** All rules that fired (deduplicated by label, sorted by priority desc) */
  matchedRules: LabelRule[];
  /** Per-file breakdown */
  matchedFiles: FileMatch[];
}

// --- Glob matching ---

/**
 * Convert a glob pattern to a RegExp.
 * Supports: ** (any depth), * (within segment), ? (single char), literal .
 * docs/** matches docs/anything, **\/*.test.* matches test files at any depth.
 */
function globToRegex(pattern: string): RegExp {
  const STAR2 = "\x01"; // placeholder for **

  // Step 1: protect ** from later * replacement
  let p = pattern.split("**").join(STAR2);

  // Step 2: escape regex special chars (not *, ?, placeholder)
  p = p.replace(/[.+^${}()|[\]\\]/g, "\\$&");

  // Step 3: * → match any chars within one path segment
  p = p.replace(/\*/g, "[^/]*");

  // Step 4: ? → any single char within one segment
  p = p.replace(/\?/g, "[^/]");

  // Step 5: ** placeholder → .*  (any chars including /)
  p = p.replace(/\x01/g, ".*");

  // Step 6a: leading ".*/" → optional directory prefix
  //   **/*.ext becomes .*/[^/]*\.ext → (?:.*/)?[^/]*\.ext
  p = p.replace(/^\.\*\//, "(?:.*/)?");

  // Step 6b: "/.*//" in the middle → (?:/.*/|/)
  //   e.g. src/**/test.ts → src/.*/test.ts → src(?:/.*/|/)test.ts
  p = p.replace(/\/\.\*\//g, "(?:/.*/|/)");

  return new RegExp(`^${p}$`);
}

/** Returns true if the file path matches the given glob pattern */
function matchesGlob(filePath: string, pattern: string): boolean {
  const regex = globToRegex(pattern);
  return regex.test(filePath);
}

// --- Core logic ---

/**
 * Given a list of changed file paths and label rules, compute which labels
 * should be applied to the PR.
 *
 * @param files     List of changed file paths (relative to repo root)
 * @param rules     Label mapping rules (glob pattern → label + priority)
 * @returns         LabelResult with deduplicated labels and per-file breakdown
 */
export function assignLabels(
  files: string[],
  rules: LabelRule[]
): LabelResult {
  // Sort rules by priority descending so higher-priority rules are evaluated first
  const sortedRules = [...rules].sort((a, b) => b.priority - a.priority);

  const matchedFiles: FileMatch[] = [];
  // Track all labels seen across all files (for deduplication)
  const globalLabels = new Set<string>();
  // Track all matched rules (by label, for deduplication in matchedRules output)
  const matchedRulesByLabel = new Map<string, LabelRule>();

  for (const file of files) {
    // Find all rules that match this file
    const fileMatchedRules: LabelRule[] = [];

    for (const rule of sortedRules) {
      if (matchesGlob(file, rule.pattern)) {
        // If a higher-priority exclusive rule already matched this file,
        // skip lower-priority rules
        const hasExclusiveMatch = fileMatchedRules.some((r) => r.exclusive);
        if (hasExclusiveMatch) break;

        fileMatchedRules.push(rule);
      }
    }

    // Collect labels for this file
    const fileLabels = fileMatchedRules.map((r) => r.label);

    if (fileMatchedRules.length > 0) {
      matchedFiles.push({
        file,
        labels: fileLabels,
        matchedRules: fileMatchedRules,
      });

      for (const rule of fileMatchedRules) {
        globalLabels.add(rule.label);
        // Keep track of the rule with this label (store once per label)
        if (!matchedRulesByLabel.has(rule.label)) {
          matchedRulesByLabel.set(rule.label, rule);
        }
      }
    }
  }

  // Build the matchedRules array: one entry per unique label, sorted by priority desc
  const matchedRules = Array.from(matchedRulesByLabel.values()).sort(
    (a, b) => b.priority - a.priority
  );

  // Build final labels list preserving priority order (highest first)
  const labels = matchedRules.map((r) => r.label);

  return { labels, matchedRules, matchedFiles };
}
