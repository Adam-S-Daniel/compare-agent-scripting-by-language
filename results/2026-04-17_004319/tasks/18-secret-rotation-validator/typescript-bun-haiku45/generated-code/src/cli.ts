export interface CLIConfig {
  inputFile: string;
  format: "markdown" | "json";
  warningDays: number;
  referenceDate?: Date;
}

// Parse command line arguments
export function parseArgs(args: string[]): CLIConfig {
  if (args.length < 3) {
    throw new Error("Usage: bun run src/index.ts <input-file> [--format markdown|json] [--warning-days N] [--reference-date YYYY-MM-DD]");
  }

  const inputFile = args[2];
  let format: "markdown" | "json" = "markdown";
  let warningDays = 14;
  let referenceDate: Date | undefined;

  for (let i = 3; i < args.length; i++) {
    const arg = args[i];

    if (arg === "--format" && i + 1 < args.length) {
      const value = args[++i];
      if (value !== "markdown" && value !== "json") {
        throw new Error(`Invalid format: ${value}. Must be 'markdown' or 'json'.`);
      }
      format = value;
    } else if (arg === "--warning-days" && i + 1 < args.length) {
      const value = parseInt(args[++i], 10);
      if (isNaN(value) || value <= 0) {
        throw new Error("Warning days must be a positive number");
      }
      warningDays = value;
    } else if (arg === "--reference-date" && i + 1 < args.length) {
      const value = args[++i];
      referenceDate = new Date(value);
      if (isNaN(referenceDate.getTime())) {
        throw new Error(`Invalid date format: ${value}. Use YYYY-MM-DD.`);
      }
    }
  }

  return {
    inputFile,
    format,
    warningDays,
    referenceDate,
  };
}
