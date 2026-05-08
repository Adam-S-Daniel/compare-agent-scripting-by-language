import { generateDeletionPlan, formatPlan } from "./cleanup";
import type { Artifact, RetentionPolicy } from "./types";

// Read input from file path passed as argument or from stdin
async function main(): Promise<void> {
  const inputPath = process.argv[2];
  if (!inputPath) {
    console.error("Usage: bun run src/index.ts <input.json>");
    console.error("  Input JSON should have { artifacts: [...], policy: {...}, dryRun: bool }");
    process.exit(1);
  }

  let rawData: string;
  try {
    rawData = await Bun.file(inputPath).text();
  } catch (err) {
    console.error(`Error reading input file: ${(err as Error).message}`);
    process.exit(1);
  }

  let input: { artifacts: RawArtifact[]; policy: RetentionPolicy; dryRun?: boolean };
  try {
    input = JSON.parse(rawData);
  } catch (err) {
    console.error(`Error parsing JSON: ${(err as Error).message}`);
    process.exit(1);
  }

  if (!input.artifacts || !Array.isArray(input.artifacts)) {
    console.error("Error: input must contain an 'artifacts' array");
    process.exit(1);
  }

  if (!input.policy) {
    console.error("Error: input must contain a 'policy' object");
    process.exit(1);
  }

  const artifacts: Artifact[] = input.artifacts.map((raw) => ({
    name: raw.name,
    sizeBytes: raw.sizeBytes,
    createdAt: new Date(raw.createdAt),
    workflowRunId: raw.workflowRunId,
  }));

  const dryRun = input.dryRun !== false;
  const plan = generateDeletionPlan(artifacts, input.policy, { dryRun });
  const output = formatPlan(plan);
  console.log(output);

  // Output structured JSON for machine parsing
  console.log("\n--- JSON Output ---");
  console.log(JSON.stringify(plan.summary));
}

interface RawArtifact {
  name: string;
  sizeBytes: number;
  createdAt: string;
  workflowRunId: string;
}

main();
