// Matrix generator for GitHub Actions builds
// Supports OS, language versions, feature flags with include/exclude rules

interface MatrixConfig {
  os?: string[];
  nodeVersion?: string[];
  features?: string[];
  include?: Record<string, string>[];
  exclude?: Record<string, string>[];
  maxParallel?: number;
  failFast?: boolean;
  maxSize?: number;
}

interface MatrixOutput {
  include: Record<string, string>[];
  exclude?: Record<string, string>[];
  maxParallel?: number;
  failFast?: boolean;
}

export function generateMatrix(config: MatrixConfig): MatrixOutput {
  // Start with base combinations from OS, nodeVersion, features
  let combinations: Record<string, string>[] = [];

  // Collect all dimension names
  const dimensions: { name: string; values: string[] }[] = [];

  if (config.os) dimensions.push({ name: "os", values: config.os });
  if (config.nodeVersion)
    dimensions.push({ name: "nodeVersion", values: config.nodeVersion });
  if (config.features) dimensions.push({ name: "features", values: config.features });

  // Generate all combinations (Cartesian product)
  if (dimensions.length === 0) {
    combinations = [{}];
  } else {
    const cartesian = (arrays: string[][]): string[][] => {
      if (arrays.length === 0) return [[]];
      const [first, ...rest] = arrays;
      const recursed = cartesian(rest);
      return first.flatMap((x) => recursed.map((y) => [x, ...y]));
    };

    const values = dimensions.map((d) => d.values);
    const products = cartesian(values);

    combinations = products.map((product) => {
      const combo: Record<string, string> = {};
      product.forEach((val, i) => {
        combo[dimensions[i].name] = val;
      });
      return combo;
    });
  }

  // Apply excludes
  let excludes: Record<string, string>[] = [];
  if (config.exclude) {
    excludes = config.exclude;
    combinations = combinations.filter((combo) => {
      return !config.exclude!.some((exclude) =>
        Object.entries(exclude).every(([key, value]) => combo[key] === value)
      );
    });
  }

  // Check size limit
  if (config.maxSize && combinations.length > config.maxSize) {
    throw new Error(
      `Matrix size ${combinations.length} exceeds maxSize ${config.maxSize}`
    );
  }

  // Build output
  const result: MatrixOutput = {
    include: combinations,
  };

  // Add excludes to output if present
  if (excludes.length > 0) {
    result.exclude = excludes;
  }

  // Add include overrides if provided
  if (config.include && config.include.length > 0) {
    result.include.push(...config.include);
  }

  // Add optional config
  if (config.maxParallel !== undefined) {
    result.maxParallel = config.maxParallel;
  }

  if (config.failFast !== undefined) {
    result.failFast = config.failFast;
  }

  return result;
}
