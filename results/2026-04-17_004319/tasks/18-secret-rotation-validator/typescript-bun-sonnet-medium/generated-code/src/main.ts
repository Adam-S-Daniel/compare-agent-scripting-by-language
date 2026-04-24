import { generateReport } from "./validator";
import { formatAsMarkdown, formatAsJSON } from "./formatter";
import type { FixtureConfig } from "./types";

function parseArgs(args: string[]): {
  input: string;
  format: "markdown" | "json";
  warningDays?: number;
} {
  const result: { input: string; format: "markdown" | "json"; warningDays?: number } = {
    input: "",
    format: "json",
  };
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--input" && args[i + 1]) result.input = args[++i];
    else if (args[i] === "--format" && args[i + 1]) {
      const f = args[++i];
      if (f === "markdown" || f === "json") result.format = f;
      else {
        console.error(`Error: unknown format '${f}'. Use 'markdown' or 'json'.`);
        process.exit(1);
      }
    } else if (args[i] === "--warning-days" && args[i + 1]) {
      result.warningDays = parseInt(args[++i], 10);
    }
  }
  return result;
}

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));

  if (!args.input) {
    console.error("Error: --input <file> is required");
    console.error("Usage: bun run src/main.ts --input fixtures/sample-secrets.json [--format json|markdown] [--warning-days N]");
    process.exit(1);
  }

  let config: FixtureConfig;
  try {
    const content = await Bun.file(args.input).text();
    config = JSON.parse(content) as FixtureConfig;
  } catch (e) {
    console.error(
      `Error: failed to read fixture '${args.input}': ${e instanceof Error ? e.message : String(e)}`
    );
    process.exit(1);
  }

  const secrets = config.secrets.map((s) => ({
    ...s,
    lastRotated: new Date(s.lastRotated + "T00:00:00Z"),
  }));

  const warningWindowDays = args.warningDays ?? config.warningWindowDays ?? 7;
  const referenceDate = config.referenceDate
    ? new Date(config.referenceDate + "T00:00:00Z")
    : undefined;

  const report = generateReport(secrets, { warningWindowDays, referenceDate });

  if (args.format === "markdown") {
    console.log(formatAsMarkdown(report));
  } else {
    console.log(formatAsJSON(report));
  }

  // Parseable summary lines for CI consumption
  console.log(`VALIDATOR_EXPIRED=${report.summary.expired}`);
  console.log(`VALIDATOR_WARNING=${report.summary.warning}`);
  console.log(`VALIDATOR_OK=${report.summary.ok}`);
}

main().catch((e) => {
  console.error("Unexpected error:", e);
  process.exit(2);
});
