// Docker image tag generator
// Generates tags following common conventions based on git context

export interface GitContext {
  branch: string;       // e.g. "main", "feature/login"
  sha: string;          // full or short commit SHA
  tags: string[];       // git tags pointing at this commit, e.g. ["v1.2.3"]
  prNumber: number | null; // PR number if this is a PR build
}

/**
 * Sanitize a string for use as a Docker image tag.
 * Rules: lowercase, replace non-alphanumeric runs with single dash,
 * strip leading/trailing dashes.
 */
export function sanitizeTag(raw: string): string {
  return raw
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")  // replace runs of invalid chars with dash
    .replace(/^-+|-+$/g, "");      // strip leading/trailing dashes
}

/**
 * Generate Docker image tags given git context.
 *
 * Conventions:
 *  - main/master branch (no version tag) → ["latest", "<branch>-<sha7>"]
 *  - PR build → ["pr-<number>", "<sanitized-branch>-<sha7>"]
 *  - Version tag present → ["v<semver>", "<semver>", ...plus main/latest if on main]
 *  - Feature branch → ["<sanitized-branch>-<sha7>"]
 */
export function generateDockerTags(ctx: GitContext): string[] {
  if (!ctx.branch) throw new Error("branch name is required");
  if (!ctx.sha) throw new Error("commit SHA is required");

  const sha7 = ctx.sha.slice(0, 7);
  const sanitizedBranch = sanitizeTag(ctx.branch);
  const branchShaTag = `${sanitizedBranch}-${sha7}`;
  const tags: string[] = [];

  // Semver tags from git tags
  const semverTags = ctx.tags.filter((t) => /^v?\d+\.\d+/.test(t));
  for (const t of semverTags) {
    tags.push(t); // e.g. "v1.2.3"
    // Also push without leading "v"
    if (t.startsWith("v")) tags.push(t.slice(1));
  }

  // PR builds
  if (ctx.prNumber !== null) {
    tags.push(`pr-${ctx.prNumber}`);
    tags.push(branchShaTag);
    return tags;
  }

  // Main/master → add "latest"
  const isDefault = ctx.branch === "main" || ctx.branch === "master";
  if (isDefault) {
    tags.push("latest");
  }

  tags.push(branchShaTag);
  return tags;
}

// CLI entrypoint: accepts JSON on stdin or as first arg
if (import.meta.main) {
  const raw = process.argv[2] ?? (await new Response(Bun.stdin.stream()).text());
  let ctx: GitContext;
  try {
    ctx = JSON.parse(raw) as GitContext;
  } catch {
    console.error("Error: input must be valid JSON matching GitContext interface");
    process.exit(1);
  }

  let tags: string[];
  try {
    tags = generateDockerTags(ctx);
  } catch (err) {
    console.error(`Error: ${(err as Error).message}`);
    process.exit(1);
  }

  console.log(tags.join("\n"));
}
