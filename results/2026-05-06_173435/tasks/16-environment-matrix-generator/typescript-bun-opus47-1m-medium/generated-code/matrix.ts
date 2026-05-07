// Build-matrix generator for GitHub Actions strategy.matrix.
// Pure functions only; no I/O so the logic can be unit tested in isolation.

export type AxisValue = string | number | boolean;
export type Combination = Record<string, AxisValue>;

export interface MatrixConfig {
  axes: Record<string, AxisValue[]>;
  include?: Combination[];
  exclude?: Combination[];
  maxParallel?: number;
  failFast?: boolean;
  maxSize?: number;
}

export interface MatrixResult {
  matrix: Record<string, AxisValue[] | Combination[]>;
  combinations: Combination[];
  total: number;
  "max-parallel"?: number;
  "fail-fast"?: boolean;
}

export class MatrixError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "MatrixError";
  }
}

// Cartesian product of axis arrays. Produces combos in the same order GitHub
// Actions uses: leftmost axis varies slowest.
function cartesian(axes: Record<string, AxisValue[]>): Combination[] {
  const keys = Object.keys(axes);
  if (keys.length === 0) return [];
  let acc: Combination[] = [{}];
  for (const key of keys) {
    const next: Combination[] = [];
    for (const combo of acc) {
      for (const value of axes[key]!) {
        next.push({ ...combo, [key]: value });
      }
    }
    acc = next;
  }
  return acc;
}

// `pattern` matches `combo` if every key in pattern exists in combo with the
// same value. Extra keys on combo are ignored — that's how partial excludes
// (e.g. {os: "mac"}) strip a whole slice.
function matches(combo: Combination, pattern: Combination): boolean {
  for (const key of Object.keys(pattern)) {
    if (combo[key] !== pattern[key]) return false;
  }
  return true;
}

// GitHub include semantics: if every key in the include row that is also a
// matrix axis already matches an existing combo (and any extra keys do not
// overwrite an axis value), merge the remaining keys into that combo;
// otherwise append the include as a new row.
function applyInclude(
  combinations: Combination[],
  axisKeys: Set<string>,
  include: Combination,
): Combination[] {
  const includeAxisKeys = Object.keys(include).filter((k) => axisKeys.has(k));
  let merged = false;
  const out = combinations.map((combo) => {
    if (merged) return combo;
    const allMatch = includeAxisKeys.every((k) => combo[k] === include[k]);
    if (!allMatch) return combo;
    merged = true;
    return { ...combo, ...include };
  });
  if (!merged) out.push({ ...include });
  return out;
}

export function generateMatrix(config: MatrixConfig): MatrixResult {
  if (!config.axes || Object.keys(config.axes).length === 0) {
    throw new MatrixError("matrix must define at least one axis");
  }
  for (const [key, values] of Object.entries(config.axes)) {
    if (!Array.isArray(values) || values.length === 0) {
      throw new MatrixError(`axis "${key}" must be a non-empty array`);
    }
  }

  let combos = cartesian(config.axes);

  if (config.exclude && config.exclude.length > 0) {
    combos = combos.filter(
      (combo) => !config.exclude!.some((rule) => matches(combo, rule)),
    );
  }

  if (config.include && config.include.length > 0) {
    const axisKeys = new Set(Object.keys(config.axes));
    for (const inc of config.include) {
      combos = applyInclude(combos, axisKeys, inc);
    }
  }

  if (config.maxSize !== undefined && combos.length > config.maxSize) {
    throw new MatrixError(
      `matrix size ${combos.length} exceeds maxSize ${config.maxSize}`,
    );
  }

  const matrix: Record<string, AxisValue[] | Combination[]> = { ...config.axes };
  if (config.include && config.include.length > 0) matrix.include = config.include;
  if (config.exclude && config.exclude.length > 0) matrix.exclude = config.exclude;

  const result: MatrixResult = {
    matrix,
    combinations: combos,
    total: combos.length,
  };
  if (config.maxParallel !== undefined) result["max-parallel"] = config.maxParallel;
  if (config.failFast !== undefined) result["fail-fast"] = config.failFast;
  return result;
}
