// Core library for parsing manifests, classifying licenses, and rendering reports.
// All I/O (manifest read, license lookup) is injected so the logic stays testable.

export interface Dependency {
  name: string;
  version: string;
}

export interface LicenseConfig {
  allow: string[];
  deny: string[];
}

export type ComplianceStatus = "approved" | "denied" | "unknown";

export interface ReportEntry {
  name: string;
  version: string;
  license: string | undefined;
  status: ComplianceStatus;
}

export type LicenseLookup = (dep: Dependency) => Promise<string | undefined>;

// Parse a manifest blob. Supports package.json (JSON) and requirements.txt (pip format).
export function parseManifest(content: string, filename: string): Dependency[] {
  const lower = filename.toLowerCase();
  if (lower.endsWith("package.json")) {
    return parsePackageJson(content);
  }
  if (lower.endsWith("requirements.txt")) {
    return parseRequirementsTxt(content);
  }
  throw new Error(`Unsupported manifest type: ${filename}`);
}

function parsePackageJson(content: string): Dependency[] {
  let data: unknown;
  try {
    data = JSON.parse(content);
  } catch (err) {
    throw new Error(`Failed to parse package.json: ${(err as Error).message}`);
  }
  if (typeof data !== "object" || data === null) {
    throw new Error("Failed to parse package.json: expected an object");
  }
  const obj = data as Record<string, unknown>;
  const deps: Dependency[] = [];
  for (const key of ["dependencies", "devDependencies"]) {
    const section = obj[key];
    if (section && typeof section === "object") {
      for (const [name, version] of Object.entries(section as Record<string, unknown>)) {
        deps.push({ name, version: String(version) });
      }
    }
  }
  return deps;
}

function parseRequirementsTxt(content: string): Dependency[] {
  // Minimal parser: "name<op>version" per line; strip comments and blanks.
  const deps: Dependency[] = [];
  for (const rawLine of content.split(/\r?\n/)) {
    const line = rawLine.replace(/#.*$/, "").trim();
    if (!line) continue;
    const match = line.match(/^([A-Za-z0-9_.\-]+)\s*(?:==|>=|<=|~=|>|<)?\s*(.*)$/);
    if (match) {
      deps.push({ name: match[1]!, version: match[2]!.trim() });
    }
  }
  return deps;
}

// Classify a license string against the config. Deny overrides allow.
export function classifyLicense(
  license: string | undefined,
  config: LicenseConfig,
): ComplianceStatus {
  if (!license) return "unknown";
  if (config.deny.includes(license)) return "denied";
  if (config.allow.includes(license)) return "approved";
  return "unknown";
}

// Resolve licenses for each dependency via the injected lookup and classify.
export async function checkDependencies(
  deps: Dependency[],
  config: LicenseConfig,
  lookup: LicenseLookup,
): Promise<ReportEntry[]> {
  const out: ReportEntry[] = [];
  for (const dep of deps) {
    let license: string | undefined;
    try {
      license = await lookup(dep);
    } catch (err) {
      // A lookup failure for a single dep should not crash the whole report.
      license = undefined;
      console.error(
        `Warning: license lookup failed for ${dep.name}@${dep.version}: ${(err as Error).message}`,
      );
    }
    out.push({
      name: dep.name,
      version: dep.version,
      license,
      status: classifyLicense(license, config),
    });
  }
  return out;
}

// Render a fixed-format compliance report. The format is parsed by the CI test harness.
export function generateReport(entries: ReportEntry[]): string {
  const counts = { approved: 0, denied: 0, unknown: 0 };
  for (const e of entries) counts[e.status]++;
  const lines: string[] = [];
  lines.push("=== Dependency License Compliance Report ===");
  lines.push(`Total dependencies: ${entries.length}`);
  lines.push(`Approved: ${counts.approved}`);
  lines.push(`Denied:   ${counts.denied}`);
  lines.push(`Unknown:  ${counts.unknown}`);
  lines.push("");
  lines.push("Details:");
  for (const e of entries) {
    const lic = e.license ?? "N/A";
    lines.push(`  [${e.status.toUpperCase()}] ${e.name}@${e.version} — ${lic}`);
  }
  return lines.join("\n");
}
