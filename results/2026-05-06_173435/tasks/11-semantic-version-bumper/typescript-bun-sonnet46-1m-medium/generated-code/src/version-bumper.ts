// Semantic version bumper implementation
// Parses conventional commits and determines the next semver bump.
import * as fs from "fs";
import type {
  SemanticVersion,
  ConventionalCommit,
  BumpType,
  ChangelogEntry,
  TestFixture,
} from "./types";

// --- Version parsing ---

export function parseVersion(versionString: string): SemanticVersion {
  // Strip optional leading 'v'
  const clean = versionString.replace(/^v/, "");
  const match = clean.match(/^(\d+)\.(\d+)\.(\d+)$/);
  if (!match) {
    throw new Error(`Invalid semantic version: "${versionString}". Expected format: X.Y.Z`);
  }
  return {
    major: parseInt(match[1], 10),
    minor: parseInt(match[2], 10),
    patch: parseInt(match[3], 10),
  };
}

export function formatVersion(version: SemanticVersion): string {
  return `${version.major}.${version.minor}.${version.patch}`;
}

// --- Conventional commit parsing ---
// Spec: https://www.conventionalcommits.org/en/v1.0.0/

export function parseCommit(message: string): ConventionalCommit {
  // Split on first newline to separate subject from body/footer
  const lines = message.split("\n");
  const subject = lines[0].trim();
  const rest = lines.slice(1).join("\n");

  // Pattern: type(scope)!: description  OR  type!: description  OR  type: description
  const headerPattern = /^([a-zA-Z]+)(\([^)]+\))?(!)?:\s*(.+)$/;
  const match = subject.match(headerPattern);

  if (!match) {
    return {
      type: "other",
      description: subject,
      isBreaking: false,
      raw: message,
    };
  }

  const type = match[1];
  const scope = match[2] ? match[2].slice(1, -1) : undefined; // strip parens
  const bang = match[3] === "!";
  const description = match[4].trim();

  // BREAKING CHANGE footer also marks a breaking change
  const hasBreakingFooter = /BREAKING[ -]CHANGE:/i.test(rest);
  const isBreaking = bang || hasBreakingFooter;

  return { type, scope, description, isBreaking, raw: message };
}

// --- Bump type determination ---

// Priority order: major > minor > patch > none
const BUMP_PRIORITY: Record<BumpType, number> = {
  major: 3,
  minor: 2,
  patch: 1,
  none: 0,
};

export function determineBumpType(commits: ConventionalCommit[]): BumpType {
  let highest: BumpType = "none";

  for (const commit of commits) {
    let bump: BumpType = "none";

    if (commit.isBreaking) {
      bump = "major";
    } else if (commit.type === "feat") {
      bump = "minor";
    } else if (commit.type === "fix" || commit.type === "perf") {
      bump = "patch";
    }

    if (BUMP_PRIORITY[bump] > BUMP_PRIORITY[highest]) {
      highest = bump;
    }
  }

  return highest;
}

// --- Version bumping ---

export function bumpVersion(version: SemanticVersion, bumpType: BumpType): SemanticVersion {
  switch (bumpType) {
    case "major":
      return { major: version.major + 1, minor: 0, patch: 0 };
    case "minor":
      return { major: version.major, minor: version.minor + 1, patch: 0 };
    case "patch":
      return { major: version.major, minor: version.minor, patch: version.patch + 1 };
    case "none":
      return { ...version };
  }
}

// --- Changelog generation ---

export function generateChangelog(
  commits: ConventionalCommit[],
  newVersion: string,
  date?: string
): ChangelogEntry {
  const entry: ChangelogEntry = {
    version: newVersion,
    date: date ?? new Date().toISOString().split("T")[0],
    breaking: [],
    features: [],
    fixes: [],
    other: [],
  };

  for (const commit of commits) {
    if (commit.isBreaking) {
      entry.breaking.push(commit.description);
    }
    if (commit.type === "feat" && !commit.isBreaking) {
      entry.features.push(commit.description);
    } else if (commit.type === "fix" || commit.type === "perf") {
      const label = commit.scope ? `${commit.scope}: ${commit.description}` : commit.description;
      entry.fixes.push(label);
    } else if (!commit.isBreaking && commit.type !== "feat") {
      entry.other.push(`${commit.type}: ${commit.description}`);
    }
  }

  return entry;
}

