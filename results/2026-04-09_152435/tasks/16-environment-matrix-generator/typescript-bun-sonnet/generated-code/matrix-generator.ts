/**
 * Environment Matrix Generator
 *
 * Generates a GitHub Actions strategy.matrix JSON object from a configuration
 * that describes OS options, language versions, and feature flags.
 *
 * Design:
 *  1. Build axes from os, language_versions, and feature_flags.
 *  2. Compute the cartesian product to get effective combination count.
 *  3. Apply exclude rules (reduces combination count).
 *  4. Apply include rules (each include that doesn't overlap adds a job).
 *  5. Validate total combination count against max_size.
 *  6. Return the GitHub Actions strategy object with matrix, fail-fast,
 *     max-parallel (if provided), and combinationCount for callers to inspect.
 */

// ── Types ─────────────────────────────────────────────────────────────────────

export interface MatrixConfig {
  /** OS images to include, e.g. ["ubuntu-latest", "windows-latest"] */
  os?: string[];
  /** Language → version arrays, e.g. { node: ["18", "20"] } */
  language_versions?: Record<string, string[]>;
  /** Boolean feature flags, e.g. { experimental: [true, false] } */
  feature_flags?: Record<string, boolean[]>;
  /** Extra matrix entries to inject (GitHub Actions include) */
  include?: Record<string, unknown>[];
  /** Matrix entries to remove (GitHub Actions exclude) */
  exclude?: Record<string, unknown>[];
  /** GitHub Actions max-parallel limit */
  max_parallel?: number;
  /** Whether to cancel in-progress jobs on first failure (default: true) */
  fail_fast?: boolean;
  /** Maximum number of effective jobs allowed (default: 256) */
  max_size?: number;
}

export interface MatrixOutput {
  strategy: {
    matrix: Record<string, unknown>;
    "fail-fast": boolean;
    "max-parallel"?: number;
  };
  /** Total effective job count (base combos − excludes + new includes) */
  combinationCount: number;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/**
 * Returns the cartesian product of an array of value arrays.
 * E.g. cartesian([["a","b"], [1,2]]) → [["a",1],["a",2],["b",1],["b",2]]
 */
function cartesian(arrays: unknown[][]): unknown[][] {
  if (arrays.length === 0) return [[]];
  const [first, ...rest] = arrays;
  const tail = cartesian(rest);
  const result: unknown[][] = [];
  for (const item of first) {
    for (const combo of tail) {
      result.push([item, ...combo]);
    }
  }
  return result;
}

/**
 * Returns true when a matrix entry matches all key/value pairs in a rule.
 * Used for both exclude matching and include-overlap detection.
 */
function matchesRule(
  entry: Record<string, unknown>,
  rule: Record<string, unknown>
): boolean {
  return Object.entries(rule).every(([k, v]) => entry[k] === v);
}

// ── Core generator ────────────────────────────────────────────────────────────

export function generateMatrix(config: MatrixConfig): MatrixOutput {
  const {
    os = [],
    language_versions = {},
    feature_flags = {},
    include = [],
    exclude = [],
    max_parallel,
    fail_fast = true,
    max_size = 256,
  } = config;

  // Build ordered axes: OS first, then language versions, then feature flags.
  type Axis = { name: string; values: unknown[] };
  const axes: Axis[] = [];

  if (os.length > 0) {
    axes.push({ name: "os", values: os });
  }
  for (const [lang, versions] of Object.entries(language_versions)) {
    if (versions.length > 0) {
      axes.push({ name: lang, values: versions });
    }
  }
  for (const [flag, values] of Object.entries(feature_flags)) {
    if (values.length > 0) {
      axes.push({ name: flag, values: values });
    }
  }

  // Compute base combinations as objects so we can apply exclude rules.
  const axisCombos =
    axes.length > 0
      ? cartesian(axes.map((a) => a.values))
      : [[]]; // one empty combo when there are no axes

  let baseCombos: Record<string, unknown>[] = axisCombos.map((combo) => {
    const entry: Record<string, unknown> = {};
    axes.forEach((axis, i) => {
      entry[axis.name] = combo[i];
    });
    return entry;
  });

  // Apply exclude rules — remove any base combo that matches an exclude entry.
  if (exclude.length > 0) {
    baseCombos = baseCombos.filter(
      (entry) => !exclude.some((rule) => matchesRule(entry, rule))
    );
  }

  // Count new include entries (those that don't overlap with existing combos).
  // Overlapping includes only add extra keys to matching jobs, not new jobs.
  const newIncludeCount = include.filter(
    (inc) => !baseCombos.some((entry) => matchesRule(entry, inc))
  ).length;

  const combinationCount = baseCombos.length + newIncludeCount;

  // Validate against max_size.
  if (combinationCount > max_size) {
    throw new Error(
      `Matrix size ${combinationCount} exceeds maximum allowed size of ${max_size}. ` +
        `Reduce the number of OS options, language versions, or feature flags, ` +
        `or increase max_size.`
    );
  }

  // Build the GitHub Actions matrix object.
  const matrix: Record<string, unknown> = {};

  // Axis arrays
  for (const axis of axes) {
    matrix[axis.name] = axis.values;
  }
  if (include.length > 0) {
    matrix.include = include;
  }
  if (exclude.length > 0) {
    matrix.exclude = exclude;
  }

  const output: MatrixOutput = {
    strategy: {
      matrix,
      "fail-fast": fail_fast,
    },
    combinationCount,
  };

  if (max_parallel !== undefined) {
    output.strategy["max-parallel"] = max_parallel;
  }

  return output;
}
