// Environment matrix generator for GitHub Actions strategy.matrix.
// Given a config with axes (os/node/feature flags), include/exclude rules,
// and limits, produce a matrix JSON object suitable for GitHub Actions.

export interface MatrixConfig {
  // Arbitrary named axes. Each axis has an array of values.
  axes: Record<string, (string | number | boolean)[]>;
  include?: Record<string, string | number | boolean>[];
  exclude?: Record<string, string | number | boolean>[];
  maxParallel?: number;
  failFast?: boolean;
  maxSize?: number; // maximum allowed combinations after include/exclude
}

export interface GeneratedMatrix {
  matrix: Record<string, unknown> & {
    include?: Record<string, unknown>[];
    exclude?: Record<string, unknown>[];
  };
  "max-parallel"?: number;
  "fail-fast"?: boolean;
  combinations: Record<string, unknown>[]; // effective combos after processing
}

// Compute cartesian product of axis values.
function cartesian(
  axes: Record<string, (string | number | boolean)[]>,
): Record<string, string | number | boolean>[] {
  const keys = Object.keys(axes);
  if (keys.length === 0) return [];
  let result: Record<string, string | number | boolean>[] = [{}];
  for (const key of keys) {
    const values = axes[key];
    if (!values || values.length === 0) {
      throw new Error(`Axis "${key}" must have at least one value`);
    }
    const next: Record<string, string | number | boolean>[] = [];
    for (const combo of result) {
      for (const v of values) {
        next.push({ ...combo, [key]: v });
      }
    }
    result = next;
  }
  return result;
}

// An exclude entry matches a combo if every key in the exclude pattern
// equals the corresponding value in the combo. Extra combo keys are ignored.
function matches(
  combo: Record<string, unknown>,
  pattern: Record<string, unknown>,
): boolean {
  for (const [k, v] of Object.entries(pattern)) {
    if (combo[k] !== v) return false;
  }
  return true;
}

export function generateMatrix(config: MatrixConfig): GeneratedMatrix {
  if (!config || typeof config !== "object") {
    throw new Error("config must be an object");
  }
  if (!config.axes || Object.keys(config.axes).length === 0) {
    throw new Error("config.axes must have at least one axis");
  }

  // Base combinations from cartesian product.
  let combos = cartesian(config.axes);

  // Apply excludes first (GitHub Actions semantics: excludes then includes).
  if (config.exclude && config.exclude.length > 0) {
    combos = combos.filter(
      (c) => !config.exclude!.some((pat) => matches(c, pat)),
    );
  }

  // Apply includes. An include that extends an existing combo (some keys match
  // existing axis values, adds new fields) attaches the new fields. Otherwise
  // it's a standalone entry added to the combinations.
  const axisKeys = new Set(Object.keys(config.axes));
  if (config.include && config.include.length > 0) {
    for (const inc of config.include) {
      const incAxisPart: Record<string, unknown> = {};
      const incExtraPart: Record<string, unknown> = {};
      for (const [k, v] of Object.entries(inc)) {
        if (axisKeys.has(k)) incAxisPart[k] = v;
        else incExtraPart[k] = v;
      }
      // Does include reference ONLY existing axis values of an existing combo?
      let extended = false;
      if (Object.keys(incAxisPart).length > 0) {
        for (const combo of combos) {
          if (matches(combo, incAxisPart)) {
            Object.assign(combo, incExtraPart);
            extended = true;
          }
        }
      }
      if (!extended) {
        combos.push({ ...inc });
      }
    }
  }

  if (config.maxSize !== undefined && combos.length > config.maxSize) {
    throw new Error(
      `Matrix size ${combos.length} exceeds maximum allowed ${config.maxSize}`,
    );
  }

  if (combos.length === 0) {
    throw new Error("Matrix is empty after applying include/exclude rules");
  }

  if (
    config.maxParallel !== undefined &&
    (!Number.isInteger(config.maxParallel) || config.maxParallel < 1)
  ) {
    throw new Error("maxParallel must be a positive integer");
  }

  // Build the strategy.matrix object: keep original axes, add include/exclude
  // so GitHub Actions can reconstruct identical semantics.
  const matrixObj: Record<string, unknown> = { ...config.axes };
  if (config.include && config.include.length > 0) {
    matrixObj.include = config.include;
  }
  if (config.exclude && config.exclude.length > 0) {
    matrixObj.exclude = config.exclude;
  }

  const out: GeneratedMatrix = {
    matrix: matrixObj as GeneratedMatrix["matrix"],
    combinations: combos,
  };
  if (config.maxParallel !== undefined) out["max-parallel"] = config.maxParallel;
  if (config.failFast !== undefined) out["fail-fast"] = config.failFast;
  return out;
}
