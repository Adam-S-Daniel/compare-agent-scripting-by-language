// matrix.ts
//
// Generate a GitHub Actions strategy.matrix from a higher-level config that
// describes OS options, language versions, and feature flags. Supports:
//
//   - Cartesian product of all axes (os x each language version axis x flags)
//   - `include` rules (passed through; counted toward total job count when
//     they specify all axis keys and don't already match an existing combo)
//   - `exclude` rules (combos matching ANY exclude rule are removed)
//   - max-parallel and fail-fast strategy options (passed through verbatim)
//   - maxSize validation (throws MatrixSizeError if exceeded)
//
// Two ways to use it:
//
//   1. As a library:
//        import { generateMatrix } from "./matrix";
//        const result = generateMatrix(config);
//
//   2. As a CLI:
//        bun run matrix.ts --input config.json [--output out.json]
//      Prints the result wrapped in BEGIN/END markers so calling scripts can
//      reliably extract just the JSON.

import { readFileSync, writeFileSync } from "node:fs";

// -------------------------- Types --------------------------

/**
 * `unknown` is used for include/exclude values because GitHub allows any
 * scalar (string, number, boolean) and we should pass them through unchanged.
 */
export type ScalarValue = string | number | boolean;
export type Combination = Record<string, ScalarValue>;
export type Rule = Record<string, ScalarValue>;

export interface MatrixConfig {
  /** OS axis. Required, non-empty. */
  os: string[];
  /** Language version axes, e.g. { node: ["18", "20"], python: ["3.11"] }. */
  languageVersions?: Record<string, string[]>;
  /** Feature flag axis. Becomes a `featureFlag` key in the matrix. */
  featureFlags?: string[];
  /** Combinations to remove from the cartesian product. */
  exclude?: Rule[];
  /** Extra combinations or augmentations (GitHub Actions semantics). */
  include?: Rule[];
  /** Maps to strategy.max-parallel. */
  maxParallel?: number;
  /** Maps to strategy.fail-fast. */
  failFast?: boolean;
  /** Hard cap on total job count; exceeding this throws MatrixSizeError. */
  maxSize?: number;
}

/**
 * The generator's return value. `strategy` is structured so it can be
 * dropped directly into a workflow's `strategy:` block. `size` is the
 * computed final job count (cartesian - excludes + new includes), and
 * `axes` echoes back the resolved axes for diagnostics.
 */
export interface MatrixResult {
  strategy: {
    matrix: Record<string, ScalarValue[] | Rule[]>;
    "max-parallel"?: number;
    "fail-fast"?: boolean;
  };
  size: number;
  axes: string[];
}

// -------------------------- Errors --------------------------

export class MatrixValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "MatrixValidationError";
  }
}

export class MatrixSizeError extends Error {
  constructor(public readonly actualSize: number, public readonly maxSize: number) {
    super(`Matrix size ${actualSize} exceeds maximum allowed size ${maxSize}`);
    this.name = "MatrixSizeError";
  }
}

// -------------------------- Validation --------------------------

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return (
    typeof value === "object" &&
    value !== null &&
    !Array.isArray(value) &&
    Object.getPrototypeOf(value) === Object.prototype
  );
}

function isScalar(value: unknown): value is ScalarValue {
  return (
    typeof value === "string" ||
    typeof value === "number" ||
    typeof value === "boolean"
  );
}

