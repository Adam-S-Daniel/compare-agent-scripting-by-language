// CLI entry point for the test results aggregator.
// Usage: bun run main.ts <fixtures-directory>
//
// Scans the given directory for *.xml and *.json files, parses each,
// aggregates results, and outputs a Markdown summary to stdout.
// When $GITHUB_STEP_SUMMARY is set, also appends to that file.

import { readdirSync, readFileSync, appendFileSync } from 'fs';
import { join, extname, basename } from 'path';
import { parseJUnitXML, parseJSONResults } from './parsers';
import { aggregateResults } from './aggregator';
import { generateMarkdown } from './markdown';
import type { TestSuite } from './types';

function main(): void {
  const dir = process.argv[2];
  if (!dir) {
    console.error('Usage: bun run main.ts <fixtures-directory>');
    process.exit(1);
  }

  let files: string[];
  try {
    files = readdirSync(dir);
  } catch (e) {
    console.error(`Error reading directory "${dir}": ${(e as Error).message}`);
    process.exit(1);
  }

  const suites: TestSuite[] = [];

  for (const file of files.sort()) {
    const fullPath = join(dir, file);
    const ext = extname(file).toLowerCase();

    if (ext !== '.xml' && ext !== '.json') continue;

    let content: string;
    try {
      content = readFileSync(fullPath, 'utf8');
    } catch (e) {
      console.error(`Error reading "${fullPath}": ${(e as Error).message}`);
      continue;
    }

    try {
      if (ext === '.xml') {
        suites.push(...parseJUnitXML(content, basename(file)));
      } else {
        suites.push(...parseJSONResults(content, basename(file)));
      }
    } catch (e) {
      console.error(`Error parsing "${file}": ${(e as Error).message}`);
      continue;
    }
  }

  if (suites.length === 0) {
    console.error('No test result files found.');
    process.exit(1);
  }

  const aggregated = aggregateResults(suites);
  const markdown = generateMarkdown(aggregated);

  // Print to stdout (visible in act output)
  console.log(markdown);

  // Also write to GitHub Step Summary if available
  const stepSummary = process.env.GITHUB_STEP_SUMMARY;
  if (stepSummary) {
    try {
      appendFileSync(stepSummary, markdown + '\n');
    } catch (e) {
      console.error(`Warning: could not write to GITHUB_STEP_SUMMARY: ${(e as Error).message}`);
    }
  }
}

main();
