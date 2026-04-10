/**
 * Environment Matrix Generator for GitHub Actions
 *
 * Generates a build matrix (JSON) suitable for GitHub Actions strategy.matrix.
 * Supports:
 *   - Cartesian product of OS, language versions, and feature flags
 *   - include/exclude rules to add or remove specific combinations
 *   - max-parallel limits
 *   - fail-fast configuration
 *   - Matrix size validation (GitHub Actions limit: 256 combinations)
 */

// --- Types & Interfaces ---

/** A single dimension in the matrix (e.g., os, node-version, feature-flag) */
export interface MatrixDimension {
  name: string;
  values: string[];
}

/** A partial combination used in include/exclude rules */
export interface MatrixEntry {
  [key: string]: string;
}

/** Include rule: adds a specific combination (may extend with extra keys) */
export interface IncludeRule {
  /** Key-value pairs defining the combination to include */
  [key: string]: string;
}

/** Exclude rule: removes matching combinations from the cartesian product */
export interface ExcludeRule {
  /** Key-value pairs that must all match for exclusion */
  [key: string]: string;
}

/** Top-level configuration for the matrix generator */
export interface MatrixConfig {
  /** Dimensions to form the cartesian product */
  dimensions: MatrixDimension[];
  /** Combinations to explicitly include (added after cartesian product) */
  include?: IncludeRule[];
  /** Combinations to exclude from the cartesian product */
  exclude?: ExcludeRule[];
  /** Maximum parallel jobs (optional) */
  "max-parallel"?: number;
  /** Whether to cancel all jobs on first failure (default: true) */
  "fail-fast"?: boolean;
  /** Maximum allowed matrix size (default: 256, GitHub Actions limit) */
  "max-size"?: number;
}

/** The output format matching GitHub Actions strategy.matrix */
export interface MatrixOutput {
  matrix: {
    [key: string]: string[];
    include?: MatrixEntry[];
    exclude?: MatrixEntry[];
  };
  "fail-fast"?: boolean;
  "max-parallel"?: number;
}

/** Fully expanded output with all combinations listed */
export interface ExpandedMatrixOutput {
  /** All individual combinations after include/exclude processing */
  combinations: MatrixEntry[];
  /** The GitHub Actions strategy block */
  strategy: MatrixOutput;
  /** Total number of jobs */
  "total-jobs": number;
}

// --- Core Logic ---

/**
 * Compute the cartesian product of multiple arrays.
 * Returns an array of objects with dimension names as keys.
 */
export function cartesianProduct(dimensions: MatrixDimension[]): MatrixEntry[] {
  if (dimensions.length === 0) return [{}];

  // Validate no empty dimensions
  for (const dim of dimensions) {
    if (dim.values.length === 0) {
      throw new Error(`Dimension "${dim.name}" has no values`);
    }
  }

  let result: MatrixEntry[] = [{}];
  for (const dim of dimensions) {
    const next: MatrixEntry[] = [];
    for (const entry of result) {
      for (const val of dim.values) {
        next.push({ ...entry, [dim.name]: val });
      }
    }
    result = next;
  }
  return result;
}

/**
 * Check if an entry matches all key-value pairs in a rule.
 */
export function matchesRule(entry: MatrixEntry, rule: MatrixEntry): boolean {
  return Object.entries(rule).every(([key, value]) => entry[key] === value);
}

/**
 * Apply exclude rules: remove any combination matching all keys in any exclude rule.
 */
export function applyExcludes(
  combinations: MatrixEntry[],
  excludes: ExcludeRule[]
): MatrixEntry[] {
  if (!excludes || excludes.length === 0) return combinations;
  return combinations.filter(
    (entry) => !excludes.some((rule) => matchesRule(entry, rule))
  );
}

/**
 * Apply include rules: add combinations that are explicitly included.
 * If an include matches an existing combination (on shared keys), it extends it.
 * Otherwise it adds a new combination.
 */
export function applyIncludes(
  combinations: MatrixEntry[],
  includes: IncludeRule[],
  dimensionNames: string[]
): MatrixEntry[] {
  if (!includes || includes.length === 0) return combinations;

  const result = [...combinations];
  for (const rule of includes) {
    // Check if any existing combination matches on all dimension keys present in the rule
    const sharedKeys = dimensionNames.filter((k) => k in rule);
    let matched = false;

    if (sharedKeys.length > 0) {
      for (let i = 0; i < result.length; i++) {
        if (sharedKeys.every((k) => result[i][k] === rule[k])) {
          // Extend the existing combination with extra keys from the rule
          result[i] = { ...result[i], ...rule };
          matched = true;
        }
      }
    }

    if (!matched) {
      // Add as a new combination
      result.push({ ...rule });
    }
  }
  return result;
}

