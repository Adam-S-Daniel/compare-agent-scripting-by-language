// CLI entry point: reads changed files and config, outputs assigned labels.
import { assignLabels, type LabelConfig } from "./labeler";
import { readFileSync } from "fs";

function parseArgs(args: string[]): { configPath: string; filesPath: string } {
  let configPath = "fixtures/config.json";
  let filesPath = "fixtures/changed-files.txt";
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--config" && args[i + 1]) configPath = args[++i];
    if (args[i] === "--files" && args[i + 1]) filesPath = args[++i];
  }
  return { configPath, filesPath };
}

const { configPath, filesPath } = parseArgs(process.argv.slice(2));

let config: LabelConfig;
try {
  config = JSON.parse(readFileSync(configPath, "utf-8"));
} catch (err) {
  console.error(`Error reading config from ${configPath}: ${err}`);
  process.exit(1);
}

let files: string[];
try {
  files = readFileSync(filesPath, "utf-8")
    .split("\n")
    .map((f) => f.trim())
    .filter((f) => f.length > 0);
} catch (err) {
  console.error(`Error reading files from ${filesPath}: ${err}`);
  process.exit(1);
}

const labels = assignLabels(files, config);

console.log("Changed files:");
files.forEach((f) => console.log(`  ${f}`));
console.log("\nAssigned labels:");
if (labels.length === 0) {
  console.log("  (none)");
} else {
  labels.forEach((l) => console.log(`  ${l}`));
}

// Machine-parseable output line for test harness assertions
console.log(`\nASSIGNED_LABELS=${labels.join(",")}`);
