// Core PR label assignment logic.
// Given a set of changed file paths and a list of glob-based rules,
// produces the unique set of labels to apply, ordered by rule priority.

export interface LabelRule {
  label: string;
  patterns: string[];
  // Lower priority numbers come first in the output. Undefined sorts last,
  // preserving the declaration order among non-prioritized rules.
  priority?: number;
}

function normalize(p: string): string {
  return p.startsWith("./") ? p.slice(2) : p;
}

function matchesAny(file: string, patterns: string[]): boolean {
  for (const pattern of patterns) {
    const glob = new Bun.Glob(pattern);
    if (glob.match(file)) return true;
  }
  return false;
}

export function assignLabels(files: string[], rules: LabelRule[]): string[] {
  if (files.length === 0) {
    throw new Error("Expected at least one file path; received empty list.");
  }
  for (const rule of rules) {
    if (!rule.patterns || rule.patterns.length === 0) {
      throw new Error(
        `Rule for label "${rule.label}" must have at least one pattern.`,
      );
    }
  }

  const normalized = files.map(normalize);

  // Sort rules by priority (ascending), preserving declaration order for ties
  // and for rules lacking an explicit priority (those go to the end).
  const indexed = rules.map((rule, index) => ({ rule, index }));
  indexed.sort((a, b) => {
    const ap = a.rule.priority;
    const bp = b.rule.priority;
    if (ap === undefined && bp === undefined) return a.index - b.index;
    if (ap === undefined) return 1;
    if (bp === undefined) return -1;
    if (ap !== bp) return ap - bp;
    return a.index - b.index;
  });

  const result: string[] = [];
  const seen = new Set<string>();
  for (const { rule } of indexed) {
    const hit = normalized.some((f) => matchesAny(f, rule.patterns));
    if (hit && !seen.has(rule.label)) {
      seen.add(rule.label);
      result.push(rule.label);
    }
  }
  return result;
}
