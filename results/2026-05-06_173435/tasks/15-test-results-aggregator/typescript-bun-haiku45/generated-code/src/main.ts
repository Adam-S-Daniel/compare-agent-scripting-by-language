import * as fs from 'fs';
import * as path from 'path';
import { parseJunitXml, parseJsonResults } from './parser';
import { aggregateResults } from './aggregator';
import { generateMarkdownSummary } from './markdown';

async function main() {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    console.error('Usage: bun run src/main.ts <results-dir> [output-file]');
    console.error('  <results-dir>: Directory containing test result files (*.xml, *.json)');
    console.error('  [output-file]: Optional output file for markdown summary (defaults to stdout)');
    process.exit(1);
  }

  const resultsDir = args[0];
  const outputFile = args[1];

  // Validate directory exists
  if (!fs.existsSync(resultsDir)) {
    console.error(`Error: Directory not found: ${resultsDir}`);
    process.exit(1);
  }

  // Find all result files
  const files = fs.readdirSync(resultsDir);
  const resultFiles = files.filter(f => f.endsWith('.xml') || f.endsWith('.json'));

  if (resultFiles.length === 0) {
    console.error(`Error: No .xml or .json files found in ${resultsDir}`);
    process.exit(1);
  }

  // Parse all result files
  const parsedResults = [];

  for (const file of resultFiles) {
    const filePath = path.join(resultsDir, file);
    const content = fs.readFileSync(filePath, 'utf-8');
    const runId = path.basename(file, path.extname(file));

    try {
      if (file.endsWith('.xml')) {
        parsedResults.push(parseJunitXml(content, runId));
      } else if (file.endsWith('.json')) {
        parsedResults.push(parseJsonResults(content, runId));
      }
    } catch (error) {
      console.error(`Error parsing ${file}:`, error instanceof Error ? error.message : String(error));
      process.exit(1);
    }
  }

  // Aggregate results
  const aggregated = aggregateResults(parsedResults);

  // Generate markdown summary
  const markdown = generateMarkdownSummary(aggregated);

  // Output results
  if (outputFile) {
    fs.writeFileSync(outputFile, markdown);
    console.log(`Summary written to ${outputFile}`);
  } else {
    console.log(markdown);
  }

  // Exit with appropriate code
  process.exit(aggregated.totalFailed > 0 ? 1 : 0);
}

main().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