/**
 * Validate the matrix configuration.
 */
export function validateConfig(config: MatrixConfig): void {
  if (!config.dimensions || !Array.isArray(config.dimensions)) {
    throw new Error("Config must have a 'dimensions' array");
  }

  if (config.dimensions.length === 0) {
    throw new Error("Config must have at least one dimension");
  }

  // Check for duplicate dimension names
  const names = config.dimensions.map((d) => d.name);
  const uniqueNames = new Set(names);
  if (uniqueNames.size !== names.length) {
    throw new Error("Duplicate dimension names are not allowed");
  }

  // Validate dimension values
  for (const dim of config.dimensions) {
    if (!dim.name || typeof dim.name !== "string") {
      throw new Error("Each dimension must have a non-empty string 'name'");
    }
    if (!Array.isArray(dim.values)) {
      throw new Error(`Dimension "${dim.name}" must have a 'values' array`);
    }
  }

  // Validate max-parallel
  if (config["max-parallel"] !== undefined) {
    if (
      typeof config["max-parallel"] !== "number" ||
      config["max-parallel"] < 1 ||
      !Number.isInteger(config["max-parallel"])
    ) {
      throw new Error("'max-parallel' must be a positive integer");
    }
  }

  // Validate max-size
  if (config["max-size"] !== undefined) {
    if (
      typeof config["max-size"] !== "number" ||
      config["max-size"] < 1 ||
      !Number.isInteger(config["max-size"])
    ) {
      throw new Error("'max-size' must be a positive integer");
    }
  }
}

/**
 * Main entry point: generate the matrix from configuration.
 */
export function generateMatrix(config: MatrixConfig): ExpandedMatrixOutput {
  // Validate input
  validateConfig(config);

  const maxSize = config["max-size"] ?? 256;
  const dimensionNames = config.dimensions.map((d) => d.name);

  // Step 1: Compute cartesian product
  let combinations = cartesianProduct(config.dimensions);

  // Step 2: Apply excludes
  combinations = applyExcludes(combinations, config.exclude ?? []);

  // Step 3: Apply includes
  combinations = applyIncludes(
    combinations,
    config.include ?? [],
    dimensionNames
  );

  // Step 4: Validate size
  if (combinations.length > maxSize) {
    throw new Error(
      `Matrix size ${combinations.length} exceeds maximum allowed size of ${maxSize}`
    );
  }

  if (combinations.length === 0) {
    throw new Error(
      "Matrix is empty after applying include/exclude rules"
    );
  }

  // Build the GitHub Actions strategy output
  const matrixBlock: MatrixOutput["matrix"] = {} as any;
  for (const dim of config.dimensions) {
    (matrixBlock as any)[dim.name] = dim.values;
  }
  if (config.exclude && config.exclude.length > 0) {
    (matrixBlock as any).exclude = config.exclude;
  }
  if (config.include && config.include.length > 0) {
    (matrixBlock as any).include = config.include;
  }

  const strategy: MatrixOutput = { matrix: matrixBlock };
  if (config["fail-fast"] !== undefined) {
    strategy["fail-fast"] = config["fail-fast"];
  }
  if (config["max-parallel"] !== undefined) {
    strategy["max-parallel"] = config["max-parallel"];
  }

  return {
    combinations,
    strategy,
    "total-jobs": combinations.length,
  };
}

// --- CLI entry point ---
// When run directly, reads a config JSON file and outputs the matrix
if (import.meta.main) {
  const args = Bun.argv.slice(2);

  if (args.length === 0) {
    // Read from stdin
    const input = await Bun.stdin.text();
    try {
      const config: MatrixConfig = JSON.parse(input);
      const result = generateMatrix(config);
      console.log(JSON.stringify(result, null, 2));
    } catch (err: any) {
      console.error(`ERROR: ${err.message}`);
      process.exit(1);
    }
  } else {
    // Read from file
    const filePath = args[0];
    try {
      const file = Bun.file(filePath);
      const text = await file.text();
      const config: MatrixConfig = JSON.parse(text);
      const result = generateMatrix(config);
      console.log(JSON.stringify(result, null, 2));
    } catch (err: any) {
      console.error(`ERROR: ${err.message}`);
      process.exit(1);
    }
  }
}
