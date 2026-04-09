// matrix-generator.ts
// Generates GitHub Actions strategy.matrix JSON from a configuration object.
//
// GitHub Actions strategy structure:
//   strategy:
//     matrix:
//       os: [ubuntu-latest, windows-latest]
//       node-version: [18, 20]
//       include: [...]   # add or extend combinations
//       exclude: [...]   # remove combinations
//     max-parallel: 4
//     fail-fast: false

// ---- Types --------------------------------------------------------

/** Dimension values: each key maps to an array of string/number values. */
export interface MatrixDimensions {
  [key: string]: (string | number)[];
}

/** Input configuration for matrix generation. */
export interface MatrixConfig {
  /** The dimensions to form a cartesian product from. */
  matrix: MatrixDimensions;
  /**
   * Additional combinations to include. An entry that matches all dimension
   * keys of an existing combination just adds extra properties to it; an
   * entry with unrecognised keys (or values that don't match any existing
   * combination) adds a brand-new job.
   */
  include?: Array<Record<string, string | number>>;
  /** Combinations to remove from the cartesian product. */
  exclude?: Array<Record<string, string | number>>;
  /** Maximum number of jobs to run in parallel. */
  maxParallel?: number;
  /**
   * Whether GitHub Actions should cancel all in-progress jobs when any job
   * fails. Defaults to false.
   */
  failFast?: boolean;
  /**
   * Maximum total number of jobs (after excludes + non-overlapping includes).
   * Defaults to 256 — the GitHub Actions hard limit.
   */
  maxSize?: number;
}

/** Output that maps directly to the GitHub Actions `strategy` object. */
export interface MatrixOutput {
  matrix: {
    [key: string]:
      | (string | number)[]
      | Array<Record<string, string | number>>;
  };
  "max-parallel"?: number;
  "fail-fast": boolean;
}

// ---- Internal helpers --------------------------------------------

/**
 * Computes the cartesian product of all dimension arrays.
 * Returns one object per combination, e.g.:
 *   { os: ['a','b'], x: [1,2] }  →  [{os:'a',x:1}, {os:'a',x:2}, ...]
 */
function cartesianProduct(
  dimensions: MatrixDimensions
): Array<Record<string, string | number>> {
  const keys = Object.keys(dimensions);
  if (keys.length === 0) return [];

  let result: Array<Record<string, string | number>> = [{}];

  for (const key of keys) {
    const values = dimensions[key];
    const next: Array<Record<string, string | number>> = [];
    for (const existing of result) {
      for (const value of values) {
        next.push({ ...existing, [key]: value });
      }
    }
    result = next;
  }

  return result;
}

/**
 * Returns true if every key/value in `criteria` is present and equal in
 * `combo`. A criteria entry must match all of its own fields, but `combo`
 * may have additional fields.
 */
function matchesCriteria(
  combo: Record<string, string | number>,
  criteria: Record<string, string | number>
): boolean {
  return Object.entries(criteria).every(([k, v]) => combo[k] === v);
}

/**
 * Calculates the effective job count for size-validation purposes.
 *
 * Each include entry that matches an existing base combination merely adds
 * properties to that combination — it does NOT create a new job. An include
 * that has no matching base combination (i.e., it introduces a new
 * os/language/etc. combination) DOES add a new job.
 */
function calculateEffectiveSize(
  baseCombinations: Array<Record<string, string | number>>,
  includes: Array<Record<string, string | number>>,
  dimensionKeys: string[]
): number {
  let extra = 0;

  for (const inc of includes) {
    // Identify which of the include's keys are actual matrix dimension keys.
    const incDimKeys = Object.keys(inc).filter((k) =>
      dimensionKeys.includes(k)
    );

    if (incDimKeys.length === 0 || baseCombinations.length === 0) {
      // No overlap with dimensions → always a new independent job.
      extra += 1;
    } else {
      const incDimSlice = Object.fromEntries(
        incDimKeys.map((k) => [k, inc[k]])
      );
      const matchesExisting = baseCombinations.some((combo) =>
        matchesCriteria(combo, incDimSlice)
      );
      if (!matchesExisting) {
        // The include introduces a combination not present after excludes.
        extra += 1;
      }
      // If it matches, it only augments an existing job → no size change.
    }
  }

  return baseCombinations.length + extra;
}

// ---- Public API --------------------------------------------------

/**
 * Generates a GitHub Actions strategy matrix from the provided configuration.
 *
 * @param config - Matrix dimensions, include/exclude rules, and limits.
 * @returns A `MatrixOutput` object ready to be serialised as JSON and used
 *          in a `strategy:` block.
 * @throws {Error} When the effective job count exceeds `config.maxSize`
 *                 (default: 256).
 */
export function generateMatrix(config: MatrixConfig): MatrixOutput {
  const maxSize = config.maxSize ?? 256;
  const failFast = config.failFast ?? false;
  const includes = config.include ?? [];
  const excludes = config.exclude ?? [];

  // 1. Build the full cartesian product.
  let combinations = cartesianProduct(config.matrix);

  // 2. Apply excludes: drop any combination that matches an exclude entry.
  if (excludes.length > 0) {
    combinations = combinations.filter(
      (combo) => !excludes.some((exc) => matchesCriteria(combo, exc))
    );
  }

  // 3. Validate total size against the limit.
  const dimensionKeys = Object.keys(config.matrix);
  const totalSize = calculateEffectiveSize(combinations, includes, dimensionKeys);

  if (totalSize > maxSize) {
    throw new Error(
      `Matrix size ${totalSize} exceeds maximum allowed size of ${maxSize}. ` +
        `Reduce dimensions or increase maxSize.`
    );
  }

  // 4. Build the output matrix object, only adding include/exclude keys when
  //    the arrays are non-empty (keeps the JSON clean).
  const outputMatrix: MatrixOutput["matrix"] = { ...config.matrix };

  if (includes.length > 0) {
    outputMatrix["include"] = includes;
  }

  if (excludes.length > 0) {
    outputMatrix["exclude"] = excludes;
  }

  // 5. Assemble the strategy-level output.
  const output: MatrixOutput = {
    matrix: outputMatrix,
    "fail-fast": failFast,
  };

  if (config.maxParallel !== undefined) {
    output["max-parallel"] = config.maxParallel;
  }

  return output;
}

// ---- CLI entry point ---------------------------------------------

if (import.meta.main) {
  const configFile = process.argv[2];

  if (!configFile) {
    console.error("Usage: bun run matrix-generator.ts <config.json>");
    process.exit(1);
  }

  try {
    const raw = await Bun.file(configFile).json() as MatrixConfig;
    const result = generateMatrix(raw);

    // Use sentinel markers so act output can be reliably parsed.
    console.log("=== MATRIX OUTPUT START ===");
    console.log(JSON.stringify(result, null, 2));
    console.log("=== MATRIX OUTPUT END ===");
  } catch (error) {
    if (error instanceof Error) {
      console.error(`Error: ${error.message}`);
    } else {
      console.error("Unknown error occurred");
    }
    process.exit(1);
  }
}
