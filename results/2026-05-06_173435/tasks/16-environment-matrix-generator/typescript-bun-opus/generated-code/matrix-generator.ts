import type { MatrixConfig, MatrixEntry, MatrixOutput } from "./types";
import { readFileSync } from "fs";

const DEFAULT_MAX_COMBINATIONS = 256;

function validateConfig(config: unknown): MatrixConfig {
  if (typeof config !== "object" || config === null) {
    throw new Error("Config must be a JSON object");
  }
  const c = config as Record<string, unknown>;
  if (!c.matrix || typeof c.matrix !== "object") {
    throw new Error("Config must have a 'matrix' object with at least one dimension");
  }
  const matrix = c.matrix as Record<string, unknown>;
  for (const [key, values] of Object.entries(matrix)) {
    if (!Array.isArray(values) || values.length === 0) {
      throw new Error(`Dimension '${key}' must be a non-empty array`);
    }
  }
  if (c.include !== undefined && !Array.isArray(c.include)) {
    throw new Error("'include' must be an array of objects");
  }
  if (c.exclude !== undefined && !Array.isArray(c.exclude)) {
    throw new Error("'exclude' must be an array of objects");
  }
  if (c["max-parallel"] !== undefined && (typeof c["max-parallel"] !== "number" || c["max-parallel"] < 1)) {
    throw new Error("'max-parallel' must be a positive integer");
  }
  if (c["max-combinations"] !== undefined && (typeof c["max-combinations"] !== "number" || c["max-combinations"] < 1)) {
    throw new Error("'max-combinations' must be a positive integer");
  }
  return config as MatrixConfig;
}

function cartesianProduct(matrix: Record<string, (string | number | boolean)[]>): MatrixEntry[] {
  const keys = Object.keys(matrix);
  if (keys.length === 0) return [{}];

  const result: MatrixEntry[] = [];
  const values = keys.map((k) => matrix[k]);

  function recurse(depth: number, current: MatrixEntry): void {
    if (depth === keys.length) {
      result.push({ ...current });
      return;
    }
    for (const val of values[depth]) {
      current[keys[depth]] = val;
      recurse(depth + 1, current);
    }
  }
  recurse(0, {});
  return result;
}

function matchesRule(entry: MatrixEntry, rule: Record<string, string | number | boolean>): boolean {
  return Object.entries(rule).every(([key, val]) => entry[key] === val);
}

function applyExcludes(combinations: MatrixEntry[], excludes: Record<string, string | number | boolean>[]): MatrixEntry[] {
  return combinations.filter((entry) => !excludes.some((rule) => matchesRule(entry, rule)));
}

function applyIncludes(
  combinations: MatrixEntry[],
  includes: Record<string, string | number | boolean>[],
  dimensionKeys: string[]
): MatrixEntry[] {
  const result = combinations.map((e) => ({ ...e }));

  for (const inc of includes) {
    const matchIdx = result.findIndex((entry) =>
      dimensionKeys.every((k) => !(k in inc) || entry[k] === inc[k])
    );

    const hasNewDimensionValue = dimensionKeys.some(
      (k) => k in inc && !combinations.some((e) => e[k] === inc[k])
    );

    if (hasNewDimensionValue || matchIdx === -1) {
      result.push({ ...inc });
    } else {
      Object.assign(result[matchIdx], inc);
    }
  }
  return result;
}

export function generateMatrix(config: MatrixConfig): MatrixOutput {
  const validated = validateConfig(config);
  const maxCombinations = validated["max-combinations"] ?? DEFAULT_MAX_COMBINATIONS;
  const dimensionKeys = Object.keys(validated.matrix);

  let combinations = cartesianProduct(validated.matrix);

  if (validated.exclude) {
    combinations = applyExcludes(combinations, validated.exclude);
  }

  if (validated.include) {
    combinations = applyIncludes(combinations, validated.include, dimensionKeys);
  }

  if (combinations.length > maxCombinations) {
    throw new Error(
      `Matrix produces ${combinations.length} combinations, exceeding limit of ${maxCombinations}`
    );
  }

  if (combinations.length === 0) {
    throw new Error("Matrix produces 0 combinations after applying include/exclude rules");
  }

  const dimensions: Record<string, number> = {};
  for (const key of dimensionKeys) {
    dimensions[key] = validated.matrix[key].length;
  }

  const output: MatrixOutput = {
    strategy: {
      "fail-fast": validated["fail-fast"] ?? true,
      matrix: {
        include: combinations,
      },
    },
    total_combinations: combinations.length,
    dimensions,
  };

  if (validated["max-parallel"] !== undefined) {
    output.strategy["max-parallel"] = validated["max-parallel"];
  }

  return output;
}

if (import.meta.main) {
  const args = process.argv.slice(2);
  if (args.length !== 1) {
    console.error("Usage: bun run matrix-generator.ts <config.json>");
    process.exit(1);
  }

  try {
    const raw = readFileSync(args[0], "utf-8");
    const config = JSON.parse(raw);
    const result = generateMatrix(config);
    console.log(JSON.stringify(result, null, 2));
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(`ERROR: ${msg}`);
    process.exit(1);
  }
}
