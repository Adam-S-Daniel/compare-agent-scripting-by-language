import { readFileSync, writeFileSync } from "fs";
import { extname } from "path";

export interface SemVersion {
  major: number;
  minor: number;
  patch: number;
}

export type BumpType = "major" | "minor" | "patch";

// Parse semantic version string like "1.2.3" or "v1.2.3"
export function parseVersion(versionString: string): SemVersion {
  const cleaned = versionString.trim().replace(/^v/, "");
  const match = cleaned.match(/^(\d+)\.(\d+)\.(\d+)$/);

  if (!match) {
    throw new Error(`Invalid semantic version: "${versionString}"`);
  }

  return {
    major: parseInt(match[1], 10),
    minor: parseInt(match[2], 10),
    patch: parseInt(match[3], 10),
  };
}

// Format a version object as string
export function formatVersion(version: SemVersion): string {
  return `${version.major}.${version.minor}.${version.patch}`;
}

// Bump version based on commit type
export function bumpVersion(version: SemVersion, bumpType: BumpType): SemVersion {
  switch (bumpType) {
    case "major":
      return { major: version.major + 1, minor: 0, patch: 0 };
    case "minor":
      return { major: version.major, minor: version.minor + 1, patch: 0 };
    case "patch":
      return { major: version.major, minor: version.minor, patch: version.patch + 1 };
  }
}

// Read version from package.json or VERSION file
export function readVersionFile(filePath: string): string {
  const content = readFileSync(filePath, "utf-8");
  const ext = extname(filePath);

  if (ext === ".json") {
    const pkg = JSON.parse(content);
    if (!pkg.version) {
      throw new Error(`No version field in ${filePath}`);
    }
    return pkg.version;
  }

  // Plain text VERSION file
  return content.trim();
}

// Write version to package.json or VERSION file
export function writeVersionFile(filePath: string, newVersion: string): void {
  const ext = extname(filePath);

  if (ext === ".json") {
    const content = readFileSync(filePath, "utf-8");
    const pkg = JSON.parse(content);
    pkg.version = newVersion;
    writeFileSync(filePath, JSON.stringify(pkg, null, 2) + "\n");
  } else {
    writeFileSync(filePath, newVersion + "\n");
  }
}
