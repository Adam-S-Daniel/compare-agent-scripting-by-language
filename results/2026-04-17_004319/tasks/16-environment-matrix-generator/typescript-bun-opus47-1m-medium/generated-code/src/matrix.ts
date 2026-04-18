// Matrix generator for GitHub Actions strategy.matrix.
// Takes axes (OS/language/etc), include/exclude rules, feature flags,
// and produces a GH Actions-shaped matrix with max-parallel + fail-fast.

export type MatrixEntry = Record<string, string | number | boolean>;

export interface MatrixConfig {
  axes: Record<string, Array<string | number | boolean>>;
  include?: MatrixEntry[];
  exclude?: Partial<MatrixEntry>[];
  features?: Record<string, string | number | boolean>;
  maxParallel?: number;
  failFast?: boolean;
  maxSize?: number;
}

export interface GeneratedMatrix {
  matrix: {
    include: MatrixEntry[];
    "max-parallel"?: number;
    "fail-fast"?: boolean;
  };
}

function cartesian(
  axes: Record<string, Array<string | number | boolean>>,
): MatrixEntry[] {
  const keys = Object.keys(axes);
  let acc: MatrixEntry[] = [{}];
  for (const key of keys) {
    const next: MatrixEntry[] = [];
    for (const combo of acc) {
      for (const value of axes[key]!) {
        next.push({ ...combo, [key]: value });
      }
    }
    acc = next;
  }
  return acc;
}

function matchesExclude(
  entry: MatrixEntry,
  rule: Partial<MatrixEntry>,
): boolean {
  // Every key-value in the rule must appear in the entry.
  for (const [k, v] of Object.entries(rule)) {
    if (entry[k] !== v) return false;
  }
  return true;
}

function entryKey(e: MatrixEntry): string {
  const keys = Object.keys(e).sort();
  return keys.map((k) => `${k}=${JSON.stringify(e[k])}`).join("|");
}

export function generateMatrix(config: MatrixConfig): GeneratedMatrix {
  const axisKeys = Object.keys(config.axes);
  if (axisKeys.length === 0) {
    throw new Error("Matrix must define at least one axis");
  }
  for (const [k, values] of Object.entries(config.axes)) {
    if (!Array.isArray(values) || values.length === 0) {
      throw new Error(`Axis "${k}" must have at least one value`);
    }
  }

  let combos = cartesian(config.axes);

  if (config.exclude && config.exclude.length > 0) {
    combos = combos.filter(
      (c) => !config.exclude!.some((rule) => matchesExclude(c, rule)),
    );
  }

  if (config.features) {
    combos = combos.map((c) => ({ ...c, ...config.features }));
  }

  // Merge include entries, deduplicating against existing combos.
  const seen = new Set(combos.map(entryKey));
  if (config.include) {
    for (const inc of config.include) {
      const key = entryKey(inc);
      if (!seen.has(key)) {
        combos.push(inc);
        seen.add(key);
      }
    }
  }

  if (config.maxSize !== undefined && combos.length > config.maxSize) {
    throw new Error(
      `Matrix size ${combos.length} exceeds maximum size ${config.maxSize}`,
    );
  }

  const matrix: GeneratedMatrix["matrix"] = { include: combos };
  if (config.maxParallel !== undefined) matrix["max-parallel"] = config.maxParallel;
  if (config.failFast !== undefined) matrix["fail-fast"] = config.failFast;

  return { matrix };
}
