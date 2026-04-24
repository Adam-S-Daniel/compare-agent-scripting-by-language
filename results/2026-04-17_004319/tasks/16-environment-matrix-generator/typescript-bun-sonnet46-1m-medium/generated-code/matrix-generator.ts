// Environment Matrix Generator — core logic
// Generates GitHub Actions strategy.matrix JSON from a configuration object.

export type MatrixValue = string | boolean | number;
export type MatrixEntry = Record<string, MatrixValue>;

export interface MatrixConfig {
  os?: string[];
  // Named language/tool dimensions, e.g. { node: ['18','20'], python: ['3.11','3.12'] }
  languages?: Record<string, string[]>;
  // Feature flags: boolean/string scalar → constant on every entry; array → new dimension
  features?: Record<string, MatrixValue | MatrixValue[]>;
  // Explicit entries to add after cartesian product
  include?: MatrixEntry[];
  // Patterns to remove from the cartesian product
  exclude?: MatrixEntry[];
  maxParallel?: number;
  failFast?: boolean;
  // Maximum allowed combinations (default 256, GitHub's actual limit)
  maxSize?: number;
}

export interface MatrixSuccess {
  success: true;
  matrix: { include: MatrixEntry[] };
  strategy: {
    'max-parallel'?: number;
    'fail-fast': boolean;
  };
  summary: {
    totalCombinations: number;
    maxSize: number;
    valid: true;
  };
}

export interface MatrixError {
  success: false;
  error: string;
}

export type GenerateResult = MatrixSuccess | MatrixError;

// Computes the cartesian product of named dimensions.
// Returns [{}] when there are no dimensions (one empty entry).
function cartesian(dims: Record<string, MatrixValue[]>): MatrixEntry[] {
  const keys = Object.keys(dims);
  if (keys.length === 0) return [{}];

  const [head, ...tail] = keys;
  const tailProduct = cartesian(Object.fromEntries(tail.map(k => [k, dims[k]])));

  const result: MatrixEntry[] = [];
  for (const val of dims[head]) {
    for (const rest of tailProduct) {
      result.push({ [head]: val, ...rest });
    }
  }
  return result;
}

// Returns true if every key/value in pattern matches the entry.
function matches(entry: MatrixEntry, pattern: MatrixEntry): boolean {
  return Object.entries(pattern).every(([k, v]) => entry[k] === v);
}

export function generateMatrix(config: MatrixConfig): GenerateResult {
  const maxSize = config.maxSize ?? 256;

  // Separate array-valued features (→ dimensions) from scalar ones (→ constants).
  const dims: Record<string, MatrixValue[]> = {};
  const constants: MatrixEntry = {};

  if (config.os?.length) dims['os'] = config.os;

  for (const [lang, versions] of Object.entries(config.languages ?? {})) {
    if (versions.length) dims[lang] = versions;
  }

  for (const [flag, val] of Object.entries(config.features ?? {})) {
    if (Array.isArray(val)) {
      dims[flag] = val;
    } else {
      constants[flag] = val;
    }
  }

  // Build base set: cartesian product with constants merged in.
  let entries = cartesian(dims).map(e => ({ ...e, ...constants }));

  // Apply excludes — remove any entry that fully matches an exclude pattern.
  if (config.exclude?.length) {
    entries = entries.filter(e => !config.exclude!.some(pat => matches(e, pat)));
  }

  // Apply includes — add entries that don't already exist in the set.
  for (const inc of config.include ?? []) {
    if (!entries.some(e => matches(e, inc) && matches(inc, e))) {
      entries.push(inc);
    }
  }

  if (entries.length > maxSize) {
    return {
      success: false,
      error: `Matrix size ${entries.length} exceeds maximum allowed size of ${maxSize}`,
    };
  }

  const strategy: MatrixSuccess['strategy'] = {
    'fail-fast': config.failFast ?? true,
  };
  if (config.maxParallel !== undefined) {
    strategy['max-parallel'] = config.maxParallel;
  }

  return {
    success: true,
    matrix: { include: entries },
    strategy,
    summary: { totalCombinations: entries.length, maxSize, valid: true },
  };
}
