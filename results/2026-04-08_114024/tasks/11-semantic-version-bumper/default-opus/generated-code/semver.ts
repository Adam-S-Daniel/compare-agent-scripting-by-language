// Semantic version bumper — core library.
// Parses conventional commits, bumps semver, updates version files,
// and generates changelog entries.

// ── Types ────────────────────────────────────────────────────────────────────

export interface SemVer {
  major: number;
  minor: number;
  patch: number;
}

// ── Version parsing ──────────────────────────────────────────────────────────

const SEMVER_RE = /^v?(\d+)\.(\d+)\.(\d+)$/;

/** Parse a "major.minor.patch" string (optional leading "v"). */
export function parseVersion(raw: string): SemVer {
  const m = SEMVER_RE.exec(raw.trim());
  if (!m) throw new Error(`Invalid semantic version: "${raw}"`);
  return { major: Number(m[1]), minor: Number(m[2]), patch: Number(m[3]) };
}

/** Format a SemVer object back to a string. */
export function formatVersion(v: SemVer): string {
  return `${v.major}.${v.minor}.${v.patch}`;
}

// ── Commit parsing ───────────────────────────────────────────────────────────

export interface Commit {
  hash: string;
  message: string;
}

export interface ClassifiedCommits {
  major: Commit[];
  minor: Commit[];
  patch: Commit[];
}

export type BumpType = "major" | "minor" | "patch";

/**
 * Parse a git log (one commit per line: "<hash> <message>") into Commit objects.
 * Multi-line messages (e.g. with BREAKING CHANGE footers) are supported —
 * continuation lines that don't start with a hash are appended to the
 * previous commit's message.
 */
export function parseCommitLog(raw: string): Commit[] {
  const commits: Commit[] = [];
  // Matches lines starting with a hex hash (7+ chars) followed by a space
  const COMMIT_LINE = /^([0-9a-f]{7,}) (.+)$/;

  for (const line of raw.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed) continue;

    const m = COMMIT_LINE.exec(trimmed);
    if (m) {
      commits.push({ hash: m[1], message: m[2] });
    } else if (commits.length > 0) {
      // Continuation line (e.g. BREAKING CHANGE footer) — append to previous
      commits[commits.length - 1].message += "\n" + trimmed;
    }
  }
  return commits;
}

// Conventional commit prefix regex:  type(scope)?: message  or  type(scope)!: message
const CONVENTIONAL_RE = /^(\w+)(?:\([^)]*\))?(!)?: /;

/**
 * Classify commits by their impact level according to conventional commits:
 *   - "!" suffix or BREAKING CHANGE footer → major
 *   - "feat" type → minor
 *   - "fix" type → patch
 *   - everything else is ignored (docs, chore, ci, etc.)
 */
export function classifyCommits(commits: Commit[]): ClassifiedCommits {
  const result: ClassifiedCommits = { major: [], minor: [], patch: [] };

  for (const commit of commits) {
    // Check for BREAKING CHANGE footer anywhere in the message
    if (commit.message.includes("BREAKING CHANGE")) {
      result.major.push(commit);
      continue;
    }

    const m = CONVENTIONAL_RE.exec(commit.message);
    if (!m) continue; // non-conventional commit, skip

    const type = m[1];
    const bang = m[2]; // "!" if present

    if (bang) {
      result.major.push(commit);
    } else if (type === "feat") {
      result.minor.push(commit);
    } else if (type === "fix") {
      result.patch.push(commit);
    }
    // other types (docs, chore, etc.) are intentionally ignored
  }

  return result;
}

// ── Version bumping ──────────────────────────────────────────────────────────

/** Determine the highest-priority bump needed, or null if no bump is needed. */
export function determineBump(classified: ClassifiedCommits): BumpType | null {
  if (classified.major.length > 0) return "major";
  if (classified.minor.length > 0) return "minor";
  if (classified.patch.length > 0) return "patch";
  return null;
}

/** Apply a bump to a version, following semver rules (reset lower fields). */
export function bumpVersion(v: SemVer, bump: BumpType): SemVer {
  switch (bump) {
    case "major":
      return { major: v.major + 1, minor: 0, patch: 0 };
    case "minor":
      return { major: v.major, minor: v.minor + 1, patch: 0 };
    case "patch":
      return { major: v.major, minor: v.minor, patch: v.patch + 1 };
  }
}

// ── Version file I/O ─────────────────────────────────────────────────────────

/** Read the current version from a file (plain text or package.json). */
export async function readVersionFile(path: string): Promise<SemVer> {
  const content = await Bun.file(path).text();

  if (path.endsWith(".json")) {
    const pkg = JSON.parse(content);
    if (!pkg.version) throw new Error(`No "version" field found in ${path}`);
    return parseVersion(pkg.version);
  }

  // Plain text file — expect just the version string
  return parseVersion(content.trim());
}

/** Write a version to a file (plain text or package.json, preserving fields). */
export async function writeVersionFile(
  path: string,
  version: SemVer
): Promise<void> {
  const vStr = formatVersion(version);

  if (path.endsWith(".json")) {
    const content = await Bun.file(path).text();
    const pkg = JSON.parse(content);
    pkg.version = vStr;
    await Bun.write(path, JSON.stringify(pkg, null, 2) + "\n");
  } else {
    await Bun.write(path, vStr + "\n");
  }
}

// ── Changelog generation ─────────────────────────────────────────────────────

/** Strip the conventional commit prefix to get just the human-readable part. */
function stripPrefix(msg: string): string {
  // Take only the first line (ignore footers)
  const firstLine = msg.split("\n")[0];
  return firstLine.replace(CONVENTIONAL_RE, "");
}

/** Generate a markdown changelog entry for a release. */
export function generateChangelog(
  version: string,
  classified: ClassifiedCommits
): string {
  const lines: string[] = [];
  const date = new Date().toISOString().slice(0, 10);

  lines.push(`## ${version} (${date})`);
  lines.push("");

  if (classified.major.length > 0) {
    lines.push("### Breaking Changes");
    for (const c of classified.major) lines.push(`- ${stripPrefix(c.message)} (${c.hash})`);
    lines.push("");
  }

  if (classified.minor.length > 0) {
    lines.push("### Features");
    for (const c of classified.minor) lines.push(`- ${stripPrefix(c.message)} (${c.hash})`);
    lines.push("");
  }

  if (classified.patch.length > 0) {
    lines.push("### Bug Fixes");
    for (const c of classified.patch) lines.push(`- ${stripPrefix(c.message)} (${c.hash})`);
    lines.push("");
  }

  return lines.join("\n");
}
