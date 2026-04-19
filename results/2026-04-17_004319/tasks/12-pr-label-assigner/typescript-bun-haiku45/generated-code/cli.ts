import { assignLabels, assignLabelsDetailed, LabelRule } from "./pr-label-assigner";

// Default label rules configuration
const DEFAULT_RULES: LabelRule[] = [
  { pattern: "docs/**", labels: ["documentation"], priority: 1 },
  { pattern: "src/api/**", labels: ["api"], priority: 2 },
  { pattern: "src/**", labels: ["code"], priority: 3 },
  { pattern: "*.test.*", labels: ["tests"], priority: 1 },
  { pattern: "*.test.ts", labels: ["tests"], priority: 1 },
  { pattern: "*.spec.*", labels: ["tests"], priority: 1 },
  { pattern: "tests/**", labels: ["tests"], priority: 1 },
  { pattern: "*.json", labels: ["configuration"], priority: 2 },
  { pattern: ".github/**", labels: ["ci"], priority: 2 },
  { pattern: "*.md", labels: ["documentation"], priority: 2 },
  { pattern: "*.yml", labels: ["configuration"], priority: 2 },
  { pattern: "*.yaml", labels: ["configuration"], priority: 2 },
];

interface CLIOptions {
  files?: string[];
  rulesFile?: string;
  detailed?: boolean;
}

// Parse command line arguments
function parseArgs(): CLIOptions {
  const args = process.argv.slice(2);
  const options: CLIOptions = {};

  let i = 0;
  while (i < args.length) {
    const arg = args[i];

    if (arg === "--files" && i + 1 < args.length) {
      options.files = args[i + 1].split(",").map((f) => f.trim());
      i += 2;
    } else if (arg === "--rules-file" && i + 1 < args.length) {
      options.rulesFile = args[i + 1];
      i += 2;
    } else if (arg === "--detailed") {
      options.detailed = true;
      i += 1;
    } else {
      i += 1;
    }
  }

  return options;
}

// Load custom rules from file if provided
async function loadRules(rulesPath?: string): Promise<LabelRule[]> {
  if (!rulesPath) {
    return DEFAULT_RULES;
  }

  try {
    const file = Bun.file(rulesPath);
    const content = await file.text();
    const rules = JSON.parse(content);

    if (!Array.isArray(rules)) {
      throw new Error("Rules file must contain a JSON array");
    }

    return rules;
  } catch (error) {
    console.error(`Error loading rules from ${rulesPath}:`, error);
    process.exit(1);
  }
}

// Main CLI function
async function main() {
  const options = parseArgs();

  // Get files from environment or CLI args
  const filesEnv = process.env.CHANGED_FILES;
  const files = options.files || (filesEnv ? filesEnv.split(",") : []);

  if (files.length === 0) {
    console.error("Error: No files provided. Use --files or CHANGED_FILES env var");
    process.exit(1);
  }

  // Load rules
  const rules = await loadRules(options.rulesFile);

  // Assign labels
  if (options.detailed) {
    const detailed = assignLabelsDetailed(files, rules);
    console.log(JSON.stringify(detailed, null, 2));
  } else {
    const labels = assignLabels(files, rules);
    console.log(JSON.stringify(labels));
  }
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
