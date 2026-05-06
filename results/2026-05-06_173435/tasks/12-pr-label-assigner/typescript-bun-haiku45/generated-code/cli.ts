import { getLabelsForPR, loadConfig } from "./label-assigner";

// CLI entry point: reads changed files from env/args and applies labels
async function main() {
  try {
    // Get configuration file path from env or use default
    const configPath = process.env.LABEL_CONFIG || "label-config.json";

    // Load configuration
    const config = loadConfig(configPath);

    // Get changed files from environment variable (JSON array) or from command args
    let changedFiles: string[] = [];

    // First try to get from CHANGED_FILES env variable (JSON format)
    if (process.env.CHANGED_FILES) {
      try {
        changedFiles = JSON.parse(process.env.CHANGED_FILES);
      } catch (error) {
        console.error("Failed to parse CHANGED_FILES JSON:", error);
        process.exit(1);
      }
    } else if (process.argv.length > 2) {
      // Otherwise read from command line arguments
      changedFiles = process.argv.slice(2);
    } else {
      console.error("Error: No changed files provided");
      console.error("Usage: bun run cli.ts <file1> <file2> ...");
      console.error("Or set CHANGED_FILES env variable with JSON array");
      process.exit(1);
    }

    if (changedFiles.length === 0) {
      console.error("Error: No files to process");
      process.exit(1);
    }

    // Apply label assignment
    const labels = getLabelsForPR(changedFiles, config.rules);

    // Output results
    console.log("Changed files:", changedFiles.length);
    console.log("Assigned labels:", labels);
    console.log("Labels (JSON):", JSON.stringify(labels));

    // Exit with success
    process.exit(0);
  } catch (error) {
    console.error("Error:", error instanceof Error ? error.message : String(error));
    process.exit(1);
  }
}

main();
