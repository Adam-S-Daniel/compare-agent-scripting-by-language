// CLI entrypoint. Reads a JSON file with shape:
//   { "artifacts": Artifact[], "policy": RetentionPolicy }
// and prints a deletion plan. --dry-run is the default; --execute would mark
// the plan as live. Since this is a planning script (no real GitHub API call),
// "execute" simply changes the header / exit reporting.
import { planCleanup, formatPlan, type Artifact, type RetentionPolicy } from "./cleanup";

interface InputFile {
  artifacts: Artifact[];
  policy: RetentionPolicy;
  now?: string; // optional ISO timestamp to make output deterministic in tests
}

function parseArgs(argv: string[]): { input: string; dryRun: boolean; json: boolean } {
  let input = "";
  let dryRun = true;
  let json = false;
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--input" || a === "-i") input = argv[++i] ?? "";
    else if (a === "--execute") dryRun = false;
    else if (a === "--dry-run") dryRun = true;
    else if (a === "--json") json = true;
    else if (a === "--help" || a === "-h") {
      console.log("Usage: bun run src/cli.ts --input <file.json> [--dry-run|--execute] [--json]");
      process.exit(0);
    }
  }
  if (!input) {
    throw new Error("Missing required --input <file.json>");
  }
  return { input, dryRun, json };
}

async function main(): Promise<void> {
  const { input, dryRun, json } = parseArgs(process.argv.slice(2));

  const file = Bun.file(input);
  if (!(await file.exists())) {
    throw new Error(`Input file not found: ${input}`);
  }

  let data: InputFile;
  try {
    data = await file.json();
  } catch (e) {
    throw new Error(`Failed to parse JSON in ${input}: ${(e as Error).message}`);
  }

  if (!Array.isArray(data.artifacts)) {
    throw new Error(`Input must contain an "artifacts" array`);
  }
  if (!data.policy || typeof data.policy !== "object") {
    throw new Error(`Input must contain a "policy" object`);
  }

  const now = data.now ? Date.parse(data.now) : Date.now();
  if (Number.isNaN(now)) {
    throw new Error(`Invalid "now" timestamp: ${data.now}`);
  }

  const plan = planCleanup(data.artifacts, data.policy, now);

  if (json) {
    console.log(JSON.stringify({
      dryRun,
      summary: plan.summary,
      toDelete: plan.toDelete.map(a => a.id),
      toRetain: plan.toRetain.map(a => a.id),
    }, null, 2));
  } else {
    console.log(formatPlan(plan, dryRun));
  }
}

main().catch((err: Error) => {
  console.error(`ERROR: ${err.message}`);
  process.exit(1);
});
