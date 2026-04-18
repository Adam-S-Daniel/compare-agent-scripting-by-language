// Parse a package.json-format manifest and return a flat list of
// dependencies. We merge `dependencies` and `devDependencies` since
// license compliance applies to anything that ships or runs in CI.

import type { Dependency } from "./types.ts";

// Strip common semver-range prefixes so downstream code can compare
// versions as plain strings. We do NOT try to resolve the range — a
// real checker would lock to the installed version via the lockfile,
// but for the scope of this task the declared version is sufficient.
function normalizeVersion(raw: string): string {
  return raw.trim().replace(/^[\^~]|^>=?|^<=?|^=/, "").trim();
}

export function parsePackageJson(source: string): Dependency[] {
  let manifest: unknown;
  try {
    manifest = JSON.parse(source);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    throw new Error(`Failed to parse manifest: ${msg}`);
  }
  if (manifest === null || typeof manifest !== "object" || Array.isArray(manifest)) {
    throw new Error("Manifest must be a JSON object at the top level.");
  }
  const m = manifest as Record<string, unknown>;
  const sections: Array<Record<string, unknown> | undefined> = [
    m.dependencies as Record<string, unknown> | undefined,
    m.devDependencies as Record<string, unknown> | undefined,
  ];
  const out: Dependency[] = [];
  for (const section of sections) {
    if (!section || typeof section !== "object") continue;
    for (const [name, version] of Object.entries(section)) {
      if (typeof version !== "string") continue;
      out.push({ name, version: normalizeVersion(version) });
    }
  }
  return out;
}