function validateConfig(raw: unknown): MatrixConfig {
  if (!isPlainObject(raw)) {
    throw new MatrixValidationError("Config must be a JSON object");
  }

  const cfg = raw as Record<string, unknown>;

  if (!Array.isArray(cfg.os) || cfg.os.length === 0) {
    throw new MatrixValidationError("Config.os must be a non-empty array of strings");
  }
  for (const v of cfg.os) {
    if (typeof v !== "string" || v.length === 0) {
      throw new MatrixValidationError("Config.os entries must be non-empty strings");
    }
  }

  if (cfg.languageVersions !== undefined) {
    if (!isPlainObject(cfg.languageVersions)) {
      throw new MatrixValidationError("Config.languageVersions must be an object");
    }
    for (const [lang, versions] of Object.entries(cfg.languageVersions)) {
      if (lang === "os" || lang === "include" || lang === "exclude" || lang === "featureFlag") {
        throw new MatrixValidationError(
          `languageVersions key "${lang}" collides with reserved matrix axis`,
        );
      }
      if (!Array.isArray(versions) || versions.length === 0) {
        throw new MatrixValidationError(
          `languageVersions["${lang}"] must be a non-empty array`,
        );
      }
      for (const ver of versions) {
        if (typeof ver !== "string" || ver.length === 0) {
          throw new MatrixValidationError(
            `languageVersions["${lang}"] entries must be non-empty strings`,
          );
        }
      }
    }
  }

  if (cfg.featureFlags !== undefined) {
    if (!Array.isArray(cfg.featureFlags)) {
      throw new MatrixValidationError("Config.featureFlags must be an array of strings");
    }
    for (const f of cfg.featureFlags) {
      if (typeof f !== "string" || f.length === 0) {
        throw new MatrixValidationError("featureFlags entries must be non-empty strings");
      }
    }
  }

  for (const ruleField of ["include", "exclude"] as const) {
    const v = cfg[ruleField];
    if (v === undefined) continue;
    if (!Array.isArray(v)) {
      throw new MatrixValidationError(`Config.${ruleField} must be an array of objects`);
    }
    for (const rule of v) {
      if (!isPlainObject(rule)) {
        throw new MatrixValidationError(
          `Config.${ruleField} entries must be objects`,
        );
      }
      for (const [k, val] of Object.entries(rule)) {
        if (!isScalar(val)) {
          throw new MatrixValidationError(
            `Config.${ruleField} entry key "${k}" must be a scalar (string/number/boolean)`,
          );
        }
      }
    }
  }

  if (cfg.maxParallel !== undefined) {
    if (
      typeof cfg.maxParallel !== "number" ||
      !Number.isInteger(cfg.maxParallel) ||
      cfg.maxParallel < 1
    ) {
      throw new MatrixValidationError("maxParallel must be a positive integer");
    }
  }

  if (cfg.failFast !== undefined && typeof cfg.failFast !== "boolean") {
    throw new MatrixValidationError("failFast must be a boolean");
  }

  if (cfg.maxSize !== undefined) {
    if (
      typeof cfg.maxSize !== "number" ||
      !Number.isInteger(cfg.maxSize) ||
      cfg.maxSize < 1
    ) {
      throw new MatrixValidationError("maxSize must be a positive integer");
    }
  }

  return cfg as MatrixConfig;
}

// -------------------------- Core logic --------------------------

/** Build the cartesian product of all axes, in stable insertion order. */
function cartesianProduct(axes: Record<string, ScalarValue[]>): Combination[] {
  const keys = Object.keys(axes);
  let acc: Combination[] = [{}];
  for (const k of keys) {
    const next: Combination[] = [];
    const values = axes[k]!;
    for (const partial of acc) {
      for (const v of values) {
        next.push({ ...partial, [k]: v });
      }
    }
    acc = next;
  }
  return acc;
}

/** A combo "matches" a rule when every key in the rule equals the combo's value. */
function comboMatchesRule(combo: Combination, rule: Rule): boolean {
  for (const [k, v] of Object.entries(rule)) {
    if (combo[k] !== v) return false;
  }
  return true;
}

/**
 * Approximate GitHub Actions semantics for `include`:
 *  - If an include entry's keys are NOT a subset of axis keys, it can only
 *    augment matching combos; it doesn't add a new job.
 *  - If an include entry's keys ARE a subset of axis keys but it doesn't
 *    pin every axis, it augments any combo whose axis values match (no new
 *    job — these are extra columns on existing combos).
 *  - If an include entry pins every axis, it creates a new combo unless
 *    that exact combo already exists.
 *
 * Returns the count of NEW combos contributed by includes.
 */
function countNewIncludes(
  axes: Record<string, ScalarValue[]>,
  postExclude: Combination[],
  includes: Rule[],
): number {
  const axisKeys = Object.keys(axes);
  let added = 0;
  for (const inc of includes) {
    const incKeys = Object.keys(inc);
    const allInAxes = incKeys.every((k) => axisKeys.includes(k));
    if (!allInAxes) continue; // pure augmentation, never a new job
    if (incKeys.length < axisKeys.length) continue; // partial pin → augmentation
    const exists = postExclude.some(
      (combo) =>
        axisKeys.every((k) => combo[k] === inc[k]),
    );
    if (!exists) added++;
  }
  return added;
}

