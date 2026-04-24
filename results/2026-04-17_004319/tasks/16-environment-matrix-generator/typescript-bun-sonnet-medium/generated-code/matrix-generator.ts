// Environment Matrix Generator
// Generates GitHub Actions strategy.matrix JSON from a configuration file.

export interface MatrixConfig {
  dimensions: Record<string, string[]>;
  include?: Record<string, string>[];
  exclude?: Record<string, string>[];
  maxParallel?: number;
  failFast?: boolean;
  maxSize?: number;
}

// The matrix property mirrors what GitHub Actions expects in strategy.matrix
export interface GHAMatrix {
  [key: string]: string[] | Record<string, string>[] | undefined;
  include?: Record<string, string>[];
  exclude?: Record<string, string>[];
}

export interface MatrixOutput {
  matrix: GHAMatrix;
  maxParallel?: number;
  failFast?: boolean;
  combinations: number;
  valid: boolean;
  errors?: string[];
}

const DEFAULT_MAX_SIZE = 256;

// Compute the Cartesian product of all dimensions.
// Returns an array of every combination as a flat object.
export function cartesianProduct(
  dims: Record<string, string[]>
): Record<string, string>[] {
  const keys = Object.keys(dims);
  if (keys.length === 0) return [{}];

  let result: Record<string, string>[] = [{}];

  for (const key of keys) {
    const values = dims[key];
    const next: Record<string, string>[] = [];
    for (const existing of result) {
      for (const value of values) {
        next.push({ ...existing, [key]: value });
      }
    }
    result = next;
  }

  return result;
}

// Check whether a combination matches all key/value pairs in a rule.
function matchesRule(
  combo: Record<string, string>,
  rule: Record<string, string>
): boolean {
  return Object.entries(rule).every(([k, v]) => combo[k] === v);
}

// Determine how many total jobs the matrix will run:
// - Start with Cartesian product
// - Remove excluded combos
// - For each include: if it matches an existing combo (on dimension keys only),
//   it's an augmentation (no new job); otherwise it's a new job.
function countEffectiveCombinations(
  baseCombos: Record<string, string>[],
  includes: Record<string, string>[],
  dimensionKeys: string[]
): number {
  let count = baseCombos.length;

  for (const include of includes) {
    // Extract only the dimension keys from this include entry
    const dimPart = Object.fromEntries(
      dimensionKeys
        .filter((k) => include[k] !== undefined)
        .map((k) => [k, include[k]])
    );

    // If dimPart is non-empty, check if it matches any existing combo
    const isAugmentation =
      Object.keys(dimPart).length > 0 &&
      baseCombos.some((combo) => matchesRule(combo, dimPart));

    if (!isAugmentation) {
      count++;
    }
  }

  return count;
}

export function generateMatrix(config: MatrixConfig): MatrixOutput {
  const { dimensions, include, exclude, maxParallel, failFast, maxSize } =
    config;

  const limit = maxSize ?? DEFAULT_MAX_SIZE;
  const dimensionKeys = Object.keys(dimensions);

  // Build the base matrix from the Cartesian product
  let baseCombos =
    dimensionKeys.length === 0 ? [] : cartesianProduct(dimensions);

  // Apply exclude rules
  if (exclude && exclude.length > 0) {
    baseCombos = baseCombos.filter(
      (combo) => !exclude.some((rule) => matchesRule(combo, rule))
    );
  }

  // Count total effective combinations (base + any new jobs from includes)
  const totalCombinations = countEffectiveCombinations(
    baseCombos,
    include ?? [],
    dimensionKeys
  );

  // Build the GHA matrix object
  const matrix: GHAMatrix = { ...dimensions };
  if (include && include.length > 0) {
    matrix.include = include;
  }
  if (exclude && exclude.length > 0) {
    matrix.exclude = exclude;
  }

  // Validate against max size
  const errors: string[] = [];
  if (totalCombinations > limit) {
    errors.push(
      `Matrix has ${totalCombinations} combinations, exceeding max-size of ${limit}`
    );
  }

  const output: MatrixOutput = {
    matrix,
    combinations: totalCombinations,
    valid: errors.length === 0,
  };

  if (maxParallel !== undefined) output.maxParallel = maxParallel;
  if (failFast !== undefined) output.failFast = failFast;
  if (errors.length > 0) output.errors = errors;

  return output;
}

// CLI entry point: bun run matrix-generator.ts <config-file.json>
async function main() {
  const args = process.argv.slice(2);
  if (args.length === 0) {
    console.error("Usage: bun run matrix-generator.ts <config-file.json>");
    process.exit(1);
  }

  const configPath = args[0];
  let config: MatrixConfig;

  try {
    const raw = await Bun.file(configPath).text();
    config = JSON.parse(raw) as MatrixConfig;
  } catch (err) {
    console.error(`Failed to read config file '${configPath}': ${err}`);
    process.exit(1);
  }

  const result = generateMatrix(config);
  console.log(JSON.stringify(result, null, 2));

  if (!result.valid) {
    console.error(`Matrix validation failed: ${result.errors?.join(", ")}`);
    process.exit(1);
  }
}

// Run CLI when invoked directly (not imported as a module)
if (import.meta.main) {
  main();
}
