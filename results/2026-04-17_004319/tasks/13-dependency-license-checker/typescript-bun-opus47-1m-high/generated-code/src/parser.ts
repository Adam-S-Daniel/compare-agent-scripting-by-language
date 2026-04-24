// Parses a package.json-style manifest into a flat list of dependencies.
// Combines `dependencies` and `devDependencies` since both must be vetted
// for licence compliance.

export interface Dependency {
  name: string;
  version: string;
}

export function parseManifest(manifestText: string): Dependency[] {
  let parsed: unknown;
  try {
    parsed = JSON.parse(manifestText);
  } catch (err) {
    const reason = err instanceof Error ? err.message : String(err);
    throw new Error(`Invalid manifest: not valid JSON (${reason})`);
  }

  if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("Invalid manifest: manifest must be a JSON object");
  }

  const manifest = parsed as Record<string, unknown>;
  const out: Dependency[] = [];

  for (const section of ["dependencies", "devDependencies"] as const) {
    const group = manifest[section];
    if (group === undefined) continue;
    if (group === null || typeof group !== "object" || Array.isArray(group)) {
      throw new Error(`Invalid manifest: '${section}' must be an object`);
    }
    for (const [name, version] of Object.entries(group as Record<string, unknown>)) {
      if (typeof version !== "string") {
        throw new Error(`Invalid manifest: version for '${name}' must be a string`);
      }
      out.push({ name, version });
    }
  }

  return out;
}
