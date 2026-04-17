// PR label assigner.
//
// Given a list of changed file paths and a set of rules mapping glob patterns
// to labels, compute the final set of labels for a PR.
//
// Features:
//   - Glob patterns (via Bun.Glob — supports **, *, ?, [abc], {a,b}).
//   - A single file can collect labels from multiple rules.
//   - Rules can have a numeric priority; higher priorities sort first in output.
//   - Rules can belong to an exclusive `group` (e.g., "size"). Within a group,
//     only the highest-priority matching rule wins — useful for mutually
//     exclusive label families like size/S, size/M, size/L.

export interface LabelRule {
  /** Glob pattern matched against each file path. Required, non-empty. */
  pattern: string;
  /** Label applied when the pattern matches. Required, non-empty. */
  label: string;
  /** Higher = sorts first in output, and wins within an exclusive group. Defaults to 0. */
  priority?: number;
  /** Exclusive group name. Only the highest-priority matching rule per group is kept. */
  group?: string;
}

interface RulesFile {
  rules: LabelRule[];
}

/**
 * Assign labels to a changed-file list by applying `rules`.
 *
 * Algorithm:
 *   1. For each rule, check whether any of the changed files matches its glob.
 *   2. Collect all matching rules.
 *   3. For exclusive groups, drop all but the highest-priority rule per group.
 *   4. Dedupe by label, then sort by priority DESC, then label ASC.
 */
export function assignLabels(files: string[], rules: LabelRule[]): string[] {
  if (!Array.isArray(rules)) {
    throw new Error("rules must be an array");
  }
  for (const rule of rules) {
    validateRule(rule);
  }

  // Step 1–2: collect rules that match at least one file.
  const matched: LabelRule[] = [];
  for (const rule of rules) {
    const glob = new Bun.Glob(rule.pattern);
    const hit = files.some((f) => glob.match(f));
    if (hit) matched.push(rule);
  }

  // Step 3: exclusive-group filtering. Keep only the top-priority rule per group.
  const bestByGroup = new Map<string, LabelRule>();
  const ungrouped: LabelRule[] = [];
  for (const rule of matched) {
    if (!rule.group) {
      ungrouped.push(rule);
      continue;
    }
    const current = bestByGroup.get(rule.group);
    if (!current || priorityOf(rule) > priorityOf(current)) {
      bestByGroup.set(rule.group, rule);
    }
  }
  const kept = [...ungrouped, ...bestByGroup.values()];

  // Step 4: dedupe by label. If the same label appears twice, keep the one with
  // the higher priority so sort order reflects the strongest ranking.
  const byLabel = new Map<string, LabelRule>();
  for (const rule of kept) {
    const existing = byLabel.get(rule.label);
    if (!existing || priorityOf(rule) > priorityOf(existing)) {
      byLabel.set(rule.label, rule);
    }
  }

  // Sort: priority DESC, then label ASC (stable, deterministic output).
  return [...byLabel.values()]
    .sort((a, b) => {
      const pDiff = priorityOf(b) - priorityOf(a);
      if (pDiff !== 0) return pDiff;
      return a.label.localeCompare(b.label);
    })
    .map((r) => r.label);
}

function priorityOf(rule: LabelRule): number {
  return typeof rule.priority === "number" ? rule.priority : 0;
}

function validateRule(rule: LabelRule): void {
  if (typeof rule !== "object" || rule === null) {
    throw new Error("invalid rule: expected an object");
  }
  if (typeof rule.pattern !== "string" || rule.pattern.length === 0) {
    throw new Error("invalid rule: pattern must be a non-empty string");
  }
  if (typeof rule.label !== "string" || rule.label.length === 0) {
    throw new Error("invalid rule: label must be a non-empty string");
  }
}

/**
 * Load rules from a JSON file of the form `{ "rules": [...] }`.
 * Throws with a helpful message on I/O or parse errors.
 */
export async function loadRules(path: string): Promise<LabelRule[]> {
  const file = Bun.file(path);
  if (!(await file.exists())) {
    throw new Error(`config file not found: ${path}`);
  }
  let text: string;
  try {
    text = await file.text();
  } catch (err) {
    throw new Error(`failed to read config file ${path}: ${(err as Error).message}`);
  }
  let parsed: RulesFile;
  try {
    parsed = JSON.parse(text) as RulesFile;
  } catch (err) {
    throw new Error(`failed to parse config ${path}: ${(err as Error).message}`);
  }
  if (!parsed || !Array.isArray(parsed.rules)) {
    throw new Error(`invalid config: missing "rules" array in ${path}`);
  }
  for (const rule of parsed.rules) {
    validateRule(rule);
  }
  return parsed.rules;
}
