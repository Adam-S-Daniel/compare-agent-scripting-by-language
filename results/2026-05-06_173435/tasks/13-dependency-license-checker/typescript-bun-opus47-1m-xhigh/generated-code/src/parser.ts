// Manifest parser. Detects format from filename and returns a flat list of
// (name, version) pairs. Results are sorted by name to keep downstream output
// deterministic regardless of object-key ordering.

export interface Dependency {
  name: string;
  version: string;
  source: string;
}

type ParserFn = (text: string) => Array<Pick<Dependency, "name" | "version">>;

const parsers: Record<string, ParserFn> = {
  "package.json": parsePackageJson,
  "requirements.txt": parseRequirementsTxt,
};

export function parseManifest(filename: string, text: string): Dependency[] {
  const baseName = filename.split("/").pop() ?? filename;
  const parser = parsers[baseName];
  if (!parser) {
    throw new Error(
      `Unsupported manifest "${baseName}". Supported: ${Object.keys(parsers).join(", ")}`,
    );
  }
  const raw = parser(text);
  return raw
    .map((d) => ({ ...d, source: baseName }))
    .sort((a, b) => a.name.localeCompare(b.name));
}

function parsePackageJson(text: string): Array<Pick<Dependency, "name" | "version">> {
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch (err) {
    throw new Error(`Failed to parse package.json: ${(err as Error).message}`);
  }
  if (typeof parsed !== "object" || parsed === null) {
    throw new Error("Failed to parse package.json: top-level value is not an object");
  }
  const pkg = parsed as Record<string, unknown>;
  // Cover the common dep buckets npm understands.
  const buckets = ["dependencies", "devDependencies", "optionalDependencies", "peerDependencies"];
  const out: Array<Pick<Dependency, "name" | "version">> = [];
  for (const bucket of buckets) {
    const obj = pkg[bucket];
    if (!obj || typeof obj !== "object") continue;
    for (const [name, version] of Object.entries(obj as Record<string, unknown>)) {
      if (typeof version !== "string") continue;
      out.push({ name, version });
    }
  }
  return out;
}

function parseRequirementsTxt(text: string): Array<Pick<Dependency, "name" | "version">> {
  // PEP 508 is broad; we cover the common pin/range operators here.
  // Anything we can't recognise is reported with version "unspecified" so
  // it still surfaces in the compliance report rather than being silently dropped.
  const out: Array<Pick<Dependency, "name" | "version">> = [];
  const lines = text.split(/\r?\n/);
  const opPattern = /(==|>=|<=|~=|!=|>|<|===)/;
  for (const rawLine of lines) {
    const line = rawLine.split("#")[0]?.trim();
    if (!line) continue;
    const match = line.match(opPattern);
    if (!match || match.index === undefined) {
      // Bare name with no version specifier.
      out.push({ name: line, version: "unspecified" });
      continue;
    }
    const name = line.slice(0, match.index).trim();
    const version = line.slice(match.index).trim();
    if (!name) continue;
    out.push({ name, version });
  }
  return out;
}