export function formatChangelog(entry: ChangelogEntry): string {
  const lines: string[] = [`## [${entry.version}] - ${entry.date}`, ""];

  if (entry.breaking.length > 0) {
    lines.push("### BREAKING CHANGES", "");
    for (const b of entry.breaking) lines.push(`- ${b}`);
    lines.push("");
  }
  if (entry.features.length > 0) {
    lines.push("### Features", "");
    for (const f of entry.features) lines.push(`- ${f}`);
    lines.push("");
  }
  if (entry.fixes.length > 0) {
    lines.push("### Bug Fixes", "");
    for (const f of entry.fixes) lines.push(`- ${f}`);
    lines.push("");
  }
  if (entry.other.length > 0) {
    lines.push("### Other", "");
    for (const o of entry.other) lines.push(`- ${o}`);
    lines.push("");
  }

  return lines.join("\n");
}

// --- File I/O ---

export function readVersionFromFile(filePath: string): SemanticVersion {
  if (!fs.existsSync(filePath)) {
    throw new Error(`Version file not found: ${filePath}`);
  }
  const content = fs.readFileSync(filePath, "utf-8");
  let parsed: { version?: string };
  try {
    parsed = JSON.parse(content);
  } catch {
    throw new Error(`Failed to parse JSON from: ${filePath}`);
  }
  if (!parsed.version) {
    throw new Error(`No "version" field found in: ${filePath}`);
  }
  return parseVersion(parsed.version);
}

export function writeVersionToFile(filePath: string, version: SemanticVersion): void {
  const content = fs.readFileSync(filePath, "utf-8");
  const parsed = JSON.parse(content);
  parsed.version = formatVersion(version);
  fs.writeFileSync(filePath, JSON.stringify(parsed, null, 2) + "\n");
}

// --- CLI entry point ---

async function main(): Promise<void> {
  const args = process.argv.slice(2);

  // Parse --fixture <path> flag
  const fixtureIdx = args.indexOf("--fixture");
  const fixtureFile = fixtureIdx !== -1 ? args[fixtureIdx + 1] : "fixtures/test-case.json";

  // Parse --version-file <path> flag
  const vfIdx = args.indexOf("--version-file");
  const defaultVersionFile = "package.json";
  const versionFile = vfIdx !== -1 ? args[vfIdx + 1] : defaultVersionFile;

  let currentVersion: SemanticVersion;
  let rawCommits: string[];

  // If a fixture file is provided, use it (for CI/CD testing)
  if (fs.existsSync(fixtureFile)) {
    const fixture: TestFixture = JSON.parse(fs.readFileSync(fixtureFile, "utf-8"));
    currentVersion = parseVersion(fixture.currentVersion);
    rawCommits = fixture.commits;
    console.log(`Using fixture: ${fixtureFile}`);
  } else {
    // Production mode: read version from file, commits from stdin or git
    currentVersion = readVersionFromFile(versionFile);
    // Read commits from stdin if piped, otherwise use placeholder
    const stdinData = fs.readFileSync("/dev/stdin", "utf-8").trim();
    rawCommits = stdinData ? stdinData.split("\n").filter(Boolean) : [];
    console.log(`Reading version from: ${versionFile}`);
  }

  const commits = rawCommits.map(parseCommit);
  const bumpType = determineBumpType(commits);
  const newVersion = bumpVersion(currentVersion, bumpType);
  const newVersionStr = formatVersion(newVersion);

  const entry = generateChangelog(commits, newVersionStr);
  const changelogText = formatChangelog(entry);

  console.log(`Current version: ${formatVersion(currentVersion)}`);
  console.log(`Bump type: ${bumpType}`);
  console.log(`New version: ${newVersionStr}`);
  console.log("");
  console.log("Changelog:");
  console.log(changelogText);

  // Update the version file if using a real version file (not fixture mode)
  if (!fs.existsSync(fixtureFile) && fs.existsSync(versionFile)) {
    writeVersionToFile(versionFile, newVersion);
    console.log(`Updated ${versionFile} to ${newVersionStr}`);
  }
}

// Only run main when executed directly, not when imported as a module
if (import.meta.main) {
  main().catch((err) => {
    console.error(`Error: ${err.message}`);
    process.exit(1);
  });
}
