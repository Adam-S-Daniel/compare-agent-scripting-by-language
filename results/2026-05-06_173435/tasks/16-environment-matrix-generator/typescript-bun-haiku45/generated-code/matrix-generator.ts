// Matrix Generator: Creates GitHub Actions build matrices from configuration
// Supports OS options, language versions, feature flags, include/exclude rules

export interface MatrixEntry {
  [key: string]: string;
}

export interface GitHubMatrix {
  include: MatrixEntry[];
  exclude?: MatrixEntry[];
  maxParallel?: number;
  failFast?: boolean;
}

export interface MatrixConfig {
  os: string[];
  language: string[];
  features?: string[];
  exclude?: MatrixEntry[];
  include?: MatrixEntry[];
  maxSize?: number;
  maxParallel: number;
  failFast: boolean;
}

export interface MatrixResult {
  matrix: GitHubMatrix;
  error?: string;
}

export function generateMatrix(config: MatrixConfig): MatrixResult {
  // Validate input
  if (!config.os || config.os.length === 0) {
    return { matrix: { include: [] }, error: "OS array is required and cannot be empty" };
  }
  if (!config.language || config.language.length === 0) {
    return { matrix: { include: [] }, error: "Language array is required and cannot be empty" };
  }

  // Step 1: Generate cartesian product of base dimensions
  const baseCombinations = createCartesianProduct(config);

  // Step 2: Add feature flags as additional dimension
  let allCombinations = baseCombinations;
  if (config.features && config.features.length > 0) {
    allCombinations = expandWithFeatures(baseCombinations, config.features);
  }

  // Step 3: Apply exclude rules
  if (config.exclude && config.exclude.length > 0) {
    allCombinations = applyExcludes(allCombinations, config.exclude);
  }

  // Step 4: Check matrix size limit
  const maxSize = config.maxSize || 256; // GitHub Actions default
  if (allCombinations.length > maxSize) {
    return {
      matrix: { include: allCombinations },
      error: `Matrix size ${allCombinations.length} exceeds maximum matrix size of ${maxSize}`,
    };
  }

  // Step 5: Add include rules (additional combinations)
  if (config.include && config.include.length > 0) {
    allCombinations = [...allCombinations, ...config.include];
  }

  // Step 6: Build final matrix with strategy configuration
  const matrix: GitHubMatrix = {
    include: allCombinations,
    maxParallel: config.maxParallel,
    failFast: config.failFast,
  };

  return { matrix };
}

// Create cartesian product of OS and language versions
function createCartesianProduct(config: MatrixConfig): MatrixEntry[] {
  const result: MatrixEntry[] = [];

  for (const os of config.os) {
    for (const language of config.language) {
      result.push({
        os,
        language,
      });
    }
  }

  return result;
}

// Expand combinations with feature flags
function expandWithFeatures(
  combinations: MatrixEntry[],
  features: string[]
): MatrixEntry[] {
  const result: MatrixEntry[] = [];

  for (const combo of combinations) {
    for (const feature of features) {
      result.push({
        ...combo,
        feature,
      });
    }
  }

  return result;
}

// Apply exclude rules to filter out unwanted combinations
function applyExcludes(
  combinations: MatrixEntry[],
  excludes: MatrixEntry[]
): MatrixEntry[] {
  return combinations.filter((combo) => {
    return !excludes.some((exclude) => {
      // Check if all exclude keys match in the combo
      return Object.keys(exclude).every((key) => combo[key] === exclude[key]);
    });
  });
}

// Main entry point: reads config from stdin and outputs matrix JSON
export async function main() {
  try {
    const input = await Bun.stdin.text();
    const config: MatrixConfig = JSON.parse(input);
    const result = generateMatrix(config);

    if (result.error) {
      console.error(`Error: ${result.error}`);
      process.exit(1);
    }

    console.log(JSON.stringify(result.matrix, null, 2));
  } catch (error) {
    console.error("Failed to generate matrix:", error);
    process.exit(1);
  }
}

// Run main if this file is executed directly
if (import.meta.main) {
  await main();
}
