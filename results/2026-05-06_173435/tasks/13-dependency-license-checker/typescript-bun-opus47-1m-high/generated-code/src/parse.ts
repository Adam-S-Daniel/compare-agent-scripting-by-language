// Manifest parsing.
//
// We extract dependency name + version from common manifest formats. Versions
// are normalized to a bare semver-ish string by stripping leading range
// specifiers (^, ~, >=, ==, etc.). Real-world resolution is a much harder
// problem, but for compliance reporting the manifest entry is enough.

export interface Dependency {
  name: string;
  version: string;
}

const RANGE_PREFIX_RE = /^[~^=<>!\s]+/;

function cleanVersion(raw: string): string {
  const trimmed = raw.trim();
  if (!trimmed) return "unknown";
  return trimmed.replace(RANGE_PREFIX_RE, "").trim() || "unknown";
}

export function parsePackageJson(content: string): Dependency[] {
  let parsed: unknown;
  try {
    parsed = JSON.parse(content);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    throw new Error(`Failed to parse package.json: ${msg}`);
  }
  if (!parsed || typeof parsed !== "object") {
    throw new Error("Failed to parse package.json: top-level value is not an object");
  }
  const obj = parsed as Record<string, unknown>;
  // Both runtime and dev deps count; lockfile-only entries are out of scope.
  const sections = ["dependencies", "devDependencies"] as const;
  const out: Dependency[] = [];
  for (const key of sections) {
    const section = obj[key];
    if (section && typeof section === "object") {
      for (const [name, version] of Object.entries(section as Record<string, unknown>)) {
        out.push({ name, version: cleanVersion(String(version)) });
      }
    }
  }
  return out;
}

export function parseRequirementsTxt(content: string): Dependency[] {
  const out: Dependency[] = [];
  for (const rawLine of content.split(/\r?\n/)) {
    // Strip inline comments and ignore blanks/comment-only lines.
    const line = rawLine.split("#")[0]!.trim();
    if (!line) continue;
    // Match "name<op>version" where <op> is one of the standard PEP-440 operators.
    const m = line.match(/^([A-Za-z0-9_.\-]+)\s*(==|>=|<=|~=|!=|>|<)\s*([A-Za-z0-9_.\-+*]+)/);
    if (m) {
      out.push({ name: m[1]!, version: m[3]! });
      continue;
    }
    // Bare name with no pin — record it but flag the version as unknown so
    // downstream code can decide what to do with floating deps.
    const bare = line.match(/^([A-Za-z0-9_.\-]+)$/);
    if (bare) {
      out.push({ name: bare[1]!, version: "unknown" });
    }
  }
  return out;
}

export function parseManifest(filename: string, content: string): Dependency[] {
  const base = filename.split(/[\\/]/).pop()!.toLowerCase();
  if (base === "package.json") return parsePackageJson(content);
  if (base === "requirements.txt") return parseRequirementsTxt(content);
  throw new Error(`Unsupported manifest: ${filename}`);
}
