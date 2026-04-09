#!/usr/bin/env bun

/**
 * Docker Image Tag Generator
 *
 * Generates Docker image tags from git context following common conventions:
 *   - "latest"                for the main/master branch
 *   - "pr-{number}"           for pull requests
 *   - "v{semver}"             for semver tags (also "latest" if on main)
 *   - "{branch}-{short-sha}"  for feature branches
 *
 * All tags are sanitised: lowercased, special characters replaced with hyphens,
 * leading/trailing hyphens stripped, consecutive hyphens collapsed.
 */

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** All possible inputs describing the current git context. */
export interface GitContext {
  branch: string;       // e.g. "main", "feature/cool-thing"
  commitSha: string;    // full 40-char SHA
  tag?: string;         // e.g. "v1.2.3" (optional)
  prNumber?: number;    // e.g. 42 (optional, present for PR events)
}

// ---------------------------------------------------------------------------
// Tag sanitisation
// ---------------------------------------------------------------------------

/**
 * Sanitise a string so it is a valid Docker tag component.
 * Docker tags may contain lowercase alphanumerics, hyphens, dots, and
 * underscores – but we further restrict to lowercase alphanumerics and
 * hyphens for maximum portability.
 */
export function sanitiseTag(raw: string): string {
  return raw
    .toLowerCase()                      // force lowercase
    .replace(/[^a-z0-9.\-]/g, "-")       // replace non-alphanumeric (except hyphen and dot) with hyphen
    .replace(/-{2,}/g, "-")             // collapse consecutive hyphens
    .replace(/^-+|-+$/g, "");           // strip leading/trailing hyphens
}

// ---------------------------------------------------------------------------
// Tag generation
// ---------------------------------------------------------------------------

/** Return whether a branch name refers to the default (main/master) branch. */
function isDefaultBranch(branch: string): boolean {
  const normalised = branch.replace(/^refs\/heads\//, "");
  return normalised === "main" || normalised === "master";
}

/** Determine whether a tag string looks like a semver tag (v1.2.3 etc.). */
function isSemverTag(tag: string): boolean {
  return /^v?\d+\.\d+\.\d+/.test(tag);
}

/**
 * Core logic: given a GitContext, produce an ordered list of Docker image tags.
 *
 * Rules (applied in order – duplicates are removed):
 *  1. If a semver tag is present  → add the sanitised tag (e.g. "v1.2.3")
 *  2. If branch is main/master   → add "latest"
 *  3. If a PR number is present   → add "pr-{number}"
 *  4. Always add "{branch}-{shortSha}" as a unique, traceable tag
 */
export function generateTags(ctx: GitContext): string[] {
  // Validate required fields
  if (!ctx.branch || typeof ctx.branch !== "string") {
    throw new Error("GitContext.branch is required and must be a non-empty string");
  }
  if (!ctx.commitSha || typeof ctx.commitSha !== "string") {
    throw new Error("GitContext.commitSha is required and must be a non-empty string");
  }

  const tags: string[] = [];
  const shortSha = ctx.commitSha.substring(0, 7);
  const cleanBranch = ctx.branch.replace(/^refs\/heads\//, "");

  // 1. Semver tag
  if (ctx.tag && isSemverTag(ctx.tag)) {
    tags.push(sanitiseTag(ctx.tag));
  }

  // 2. Default branch → "latest"
  if (isDefaultBranch(ctx.branch)) {
    tags.push("latest");
  }

  // 3. Pull-request tag
  if (ctx.prNumber !== undefined && ctx.prNumber !== null) {
    tags.push(`pr-${ctx.prNumber}`);
  }

  // 4. Branch-SHA tag (always)
  tags.push(sanitiseTag(`${cleanBranch}-${shortSha}`));

  // De-duplicate while preserving order
  return [...new Set(tags)];
}

// ---------------------------------------------------------------------------
// CLI entry-point
// ---------------------------------------------------------------------------

/**
 * When executed directly, read git context from environment variables
 * and print the generated tags, one per line.
 *
 * Expected env vars:
 *   GIT_BRANCH    – branch name (required)
 *   GIT_COMMIT    – full commit SHA (required)
 *   GIT_TAG       – tag name (optional)
 *   PR_NUMBER     – pull-request number (optional)
 */
function main(): void {
  const branch = process.env.GIT_BRANCH ?? "";
  const commitSha = process.env.GIT_COMMIT ?? "";
  const tag = process.env.GIT_TAG;
  const prNumberRaw = process.env.PR_NUMBER;

  const prNumber = prNumberRaw ? parseInt(prNumberRaw, 10) : undefined;

  if (!branch) {
    console.error("Error: GIT_BRANCH environment variable is required");
    process.exit(1);
  }
  if (!commitSha) {
    console.error("Error: GIT_COMMIT environment variable is required");
    process.exit(1);
  }

  const ctx: GitContext = { branch, commitSha, tag, prNumber };
  const tags = generateTags(ctx);

  // Output each tag on its own line for easy consumption by shell scripts
  console.log("Generated Docker image tags:");
  for (const t of tags) {
    console.log(`  ${t}`);
  }

  // Also output as a comma-separated list for GitHub Actions outputs
  const joined = tags.join(",");
  console.log(`TAGS=${joined}`);
}

// Run main when executed directly (not imported)
if (import.meta.main) {
  main();
}
