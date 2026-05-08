// GitHub Actions matrix generator with include/exclude rules,
// max-parallel, fail-fast, and size validation.

export type MatrixValue = string | number | boolean;
export type MatrixEntry = Record<string, MatrixValue>;

export interface MatrixConfig {
  axes: Record<string, MatrixValue[]>;
  include?: MatrixEntry[];
  exclude?: MatrixEntry[];
  maxParallel?: number;
  failFast?: boolean;
  maxSize?: number;
}

export interface MatrixOutput {
  include: MatrixEntry[];
  "max-parallel"?: number;
  "fail-fast"?: boolean;
}

// Cartesian product of axis values.
function cartesian(axes: Record<string, MatrixValue[]>): MatrixEntry[] {
  const keys = Object.keys(axes);
  let result: MatrixEntry[] = [{}];
  for (const key of keys) {
    const values = axes[key]!;
    const next: MatrixEntry[] = [];
    for (const entry of result) {
      for (const v of values) {
        next.push({ ...entry, [key]: v });
      }
    }
    result = next;
  }
  return result;
}

// Check whether `rule`'s keys are all present in `entry` with equal values.
function ruleMatches(rule: MatrixEntry, entry: MatrixEntry): boolean {
  for (const k of Object.keys(rule)) {
    if (!(k in entry) || entry[k] !== rule[k]) return false;
  }
  return true;
}

// Apply GitHub-Actions-style include semantics:
// - If the include entry has any key that is NOT in the original axes,
//   it can augment matching entries (where all original-axis keys match).
// - Otherwise the include is added as a new entry.
// (Simplified GHA behavior; sufficient for this task.)
function applyIncludes(
  base: MatrixEntry[],
  includes: MatrixEntry[],
  axisKeys: string[],
): MatrixEntry[] {
  const result = base.map((e) => ({ ...e }));
  for (const inc of includes) {
    const incAxisPart: MatrixEntry = {};
    const incExtraPart: MatrixEntry = {};
    for (const k of Object.keys(inc)) {
      if (axisKeys.includes(k)) incAxisPart[k] = inc[k]!;
      else incExtraPart[k] = inc[k]!;
    }

    // Try to augment matching base entries when there are extra keys.
    let augmented = false;
    if (Object.keys(incExtraPart).length > 0) {
      for (const entry of result) {
        if (ruleMatches(incAxisPart, entry)) {
          Object.assign(entry, incExtraPart);
          augmented = true;
        }
      }
    }
    // If no augmentation happened, add as a new entry.
    if (!augmented) {
      result.push({ ...inc });
    }
  }
  return result;
}

export function generateMatrix(config: MatrixConfig): MatrixOutput {
  const axisKeys = Object.keys(config.axes);
  if (axisKeys.length === 0) {
    throw new Error("Matrix must have at least one axis");
  }
  for (const k of axisKeys) {
    if (!config.axes[k] || config.axes[k]!.length === 0) {
      throw new Error(`Axis "${k}" is empty`);
    }
  }

  // 1. Build cartesian product.
  let entries = cartesian(config.axes);

  // 2. Apply excludes (must happen before includes per GHA semantics).
  if (config.exclude && config.exclude.length > 0) {
    entries = entries.filter(
      (e) => !config.exclude!.some((rule) => ruleMatches(rule, e)),
    );
  }

  // 3. Apply includes (augment or append).
  if (config.include && config.include.length > 0) {
    entries = applyIncludes(entries, config.include, axisKeys);
  }

  // 4. Validate size.
  if (config.maxSize !== undefined && entries.length > config.maxSize) {
    throw new Error(
      `Matrix size ${entries.length} exceeds maximum size ${config.maxSize}`,
    );
  }

  const out: MatrixOutput = { include: entries };
  if (config.maxParallel !== undefined) out["max-parallel"] = config.maxParallel;
  if (config.failFast !== undefined) out["fail-fast"] = config.failFast;
  return out;
}
