#!/usr/bin/env bun

/**
 * Environment Matrix Generator for GitHub Actions
 *
 * Generates a build matrix (strategy.matrix JSON) from a configuration
 * describing OS options, language versions, feature flags, and
 * include/exclude rules.
 */

// --- Type Definitions ---

/** A single dimension in the matrix (e.g., os, node-version, feature-flag) */
interface MatrixDimension {
  [key: string]: string[];
}

/** A single combination to include or exclude */
interface MatrixEntry {
  [key: string]: string | number | boolean;
}

/** Input configuration for the matrix generator */
interface MatrixConfig {
  /** Named dimensions — each key maps to an array of values */
  dimensions: MatrixDimension;
  /** Combinations to explicitly include (added to the Cartesian product) */
  include?: MatrixEntry[];
  /** Combinations to explicitly exclude (removed from the Cartesian product) */
  exclude?: MatrixEntry[];
  /** Maximum number of parallel jobs (optional) */
  "max-parallel"?: number;
  /** Whether to cancel all jobs if one fails (default: true) */
  "fail-fast"?: boolean;
  /** Maximum allowed matrix size — validation guard */
  "max-size"?: number;
}

/** Output format matching GitHub Actions strategy.matrix */
interface MatrixOutput {
  matrix: {
    include: MatrixEntry[];
  };
  "fail-fast"?: boolean;
  "max-parallel"?: number;
}

// --- Constants ---

/** Default maximum matrix size to prevent accidental combinatorial explosion */
const DEFAULT_MAX_SIZE = 256;

// --- Core Logic ---

/**
 * Validates the input configuration and throws descriptive errors.
 */
function validateConfig(config: MatrixConfig): void {
  if (!config) {
    throw new Error("Configuration is required");
  }

  if (!config.dimensions || typeof config.dimensions !== "object") {
    throw new Error("Configuration must include a 'dimensions' object");
  }

  const keys = Object.keys(config.dimensions);
  if (keys.length === 0) {
    throw new Error("At least one dimension is required");
  }

  for (const key of keys) {
    const values = config.dimensions[key];
    if (!Array.isArray(values)) {
      throw new Error(`Dimension '${key}' must be an array of values`);
    }
    if (values.length === 0) {
      throw new Error(`Dimension '${key}' must have at least one value`);
    }
  }

  if (config["max-parallel"] !== undefined) {
    if (
      typeof config["max-parallel"] !== "number" ||
      config["max-parallel"] < 1 ||
      !Number.isInteger(config["max-parallel"])
    ) {
      throw new Error("'max-parallel' must be a positive integer");
    }
  }

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
 * Computes the Cartesian product of all dimension value arrays.
 * Returns an array of combination objects.
 */
function cartesianProduct(dimensions: MatrixDimension): MatrixEntry[] {
  const keys = Object.keys(dimensions);
  if (keys.length === 0) return [];

  // Start with the first dimension
  let result: MatrixEntry[] = dimensions[keys[0]].map((v) => ({
    [keys[0]]: v,
  }));

  // Multiply in each subsequent dimension
  for (let i = 1; i < keys.length; i++) {
    const key = keys[i];
    const values = dimensions[key];
    const newResult: MatrixEntry[] = [];
    for (const existing of result) {
      for (const val of values) {
        newResult.push({ ...existing, [key]: val });
      }
    }
    result = newResult;
  }

  return result;
}

/**
 * Checks whether a candidate entry matches a pattern.
 * A pattern matches if every key in the pattern exists in
 * the candidate with the same value.
 */
function entryMatches(candidate: MatrixEntry, pattern: MatrixEntry): boolean {
  for (const key of Object.keys(pattern)) {
    if (String(candidate[key]) !== String(pattern[key])) {
      return false;
    }
  }
  return true;
}

/**
 * Checks if two entries are identical across all keys.
 */
function entriesEqual(a: MatrixEntry, b: MatrixEntry): boolean {
  const aKeys = Object.keys(a).sort();
  const bKeys = Object.keys(b).sort();
  if (aKeys.length !== bKeys.length) return false;
  for (let i = 0; i < aKeys.length; i++) {
    if (aKeys[i] !== bKeys[i]) return false;
    if (String(a[aKeys[i]]) !== String(b[bKeys[i]])) return false;
  }
  return true;
}

/**
 * Main generator function: takes a config and produces the matrix output.
 */
function generateMatrix(config: MatrixConfig): MatrixOutput {
  // Validate input
  validateConfig(config);

  const maxSize = config["max-size"] ?? DEFAULT_MAX_SIZE;

  // Step 1: compute Cartesian product of all dimensions
  let combinations = cartesianProduct(config.dimensions);

  // Step 2: apply exclude rules — remove matching combinations
  if (config.exclude && config.exclude.length > 0) {
    combinations = combinations.filter(
      (combo) => !config.exclude!.some((pattern) => entryMatches(combo, pattern))
    );
  }

  // Step 3: apply include rules — add extra combinations (no duplicates)
  if (config.include && config.include.length > 0) {
    for (const inc of config.include) {
      const alreadyExists = combinations.some((combo) =>
        entriesEqual(combo, inc)
      );
      if (!alreadyExists) {
        combinations.push(inc);
      }
    }
  }

  // Step 4: validate matrix size
  if (combinations.length > maxSize) {
    throw new Error(
      `Matrix size ${combinations.length} exceeds maximum allowed size of ${maxSize}`
    );
  }

  if (combinations.length === 0) {
    throw new Error(
      "Matrix is empty after applying exclude rules — no combinations remain"
    );
  }

  // Step 5: build the output
  const output: MatrixOutput = {
    matrix: {
      include: combinations,
    },
  };

  if (config["fail-fast"] !== undefined) {
    output["fail-fast"] = config["fail-fast"];
  }

  if (config["max-parallel"] !== undefined) {
    output["max-parallel"] = config["max-parallel"];
  }

  return output;
}

// --- CLI entry point ---

async function main(): Promise<void> {
  // Accept config from: CLI arg (file path), or stdin
  let configJson: string;

  const args = process.argv.slice(2);

  if (args.length > 0) {
    // Read config from file
    const filePath = args[0];
    try {
      const file = Bun.file(filePath);
      configJson = await file.text();
    } catch (err: any) {
      console.error(`Error reading config file '${filePath}': ${err.message}`);
      process.exit(1);
    }
  } else {
    // Read config from stdin
    configJson = await new Promise<string>((resolve) => {
      let data = "";
      process.stdin.on("data", (chunk: Buffer) => {
        data += chunk.toString();
      });
      process.stdin.on("end", () => resolve(data));
    });
  }

  if (!configJson.trim()) {
    console.error("Error: No configuration provided. Pass a file path or pipe JSON to stdin.");
    process.exit(1);
  }

  let config: MatrixConfig;
  try {
    config = JSON.parse(configJson);
  } catch {
    console.error("Error: Invalid JSON in configuration input");
    process.exit(1);
  }

  try {
    const result = generateMatrix(config);
    console.log(JSON.stringify(result, null, 2));
  } catch (err: any) {
    console.error(`Error: ${err.message}`);
    process.exit(1);
  }
}

main();

// Export for testing
export {
  generateMatrix,
  validateConfig,
  cartesianProduct,
  entryMatches,
  entriesEqual,
  DEFAULT_MAX_SIZE,
};
export type { MatrixConfig, MatrixOutput, MatrixEntry, MatrixDimension };
