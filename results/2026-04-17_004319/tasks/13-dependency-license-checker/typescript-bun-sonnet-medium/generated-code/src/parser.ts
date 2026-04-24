// Parses a package.json manifest and extracts all dependencies with clean versions.

import type { Dependency } from "./types";

// Strips semver range prefixes (^, ~, >=, >, <=, <, =) from a version string.
function cleanVersion(version: string): string {
  return version.replace(/^[^0-9]*/, "").trim();
}

// Parses JSON manifest content and returns a flat list of all dependencies.
// Includes both dependencies and devDependencies.
export function parseDependencies(manifestContent: string): Dependency[] {
  let pkg: Record<string, unknown>;
  try {
    pkg = JSON.parse(manifestContent);
  } catch {
    throw new Error("Failed to parse dependency manifest: invalid JSON");
  }

  const deps: Dependency[] = [];

  for (const section of ["dependencies", "devDependencies"] as const) {
    const block = pkg[section];
    if (block && typeof block === "object") {
      for (const [name, version] of Object.entries(
        block as Record<string, string>
      )) {
        deps.push({ name, version: cleanVersion(version) });
      }
    }
  }

  return deps;
}
