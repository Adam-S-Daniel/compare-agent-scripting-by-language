/**
 * PR Label Assigner - CLI entry point
 *
 * Reads changed files from an environment variable or uses mock data,
 * applies configurable label rules, and outputs the resulting label set.
 *
 * Usage:
 *   bun run src/index.ts
 *   CHANGED_FILES="src/api/users.ts,docs/readme.md" bun run src/index.ts
 *   CHANGED_FILES="src/api/users.ts" RULES_FILE="rules.json" bun run src/index.ts
 */

import { assignLabels, type LabelRule } from "./labeler";
import { readFileSync, existsSync } from "fs";

// --- Default rules ---
const DEFAULT_RULES: LabelRule[] = [
  { pattern: "docs/**", label: "documentation", priority: 10 },
  { pattern: "*.md", label: "documentation", priority: 5 },
  { pattern: "src/api/auth/**", label: "security", priority: 35 },
  { pattern: "src/api/**", label: "api", priority: 20 },
  { pattern: "src/**", label: "source", priority: 15 },
  { pattern: "**/*.test.*", label: "tests", priority: 30 },
  { pattern: "**/*.spec.*", label: "tests", priority: 30 },
  { pattern: ".github/**", label: "ci/cd", priority: 25 },
  { pattern: "infra/**", label: "infrastructure", priority: 20 },
  { pattern: "terraform/**", label: "infrastructure", priority: 20 },
  { pattern: "**/*.css", label: "styles", priority: 10 },
  { pattern: "src/components/**", label: "frontend", priority: 10 },
];

// --- Mock data for testing / demo ---
const MOCK_PR_FILES = [
  "docs/getting-started.md",
  "src/api/users.ts",
  "src/api/auth/login.ts",
  "src/api/users.test.ts",
  ".github/workflows/ci.yml",
  "README.md",
];

function loadRules(rulesFile?: string): LabelRule[] {
  if (!rulesFile) return DEFAULT_RULES;

  if (!existsSync(rulesFile)) {
    console.error(`Error: Rules file not found: ${rulesFile}`);
    process.exit(1);
  }

  try {
    const content = readFileSync(rulesFile, "utf-8");
    const parsed = JSON.parse(content);
    if (!Array.isArray(parsed)) {
      console.error("Error: Rules file must contain a JSON array of rules");
      process.exit(1);
    }
    return parsed as LabelRule[];
  } catch (err) {
    console.error(`Error: Failed to parse rules file: ${(err as Error).message}`);
    process.exit(1);
  }
}

function loadFiles(filesEnv?: string): string[] {
  if (!filesEnv) {
    console.log("No CHANGED_FILES provided, using mock data:");
    return MOCK_PR_FILES;
  }
  return filesEnv
    .split(",")
    .map((f) => f.trim())
    .filter((f) => f.length > 0);
}

function main() {
  const changedFilesEnv = process.env.CHANGED_FILES;
  const rulesFileEnv = process.env.RULES_FILE;

  const files = loadFiles(changedFilesEnv);
  const rules = loadRules(rulesFileEnv);

  console.log("\n=== PR Label Assigner ===");
  console.log(`\nChanged files (${files.length}):`);
  files.forEach((f) => console.log(`  - ${f}`));

  const result = assignLabels(files, rules);

  console.log(`\nMatched rules (${result.matchedRules.length}):`);
  result.matchedRules.forEach((r) =>
    console.log(`  [priority=${r.priority}] ${r.pattern} => ${r.label}`)
  );

  console.log(`\nPer-file breakdown:`);
  result.matchedFiles.forEach((entry) => {
    console.log(`  ${entry.file}: [${entry.labels.join(", ")}]`);
  });

  console.log(`\nFinal labels (${result.labels.length}):`);
  result.labels.forEach((l) => console.log(`  - ${l}`));

  // Output machine-readable result for CI consumption
  console.log(`\nLABELS_OUTPUT=${result.labels.join(",")}`);
}

main();
