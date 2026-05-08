import type { Dependency } from "./types";

export function parsePackageJson(content: string): Dependency[] {
  let pkg: Record<string, unknown>;
  try {
    pkg = JSON.parse(content);
  } catch {
    throw new Error("Invalid package.json: failed to parse JSON");
  }

  const deps: Dependency[] = [];
  const sections = ["dependencies", "devDependencies"] as const;

  for (const section of sections) {
    const entries = pkg[section];
    if (entries && typeof entries === "object") {
      for (const [name, version] of Object.entries(entries as Record<string, string>)) {
        deps.push({ name, version });
      }
    }
  }

  return deps;
}

export function parseRequirementsTxt(content: string): Dependency[] {
  const deps: Dependency[] = [];

  for (const raw of content.split("\n")) {
    const line = raw.trim();
    if (!line || line.startsWith("#")) continue;

    const match = line.match(/^([a-zA-Z0-9_.-]+)\s*(([><=!~]+).+)?$/);
    if (!match) continue;

    const name = match[1];
    const versionSpec = match[2];

    if (!versionSpec) {
      deps.push({ name, version: "*" });
    } else if (versionSpec.startsWith("==")) {
      deps.push({ name, version: versionSpec.slice(2) });
    } else {
      deps.push({ name, version: versionSpec });
    }
  }

  return deps;
}
