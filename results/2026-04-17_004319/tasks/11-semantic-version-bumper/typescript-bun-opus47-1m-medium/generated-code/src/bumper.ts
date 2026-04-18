// Core semantic-version-bumper logic.
// Pure functions that make the behavior easy to unit-test.

export type BumpLevel = "major" | "minor" | "patch" | "none";

export interface Version {
  major: number;
  minor: number;
  patch: number;
}

export interface Commit {
  subject: string;
  body: string;
}

const SEMVER_RE = /^(\d+)\.(\d+)\.(\d+)$/;

export function parseVersion(v: string): Version {
  const m = SEMVER_RE.exec(v.trim());
  if (!m) throw new Error(`Invalid semantic version: "${v}"`);
  return { major: +m[1]!, minor: +m[2]!, patch: +m[3]! };
}

export function formatVersion(v: Version): string {
  return `${v.major}.${v.minor}.${v.patch}`;
}

// Conventional commits: "type(scope)?!?: subject". "!" or "BREAKING CHANGE:" -> major.
const HEADER_RE = /^(\w+)(?:\([^)]*\))?(!)?: /;

export function classifyCommit(message: string): BumpLevel {
  const firstLine = message.split("\n", 1)[0] ?? "";
  const m = HEADER_RE.exec(firstLine);
  if (m?.[2] === "!") return "major";
  if (/(^|\n)BREAKING CHANGE:/.test(message)) return "major";
  const type = m?.[1]?.toLowerCase();
  if (type === "feat") return "minor";
  if (type === "fix") return "patch";
  return "none";
}

const RANK: Record<BumpLevel, number> = { none: 0, patch: 1, minor: 2, major: 3 };

export function determineBump(commitMessages: string[]): BumpLevel {
  let best: BumpLevel = "none";
  for (const msg of commitMessages) {
    const level = classifyCommit(msg);
    if (RANK[level] > RANK[best]) best = level;
  }
  return best;
}

export function bumpVersion(current: string, level: BumpLevel): string {
  const v = parseVersion(current);
  switch (level) {
    case "major":
      return formatVersion({ major: v.major + 1, minor: 0, patch: 0 });
    case "minor":
      return formatVersion({ major: v.major, minor: v.minor + 1, patch: 0 });
    case "patch":
      return formatVersion({ major: v.major, minor: v.minor, patch: v.patch + 1 });
    case "none":
      return current;
  }
}

export function generateChangelog(
  newVersion: string,
  commits: Commit[],
  date: string,
): string {
  const breaking: string[] = [];
  const features: string[] = [];
  const fixes: string[] = [];

  for (const c of commits) {
    const full = c.body ? `${c.subject}\n\n${c.body}` : c.subject;
    const level = classifyCommit(full);
    // Strip the "type(scope)?!?: " prefix for readable changelog entries.
    const clean = c.subject.replace(HEADER_RE, "");
    if (level === "major") breaking.push(clean);
    else if (level === "minor") features.push(clean);
    else if (level === "patch") fixes.push(clean);
  }

  const lines: string[] = [`## ${newVersion} - ${date}`, ""];
  if (breaking.length) {
    lines.push("### Breaking Changes", "");
    for (const s of breaking) lines.push(`- ${s}`);
    lines.push("");
  }
  if (features.length) {
    lines.push("### Features", "");
    for (const s of features) lines.push(`- ${s}`);
    lines.push("");
  }
  if (fixes.length) {
    lines.push("### Fixes", "");
    for (const s of fixes) lines.push(`- ${s}`);
    lines.push("");
  }
  return lines.join("\n");
}
