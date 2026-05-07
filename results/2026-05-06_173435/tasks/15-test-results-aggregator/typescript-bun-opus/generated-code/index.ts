import { parseFile } from "./parser";
import { aggregate } from "./aggregator";
import { generateMarkdown } from "./markdown";
import { readdir } from "fs/promises";
import { join } from "path";

async function main(): Promise<void> {
  const inputDir = process.env.TEST_RESULTS_DIR || "./fixtures";
  const outputFile = process.env.SUMMARY_OUTPUT || "";
  const githubStepSummary = process.env.GITHUB_STEP_SUMMARY || "";

  const files = await readdir(inputDir);
  const testFiles = files.filter(
    (f) => f.endsWith(".xml") || f.endsWith(".json")
  );

  if (testFiles.length === 0) {
    console.error(`No test result files found in ${inputDir}`);
    process.exit(1);
  }

  console.log(`Found ${testFiles.length} test result file(s) in ${inputDir}`);

  const runs = await Promise.all(
    testFiles.map((f) => parseFile(join(inputDir, f)))
  );

  const report = aggregate(runs);
  const markdown = generateMarkdown(report);

  console.log(markdown);

  if (outputFile) {
    await Bun.write(outputFile, markdown);
    console.log(`\nSummary written to ${outputFile}`);
  }

  if (githubStepSummary) {
    await Bun.write(githubStepSummary, markdown);
    console.log(`\nSummary written to GitHub Step Summary`);
  }

  // Print machine-readable totals for CI assertion parsing
  console.log("\n--- TOTALS ---");
  console.log(`TOTAL_TESTS=${report.totals.totalTests}`);
  console.log(`PASSED=${report.totals.passed}`);
  console.log(`FAILED=${report.totals.failed}`);
  console.log(`SKIPPED=${report.totals.skipped}`);
  console.log(`DURATION=${report.totals.duration.toFixed(2)}`);
  console.log(`FLAKY_COUNT=${report.flakyTests.length}`);
  if (report.flakyTests.length > 0) {
    for (const ft of report.flakyTests) {
      console.log(`FLAKY_TEST=${ft.suite}::${ft.name}`);
    }
  }
  console.log("--- END TOTALS ---");
}

main().catch((err: Error) => {
  console.error(`Error: ${err.message}`);
  process.exit(1);
});
