import { readVersionFromPackageJson, updateVersionInPackageJson } from "./files";
import { determineNextVersion } from "./bumper";
import { getCommitTypes } from "./commits";
import { generateChangelogEntry } from "./changelog";

// Main entry point for the semantic version bumper
export async function main(args: string[]): Promise<string> {
  // Default to package.json in current directory
  const pkgJsonPath = args[0] || "./package.json";

  // Get current version
  const currentVersion = await readVersionFromPackageJson(pkgJsonPath);

  // Get commits from args (for testing, would be from git in real scenario)
  const commits = args.slice(1);

  if (commits.length === 0) {
    console.log(`Current version: ${currentVersion}`);
    return currentVersion;
  }

  // Determine next version
  const commitTypes = getCommitTypes(commits);
  const nextVersion = determineNextVersion(currentVersion, commitTypes);

  // Update package.json
  await updateVersionInPackageJson(pkgJsonPath, nextVersion);

  // Generate changelog entry
  const changelog = generateChangelogEntry(nextVersion, commits);

  console.log(`Bumped version from ${currentVersion} to ${nextVersion}`);
  console.log("\nChangelog:");
  console.log(changelog);

  return nextVersion;
}

// Run CLI if this is the main module
if (import.meta.main) {
  main(process.argv.slice(2))
    .catch((error) => {
      console.error("Error:", error.message);
      process.exit(1);
    });
}
