/**
 * Docker Image Tag Generator
 *
 * Generates Docker image tags based on git context following common conventions:
 *   - "latest"                        for main/master branch
 *   - "{branch}-{short-sha}"          for main/master (e.g. "main-abc1234")
 *   - "pr-{number}"                   for pull request builds
 *   - "v{semver}"                     for semver git tags (e.g. "v1.2.3")
 *   - "{sanitized-branch}-{short-sha}" for feature branches
 *
 * Tag sanitization rules:
 *   - Lowercase only
 *   - Non-alphanumeric chars (except . and -) replaced with "-"
 *   - Leading/trailing dashes removed
 *   - Consecutive dashes collapsed to one
 */

// ============================================================
// Types / Interfaces
// ============================================================

/** Input: all git context needed to compute tags */
export interface GitContext {
  branch: string; // Current branch name (e.g. "main", "feature/my-thing")
  commitSha: string; // Full commit SHA (at least 7 chars)
  tags: string[]; // Git tags pointing at this commit (e.g. ["v1.2.3"])
  prNumber?: number; // Pull request number, if this is a PR build
}

/** Output: the generated tag list, or an error message */
export interface TagResult {
  tags: string[];
  error?: string;
}

// ============================================================
// Helpers
// ============================================================

/**
 * Sanitize a string for use as a Docker image tag component.
 * Docker tags must be lowercase alphanumeric with ., -, _ allowed,
 * but we normalise to only alphanumeric, dots and dashes.
 */
export function sanitizeTag(tag: string): string {
  return tag
    .toLowerCase()
    .replace(/[^a-z0-9.-]/g, "-") // replace invalid chars (incl. underscores) with dash
    .replace(/^-+|-+$/g, "") // strip leading/trailing dashes
    .replace(/-{2,}/g, "-"); // collapse runs of dashes
}

/**
 * Return true if the string looks like a semantic version tag,
 * with or without a leading "v" (e.g. "v1.2.3", "1.2.3", "v1.2.3-beta.1").
 */
export function isSemverTag(tag: string): boolean {
  return /^v?\d+\.\d+\.\d+/.test(tag);
}

// ============================================================
// Core logic
// ============================================================

/**
 * Generate Docker image tags for the given git context.
 *
 * Priority / rules (applied in order):
 *  1. If prNumber is set → emit "pr-{number}" only; stop.
 *  2. If branch is main/master → emit "latest" and "{branch}-{short-sha}".
 *  3. Otherwise → emit "{sanitized-branch}-{short-sha}".
 *  4. For any semver git tag on this commit → also emit "v{semver}" (additive).
 */
export function generateTags(context: GitContext): TagResult {
  const { branch, commitSha, tags: gitTags, prNumber } = context;

  // Validate required inputs
  if (!branch) {
    return { tags: [], error: "Branch name is required" };
  }
  if (!commitSha) {
    return { tags: [], error: "Commit SHA is required" };
  }

  const tags: string[] = [];
  const shortSha = commitSha.substring(0, 7);

  // Rule 1: PR build — emit only pr-{number}
  if (prNumber !== undefined && prNumber > 0) {
    tags.push(`pr-${prNumber}`);
    return { tags };
  }

  // Rule 2: main/master branch
  if (branch === "main" || branch === "master") {
    tags.push("latest");
    tags.push(`${branch}-${shortSha}`);
  } else {
    // Rule 3: feature/other branch
    const sanitized = sanitizeTag(branch);
    if (sanitized) {
      tags.push(`${sanitized}-${shortSha}`);
    }
  }

  // Rule 4: semver git tags (additive — can appear alongside branch tags)
  for (const gitTag of gitTags) {
    if (isSemverTag(gitTag)) {
      // Ensure "v" prefix, then sanitize (keeps dots/dashes intact)
      const normalized = gitTag.startsWith("v") ? gitTag : `v${gitTag}`;
      tags.push(sanitizeTag(normalized));
    }
  }

  return { tags };
}

// ============================================================
// CLI entry point
// ============================================================

if (import.meta.main) {
  let context: GitContext;

  // If a fixture file exists (used in testing via act), prefer it
  const fixturePath = "./fixtures/test-input.json";
  const fixtureFile = Bun.file(fixturePath);

  if (await fixtureFile.exists()) {
    const raw = await fixtureFile.json();
    context = {
      branch: String(raw.branch ?? ""),
      commitSha: String(raw.commitSha ?? ""),
      tags: Array.isArray(raw.tags) ? raw.tags.map(String) : [],
      prNumber:
        raw.prNumber && Number(raw.prNumber) > 0
          ? Number(raw.prNumber)
          : undefined,
    };
  } else {
    // Fall back to environment variables / GitHub Actions context
    const prRaw = process.env.PR_NUMBER ?? "0";
    const prNum = parseInt(prRaw, 10);
    context = {
      branch:
        process.env.BRANCH_NAME ?? process.env.GITHUB_REF_NAME ?? "unknown",
      commitSha:
        process.env.COMMIT_SHA ?? process.env.GITHUB_SHA ?? "0000000",
      tags: (process.env.GIT_TAGS ?? "")
        .split(",")
        .map((t) => t.trim())
        .filter(Boolean),
      prNumber: prNum > 0 ? prNum : undefined,
    };
  }

  const result = generateTags(context);

  if (result.error) {
    console.error(`Error: ${result.error}`);
    process.exit(1);
  }

  console.log("Generated Docker image tags:");
  for (const tag of result.tags) {
    console.log(`  - ${tag}`);
  }
  // Emit machine-parseable line for test harness
  console.log(`TAGS=${result.tags.join(",")}`);
}
