import {
  parseArtifacts,
  applyRetentionPolicies,
  generateDeletionPlan,
  type RetentionPolicy,
} from "./artifact-cleanup";

// Mock artifact data for testing
const mockArtifacts = [
  {
    name: "build-output-main-1",
    size: 5242880, // 5MB
    createdAt: "2026-04-01",
    workflowRunId: "run-main-001",
  },
  {
    name: "build-output-main-2",
    size: 6291456, // 6MB
    createdAt: "2026-04-10",
    workflowRunId: "run-main-002",
  },
  {
    name: "build-output-main-3",
    size: 7340032, // 7MB
    createdAt: "2026-04-18",
    workflowRunId: "run-main-003",
  },
  {
    name: "test-results-feature-1",
    size: 2097152, // 2MB
    createdAt: "2026-03-15",
    workflowRunId: "run-feature-001",
  },
  {
    name: "test-results-feature-2",
    size: 3145728, // 3MB
    createdAt: "2026-04-05",
    workflowRunId: "run-feature-002",
  },
  {
    name: "coverage-report",
    size: 1048576, // 1MB
    createdAt: "2026-01-01",
    workflowRunId: "run-coverage-001",
  },
];

// Default retention policy
const defaultPolicy: RetentionPolicy = {
  maxAgeDays: 30, // Keep artifacts max 30 days old
  maxTotalSizeMB: 20, // Keep max 20MB total
  keepLatestNPerWorkflow: 3, // Keep latest 3 per workflow
};

async function main() {
  const dryRun = process.argv.includes("--dry-run");
  const helpFlag = process.argv.includes("--help") || process.argv.includes("-h");

  if (helpFlag) {
    console.log(`
Artifact Cleanup Script
======================

Usage: bun run src/index.ts [OPTIONS]

Options:
  --dry-run              Show what would be deleted without actually deleting
  --help, -h             Show this help message

This script applies retention policies to artifacts and generates a deletion plan.

Default Policies:
  - Max age: ${defaultPolicy.maxAgeDays} days
  - Max total size: ${defaultPolicy.maxTotalSizeMB}MB
  - Keep latest N per workflow: ${defaultPolicy.keepLatestNPerWorkflow}
    `);
    process.exit(0);
  }

  console.log("🗑️  Artifact Cleanup Script");
  console.log("==========================\n");

  // Parse and process artifacts
  const artifacts = parseArtifacts(mockArtifacts);
  console.log(`Loaded ${artifacts.length} artifacts for analysis\n`);

  // Apply retention policies
  const toDelete = applyRetentionPolicies(artifacts, defaultPolicy);

  // Generate deletion plan
  const plan = generateDeletionPlan(artifacts, toDelete, dryRun);

  // Display the plan
  console.log(plan.summary);
  console.log("\nDetailed Deletion Plan:");
  console.log("----------------------\n");

  if (plan.toDelete.length > 0) {
    console.log("Artifacts to DELETE:");
    plan.toDelete.forEach((artifact, idx) => {
      const sizeMB = (artifact.size / (1024 * 1024)).toFixed(2);
      console.log(
        `  ${idx + 1}. ${artifact.name} (${sizeMB}MB, ${artifact.createdAt.toISOString().split("T")[0]})`
      );
    });
  } else {
    console.log("✓ No artifacts marked for deletion");
  }

  console.log("\nArtifacts to RETAIN:");
  if (plan.toRetain.length > 0) {
    plan.toRetain.forEach((artifact, idx) => {
      const sizeMB = (artifact.size / (1024 * 1024)).toFixed(2);
      console.log(
        `  ${idx + 1}. ${artifact.name} (${sizeMB}MB, ${artifact.createdAt.toISOString().split("T")[0]})`
      );
    });
  } else {
    console.log("  (none)");
  }

  console.log(`\n✨ Summary:`);
  console.log(
    `   Space to reclaim: ${plan.spaceSavedMB.toFixed(2)}MB`
  );
  console.log(
    `   Status: ${dryRun ? "DRY-RUN - No changes made" : "READY TO EXECUTE"}`
  );

  process.exit(0);
}

main().catch((error) => {
  console.error("Error:", error.message);
  process.exit(1);
});
