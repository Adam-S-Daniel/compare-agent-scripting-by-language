// Environment Matrix Generator
// Generates GitHub Actions strategy.matrix compatible JSON from a high-level config.

export type MatrixValue = string | boolean | number;

export interface MatrixConfig {
  // Each key maps to an array of values for that dimension
  dimensions: Record<string, MatrixValue[]>;
  // Extra combinations or augmentations (GitHub Actions semantics)
  include?: Record<string, MatrixValue>[];
  // Combinations to remove from the product
  exclude?: Record<string, MatrixValue>[];
  maxParallel?: number;
  failFast?: boolean;
  // Maximum allowed effective combinations (default 256, GitHub's limit)
  maxSize?: number;
}

export interface MatrixOutput {
  matrix: Record<string, MatrixValue[] | Record<string, MatrixValue>[]>;
  "max-parallel"?: number;
  "fail-fast"?: boolean;
  totalCombinations: number;
  effectiveCombinations: number;
}

// Compute the cartesian product of arrays of values.
// Returns [] for an empty input (no dimensions = no combinations).
function cartesian(arrays: MatrixValue[][]): MatrixValue[][] {
  if (arrays.length === 0) return [];
  return arrays.reduce<MatrixValue[][]>(
    (acc, curr) => acc.flatMap((a) => curr.map((b) => [...a, b])),
    [[]]
  );
}

// Returns true if entry contains every key-value pair in rule.
function matches(
  entry: Record<string, MatrixValue>,
  rule: Record<string, MatrixValue>
): boolean {
  return Object.entries(rule).every(([k, v]) => entry[k] === v);
}

export function generateMatrix(config: MatrixConfig): MatrixOutput {
  const {
    dimensions,
    include,
    exclude,
    maxParallel,
    failFast,
    maxSize = 256,
  } = config;

  const keys = Object.keys(dimensions);

  // Empty dimensions → zero combinations
  if (keys.length === 0) {
    return { matrix: {}, totalCombinations: 0, effectiveCombinations: 0 };
  }

  // Total = product of all dimension sizes (before apply any rules)
  const totalCombinations = keys.reduce((acc, k) => acc * dimensions[k].length, 1);

  // Build the full cartesian product as flat objects
  const product = cartesian(keys.map((k) => dimensions[k]));
  let entries: Record<string, MatrixValue>[] = product.map((vals) =>
    Object.fromEntries(keys.map((k, i) => [k, vals[i]]))
  );

  // Apply exclude rules: drop entries that match any exclude rule
  if (exclude?.length) {
    entries = entries.filter((e) => !exclude.some((r) => matches(e, r)));
  }

  // Count "net-new" includes — ones whose dimension values don't match any
  // remaining entry. An include that matches an existing entry just augments it
  // (GitHub Actions behaviour) and doesn't add a new combination.
  let newIncludes = 0;
  if (include?.length) {
    for (const rule of include) {
      // Extract only the keys that are dimension keys from this include rule
      const dimSubset = Object.fromEntries(
        keys.filter((k) => k in rule).map((k) => [k, rule[k]])
      );
      // If no dimension keys present, treat as always-new
      const isNew =
        Object.keys(dimSubset).length === 0 ||
        !entries.some((e) => matches(e, dimSubset));
      if (isNew) newIncludes++;
    }
  }

  const effectiveCombinations = entries.length + newIncludes;

  if (effectiveCombinations > maxSize) {
    throw new Error(
      `Matrix size ${effectiveCombinations} exceeds maximum allowed size of ${maxSize}`
    );
  }

  // Build the output matrix object
  const matrix: Record<string, MatrixValue[] | Record<string, MatrixValue>[]> = {};
  for (const [k, v] of Object.entries(dimensions)) {
    matrix[k] = v;
  }
  if (include?.length) matrix.include = include;
  if (exclude?.length) matrix.exclude = exclude;

  const output: MatrixOutput = { matrix, totalCombinations, effectiveCombinations };
  if (maxParallel !== undefined) output["max-parallel"] = maxParallel;
  if (failFast !== undefined) output["fail-fast"] = failFast;

  return output;
}
