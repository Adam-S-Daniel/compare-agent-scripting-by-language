#!/usr/bin/env bun
// PR Label Assigner - Main Script
// Usage: bun run index.ts [--fixture <path>] [--config <path>] [--files <f1,f2,...>]
//
// Reads a list of changed PR files (from fixture JSON or --files flag),
// applies configurable label rules, and prints the resulting label set.

import { assignLabels, type LabelConfig } from "./src/label-assigner";
import defaultConfig from "./label-rules.json" assert { type: "json" };

/** Fixture file format for test cases. */
interface Fixture {
  description: string;
  files: string[];
  expectedLabels: string[];
}

/** Parse CLI arguments into a simple key->value map. */
function parseArgs(argv: string[]): Record<string, string> {
  const args: Record<string, string> = {};
  for (let i = 0; i < argv.length; i++) {
    if (argv[i].startsWith("--") && i + 1 < argv.length) {
      args[argv[i].slice(2)] = argv[i + 1];
      i++;
    }
  }
  return args;
}

/** Load and validate a fixture JSON file. */
async function loadFixture(path: string): Promise<Fixture> {
  const file = Bun.file(path);
  if (!(await file.exists())) {
    throw new Error(`Fixture file not found: ${path}`);
  }
  const data = await file.json() as Fixture;
  if (!Array.isArray(data.files)) {
    throw new Error(`Fixture '${path}' must have a 'files' array`);
  }
  return data;
}

/** Load and validate a config JSON file. */
async function loadConfig(path: string): Promise<LabelConfig> {
  const file = Bun.file(path);
  if (!(await file.exists())) {
    throw new Error(`Config file not found: ${path}`);
  }
  const data = await file.json() as LabelConfig;
  if (!Array.isArray(data.rules)) {
    throw new Error(`Config '${path}' must have a 'rules' array`);
  }
  return data;
}

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));

  // Load config (default or from --config flag)
  let config: LabelConfig;
  if (args.config) {
    config = await loadConfig(args.config);
  } else {
    config = defaultConfig as LabelConfig;
  }

  // Determine file list: --fixture, --files, or built-in mock
  let files: string[];
  let description = "Mock PR (built-in)";
  let expectedLabels: string[] | undefined;

  if (args.fixture) {
    const fixture = await loadFixture(args.fixture);
    files = fixture.files;
    description = fixture.description;
    expectedLabels = fixture.expectedLabels;
  } else if (args.files) {
    files = args.files.split(",").map((f) => f.trim()).filter(Boolean);
  } else {
    // Built-in mock: simulates a realistic feature PR
    files = [
      "src/api/users.ts",
      "src/api/users.test.ts",
      "src/utils/helpers.ts",
      "docs/api-reference.md",
      ".github/workflows/ci.yml",
      "README.md",
    ];
  }

  // Assign labels
  const labels = assignLabels(files, config.rules);

  // Output results
  console.log(`PR Label Assigner`);
  console.log(`=================`);
  console.log(`Description: ${description}`);
  console.log(`Changed files (${files.length}):`);
  for (const f of files) {
    console.log(`  - ${f}`);
  }
  console.log(`\nAssigned labels: ${labels.join(", ")}`);
  console.log(`LABELS=${labels.join(",")}`);

  // Validate against expected labels if provided
  if (expectedLabels) {
    const missing = expectedLabels.filter((l) => !labels.includes(l));
    const extra = labels.filter((l) => !expectedLabels!.includes(l));

    if (missing.length > 0 || extra.length > 0) {
      if (missing.length > 0) {
        console.error(`ERROR: Missing expected labels: ${missing.join(", ")}`);
      }
      if (extra.length > 0) {
        console.error(`ERROR: Unexpected labels: ${extra.join(", ")}`);
      }
      process.exit(1);
    } else {
      console.log(`VALIDATION: All expected labels present.`);
    }
  }
}

main().catch((err: Error) => {
  console.error(`Error: ${err.message}`);
  process.exit(1);
});
