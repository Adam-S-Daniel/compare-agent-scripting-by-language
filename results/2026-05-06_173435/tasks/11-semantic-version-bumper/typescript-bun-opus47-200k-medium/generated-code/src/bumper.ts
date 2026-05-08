// Semantic version bumper based on conventional commits.
// Parses commits, determines bump type, and produces a new version + changelog.

export type BumpType = "major" | "minor" | "patch" | "none";

export interface ParsedVersion {
  major: number;
  minor: number;
  patch: number;
}

export interface ParsedCommit {
  type: string;
  scope: string | null;
  breaking: boolean;
  subject: string;
  raw: string;
}

export interface BumpResult {
  oldVersion: string;
  newVersion: string;
  bumpType: BumpType;
  changelog: string;
  commits: ParsedCommit[];
}

// Parse a semantic version string like "1.2.3" into components.
export function parseVersion(v: string): ParsedVersion {
  const m = v.trim().match(/^(\d+)\.(\d+)\.(\d+)$/);
  if (!m) throw new Error(`Invalid semantic version: ${v}`);
  return { major: Number(m[1]), minor: Number(m[2]), patch: Number(m[3]) };
}

export function formatVersion(v: ParsedVersion): string {
  return `${v.major}.${v.minor}.${v.patch}`;
}

// Parse a single conventional commit subject line.
// Accepts forms: "type: subject", "type(scope): subject", "type!: subject", "type(scope)!: subject".
// A line containing "BREAKING CHANGE:" anywhere also marks the commit as breaking.
export function parseCommit(raw: string): ParsedCommit | null {
  const trimmed = raw.trim();
  if (!trimmed) return null;
  const firstLine = trimmed.split("\n")[0];
  const m = firstLine.match(/^(\w+)(?:\(([^)]+)\))?(!)?:\s*(.+)$/);
  if (!m) return null;
  const type = m[1].toLowerCase();
  const scope = m[2] ?? null;
  const bangBreaking = !!m[3];
  const subject = m[4];
  const bodyBreaking = /BREAKING[ -]CHANGE:/.test(trimmed);
  return {
    type,
    scope,
    breaking: bangBreaking || bodyBreaking,
    subject,
    raw: trimmed,
  };
}

// Split a commit log into individual commits. Each commit starts with a
// conventional-commit header line; following non-header lines are body and
// stay with the preceding commit (so BREAKING CHANGE: footers work).
// Blank lines and "---" delimiter lines are ignored as separators.
export function parseCommits(log: string): ParsedCommit[] {
  const headerRe = /^(\w+)(?:\(([^)]+)\))?(!)?:\s*(.+)$/;
  const lines = log.split(/\r?\n/);
  const blocks: string[] = [];
  let current: string[] = [];
  const flush = () => {
    if (current.length) {
      blocks.push(current.join("\n").trim());
      current = [];
    }
  };
  for (const line of lines) {
    if (line.trim() === "" || line.trim() === "---") {
      flush();
      continue;
    }
    if (headerRe.test(line)) {
      flush();
      current.push(line);
    } else {
      current.push(line);
    }
  }
  flush();
  const commits: ParsedCommit[] = [];
  for (const b of blocks) {
    const c = parseCommit(b);
    if (c) commits.push(c);
  }
  return commits;
}

// Determine bump type based on commit list. Conventional commits semantics:
// any breaking -> major, else any "feat" -> minor, else any "fix" -> patch, else none.
export function determineBump(commits: ParsedCommit[]): BumpType {
  if (commits.some((c) => c.breaking)) return "major";
  if (commits.some((c) => c.type === "feat")) return "minor";
  if (commits.some((c) => c.type === "fix")) return "patch";
  return "none";
}

export function bumpVersion(version: string, bump: BumpType): string {
  const v = parseVersion(version);
  switch (bump) {
    case "major":
      return formatVersion({ major: v.major + 1, minor: 0, patch: 0 });
    case "minor":
      return formatVersion({ major: v.major, minor: v.minor + 1, patch: 0 });
    case "patch":
      return formatVersion({ major: v.major, minor: v.minor, patch: v.patch + 1 });
    case "none":
      return formatVersion(v);
  }
}

// Generate a markdown changelog entry grouping commits by type.
export function generateChangelog(
  newVersion: string,
  commits: ParsedCommit[],
  date: string = new Date().toISOString().slice(0, 10),
): string {
  const breaking = commits.filter((c) => c.breaking);
  const feats = commits.filter((c) => !c.breaking && c.type === "feat");
  const fixes = commits.filter((c) => !c.breaking && c.type === "fix");
  const others = commits.filter(
    (c) => !c.breaking && c.type !== "feat" && c.type !== "fix",
  );

  const lines: string[] = [];
  lines.push(`## ${newVersion} - ${date}`);
  const section = (title: string, list: ParsedCommit[]) => {
    if (list.length === 0) return;
    lines.push("");
    lines.push(`### ${title}`);
    for (const c of list) {
      const scope = c.scope ? `**${c.scope}**: ` : "";
      lines.push(`- ${scope}${c.subject}`);
    }
  };
  section("Breaking Changes", breaking);
  section("Features", feats);
  section("Bug Fixes", fixes);
  section("Other", others);
  lines.push("");
  return lines.join("\n");
}

// Read a version from package.json or a plain VERSION file.
export function readVersionFromContent(content: string, filename: string): string {
  if (filename.endsWith(".json")) {
    const obj = JSON.parse(content);
    if (typeof obj.version !== "string")
      throw new Error(`No string "version" field in ${filename}`);
    return obj.version;
  }
  return content.trim();
}

export function writeVersionToContent(
  content: string,
  filename: string,
  newVersion: string,
): string {
  if (filename.endsWith(".json")) {
    const obj = JSON.parse(content);
    obj.version = newVersion;
    return JSON.stringify(obj, null, 2) + "\n";
  }
  return newVersion + "\n";
}

export function bump(
  currentVersion: string,
  commitLog: string,
  date?: string,
): BumpResult {
  const commits = parseCommits(commitLog);
  const bumpType = determineBump(commits);
  const newVersion = bumpVersion(currentVersion, bumpType);
  const changelog = generateChangelog(newVersion, commits, date);
  return {
    oldVersion: currentVersion,
    newVersion,
    bumpType,
    changelog,
    commits,
  };
}
