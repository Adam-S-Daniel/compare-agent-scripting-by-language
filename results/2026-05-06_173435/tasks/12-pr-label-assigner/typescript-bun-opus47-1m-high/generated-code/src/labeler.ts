/**
 * PR label assigner — pure functions, no I/O.
 *
 * Given a list of changed file paths and a set of label rules (each rule
 * declares one label and one or more glob patterns), produce the deduplicated
 * set of labels that apply to the PR.
 *
 * Glob support: `*` (single segment, no `/`), `**` (any number of segments
 * including zero), `?` (single non-`/` char), and `[...]` character classes.
 * This is enough for the path-matching the task asks for; we deliberately
 * avoid pulling in a dependency since the rules are simple and testable.
 */

export interface LabelRule {
  /** Label to assign when a file matches. Must be non-empty. */
  label: string;
  /** Glob patterns; a file matches the rule if it matches ANY pattern. */
  patterns: string[];
  /** Optional negative patterns; if any matches, the file is excluded. */
  exclude?: string[];
  /**
   * Lower number = higher priority in the output ordering. Rules without
   * a priority sort after rules with one, in declaration order.
   */
  priority?: number;
}

/**
 * Convert a glob pattern into an anchored RegExp.
 *
 * Order of operations matters: `**` must be replaced before `*` so that we
 * don't double-replace. We use a placeholder during translation to keep the
 * logic readable.
 */
function globToRegex(glob: string): RegExp {
  let out = "";
  for (let i = 0; i < glob.length; i++) {
    const c = glob[i];
    if (c === "*") {
      if (glob[i + 1] === "*") {
        // `**` — match across any number of segments (including zero).
        // We also consume an immediately-following `/` so that `docs/**`
        // matches `docs` itself as well as `docs/x` and `docs/x/y`.
        if (glob[i + 2] === "/") {
          out += "(?:.*/)?";
          i += 2;
        } else {
          out += ".*";
          i += 1;
        }
      } else {
        // `*` matches anything except a path separator.
        out += "[^/]*";
      }
    } else if (c === "?") {
      out += "[^/]";
    } else if (c === "[") {
      // Character class — pass through until the matching `]`.
      const end = glob.indexOf("]", i);
      if (end === -1) {
        // Unterminated class — treat as literal.
        out += "\\[";
      } else {
        out += glob.slice(i, end + 1);
        i = end;
      }
    } else if (/[.+^$()|{}\\]/.test(c)) {
      out += "\\" + c;
    } else {
      out += c;
    }
  }
  return new RegExp("^" + out + "$");
}

/** Test whether a file path matches a single glob pattern. */
export function matchGlob(path: string, glob: string): boolean {
  return globToRegex(glob).test(path);
}

function ruleMatchesFile(rule: LabelRule, file: string): boolean {
  if (rule.exclude?.some((p) => matchGlob(file, p))) return false;
  return rule.patterns.some((p) => matchGlob(file, p));
}

function validateRules(rules: LabelRule[]): void {
  for (const rule of rules) {
    if (typeof rule.label !== "string" || rule.label.length === 0) {
      throw new Error(
        `Invalid rule: label must be a non-empty string (got ${JSON.stringify(rule.label)})`,
      );
    }
    if (!Array.isArray(rule.patterns) || rule.patterns.length === 0) {
      throw new Error(
        `Invalid rule "${rule.label}": must have at least one pattern`,
      );
    }
  }
}

/**
 * Compute the deduplicated, ordered list of labels that apply.
 *
 * Ordering: priority asc (lower number first), then rules-with-no-priority in
 * declaration order. We keep the original rule index to break ties and so
 * that callers get stable, predictable output.
 */
export function assignLabels(
  changedFiles: string[],
  rules: LabelRule[],
): string[] {
  if (!Array.isArray(changedFiles)) {
    throw new Error("changedFiles must be an array of strings");
  }
  validateRules(rules);

  const matched = new Set<number>();
  rules.forEach((rule, idx) => {
    if (changedFiles.some((f) => ruleMatchesFile(rule, f))) {
      matched.add(idx);
    }
  });

  const ordered = [...matched]
    .map((idx) => ({ idx, rule: rules[idx]! }))
    .sort((a, b) => {
      const ap = a.rule.priority;
      const bp = b.rule.priority;
      // Both have priority → numeric.
      if (ap !== undefined && bp !== undefined) return ap - bp;
      // Only A has priority → A first.
      if (ap !== undefined) return -1;
      if (bp !== undefined) return 1;
      // Neither has priority → declaration order.
      return a.idx - b.idx;
    });

  // Dedupe by label name while preserving order.
  const seen = new Set<string>();
  const result: string[] = [];
  for (const { rule } of ordered) {
    if (!seen.has(rule.label)) {
      seen.add(rule.label);
      result.push(rule.label);
    }
  }
  return result;
}
