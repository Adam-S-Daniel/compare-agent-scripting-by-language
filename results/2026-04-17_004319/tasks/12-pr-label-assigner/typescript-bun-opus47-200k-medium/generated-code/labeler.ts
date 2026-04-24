// PR Label Assigner
//
// Given a list of changed file paths and a set of glob-based path->label rules,
// compute the set of labels to apply.
//
// Semantics:
//   - A file matches a rule when its path matches the rule's glob `pattern`.
//   - A file can match multiple rules and contribute multiple labels.
//   - Rules may share a `group` tag. Within a group, at most ONE label is
//     produced per file: the label attached to the highest-priority rule wins
//     (ties broken by first declaration). This is the "priority ordering when
//     rules conflict" requirement. Rules with no group never conflict.
//   - The final label set is the union across all files, deduplicated and
//     returned sorted for deterministic output.

export interface LabelRule {
  /** Glob pattern matched against a file path (e.g. "docs/**", "**\/*.test.*"). */
  pattern: string;
  /** Label to attach when the pattern matches. */
  label: string;
  /** Optional conflict-resolution group; only one label per group is emitted per file. */
  group?: string;
  /** Higher wins within a group. Defaults to 0. */
  priority?: number;
}

/**
 * Compile a glob into a RegExp.
 *
 * Supported syntax:
 *   - `**`   — zero or more path segments (including slashes)
 *   - `*`    — zero or more non-slash chars
 *   - `?`    — single non-slash char
 *   - literal characters (dots, slashes, extensions) are escaped
 */
export function globToRegExp(glob: string): RegExp {
  let re = "";
  for (let i = 0; i < glob.length; i++) {
    const c = glob[i];
    if (c === "*") {
      if (glob[i + 1] === "*") {
        // `**` — match across path segments. Consume a trailing slash if present
        // so that "docs/**" matches "docs/a.md" (not just "docs//a.md").
        re += ".*";
        i++;
        if (glob[i + 1] === "/") i++;
      } else {
        re += "[^/]*";
      }
    } else if (c === "?") {
      re += "[^/]";
    } else if (/[.+^${}()|[\]\\]/.test(c)) {
      re += "\\" + c;
    } else {
      re += c;
    }
  }
  return new RegExp("^" + re + "$");
}

function validateRule(rule: LabelRule): void {
  if (!rule.pattern || rule.pattern.trim() === "") {
    throw new Error(`Invalid rule: pattern must be non-empty (label=${rule.label})`);
  }
  if (!rule.label || rule.label.trim() === "") {
    throw new Error(`Invalid rule: label must be non-empty (pattern=${rule.pattern})`);
  }
}

/**
 * Compute the set of labels for a list of changed files given labeling rules.
 */
export function assignLabels(files: string[], rules: LabelRule[]): string[] {
  for (const r of rules) validateRule(r);

  const compiled = rules.map((r, idx) => ({
    rule: r,
    re: globToRegExp(r.pattern),
    idx,
  }));

  const labels = new Set<string>();

  for (const file of files) {
    // Track best (highest-priority) rule per group for this file.
    const bestByGroup = new Map<string, { priority: number; idx: number; label: string }>();

    for (const c of compiled) {
      if (!c.re.test(file)) continue;
      const { rule } = c;
      if (rule.group) {
        const prev = bestByGroup.get(rule.group);
        const pri = rule.priority ?? 0;
        if (!prev || pri > prev.priority || (pri === prev.priority && c.idx < prev.idx)) {
          bestByGroup.set(rule.group, { priority: pri, idx: c.idx, label: rule.label });
        }
      } else {
        labels.add(rule.label);
      }
    }

    for (const v of bestByGroup.values()) labels.add(v.label);
  }

  return [...labels].sort();
}
