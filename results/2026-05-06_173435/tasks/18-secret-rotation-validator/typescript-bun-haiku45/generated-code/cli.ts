import {
  Secret,
  detectExpiredSecrets,
  generateMarkdownReport,
  generateJsonReport,
} from "./validator";
import * as fs from "fs";
import * as path from "path";

interface Config {
  secrets: Secret[];
  warningWindowDays?: number;
  outputFormat?: "markdown" | "json" | "both";
  referenceDate?: string;
}

async function main() {
  try {
    // Parse command line arguments
    const args = Bun.argv.slice(2);
    const configFile = args[0] || "secrets-config.json";
    const outputFormat = args[1] || "markdown";

    // Read configuration file
    if (!fs.existsSync(configFile)) {
      console.error(`Error: Configuration file not found: ${configFile}`);
      process.exit(1);
    }

    const configContent = fs.readFileSync(configFile, "utf-8");
    const config: Config = JSON.parse(configContent);

    // Validate configuration
    if (!config.secrets || !Array.isArray(config.secrets)) {
      console.error("Error: Configuration must contain a 'secrets' array");
      process.exit(1);
    }

    // Convert date strings to Date objects
    const secrets: Secret[] = config.secrets.map((s) => ({
      ...s,
      lastRotated: new Date(s.lastRotated),
    }));

    // Use reference date if provided, otherwise use today
    const now = config.referenceDate
      ? new Date(config.referenceDate)
      : new Date();
    const warningWindowDays = config.warningWindowDays || 7;

    // Generate report
    const report = detectExpiredSecrets(secrets, warningWindowDays, now);

    // Output results
    if (outputFormat === "json" || outputFormat === "both") {
      console.log(generateJsonReport(report));
      if (outputFormat === "both") {
        console.log("\n---\n");
      }
    }

    if (outputFormat === "markdown" || outputFormat === "both") {
      console.log(generateMarkdownReport(report));
    }

    // Exit with error code if there are expired secrets
    if (report.expired.length > 0) {
      process.exit(1);
    }
  } catch (error) {
    console.error("Error:", error instanceof Error ? error.message : String(error));
    process.exit(1);
  }
}

main();
