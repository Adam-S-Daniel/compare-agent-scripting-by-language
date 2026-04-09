// Manifest parser: extracts dependency names and versions from
// package.json and requirements.txt formats.

import type { Dependency } from "./types";

/** Parse a package.json string and extract all dependencies */
export function parsePackageJson(content: string): Dependency[] {
  const pkg = JSON.parse(content);
  const deps: Dependency[] = [];

  // Collect both regular and dev dependencies
  for (const section of ["dependencies", "devDependencies"] as const) {
    const entries = pkg[section];
    if (entries && typeof entries === "object") {
      for (const [name, version] of Object.entries(entries)) {
        deps.push({ name, version: version as string });
      }
    }
  }

  return deps;
}

/** Parse a requirements.txt string and extract all dependencies */
export function parseRequirementsTxt(content: string): Dependency[] {
  const deps: Dependency[] = [];

  for (const rawLine of content.split("\n")) {
    const line = rawLine.trim();
    // Skip blank lines and comments
    if (!line || line.startsWith("#")) continue;

    // Match: package==version, package>=version, package~=version, etc.
    const match = line.match(/^([a-zA-Z0-9_.-]+)\s*(([>=<!~]+.+)?)$/);
    if (match) {
      const name = match[1];
      const versionSpec = match[2];

      if (!versionSpec) {
        deps.push({ name, version: "*" });
      } else if (versionSpec.startsWith("==")) {
        // Pinned version: strip the ==
        deps.push({ name, version: versionSpec.slice(2) });
      } else {
        // Range or other specifier: keep as-is
        deps.push({ name, version: versionSpec });
      }
    }
  }

  return deps;
}

/** Auto-detect manifest type by filename and parse accordingly.
 *  Supports exact names (package.json, requirements.txt) and also
 *  files ending with .json (treated as package.json format) or
 *  .txt (treated as requirements.txt format). */
export function parseManifest(filename: string, content: string): Dependency[] {
  const basename = filename.split("/").pop() ?? filename;

  if (basename === "package.json" || basename.endsWith(".json")) {
    return parsePackageJson(content);
  } else if (basename === "requirements.txt" || basename.endsWith(".txt")) {
    return parseRequirementsTxt(content);
  }

  throw new Error(`Unsupported manifest file: ${basename}`);
}
