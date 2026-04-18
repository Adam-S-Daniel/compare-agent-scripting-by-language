#!/usr/bin/env bun
// CLI entry point. Reads a secrets JSON config, emits a grouped report.
// Flags are minimal; `--now` is accepted only for deterministic CI output.
//
// Usage: bun run src/cli.ts --input fixtures/secrets.json --format markdown \
//                           --warning-days 7 [--now 2026-04-17]
// Exit code is 1 when any secret is expired (so CI can fail), 0 otherwise.

import { readFileSync } from "node:fs";
import { generateReport, formatJson, formatMarkdown, loadConfig } from "./validator";

interface Args {
  input: string;
  format: "markdown" | "json";
  warningDays: number;
  now: Date;
  failOnExpired: boolean;
}

function parseArgs(argv: string[]): Args {
  const args: Record<string, string> = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith("--")) {
      const key = a.slice(2);
      const next = argv[i + 1];
      if (next === undefined || next.startsWith("--")) {
        args[key] = "true";
      } else {
        args[key] = next;
        i++;
      }
    }
  }
  if (!args.input) throw new Error("--input <path> is required");
  const format = (args.format ?? "markdown") as "markdown" | "json";
  if (format !== "markdown" && format !== "json")
    throw new Error(`unknown --format '${format}' (markdown|json)`);
  const warningDays = Number(args["warning-days"] ?? "7");
  if (!Number.isFinite(warningDays) || warningDays < 0)
    throw new Error(`invalid --warning-days '${args["warning-days"]}'`);
  const now = args.now ? new Date(`${args.now}T00:00:00Z`) : new Date();
  if (Number.isNaN(now.getTime())) throw new Error(`invalid --now '${args.now}'`);
  const failOnExpired = args["fail-on-expired"] !== "false";
  return { input: args.input, format, warningDays, now, failOnExpired };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const raw = readFileSync(args.input, "utf8");
  const secrets = loadConfig(raw);
  const report = generateReport(secrets, args.now, args.warningDays);
  const output = args.format === "json" ? formatJson(report) : formatMarkdown(report);
  process.stdout.write(output);
  if (!output.endsWith("\n")) process.stdout.write("\n");
  // Summary line to stderr so it's easy to grep in CI logs without
  // polluting the formatted stdout payload.
  process.stderr.write(
    `SUMMARY expired=${report.expired.length} warning=${report.warning.length} ok=${report.ok.length}\n`,
  );
  if (args.failOnExpired && report.expired.length > 0) process.exit(1);
}

main().catch((err: unknown) => {
  const msg = err instanceof Error ? err.message : String(err);
  process.stderr.write(`error: ${msg}\n`);
  process.exit(2);
});
