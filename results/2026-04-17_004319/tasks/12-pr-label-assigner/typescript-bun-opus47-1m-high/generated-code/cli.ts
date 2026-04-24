// CLI entrypoint for the PR label assigner.
//
// Usage:
//   bun run cli.ts --config <rules.json> --files <files.txt>
//   bun run cli.ts --config <rules.json> --files-json '["a.md","b.ts"]'
//
// The CLI is intentionally tiny: it parses flags, reads inputs, and calls the
// library in labeler.ts. All interesting logic lives in the library so it can
// be unit-tested directly.
import { readFileSync } from "node:fs";
import { parseRules, assignLabels } from "./labeler.ts";

interface Args {
  config?: string;
  files?: string;
  filesJson?: string;
  format: "lines" | "json";
}

function parseArgs(argv: string[]): Args {
  const out: Args = { format: "lines" };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]!;
    const next = () => {
      const v = argv[++i];
      if (v === undefined) throw new Error(`${a} requires a value`);
      return v;
    };
    switch (a) {
      case "--config":
        out.config = next();
        break;
      case "--files":
        out.files = next();
        break;
      case "--files-json":
        out.filesJson = next();
        break;
      case "--format":
        {
          const v = next();
          if (v !== "lines" && v !== "json") {
            throw new Error(`--format must be 'lines' or 'json' (got '${v}')`);
          }
          out.format = v;
        }
        break;
      case "-h":
      case "--help":
        printHelp();
        process.exit(0);
      default:
        throw new Error(`Unknown argument: ${a}`);
    }
  }
  return out;
}

function printHelp(): void {
  console.log(
    "Usage: bun run cli.ts --config <rules.json> (--files <file> | --files-json <json>) [--format lines|json]",
  );
}

function readFileList(args: Args): string[] {
  if (args.filesJson !== undefined) {
    const parsed = JSON.parse(args.filesJson);
    if (!Array.isArray(parsed) || !parsed.every((f) => typeof f === "string")) {
      throw new Error("--files-json must be a JSON array of strings");
    }
    return parsed;
  }
  if (args.files !== undefined) {
    const raw = readFileSync(args.files, "utf8");
    // One path per line, blanks ignored so commented-out fixtures are easy.
    return raw
      .split("\n")
      .map((l) => l.trim())
      .filter((l) => l.length > 0);
  }
  throw new Error("Provide --files <path> or --files-json <json>");
}

function main(): void {
  let args: Args;
  try {
    args = parseArgs(process.argv.slice(2));
  } catch (e) {
    console.error(`error: ${(e as Error).message}`);
    printHelp();
    process.exit(2);
  }
  if (args.config === undefined) {
    console.error("error: --config is required");
    process.exit(2);
  }

  try {
    const configText = readFileSync(args.config, "utf8");
    const rules = parseRules(configText);
    const files = readFileList(args);
    const labels = assignLabels(files, rules);
    if (args.format === "json") {
      console.log(JSON.stringify({ labels }));
    } else {
      // Marker lines make it easy for the test harness to slice output out of
      // act's verbose logs.
      console.log("LABELS_BEGIN");
      for (const l of labels) console.log(l);
      console.log("LABELS_END");
      console.log(`LABEL_COUNT=${labels.length}`);
    }
  } catch (e) {
    console.error(`error: ${(e as Error).message}`);
    process.exit(1);
  }
}

main();
