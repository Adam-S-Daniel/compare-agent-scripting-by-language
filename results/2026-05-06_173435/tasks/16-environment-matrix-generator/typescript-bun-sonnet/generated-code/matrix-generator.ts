// matrix-generator.ts
// Environment Matrix Generator for GitHub Actions strategy.matrix
// Usage: bun run matrix-generator.ts --config <config.json>

import { readFileSync } from "fs";

// ─── Types ────────────────────────────────────────────────────────────────────

export interface MatrixConfig {
  os: string[];
  languageVersions: Record<string, string[]>;
  featureFlags?: Record<string, boolean[]>;
  /** Extra entries to add (or merge into existing matching entries) */
  include?: Record<string, string | boolean>[];
  /** Entries matching ALL specified fields are removed */
  exclude?: Record<string, string | boolean>[];
  maxParallel?: number;
  failFast?: boolean;
  /** Max entries allowed; defaults to 256 (GitHub Actions limit) */
  maxSize?: number;
}

export interface MatrixEntry {
  os: string;
  [key: string]: string | boolean;
}

export interface MatrixOutput {
  matrix: { include: MatrixEntry[] };
  "fail-fast": boolean;
  "max-parallel"?: number;
}

// ─── Core logic ───────────────────────────────────────────────────────────────

/** Compute cartesian product of all dimension values. */
function cartesian(
  dimensions: Record<string, (string | boolean)[]>
): Record<string, string | boolean>[] {
  const keys = Object.keys(dimensions);
  if (keys.length === 0) return [{}];

  let result: Record<string, string | boolean>[] = [{}];
  for (const key of keys) {
    const expanded: Record<string, string | boolean>[] = [];
    for (const existing of result) {
      for (const value of dimensions[key]) {
        expanded.push({ ...existing, [key]: value });
      }
    }
    result = expanded;
  }
  return result;
}

/** Returns true if every field in `pattern` equals the corresponding field in `entry`. */
function matchesPattern(
  entry: Record<string, string | boolean>,
  pattern: Record<string, string | boolean>
): boolean {
  return Object.entries(pattern).every(([k, v]) => entry[k] === v);
}

export function generateMatrix(config: MatrixConfig): MatrixOutput {
  const maxSize = config.maxSize ?? 256;

  // Build the dimension map: os + all language version keys + optional feature flags
  const dimensions: Record<string, (string | boolean)[]> = {
    os: config.os,
    ...config.languageVersions,
    ...(config.featureFlags ?? {}),
  };

  // Start with the full cartesian product
  let entries = cartesian(dimensions) as MatrixEntry[];

  // Apply exclude rules — remove any entry that matches every field in an exclude pattern
  if (config.exclude && config.exclude.length > 0) {
    entries = entries.filter(
      (e) =>
        !config.exclude!.some((pattern) =>
          matchesPattern(e as Record<string, string | boolean>, pattern)
        )
    );
  }

  // Apply include rules — merge into existing matching entries or add new ones.
  // Matching is done on the base dimension keys only (os + languageVersions + featureFlags),
  // so that extra/additional fields in an include entry don't prevent a match.
  const baseKeys = new Set<string>([
    "os",
    ...Object.keys(config.languageVersions),
    ...Object.keys(config.featureFlags ?? {}),
  ]);

  if (config.include && config.include.length > 0) {
    for (const inc of config.include) {
      const baseFields = Object.fromEntries(
        Object.entries(inc).filter(([k]) => baseKeys.has(k))
      );
      const match =
        Object.keys(baseFields).length > 0
          ? entries.find((e) =>
              matchesPattern(e as Record<string, string | boolean>, baseFields)
            )
          : undefined;

      if (match) {
        // Merge all fields (including extras) into the existing entry
        Object.assign(match, inc);
      } else {
        entries.push(inc as MatrixEntry);
      }
    }
  }

  // Validate matrix size
  if (entries.length > maxSize) {
    throw new Error(
      `Matrix size ${entries.length} exceeds maximum allowed size of ${maxSize}`
    );
  }

  const output: MatrixOutput = {
    matrix: { include: entries },
    "fail-fast": config.failFast ?? true,
  };

  if (config.maxParallel !== undefined) {
    output["max-parallel"] = config.maxParallel;
  }

  return output;
}

// ─── CLI entry point ──────────────────────────────────────────────────────────

if (import.meta.main) {
  const args = process.argv.slice(2);
  const configIdx = args.indexOf("--config");
  const configPath = configIdx !== -1 ? args[configIdx + 1] : args[0];

  if (!configPath) {
    console.error("Usage: bun run matrix-generator.ts --config <config.json>");
    process.exit(1);
  }

  let raw: string;
  try {
    raw = readFileSync(configPath, "utf-8");
  } catch {
    console.error(`Error: cannot read config file: ${configPath}`);
    process.exit(1);
  }

  let config: MatrixConfig;
  try {
    config = JSON.parse(raw) as MatrixConfig;
  } catch {
    console.error("Error: config file is not valid JSON");
    process.exit(1);
  }

  try {
    const result = generateMatrix(config);
    console.log(JSON.stringify(result, null, 2));
  } catch (err) {
    console.error(`Error: ${(err as Error).message}`);
    process.exit(1);
  }
}
