/**
 * PR Label Assigner
 *
 * Given a list of changed file paths, applies labels based on configurable
 * path-to-label mapping rules using glob patterns. Supports multiple labels
 * per file and priority ordering when rules conflict.
 */

// --- Types ---

/** A single rule mapping a glob pattern to a label with a priority. */
export interface LabelRule {
  /** Glob pattern to match against file paths (e.g., "docs/**", "*.test.*") */
  pattern: string;
  /** Label to apply when the pattern matches */
  label: string;
  /** Priority: higher number = higher priority. Used to resolve conflicts. */
  priority: number;
}

/** Configuration for the label assigner. */
export interface LabelConfig {
  rules: LabelRule[];
  /**
   * When true, if multiple rules match a file and produce conflicting labels,
   * only the highest-priority label is kept per file. When false (default),
   * all matching labels are collected.
   */
  exclusiveMode?: boolean;
}

/** Result of running the label assigner. */
export interface LabelResult {
  /** The final set of labels to apply. */
  labels: string[];
  /** Map from each label to the files that triggered it. */
  labelToFiles: Record<string, string[]>;
}

// --- Glob matching ---

/**
 * Convert a simple glob pattern to a RegExp.
 * Supports: ** (any path), * (any segment chars), ? (single char).
 */
export function globToRegex(pattern: string): RegExp {
  let regexStr = "";
  let i = 0;

  while (i < pattern.length) {
    const ch = pattern[i];

    if (ch === "*" && pattern[i + 1] === "*") {
      // ** matches any number of path segments
      if (pattern[i + 2] === "/") {
        regexStr += "(?:.+/)?";
        i += 3;
      } else {
        regexStr += ".*";
        i += 2;
      }
    } else if (ch === "*") {
      // * matches anything except /
      regexStr += "[^/]*";
      i++;
    } else if (ch === "?") {
      regexStr += "[^/]";
      i++;
    } else if (ch === ".") {
      regexStr += "\\.";
      i++;
    } else if (ch === "/") {
      regexStr += "/";
      i++;
    } else {
      regexStr += ch;
      i++;
    }
  }

  return new RegExp(`^${regexStr}$`);
}

// --- Core logic ---

/**
 * Assign labels to a set of changed files based on the provided rules.
 *
 * @param changedFiles - List of file paths that changed in the PR
 * @param config - Label configuration with rules and options
 * @returns The computed label result
 */
export function assignLabels(
  changedFiles: string[],
  config: LabelConfig
): LabelResult {
  if (!config.rules || config.rules.length === 0) {
    return { labels: [], labelToFiles: {} };
  }

  if (!changedFiles || changedFiles.length === 0) {
    return { labels: [], labelToFiles: {} };
  }

  // Validate rules
  for (const rule of config.rules) {
    if (!rule.pattern) {
      throw new Error(`Rule with label "${rule.label}" has an empty pattern`);
    }
    if (!rule.label) {
      throw new Error(`Rule with pattern "${rule.pattern}" has an empty label`);
    }
  }

  // Sort rules by priority descending so higher-priority rules are checked first
  const sortedRules = [...config.rules].sort(
    (a, b) => b.priority - a.priority
  );

  // Compile all patterns once.
  // If a pattern has no path separator, auto-prefix with **/ so it matches
  // at any directory depth (standard label-tool behavior).
  const compiledRules = sortedRules.map((rule) => {
    const effectivePattern =
      rule.pattern.includes("/") ? rule.pattern : `**/${rule.pattern}`;
    return {
      ...rule,
      regex: globToRegex(effectivePattern),
    };
  });

  const labelToFiles: Record<string, string[]> = {};

  for (const file of changedFiles) {
    const matchedLabels: Array<{ label: string; priority: number }> = [];

    for (const rule of compiledRules) {
      if (rule.regex.test(file)) {
        matchedLabels.push({ label: rule.label, priority: rule.priority });
      }
    }

    if (config.exclusiveMode && matchedLabels.length > 0) {
      // In exclusive mode, only keep the highest-priority label per file
      const topPriority = matchedLabels[0].priority; // already sorted desc
      const topLabels = matchedLabels.filter(
        (m) => m.priority === topPriority
      );
      for (const m of topLabels) {
        if (!labelToFiles[m.label]) labelToFiles[m.label] = [];
        labelToFiles[m.label].push(file);
      }
    } else {
      // Collect all matching labels
      for (const m of matchedLabels) {
        if (!labelToFiles[m.label]) labelToFiles[m.label] = [];
        labelToFiles[m.label].push(file);
      }
    }
  }

  // Deduplicate file lists
  for (const label of Object.keys(labelToFiles)) {
    labelToFiles[label] = [...new Set(labelToFiles[label])];
  }

  // Sort labels by highest priority that produced them, then alphabetically
  const labelPriorityMap: Record<string, number> = {};
  for (const rule of sortedRules) {
    if (
      labelToFiles[rule.label] &&
      (labelPriorityMap[rule.label] === undefined ||
        rule.priority > labelPriorityMap[rule.label])
    ) {
      labelPriorityMap[rule.label] = rule.priority;
    }
  }

  const labels = Object.keys(labelToFiles).sort((a, b) => {
    const pDiff = (labelPriorityMap[b] ?? 0) - (labelPriorityMap[a] ?? 0);
    if (pDiff !== 0) return pDiff;
    return a.localeCompare(b);
  });

  return { labels, labelToFiles };
}

// --- CLI entry point ---

/**
 * Main function: reads config from env/stdin and outputs labels as JSON.
 * Used by the GitHub Actions workflow.
 */
async function main(): Promise<void> {
  // Read config from LABEL_CONFIG env var or default
  const configEnv = process.env.LABEL_CONFIG;
  if (!configEnv) {
    console.error("Error: LABEL_CONFIG environment variable is not set");
    process.exit(1);
  }

  // Read changed files from CHANGED_FILES env var (newline-separated)
  const filesEnv = process.env.CHANGED_FILES;
  if (!filesEnv) {
    console.error("Error: CHANGED_FILES environment variable is not set");
    process.exit(1);
  }

  let config: LabelConfig;
  try {
    config = JSON.parse(configEnv) as LabelConfig;
  } catch (e) {
    console.error(`Error: Failed to parse LABEL_CONFIG: ${(e as Error).message}`);
    process.exit(1);
  }

  const changedFiles = filesEnv
    .split("\n")
    .map((f) => f.trim())
    .filter((f) => f.length > 0);

  try {
    const result = assignLabels(changedFiles, config);
    // Output in a structured way for CI parsing
    console.log("=== LABEL RESULT START ===");
    console.log(JSON.stringify(result, null, 2));
    console.log("=== LABEL RESULT END ===");
  } catch (e) {
    console.error(`Error: ${(e as Error).message}`);
    process.exit(1);
  }
}

// Run main if executed directly
const isMainModule =
  typeof Bun !== "undefined" &&
  import.meta.path === Bun.main;

if (isMainModule) {
  main();
}
