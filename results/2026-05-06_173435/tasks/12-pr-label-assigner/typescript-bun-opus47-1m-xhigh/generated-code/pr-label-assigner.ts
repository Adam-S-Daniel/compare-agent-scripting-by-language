// PR Label Assigner — applies labels to a list of changed file paths
// according to a configurable set of glob-pattern -> label rules.
//
// Public surface:
//   - Config / Rule / ExclusiveGroup types
//   - assignLabels(config, files): the pure logic
//   - main()  : CLI entry that reads --config and --files, prints JSON
//
// Design notes:
//   - Uses Bun.Glob for pattern matching against path strings.
//   - Each rule has one label and one or more glob patterns.
//   - A file may match many rules (multiple labels per file).
//   - Optional `exclusiveGroups` resolve conflicts between mutually
//     exclusive labels by keeping the highest-priority winner only.
//   - Output is the deduplicated label set, sorted by priority desc
//     (and label name asc as a tiebreaker) for stable, comparable output.

export interface Rule {
  label: string;
  patterns: string[];
  priority?: number;
}

export interface ExclusiveGroup {
  labels: string[];
}

export interface Config {
  rules: Rule[];
  exclusiveGroups?: ExclusiveGroup[];
}

/**
 * Pure function: given a config and a list of changed file paths,
 * return the final, sorted set of labels.
 *
 * Steps:
 *   1. For every rule, check whether any pattern matches any file.
 *      If so, the rule contributes its label.
 *   2. Resolve `exclusiveGroups`: within each group, only the
 *      highest-priority matched label survives (alphabetical tiebreak).
 *   3. Sort the surviving label set by priority desc, then label asc.
 */
export function assignLabels(config: Config, files: string[]): string[] {
  // Index rule priorities by label so we can sort & resolve later.
  const priorityOf = new Map<string, number>();
  for (const rule of config.rules) {
    priorityOf.set(rule.label, rule.priority ?? 0);
  }

  const matched = new Set<string>();
  for (const rule of config.rules) {
    const globs = rule.patterns.map((p) => new Bun.Glob(p));
    if (files.some((f) => globs.some((g) => g.match(f)))) {
      matched.add(rule.label);
    }
  }

  // Resolve exclusive groups by keeping only the highest-priority winner.
  for (const group of config.exclusiveGroups ?? []) {
    const present = group.labels.filter((l) => matched.has(l));
    if (present.length <= 1) continue;
    const winner = present.sort(comparator(priorityOf))[0]!;
    for (const l of present) {
      if (l !== winner) matched.delete(l);
    }
  }

  return [...matched].sort(comparator(priorityOf));
}

// Sort: priority desc, then label name asc (stable, deterministic order).
function comparator(priorityOf: Map<string, number>) {
  return (a: string, b: string): number => {
    const dp = (priorityOf.get(b) ?? 0) - (priorityOf.get(a) ?? 0);
    if (dp !== 0) return dp;
    return a < b ? -1 : a > b ? 1 : 0;
  };
}

// --- CLI ---------------------------------------------------------------

interface CliArgs {
  configPath: string;
  filesPath: string;
}

function parseArgs(argv: string[]): CliArgs {
  let configPath = "";
  let filesPath = "";
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--config") configPath = argv[++i] ?? "";
    else if (a === "--files") filesPath = argv[++i] ?? "";
    else throw new Error(`Unknown argument: ${a}`);
  }
  if (!configPath) throw new Error("Missing required --config <path>");
  if (!filesPath) throw new Error("Missing required --files <path>");
  return { configPath, filesPath };
}

async function loadConfig(path: string): Promise<Config> {
  const file = Bun.file(path);
  if (!(await file.exists())) {
    throw new Error(`config file not found: ${path}`);
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(await file.text());
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    throw new Error(`invalid JSON in config ${path}: ${msg}`);
  }
  validateConfig(parsed);
  return parsed;
}

function validateConfig(c: unknown): asserts c is Config {
  if (!c || typeof c !== "object") {
    throw new Error("config must be an object");
  }
  const obj = c as Record<string, unknown>;
  if (!Array.isArray(obj.rules)) {
    throw new Error("config.rules must be an array");
  }
  for (const [i, r] of obj.rules.entries()) {
    if (!r || typeof r !== "object") {
      throw new Error(`config.rules[${i}] must be an object`);
    }
    const rule = r as Record<string, unknown>;
    if (typeof rule.label !== "string" || rule.label.length === 0) {
      throw new Error(`config.rules[${i}].label must be a non-empty string`);
    }
    if (
      !Array.isArray(rule.patterns) ||
      !rule.patterns.every((p) => typeof p === "string")
    ) {
      throw new Error(`config.rules[${i}].patterns must be a string[]`);
    }
    if (rule.priority !== undefined && typeof rule.priority !== "number") {
      throw new Error(`config.rules[${i}].priority must be a number`);
    }
  }
  if (obj.exclusiveGroups !== undefined && !Array.isArray(obj.exclusiveGroups)) {
    throw new Error("config.exclusiveGroups must be an array");
  }
}

async function loadFiles(path: string): Promise<string[]> {
  const file = Bun.file(path);
  if (!(await file.exists())) {
    throw new Error(`files list not found: ${path}`);
  }
  return (await file.text())
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l.length > 0);
}

async function main(argv: string[]): Promise<number> {
  try {
    const args = parseArgs(argv);
    const [config, files] = await Promise.all([
      loadConfig(args.configPath),
      loadFiles(args.filesPath),
    ]);
    const labels = assignLabels(config, files);
    process.stdout.write(JSON.stringify({ labels }) + "\n");
    return 0;
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    process.stderr.write(`error: ${msg}\n`);
    return 1;
  }
}

// Run as CLI when invoked as the main module.
if (import.meta.main) {
  process.exit(await main(process.argv.slice(2)));
}
