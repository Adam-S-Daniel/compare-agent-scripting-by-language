/**
 * PR Label Assigner
 *
 * Given a list of changed file paths (simulating a PR's changed files),
 * applies labels based on configurable path-to-label mapping rules.
 *
 * Supports:
 * - Glob pattern matching (e.g., docs/** -> documentation)
 * - Multiple labels per file
 * - Priority ordering when rules conflict
 */

// --- Types ---

/** A single rule mapping a glob pattern to a label with a priority. */
export interface LabelRule {
  /** Glob pattern to match file paths against */
  pattern: string;
  /** Label to apply when the pattern matches */
  label: string;
  /** Priority (lower number = higher priority). Used for conflict resolution. */
  priority: number;
}

/** Configuration for the label assigner */
export interface LabelConfig {
  /** List of rules, evaluated in order */
  rules: LabelRule[];
  /** Maximum number of labels to apply (optional, defaults to unlimited) */
  maxLabels?: number;
}

/** Result of label assignment for a single file */
export interface FileLabels {
  file: string;
  matchedLabels: string[];
}

/** Overall result of the label assignment process */
export interface AssignmentResult {
  /** Per-file label matches */
  fileResults: FileLabels[];
  /** Final deduplicated set of labels to apply */
  finalLabels: string[];
}

// --- Glob matching ---

/**
 * Converts a glob pattern to a RegExp.
 * Supports: **, *, ?, and character classes [...].
 */
export function globToRegex(pattern: string): RegExp {
  let regex = "";
  let i = 0;

  while (i < pattern.length) {
    const ch = pattern[i];

    if (ch === "*") {
      if (pattern[i + 1] === "*") {
        // ** matches any path segment(s)
        if (pattern[i + 2] === "/") {
          regex += "(?:.+/)?";
          i += 3;
        } else {
          regex += ".*";
          i += 2;
        }
      } else {
        // * matches anything except /
        regex += "[^/]*";
        i += 1;
      }
    } else if (ch === "?") {
      regex += "[^/]";
      i += 1;
    } else if (ch === "[") {
      // Pass through character class
      const close = pattern.indexOf("]", i);
      if (close === -1) {
        throw new Error(`Unclosed character class in pattern: ${pattern}`);
      }
      regex += pattern.slice(i, close + 1);
      i = close + 1;
    } else if (ch === ".") {
      regex += "\\.";
      i += 1;
    } else if (ch === "/") {
      regex += "/";
      i += 1;
    } else {
      regex += ch;
      i += 1;
    }
  }

  return new RegExp(`^${regex}$`);
}

/**
 * Check if a file path matches a glob pattern.
 */
export function matchesGlob(filePath: string, pattern: string): boolean {
  const re = globToRegex(pattern);
  return re.test(filePath);
}

// --- Core logic ---

/**
 * Assign labels to a set of changed files based on the provided config.
 *
 * Algorithm:
 * 1. For each file, find all matching rules.
 * 2. Collect all matched labels across all files.
 * 3. If maxLabels is set, keep only the highest-priority labels (lowest priority number).
 * 4. Return per-file results and the final deduplicated label set.
 */
export function assignLabels(
  changedFiles: string[],
  config: LabelConfig
): AssignmentResult {
  if (!changedFiles || changedFiles.length === 0) {
    return { fileResults: [], finalLabels: [] };
  }

  if (!config || !config.rules || config.rules.length === 0) {
    throw new Error("Label config must contain at least one rule");
  }

  // Validate rules
  for (const rule of config.rules) {
    if (!rule.pattern || rule.pattern.trim() === "") {
      throw new Error("Rule pattern must not be empty");
    }
    if (!rule.label || rule.label.trim() === "") {
      throw new Error("Rule label must not be empty");
    }
    if (typeof rule.priority !== "number" || rule.priority < 0) {
      throw new Error(
        `Rule priority must be a non-negative number, got: ${rule.priority}`
      );
    }
  }

  // Track label -> best (lowest) priority across all files
  const labelPriority = new Map<string, number>();
  const fileResults: FileLabels[] = [];

  for (const file of changedFiles) {
    const matchedLabels: string[] = [];

    for (const rule of config.rules) {
      if (matchesGlob(file, rule.pattern)) {
        matchedLabels.push(rule.label);

        const existing = labelPriority.get(rule.label);
        if (existing === undefined || rule.priority < existing) {
          labelPriority.set(rule.label, rule.priority);
        }
      }
    }

    fileResults.push({ file, matchedLabels });
  }

  // Sort labels by priority (ascending = highest priority first)
  let sortedLabels = Array.from(labelPriority.entries())
    .sort((a, b) => a[1] - b[1])
    .map(([label]) => label);

  // Apply maxLabels cap if configured
  if (config.maxLabels !== undefined && config.maxLabels > 0) {
    sortedLabels = sortedLabels.slice(0, config.maxLabels);
  }

  return { fileResults, finalLabels: sortedLabels };
}

// --- CLI entry point ---

if (import.meta.main) {
  // Read config and file list from environment or stdin
  const configPath = process.env.LABEL_CONFIG_PATH || "label-config.json";
  const filesEnv = process.env.CHANGED_FILES || "";

  if (!filesEnv) {
    console.error("Error: CHANGED_FILES environment variable is required");
    console.error('Set it to a comma-separated list of file paths, e.g.:');
    console.error('  CHANGED_FILES="src/index.ts,docs/README.md" bun run label-assigner.ts');
    process.exit(1);
  }

  const changedFiles = filesEnv.split(",").map((f) => f.trim()).filter(Boolean);

  let config: LabelConfig;
  try {
    const raw = await Bun.file(configPath).text();
    config = JSON.parse(raw) as LabelConfig;
  } catch (err) {
    console.error(`Error reading config from ${configPath}: ${(err as Error).message}`);
    process.exit(1);
  }

  try {
    const result = assignLabels(changedFiles, config);

    console.log("=== PR Label Assignment Results ===");
    console.log("");

    for (const fr of result.fileResults) {
      const labels = fr.matchedLabels.length > 0
        ? fr.matchedLabels.join(", ")
        : "(no match)";
      console.log(`  ${fr.file} -> [${labels}]`);
    }

    console.log("");
    console.log(`FINAL_LABELS: ${result.finalLabels.join(",")}`);
  } catch (err) {
    console.error(`Error: ${(err as Error).message}`);
    process.exit(1);
  }
}
