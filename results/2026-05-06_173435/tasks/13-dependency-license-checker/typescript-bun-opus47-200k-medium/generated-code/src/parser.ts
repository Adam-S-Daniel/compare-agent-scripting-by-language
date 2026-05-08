// Parses dependency manifests into a normalized list of {name, version}.
// Supports two common formats: npm's package.json and pip's requirements.txt.

export interface Dependency {
  name: string;
  version: string;
}

export function parseManifest(filename: string, contents: string): Dependency[] {
  const base = filename.split(/[\\/]/).pop() ?? filename;
  if (base === "package.json") return parsePackageJson(contents);
  if (base === "requirements.txt") return parseRequirements(contents);
  throw new Error(`Unsupported manifest type: ${base}`);
}

function parsePackageJson(contents: string): Dependency[] {
  let data: { dependencies?: Record<string, string>; devDependencies?: Record<string, string> };
  try {
    data = JSON.parse(contents);
  } catch (err) {
    throw new Error(`Invalid package.json: ${(err as Error).message}`);
  }
  const out: Dependency[] = [];
  for (const block of [data.dependencies, data.devDependencies]) {
    if (!block) continue;
    for (const [name, version] of Object.entries(block)) {
      out.push({ name, version });
    }
  }
  return out;
}

// requirements.txt grammar we handle: "name<op>version" where <op> is one of
// ==, >=, <=, ~=, >, <. Lines starting with # and blank lines are ignored.
function parseRequirements(contents: string): Dependency[] {
  const out: Dependency[] = [];
  for (const rawLine of contents.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;
    const match = line.match(/^([A-Za-z0-9_.\-]+)\s*(==|>=|<=|~=|>|<)?\s*(.*)$/);
    if (!match) continue;
    const [, name, op, ver] = match;
    const version = op ? `${op}${ver.trim()}` : "*";
    out.push({ name, version });
  }
  return out;
}
