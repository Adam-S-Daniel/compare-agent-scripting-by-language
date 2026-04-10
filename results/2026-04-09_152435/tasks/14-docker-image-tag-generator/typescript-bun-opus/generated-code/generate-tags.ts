#!/usr/bin/env bun

// Docker Image Tag Generator
// Generates Docker image tags from git context (branch, SHA, tags, PR number).
// Conventions:
//   - "latest" + "{branch}-{sha}" for main/master
//   - "pr-{number}" for pull requests
//   - "{tag}" + "{version}" for semver tags (e.g. v1.2.3 → v1.2.3, 1.2.3)
//   - "{branch}-{sha}" for feature branches
// All tags are sanitized: lowercase, no special chars except dots and hyphens.

// ---------- Types ----------

/** Git context used to determine which Docker tags to generate */
interface GitContext {
  ref: string;         // e.g. refs/heads/main, refs/tags/v1.2.3, refs/pull/42/merge
  sha: string;         // full commit SHA
  eventName: string;   // push, pull_request, etc.
  headRef?: string;    // source branch for PRs (GITHUB_HEAD_REF)
  prNumber?: number;   // PR number
}

/** Result containing the generated tags */
interface TagResult {
  tags: string[];
  primary: string;     // the first / most important tag
}

// ---------- Core logic ----------

/**
 * Sanitize a string for use as a Docker image tag.
 * Docker tags must match [a-zA-Z0-9._-]+, max 128 chars.
 * We additionally force lowercase for consistency.
 */
function sanitizeTag(raw: string): string {
  return raw
    .toLowerCase()
    .replace(/[^a-z0-9._-]/g, "-")   // replace disallowed chars with hyphens
    .replace(/-+/g, "-")              // collapse consecutive hyphens
    .replace(/^-+|-+$/g, "");         // strip leading/trailing hyphens
}

/**
 * Generate Docker image tags from the given git context.
 * Throws on invalid input (missing ref or sha).
 */
function generateTags(ctx: GitContext): TagResult {
  if (!ctx.ref) {
    throw new Error("ref is required (e.g. refs/heads/main)");
  }
  if (!ctx.sha || ctx.sha.length < 7) {
    throw new Error("sha must be at least 7 characters");
  }

  const shortSha = ctx.sha.substring(0, 7);
  const tags: string[] = [];

  // --- Tag push (refs/tags/...) ---
  if (ctx.ref.startsWith("refs/tags/")) {
    const tagName = ctx.ref.replace("refs/tags/", "");
    tags.push(sanitizeTag(tagName));

    // For semver tags like v1.2.3, also emit the bare version without "v"
    const semverMatch = tagName.match(/^v(\d+\.\d+\.\d+.*)$/i);
    if (semverMatch) {
      tags.push(sanitizeTag(semverMatch[1]));
    }
    return { tags, primary: tags[0] };
  }

  // --- Pull request ---
  if (ctx.eventName === "pull_request" && ctx.prNumber != null) {
    tags.push(`pr-${ctx.prNumber}`);
    if (ctx.headRef) {
      tags.push(`${sanitizeTag(ctx.headRef)}-${shortSha}`);
    }
    return { tags, primary: tags[0] };
  }

  // --- Branch push ---
  const branch = ctx.ref.replace("refs/heads/", "");
  const sanitizedBranch = sanitizeTag(branch);

  if (branch === "main" || branch === "master") {
    tags.push("latest");
    tags.push(`${sanitizedBranch}-${shortSha}`);
  } else {
    tags.push(`${sanitizedBranch}-${shortSha}`);
  }

  return { tags, primary: tags[0] };
}

// ---------- CLI entry point ----------

function main(): void {
  // Read git context from environment variables (set by GitHub Actions or overrides)
  const ctx: GitContext = {
    ref: process.env.INPUT_REF ?? process.env.GITHUB_REF ?? "",
    sha: process.env.INPUT_SHA ?? process.env.GITHUB_SHA ?? "",
    eventName: process.env.INPUT_EVENT ?? process.env.GITHUB_EVENT_NAME ?? "push",
    headRef: process.env.INPUT_HEAD_REF ?? process.env.GITHUB_HEAD_REF,
    prNumber: process.env.INPUT_PR_NUMBER
      ? parseInt(process.env.INPUT_PR_NUMBER, 10)
      : undefined,
  };

  try {
    const result = generateTags(ctx);

    console.log("=== Docker Image Tags ===");
    for (const tag of result.tags) {
      console.log(`  ${tag}`);
    }
    console.log(`Primary tag: ${result.primary}`);
    console.log(`Total tags: ${result.tags.length}`);

    // Output in GitHub Actions format (for downstream steps)
    const tagsJoined = result.tags.join(",");
    if (process.env.GITHUB_OUTPUT) {
      const fs = require("fs");
      fs.appendFileSync(process.env.GITHUB_OUTPUT, `tags=${tagsJoined}\n`);
      fs.appendFileSync(process.env.GITHUB_OUTPUT, `primary=${result.primary}\n`);
    }
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(`Error: ${msg}`);
    process.exit(1);
  }
}

main();

// Export for potential reuse (though all testing goes through the workflow)
export { sanitizeTag, generateTags, type GitContext, type TagResult };
