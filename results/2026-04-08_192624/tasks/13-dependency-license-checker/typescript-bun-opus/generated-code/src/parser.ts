// Manifest parser — extracts dependencies from package.json and requirements.txt
import type { Dependency } from "./types";

/**
 * Parse a package.json string and extract all dependencies (both regular and dev).
 * Throws on invalid JSON with a meaningful error message.
 */
export function parsePackageJson(content: string): Dependency[] {
  let parsed: Record<string, unknown>;
  try {
    parsed = JSON.parse(content);
  } catch {
    throw new Error("Invalid package.json: failed to parse JSON");
  }

  const deps: Dependency[] = [];
  const sections = ["dependencies", "devDependencies"] as const;

  for (const section of sections) {
    const entries = parsed[section];
    if (entries && typeof entries === "object") {
      for (const [name, version] of Object.entries(entries as Record<string, string>)) {
        deps.push({ name, version });
      }
    }
  }

  return deps;
}

/**
 * Parse a requirements.txt string and extract dependency names and versions.
 * Supports ==, >=, <=, ~=, != version operators; extracts the version number.
 * Packages without a version get version "*".
 */
export function parseRequirementsTxt(content: string): Dependency[] {
  const deps: Dependency[] = [];

  for (const rawLine of content.split("\n")) {
    const line = rawLine.trim();
    // Skip empty lines and comments
    if (!line || line.startsWith("#")) continue;

    // Match patterns like: package==1.0.0, package>=1.0.0, etc.
    const match = line.match(/^([a-zA-Z0-9_.-]+)\s*(?:[><=!~]+)\s*(.+)$/);
    if (match) {
      deps.push({ name: match[1], version: match[2].trim() });
    } else {
      // Package with no version specifier
      deps.push({ name: line.trim(), version: "*" });
    }
  }

  return deps;
}

/**
 * Auto-detect manifest type by filename and parse accordingly.
 * Throws for unsupported manifest types.
 */
export function parseManifest(filename: string, content: string): Dependency[] {
  if (filename.endsWith("package.json")) {
    return parsePackageJson(content);
  }
  if (filename.endsWith("requirements.txt")) {
    return parseRequirementsTxt(content);
  }
  throw new Error(`Unsupported manifest type: ${filename}`);
}
