// PR Label Assigner
// Assigns labels to PRs based on changed file paths using configurable glob rules.
// Supports multiple labels per file, priority ordering, and deduplication.

export interface LabelRule {
  pattern: string; // glob pattern (e.g. "docs/**", "**/*.test.*")
  label: string;   // label to apply when pattern matches
  priority: number; // higher number = higher priority (affects sort order)
}

export interface LabelConfig {
  rules: LabelRule[];
}

/**
 * Match a single file path against a glob pattern.
 * Supports **, *, and ? wildcards.
 *
 * **  — matches any sequence of characters including path separators (/)
 * *   — matches any sequence of non-separator characters
 * ?   — matches exactly one non-separator character
 */
function matchGlob(pattern: string, filepath: string): boolean {
  let regexStr = "";
  let i = 0;
  while (i < pattern.length) {
    if (pattern[i] === "*" && pattern[i + 1] === "*") {
      if (pattern[i + 2] === "/") {
        // **/ at a non-terminal position: match zero or more directory prefixes
        regexStr += "(?:.+/)?";
        i += 3;
      } else {
        // ** at end of pattern: match anything including slashes
        regexStr += ".*";
        i += 2;
      }
      continue;
    } else if (pattern[i] === "*") {
      regexStr += "[^/]*";
    } else if (pattern[i] === "?") {
      regexStr += "[^/]";
    } else if (".+^${}()|[]\\".includes(pattern[i]!)) {
      // Escape regex special characters (except glob metacharacters handled above)
      regexStr += "\\" + pattern[i];
    } else {
      regexStr += pattern[i];
    }
    i++;
  }
  const regex = new RegExp("^" + regexStr + "$");
  return regex.test(filepath);
}

/**
 * Assign labels to a PR given a list of changed file paths and a label config.
 * Returns a deduplicated array of labels sorted by descending priority.
 * If a pattern is invalid (e.g. unbalanced brackets), it is silently skipped.
 */
export function assignLabels(files: string[], config: LabelConfig): string[] {
  // Map from label -> highest priority that triggered it
  const matched = new Map<string, number>();

  for (const rule of config.rules) {
    let anyMatch = false;
    try {
      for (const file of files) {
        if (matchGlob(rule.pattern, file)) {
          anyMatch = true;
          break;
        }
      }
    } catch {
      // Invalid pattern — skip gracefully
      continue;
    }

    if (anyMatch) {
      const existing = matched.get(rule.label);
      if (existing === undefined || rule.priority > existing) {
        matched.set(rule.label, rule.priority);
      }
    }
  }

  // Sort labels by descending priority, then alphabetically for stability
  const entries = Array.from(matched.entries());
  entries.sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]));
  return entries.map(([label]) => label);
}

// CLI entrypoint: bun run label-assigner.ts [config.json] [files...]
// Or pipe file list via stdin when no args given
if (import.meta.main) {
  const args = Bun.argv.slice(2);

  // Default demo config and file list if no args provided
  const defaultConfig: LabelConfig = {
    rules: [
      { pattern: "docs/**", label: "documentation", priority: 1 },
      { pattern: "src/api/**", label: "api", priority: 3 },
      { pattern: "**/*.test.*", label: "tests", priority: 2 },
      { pattern: "src/**", label: "source", priority: 1 },
      { pattern: ".github/**", label: "ci", priority: 4 },
    ],
  };

  const defaultFiles = [
    "docs/api-guide.md",
    "src/api/users.ts",
    "src/api/users.test.ts",
    "src/utils.ts",
  ];

  let config = defaultConfig;
  let files = defaultFiles;

  if (args.length >= 1) {
    // First arg: path to JSON config file, or inline JSON
    try {
      const raw = args[0]!.startsWith("{")
        ? args[0]!
        : await Bun.file(args[0]!).text();
      config = JSON.parse(raw) as LabelConfig;
    } catch (e) {
      console.error(`Error reading config: ${e}`);
      process.exit(1);
    }
  }

  if (args.length >= 2) {
    files = args.slice(1);
  }

  const labels = assignLabels(files, config);
  console.log("Changed files:");
  files.forEach((f) => console.log(`  ${f}`));
  console.log("\nAssigned labels:");
  if (labels.length === 0) {
    console.log("  (none)");
  } else {
    labels.forEach((l) => console.log(`  ${l}`));
  }
  console.log("\nLabel set: " + JSON.stringify(labels));
}