/**
 * Generate the matrix. Throws MatrixValidationError for malformed input
 * and MatrixSizeError when maxSize is exceeded.
 */
export function generateMatrix(rawConfig: unknown): MatrixResult {
  const config = validateConfig(rawConfig);

  // Build axes in a deterministic order: os first, language versions next,
  // featureFlag last. This affects the cartesian iteration order but not
  // the final job count.
  const axes: Record<string, ScalarValue[]> = { os: [...config.os] };
  if (config.languageVersions) {
    for (const [lang, versions] of Object.entries(config.languageVersions)) {
      axes[lang] = [...versions];
    }
  }
  if (config.featureFlags && config.featureFlags.length > 0) {
    axes.featureFlag = [...config.featureFlags];
  }

  const allCombos = cartesianProduct(axes);

  const excludes = config.exclude ?? [];
  const postExclude = excludes.length
    ? allCombos.filter(
        (combo) => !excludes.some((rule) => comboMatchesRule(combo, rule)),
      )
    : allCombos;

  const includes = config.include ?? [];
  const newFromIncludes = countNewIncludes(axes, postExclude, includes);

  const size = postExclude.length + newFromIncludes;

  if (config.maxSize !== undefined && size > config.maxSize) {
    throw new MatrixSizeError(size, config.maxSize);
  }

  // Build the strategy.matrix output. Axes go in as arrays; include/exclude
  // pass through verbatim so they retain GitHub's full semantics in the
  // generated workflow.
  const matrix: Record<string, ScalarValue[] | Rule[]> = {};
  for (const [k, v] of Object.entries(axes)) {
    matrix[k] = v;
  }
  if (includes.length > 0) matrix.include = includes;
  if (excludes.length > 0) matrix.exclude = excludes;

  const strategy: MatrixResult["strategy"] = { matrix };
  if (config.maxParallel !== undefined) strategy["max-parallel"] = config.maxParallel;
  if (config.failFast !== undefined) strategy["fail-fast"] = config.failFast;

  return {
    strategy,
    size,
    axes: Object.keys(axes),
  };
}

// -------------------------- CLI --------------------------

interface CliArgs {
  input: string;
  output?: string;
}

function parseArgs(argv: string[]): CliArgs {
  let input: string | undefined;
  let output: string | undefined;
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--input" || a === "-i") {
      input = argv[++i];
    } else if (a === "--output" || a === "-o") {
      output = argv[++i];
    } else if (a === "--help" || a === "-h") {
      console.log(
        "Usage: bun run matrix.ts --input <config.json> [--output <out.json>]",
      );
      process.exit(0);
    } else if (!a?.startsWith("-") && input === undefined) {
      input = a;
    }
  }
  if (!input) {
    throw new MatrixValidationError(
      "Missing --input: path to a config JSON file is required",
    );
  }
  return { input, output };
}

function main(): void {
  const args = parseArgs(process.argv.slice(2));
  const raw = readFileSync(args.input, "utf-8");
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    throw new MatrixValidationError(`Invalid JSON in ${args.input}: ${msg}`);
  }
  const result = generateMatrix(parsed);
  const json = JSON.stringify(result, null, 2);
  if (args.output) writeFileSync(args.output, json);
  console.log("=== MATRIX_OUTPUT_BEGIN ===");
  console.log(json);
  console.log("=== MATRIX_OUTPUT_END ===");
}

if (import.meta.main) {
  try {
    main();
  } catch (e) {
    if (e instanceof MatrixValidationError) {
      console.error(`VALIDATION_ERROR: ${e.message}`);
      process.exit(2);
    }
    if (e instanceof MatrixSizeError) {
      console.error(`SIZE_ERROR: ${e.message}`);
      process.exit(3);
    }
    const msg = e instanceof Error ? e.message : String(e);
    console.error(`UNEXPECTED_ERROR: ${msg}`);
    process.exit(99);
  }
}
