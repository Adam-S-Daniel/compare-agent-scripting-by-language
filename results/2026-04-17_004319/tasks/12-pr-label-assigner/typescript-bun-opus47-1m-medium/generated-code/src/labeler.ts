// PR label assigner: maps changed file paths to labels using glob rules.
// Supports priority ordering; higher priority labels appear first in output.

export interface LabelRule {
  pattern: string;
  label: string;
  priority?: number; // default 0, higher wins
}

// Convert a glob pattern to a RegExp.
// Supports: ** (any path including separators), * (single segment, no /),
// and ? (single char). Other regex-special characters are escaped.
export function globToRegex(glob: string): RegExp {
  let re = "";
  let i = 0;
  while (i < glob.length) {
    const c = glob[i];
    if (c === "*") {
      if (glob[i + 1] === "*") {
        // ** matches anything including slashes; also allow matching empty
        re += ".*";
        i += 2;
        // swallow a trailing slash so "docs/**" also matches "docs"
        if (glob[i] === "/") i += 1;
      } else {
        re += "[^/]*";
        i += 1;
      }
    } else if (c === "?") {
      re += "[^/]";
      i += 1;
    } else if ("\\^$+.()|{}[]".includes(c!)) {
      re += "\\" + c;
      i += 1;
    } else {
      re += c;
      i += 1;
    }
  }
  return new RegExp("^" + re + "$");
}

export function matchGlob(pattern: string, path: string): boolean {
  return globToRegex(pattern).test(path);
}

function validateRule(r: LabelRule): void {
  if (!r || typeof r.pattern !== "string" || r.pattern.length === 0) {
    throw new Error(`Invalid rule: missing pattern for ${JSON.stringify(r)}`);
  }
  if (typeof r.label !== "string" || r.label.length === 0) {
    throw new Error(`Invalid rule: missing label for ${JSON.stringify(r)}`);
  }
}

export function assignLabels(files: string[], rules: LabelRule[]): string[] {
  for (const r of rules) validateRule(r);

  // label -> best priority seen
  const labelPriority = new Map<string, number>();
  // preserve first-seen insertion order for deterministic tie-break
  const insertionOrder: string[] = [];

  for (const file of files) {
    for (const rule of rules) {
      if (matchGlob(rule.pattern, file)) {
        const p = rule.priority ?? 0;
        if (!labelPriority.has(rule.label)) {
          labelPriority.set(rule.label, p);
          insertionOrder.push(rule.label);
        } else if (p > labelPriority.get(rule.label)!) {
          labelPriority.set(rule.label, p);
        }
      }
    }
  }

  // Sort: priority desc, then insertion order
  return insertionOrder.slice().sort((a, b) => {
    const pa = labelPriority.get(a)!;
    const pb = labelPriority.get(b)!;
    if (pa !== pb) return pb - pa;
    return insertionOrder.indexOf(a) - insertionOrder.indexOf(b);
  });
}
