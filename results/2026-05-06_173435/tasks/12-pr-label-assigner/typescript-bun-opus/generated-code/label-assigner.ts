import type { LabelConfig, LabelResult, LabelRule } from "./types";

function globToRegex(pattern: string): RegExp {
  let result = "";
  let i = 0;
  while (i < pattern.length) {
    if (pattern[i] === "*" && pattern[i + 1] === "*" && pattern[i + 2] === "/") {
      result += "(.*/)?";
      i += 3;
    } else if (pattern[i] === "*" && pattern[i + 1] === "*") {
      result += ".*";
      i += 2;
    } else if (pattern[i] === "*") {
      result += "[^/]*";
      i += 1;
    } else if (pattern[i] === "?") {
      result += "[^/]";
      i += 1;
    } else if (".+^${}()|[]\\".includes(pattern[i])) {
      result += "\\" + pattern[i];
      i += 1;
    } else {
      result += pattern[i];
      i += 1;
    }
  }
  return new RegExp(`^${result}$`);
}

export function matchFile(filePath: string, pattern: string): boolean {
  const regex = globToRegex(pattern);
  return regex.test(filePath);
}

export function assignLabels(
  files: string[],
  config: LabelConfig
): LabelResult {
  if (!files || files.length === 0) {
    return { labels: [], fileMatches: {} };
  }

  if (!config || !config.rules || config.rules.length === 0) {
    throw new Error("Configuration must include at least one rule");
  }

  const sortedRules = [...config.rules].sort(
    (a, b) => b.priority - a.priority
  );

  const fileMatches: Record<string, string[]> = {};
  const allLabels = new Set<string>();

  for (const file of files) {
    const matchedLabels: string[] = [];

    for (const rule of sortedRules) {
      if (matchFile(file, rule.pattern) && !matchedLabels.includes(rule.label)) {
        matchedLabels.push(rule.label);
      }
    }

    if (matchedLabels.length > 0) {
      const limit = config.maxLabelsPerFile ?? matchedLabels.length;
      const limited = matchedLabels.slice(0, limit);
      fileMatches[file] = limited;
      for (const label of limited) {
        allLabels.add(label);
      }
    }
  }

  const labels = Array.from(allLabels).sort();
  return { labels, fileMatches };
}

if (import.meta.main) {
  const configPath = process.env.LABEL_CONFIG_PATH || "label-config.json";
  const filesEnv = process.env.CHANGED_FILES || "";

  if (!filesEnv) {
    console.error("Error: CHANGED_FILES environment variable is required");
    process.exit(1);
  }

  const files = filesEnv.split(",").map((f) => f.trim()).filter(Boolean);

  let config: LabelConfig;
  try {
    const configFile = await Bun.file(configPath).text();
    config = JSON.parse(configFile) as LabelConfig;
  } catch (e) {
    console.error(`Error: Failed to read config from ${configPath}: ${(e as Error).message}`);
    process.exit(1);
  }

  const result = assignLabels(files, config);

  console.log("=== PR Label Assignment Results ===");
  console.log(`LABELS: ${result.labels.join(",")}`);
  console.log("--- File Matches ---");
  for (const [file, labels] of Object.entries(result.fileMatches)) {
    console.log(`  ${file}: ${labels.join(", ")}`);
  }
  console.log("=== End Results ===");
}
