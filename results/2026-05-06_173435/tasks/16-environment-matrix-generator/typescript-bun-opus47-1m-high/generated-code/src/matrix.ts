// Environment matrix generator.
//
// Given a config describing axes (e.g. os/language version/feature flags),
// optional include/exclude rules, max-parallel, fail-fast, and a max-size
// guardrail, this module produces a JSON object compatible with GitHub
// Actions' `strategy.matrix` (using the include-only form so any combination
// can be expressed and exclusions are pre-applied).

export type MatrixValue = string | number | boolean;
export type Combination = Record<string, MatrixValue>;
export type AxisFilter = Record<string, MatrixValue>;

export interface MatrixConfig {
  /** Map of axis name -> list of values. At least one axis is required. */
  axes: Record<string, MatrixValue[]>;
  /** Extra combinations to append after the cartesian product. */
  include?: Combination[];
  /** Filters that drop matching combinations from the cartesian product. */
  exclude?: AxisFilter[];
  /** GitHub `strategy.max-parallel`. */
  maxParallel?: number;
  /** GitHub `strategy.fail-fast`. Defaults to true (GitHub default). */
  failFast?: boolean;
  /** Hard limit on resulting combinations (after include/exclude). */
  maxSize?: number;
}

export interface MatrixResult {
  /** The `strategy.matrix` body. We always emit the `include` form. */
  matrix: { include: Combination[] };
  failFast: boolean;
  maxParallel?: number;
}

/** GitHub Actions allows at most 256 jobs per matrix. */
export const GITHUB_MAX_JOBS = 256;

export class MatrixError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "MatrixError";
  }
}

/** Cartesian product over an ordered list of (name, values) pairs. */
function cartesian(axes: Array<[string, MatrixValue[]]>): Combination[] {
  // Start with a single empty combo and multiply through each axis.
  let combos: Combination[] = [{}];
  for (const [name, values] of axes) {
    if (values.length === 0) return [];
    const next: Combination[] = [];
    for (const combo of combos) {
      for (const value of values) {
        next.push({ ...combo, [name]: value });
      }
    }
    combos = next;
  }
  return combos;
}

/** True when every key in `filter` matches the same key in `combo`. */
function matchesFilter(combo: Combination, filter: AxisFilter): boolean {
  for (const [k, v] of Object.entries(filter)) {
    if (combo[k] !== v) return false;
  }
  return true;
}

/** Stable JSON-key for combo dedup. Object keys are sorted. */
function comboKey(combo: Combination): string {
  const keys = Object.keys(combo).sort();
  return JSON.stringify(keys.map((k) => [k, combo[k]]));
}

export function generateMatrix(config: MatrixConfig): MatrixResult {
  const axisEntries = Object.entries(config.axes);
  if (axisEntries.length === 0) {
    throw new MatrixError("Config must declare at least one axis under `axes`.");
  }

  // 1. Cartesian product of all axes.
  let combos = cartesian(axisEntries);

  // 2. Apply excludes.
  if (config.exclude && config.exclude.length > 0) {
    combos = combos.filter(
      (combo) => !config.exclude!.some((f) => matchesFilter(combo, f)),
    );
  }

  // 3. Append includes (deduped against existing combos with identical keys/values).
  if (config.include && config.include.length > 0) {
    const seen = new Set(combos.map(comboKey));
    for (const inc of config.include) {
      if (!seen.has(comboKey(inc))) {
        combos.push({ ...inc });
        seen.add(comboKey(inc));
      }
    }
  }

  // 4. Validate size.
  const limit = config.maxSize ?? GITHUB_MAX_JOBS;
  if (combos.length > limit) {
    const reason =
      config.maxSize !== undefined
        ? `exceeds max-size ${config.maxSize}`
        : `exceeds GitHub Actions ceiling of ${GITHUB_MAX_JOBS}`;
    throw new MatrixError(
      `Generated matrix has ${combos.length} combinations, which ${reason}.`,
    );
  }

  // 5. Validate maxParallel sanity.
  if (config.maxParallel !== undefined && config.maxParallel <= 0) {
    throw new MatrixError(
      `maxParallel must be > 0, received ${config.maxParallel}.`,
    );
  }

  return {
    matrix: { include: combos },
    failFast: config.failFast ?? true,
    maxParallel: config.maxParallel,
  };
}
