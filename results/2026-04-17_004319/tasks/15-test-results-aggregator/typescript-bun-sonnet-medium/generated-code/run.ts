// CLI entry point: bun run run.ts <fixture-dir> [<fixture-dir> ...]
import { aggregateResults } from "./src/aggregator";
import { generateMarkdown } from "./src/markdown";
import { readdir } from "fs/promises";
import { join, extname } from "path";

async function findResultFiles(dirs: string[]): Promise<string[]> {
  const files: string[] = [];
  for (const dir of dirs) {
    try {
      const entries = await readdir(dir);
      for (const entry of entries) {
        const ext = extname(entry).toLowerCase();
        if (ext === ".xml" || ext === ".json") {
          files.push(join(dir, entry));
        }
      }
    } catch (e) {
      console.error(
        `Warning: Could not read directory ${dir}: ${e instanceof Error ? e.message : String(e)}`
      );
    }
  }
  return files;
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  if (args.length === 0) {
    console.error("Usage: bun run run.ts <fixture-dir> [<fixture-dir> ...]");
    process.exit(1);
  }

  const files = await findResultFiles(args);
  if (files.length === 0) {
    console.error("No test result files found (*.xml or *.json) in given directories");
    process.exit(1);
  }

  const results = aggregateResults(files);
  const markdown = generateMarkdown(results);

  console.log(markdown);

  // Write to GitHub Actions step summary when available
  const summaryFile = process.env.GITHUB_STEP_SUMMARY;
  if (summaryFile) {
    await Bun.write(summaryFile, markdown);
  }
}

main().catch((e) => {
  console.error("Fatal error:", e instanceof Error ? e.message : String(e));
  process.exit(1);
});
