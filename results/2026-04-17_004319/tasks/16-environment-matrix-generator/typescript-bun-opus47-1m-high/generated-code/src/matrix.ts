// Environment matrix generator.
//
// Takes a declarative configuration (axes + include/exclude + limits) and
// produces a GitHub Actions-compatible strategy block with an expanded
// list of combinations. The expansion mirrors GitHub's documented rules:
//   1. Start with the cartesian product of the axes.
//   2. Remove combinations that match every key/value pair of an exclude rule.
//   3. For each include rule:
//        - If all of its keys match an existing combination (and all extra
//          keys don't conflict with an axis value in that combination), merge
//          the rule's extra keys into every matching combination.
//        - Otherwise, append it as a brand-new combination.
//
// See: https://docs.github.com/en/actions/using-jobs/using-a-matrix-for-your-jobs

export type AxisValue = string | number | boolean;
export type Combination = Record<string, AxisValue>;

export interface MatrixConfig {
  axes: Record<string, AxisValue[]>;
  include?: Combination[];
  exclude?: Partial<Combination>[];
  maxParallel?: number;
  failFast?: boolean;
  maxSize?: number;
}

export interface MatrixOutput {
  strategy: {
    "fail-fast": boolean;
    "max-parallel": number | null;
    matrix: {
      include: Combination[];
    };
  };
  total: number;
}

export class MatrixConfigError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "MatrixConfigError";
  }
}

function validateConfig(config: MatrixConfig): void {
  if (!config.axes || typeof config.axes !== "object") {
    throw new MatrixConfigError("`axes` must be an object mapping axis names to arrays");
  }
  const axisEntries = Object.entries(config.axes);
  if (axisEntries.length === 0) {
    throw new MatrixConfigError("`axes` must contain at least one axis");
  }
  for (const [name, values] of axisEntries) {
    if (!Array.isArray(values)) {
      throw new MatrixConfigError(`axis '${name}' must be an array of values`);
    }
    if (values.length === 0) {
      throw new MatrixConfigError(`axis '${name}' must have at least one value`);
    }
  }
  if (config.maxParallel !== undefined) {
    if (!Number.isInteger(config.maxParallel) || config.maxParallel < 1) {
      throw new MatrixConfigError("`maxParallel` must be a positive integer");
    }
  }
  if (config.maxSize !== undefined) {
    if (!Number.isInteger(config.maxSize) || config.maxSize < 1) {
      throw new MatrixConfigError("`maxSize` must be a positive integer");
    }
  }
}

// Cartesian product over the axis entries, preserving axis key order.
function cartesian(axes: Record<string, AxisValue[]>): Combination[] {
  const entries = Object.entries(axes);
  let result: Combination[] = [{}];
  for (const [key, values] of entries) {
    const next: Combination[] = [];
    for (const existing of result) {
      for (const value of values) {
        next.push({ ...existing, [key]: value });
      }
    }
    result = next;
  }
  return result;
}

function matchesAllKeys(combo: Combination, rule: Partial<Combination>): boolean {
  for (const [key, value] of Object.entries(rule)) {
    if (combo[key] !== value) return false;
  }
  return true;
}

function applyExcludes(
  combos: Combination[],
  excludes: Partial<Combination>[],
): Combination[] {
  if (excludes.length === 0) return combos;
  return combos.filter((combo) => !excludes.some((rule) => matchesAllKeys(combo, rule)));
}

function applyIncludes(
  combos: Combination[],
  includes: Combination[],
  axisKeys: Set<string>,
): Combination[] {
  const result = [...combos];
  for (const rule of includes) {
    // Partition the rule's keys: those shared with an existing axis (used to
    // find matching combinations), and extras (merged into matches).
    const ruleAxisKeys = Object.entries(rule).filter(([k]) => axisKeys.has(k));
    const ruleExtras = Object.entries(rule).filter(([k]) => !axisKeys.has(k));

    let merged = false;
    if (ruleAxisKeys.length > 0) {
      for (let i = 0; i < result.length; i++) {
        const combo = result[i]!;
        const matches = ruleAxisKeys.every(([k, v]) => combo[k] === v);
        if (!matches) continue;
        // Don't merge if an extra key would overwrite an axis value on the combo.
        const conflict = ruleExtras.some(
          ([k, v]) => combo[k] !== undefined && combo[k] !== v,
        );
        if (conflict) continue;
        result[i] = { ...combo, ...rule };
        merged = true;
      }
    }
    if (!merged) {
      // Either no axis-key overlap (a fully new axis combo) or nothing matched:
      // append as a brand-new combination.
      result.push({ ...rule });
    }
  }
  return result;
}

export function generateMatrix(config: MatrixConfig): MatrixOutput {
  validateConfig(config);

  const base = cartesian(config.axes);
  const afterExclude = applyExcludes(base, config.exclude ?? []);
  const axisKeys = new Set(Object.keys(config.axes));
  const finalCombos = applyIncludes(afterExclude, config.include ?? [], axisKeys);

  const total = finalCombos.length;
  if (config.maxSize !== undefined && total > config.maxSize) {
    throw new MatrixConfigError(
      `matrix size ${total} exceeds maxSize ${config.maxSize}`,
    );
  }

  return {
    strategy: {
      "fail-fast": config.failFast ?? true,
      "max-parallel": config.maxParallel ?? null,
      matrix: { include: finalCombos },
    },
    total,
  };
}
