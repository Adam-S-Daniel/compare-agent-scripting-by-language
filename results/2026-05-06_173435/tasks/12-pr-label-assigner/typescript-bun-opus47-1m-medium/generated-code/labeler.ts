// PR Label Assigner — assigns labels to a PR based on which changed files match
// configured glob patterns. Supports multiple labels per file, dedup, and a
// priority/group conflict-resolution mechanism.
//
// Approach:
//   1. Each rule has a glob pattern + label. Optional `group` + `priority` mark
//      the rule as part of a mutually-exclusive set; only the highest-priority
//      label within a group survives.
//   2. Globs are compiled to RegExps via a small minimatch-style translator
//      that supports `**`, `*`, `?`, and bracket classes.

export interface LabelRule {
  pattern: string;
  label: string;
  /** Higher priority wins within the same group. Default 0. */
  priority?: number;
  /** Rules sharing a non-empty group are mutually exclusive. */
  group?: string;
}

// Translate a glob into a regex source string. Anchored with ^...$ by caller.
function globToRegex(glob: string): RegExp {
  let re = "";
  for (let i = 0; i < glob.length; i++) {
    const c = glob[i];
    if (c === "*") {
      // '**' (optionally followed by '/') matches any sequence including '/'
      if (glob[i + 1] === "*") {
        // consume **
        i++;
        if (glob[i + 1] === "/") {
          // '**/' matches zero or more path segments
          re += "(?:.*/)?";
          i++;
        } else {
          re += ".*";
        }
      } else {
        // single * matches anything except '/'
        re += "[^/]*";
      }
    } else if (c === "?") {
      re += "[^/]";
    } else if (c === "[") {
      // Pass bracket class through, finding closing ]
      const end = glob.indexOf("]", i + 1);
      if (end === -1) {
        re += "\\[";
      } else {
        re += glob.slice(i, end + 1);
        i = end;
      }
    } else if (".+^$(){}|\\/".includes(c)) {
      re += "\\" + c;
    } else {
      re += c;
    }
  }
  return new RegExp("^" + re + "$");
}

function validateRule(rule: LabelRule): void {
  if (!rule.pattern || rule.pattern.length === 0) {
    throw new Error(`Invalid rule: empty pattern (label='${rule.label}')`);
  }
  if (!rule.label || rule.label.length === 0) {
    throw new Error(`Invalid rule: empty label (pattern='${rule.pattern}')`);
  }
}

/**
 * Compute the set of labels to apply given a list of changed file paths and a
 * list of rules. Returns a sorted, de-duplicated array of label strings.
 */
export function assignLabels(files: string[], rules: LabelRule[]): string[] {
  for (const r of rules) validateRule(r);

  // Track candidate labels with their best priority within each group.
  // Key: group name (or unique-per-rule marker for ungrouped). Value: best priority + label.
  const ungrouped = new Set<string>();
  const grouped = new Map<string, { label: string; priority: number }>();

  for (const file of files) {
    for (const rule of rules) {
      const re = globToRegex(rule.pattern);
      if (!re.test(file)) continue;

      if (rule.group) {
        const cur = grouped.get(rule.group);
        const pri = rule.priority ?? 0;
        if (!cur || pri > cur.priority) {
          grouped.set(rule.group, { label: rule.label, priority: pri });
        }
      } else {
        ungrouped.add(rule.label);
      }
    }
  }

  const out = new Set<string>(ungrouped);
  for (const v of grouped.values()) out.add(v.label);
  return Array.from(out).sort();
}

// CLI entrypoint: read a JSON config { files: [...], rules: [...] } from a path
// passed as argv[2], or from stdin if argv[2] === "-".
if (import.meta.main) {
  const arg = process.argv[2];
  if (!arg) {
    console.error("Usage: bun run labeler.ts <config.json|->");
    process.exit(2);
  }
  const text =
    arg === "-"
      ? await Bun.stdin.text()
      : await Bun.file(arg).text();
  let config: { files: string[]; rules: LabelRule[] };
  try {
    config = JSON.parse(text);
  } catch (e) {
    console.error(`Failed to parse JSON config: ${(e as Error).message}`);
    process.exit(2);
  }
  if (!Array.isArray(config.files) || !Array.isArray(config.rules)) {
    console.error("Config must have { files: string[], rules: LabelRule[] }");
    process.exit(2);
  }
  try {
    const labels = assignLabels(config.files, config.rules);
    console.log(JSON.stringify({ labels }));
  } catch (e) {
    console.error((e as Error).message);
    process.exit(1);
  }
}
