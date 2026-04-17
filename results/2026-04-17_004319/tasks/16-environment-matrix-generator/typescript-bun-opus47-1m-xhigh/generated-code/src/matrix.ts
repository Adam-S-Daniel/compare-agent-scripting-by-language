// Environment matrix generator.
//
// Given a configuration describing build dimensions (OS, language versions,
// feature flags), produce a GitHub Actions strategy.matrix-compatible output:
// a fully expanded list of job combinations under `matrix.include`, plus the
// `fail-fast` and `max-parallel` strategy fields when configured.
//
// Supported features:
//   - Cross product across arbitrary named dimensions
//   - `exclude` rules that drop any combination matching all listed keys
//   - `include` rules that either augment a matching existing combination
//     (like GitHub Actions) or append a brand-new combination
//   - `max-parallel` and `fail-fast` passthrough to the output
//   - `maxSize` validation that guards against accidental combinatorial blowup

export type MatrixValue = string | number | boolean;
export type Combination = Record<string, MatrixValue>;

export interface MatrixConfig {
  dimensions: Record<string, MatrixValue[]>;
  include?: Combination[];
  exclude?: Combination[];
  maxParallel?: number;
  failFast?: boolean;
  maxSize?: number;
}

export interface MatrixResult {
  matrix: { include: Combination[] };
  totalSize: number;
  "fail-fast"?: boolean;
  "max-parallel"?: number;
}

// Dedicated error class so callers can distinguish configuration errors from
// unrelated runtime failures (e.g., JSON.parse errors on bad input).
export class MatrixError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "MatrixError";
  }
}

// Validate the input shape before any work, so the error message points at
// the actual cause rather than failing deep inside the cartesian loop.
function validateConfig(config: MatrixConfig): void {
  if (!config || typeof config !== "object") {
    throw new MatrixError("config must be an object");
  }
  if (!config.dimensions || typeof config.dimensions !== "object") {
    throw new MatrixError("config.dimensions must be an object");
  }
  for (const [key, values] of Object.entries(config.dimensions)) {
    if (!Array.isArray(values)) {
      throw new MatrixError(
        `dimension "${key}" must be an array, got ${typeof values}`,
      );
    }
    if (values.length === 0) {
      throw new MatrixError(
        `dimension "${key}" must have at least one value`,
      );
    }
  }
  if (config.maxParallel !== undefined) {
    if (!Number.isInteger(config.maxParallel) || config.maxParallel < 1) {
      throw new MatrixError(
        `maxParallel must be a positive integer, got ${config.maxParallel}`,
      );
    }
  }
  if (config.maxSize !== undefined) {
    if (!Number.isInteger(config.maxSize) || config.maxSize < 1) {
      throw new MatrixError(
        `maxSize must be a positive integer, got ${config.maxSize}`,
      );
    }
  }
}

// Cartesian product across all dimensions. The last dimension varies fastest,
// matching the "nested for-loop" mental model (and what GitHub Actions does
// internally when expanding a matrix).
function cartesianProduct(
  dimensions: Record<string, MatrixValue[]>,
): Combination[] {
  const keys = Object.keys(dimensions);
  if (keys.length === 0) return [];
  let combos: Combination[] = [{}];
  for (const key of keys) {
    const next: Combination[] = [];
    for (const combo of combos) {
      for (const value of dimensions[key]!) {
        next.push({ ...combo, [key]: value });
      }
    }
    combos = next;
  }
  return combos;
}

// A rule matches a combo if every key in the rule is present in the combo
// with the same value. This is how GitHub Actions interprets both excludes
// (match == drop) and include-merges (match == augment).
function ruleMatches(rule: Combination, combo: Combination): boolean {
  for (const [key, value] of Object.entries(rule)) {
    if (!(key in combo) || combo[key] !== value) return false;
  }
  return true;
}

// Apply include rules following GitHub Actions semantics:
// For each include entry, check if its keys that overlap with dimensions all
// match an existing combo. If so, merge the extra keys into that combo.
// Otherwise, append as a new standalone combination.
function applyIncludes(
  base: Combination[],
  includes: Combination[],
  dimensionKeys: Set<string>,
): Combination[] {
  const result = base.map((c) => ({ ...c }));
  for (const inc of includes) {
    // Split the include entry into "dimension overlap" (used to find a match)
    // and "extra keys" (added to the matched combo).
    const overlap: Combination = {};
    const extras: Combination = {};
    for (const [k, v] of Object.entries(inc)) {
      if (dimensionKeys.has(k)) overlap[k] = v;
      else extras[k] = v;
    }

    // Decide whether this include is a merge-into-existing or a new entry.
    // It merges only when every dimension-overlap key matches an existing
    // combo AND there is at least one extra key AND the overlap covers
    // dimensions not fully specified (matches GH Actions behavior of
    // "matrix + extra").
    let merged = false;
    if (Object.keys(extras).length > 0) {
      for (const combo of result) {
        if (ruleMatches(overlap, combo)) {
          Object.assign(combo, extras);
          merged = true;
        }
      }
    }
    if (!merged) {
      // Standalone: append as its own combination.
      result.push({ ...inc });
    }
  }
  return result;
}

// Main entry point.
export function generateMatrix(config: MatrixConfig): MatrixResult {
  validateConfig(config);

  // 1. Build the full cartesian product of the dimensions.
  const crossProduct = cartesianProduct(config.dimensions);

  // 2. Drop combinations matched by any exclude rule.
  const excludes = config.exclude ?? [];
  const afterExclude =
    excludes.length === 0
      ? crossProduct
      : crossProduct.filter((combo) => !excludes.some((e) => ruleMatches(e, combo)));

  // 3. Apply includes last so they can resurrect excluded combos and add
  //    standalone combinations that fall outside the cartesian product.
  const includes = config.include ?? [];
  const dimensionKeys = new Set(Object.keys(config.dimensions));
  const finalCombos =
    includes.length === 0
      ? afterExclude
      : applyIncludes(afterExclude, includes, dimensionKeys);

  // 4. Validate final size against maxSize cap.
  if (config.maxSize !== undefined && finalCombos.length > config.maxSize) {
    throw new MatrixError(
      `matrix size ${finalCombos.length} exceeds maxSize ${config.maxSize}`,
    );
  }

  // 5. Build the output object. Only include strategy fields that were set,
  //    so the JSON stays minimal when the caller didn't configure them.
  const result: MatrixResult = {
    matrix: { include: finalCombos },
    totalSize: finalCombos.length,
  };
  if (config.failFast !== undefined) result["fail-fast"] = config.failFast;
  if (config.maxParallel !== undefined) result["max-parallel"] = config.maxParallel;
  return result;
}
