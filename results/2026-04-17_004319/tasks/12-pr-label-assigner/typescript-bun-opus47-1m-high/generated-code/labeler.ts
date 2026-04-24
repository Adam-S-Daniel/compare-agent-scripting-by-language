// PR label assigner: maps changed file paths to a deduplicated, priority-ordered
// set of labels using configurable glob-based rules.
//
// The glob engine supports three wildcards:
//   *   — matches any characters within a single path segment (no '/')
//   **  — matches any number of characters including '/' (crosses segments)
//   ?   — matches exactly one character (no '/')
//
// We avoid a dependency so this runs in an isolated container without `bun install`.

export interface Rule {
  label: string;
  patterns: string[];
  // Higher priority labels appear first in the output. Defaults to 0.
  priority: number;
}

/**
 * Compile a glob to a RegExp anchored to the full path.
 * Handling ** specially is necessary: a naive char-by-char translation would
 * turn it into `.*.*` which is correct but `**\/` should also match zero
 * directories (e.g. "**\/*.test.*" matches "a.test.js" and "x/y/a.test.js").
 */
function globToRegex(glob: string): RegExp {
  let re = "^";
  let i = 0;
  while (i < glob.length) {
    const c = glob[i]!;
    if (c === "*") {
      if (glob[i + 1] === "*") {
        // Consume "**"
        i += 2;
        // "**/..." — allow zero or more leading segments (i.e. the whole prefix optional)
        if (glob[i] === "/") {
          re += "(?:.*/)?";
          i += 1;
        } else {
          re += ".*";
        }
      } else {
        // Single *: any chars except '/'
        re += "[^/]*";
        i += 1;
      }
    } else if (c === "?") {
      re += "[^/]";
      i += 1;
    } else if (".+^$(){}|[]\\".includes(c)) {
      // Escape regex metacharacters so they are matched literally
      re += "\\" + c;
      i += 1;
    } else {
      re += c;
      i += 1;
    }
  }
  re += "$";
  return new RegExp(re);
}

export function matchGlob(path: string, pattern: string): boolean {
  return globToRegex(pattern).test(path);
}

/**
 * Parse a JSON config of the form:
 *   { "rules": [ { "label": "...", "patterns": ["..."], "priority": N? } ] }
 * Produces friendly errors for each malformed case.
 */
export function parseRules(json: string): Rule[] {
  let data: unknown;
  try {
    data = JSON.parse(json);
  } catch (e) {
    throw new Error(`Invalid JSON: ${(e as Error).message}`);
  }
  if (typeof data !== "object" || data === null || !("rules" in data)) {
    throw new Error("Config is missing a top-level 'rules' array");
  }
  const rawRules = (data as { rules: unknown }).rules;
  if (!Array.isArray(rawRules)) {
    throw new Error("Config 'rules' must be an array");
  }
  return rawRules.map((r, idx) => {
    if (typeof r !== "object" || r === null) {
      throw new Error(`Rule at index ${idx} must be an object`);
    }
    const rr = r as Record<string, unknown>;
    if (typeof rr.label !== "string" || rr.label.length === 0) {
      throw new Error(`Rule at index ${idx} is missing a 'label' string`);
    }
    if (
      !Array.isArray(rr.patterns) ||
      rr.patterns.length === 0 ||
      !rr.patterns.every((p) => typeof p === "string")
    ) {
      throw new Error(
        `Rule '${rr.label}' is missing a non-empty 'patterns' string array`,
      );
    }
    const priority =
      typeof rr.priority === "number" && Number.isFinite(rr.priority)
        ? rr.priority
        : 0;
    return {
      label: rr.label,
      patterns: rr.patterns as string[],
      priority,
    };
  });
}

/**
 * Given changed file paths and rules, return the final label set.
 * Order: higher priority first, ties broken by label name for stable output.
 */
export function assignLabels(files: string[], rules: Rule[]): string[] {
  // Collect labels whose rule matches at least one file.
  const matched = new Map<string, number>(); // label -> priority
  for (const rule of rules) {
    const hit = files.some((f) =>
      rule.patterns.some((p) => matchGlob(f, p)),
    );
    if (hit) {
      // If the same label appears twice in the rules list, keep the highest priority.
      const prior = matched.get(rule.label);
      if (prior === undefined || rule.priority > prior) {
        matched.set(rule.label, rule.priority);
      }
    }
  }
  return [...matched.entries()]
    .sort((a, b) => {
      if (b[1] !== a[1]) return b[1] - a[1];
      return a[0].localeCompare(b[0]);
    })
    .map(([label]) => label);
}
