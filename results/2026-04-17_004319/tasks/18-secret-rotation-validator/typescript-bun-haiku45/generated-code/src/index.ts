import { parseArgs } from "./cli";
import { validateSecret } from "./types";
import { generateRotationReport } from "./rotationCheck";
import { formatMarkdown, formatJSON } from "./formatters";
import { readFileSync } from "fs";

async function main() {
  try {
    const config = parseArgs(process.argv);

    // Read and parse secrets file
    const content = readFileSync(config.inputFile, "utf-8");
    const secretsData = JSON.parse(content);

    if (!Array.isArray(secretsData)) {
      throw new Error("Input file must contain a JSON array of secrets");
    }

    // Validate all secrets
    const secrets = [];
    for (const secret of secretsData) {
      const validation = validateSecret(secret);
      if (!validation.isValid) {
        throw new Error(`Invalid secret '${secret.name}': ${validation.errors.join(", ")}`);
      }

      // Convert date strings to Date objects if necessary
      if (typeof secret.lastRotated === "string") {
        secret.lastRotated = new Date(secret.lastRotated);
      }

      secrets.push(secret);
    }

    // Generate report
    const referenceDate = config.referenceDate || new Date();
    const report = generateRotationReport(secrets, referenceDate, config.warningDays);

    // Format and output
    const output = config.format === "json" ? formatJSON(report) : formatMarkdown(report);
    console.log(output);

  } catch (error) {
    console.error("Error:", error instanceof Error ? error.message : String(error));
    process.exit(1);
  }
}

main();
