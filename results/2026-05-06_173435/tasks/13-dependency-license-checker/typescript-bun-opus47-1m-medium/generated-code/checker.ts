// Dependency license checker.
// Parses a manifest (package.json or requirements.txt), then checks each
// dependency's license against an allow-list / deny-list config and produces
// a compliance report.

export interface Dependency {
  name: string;
  version: string;
}

export interface LicenseConfig {
  allow: string[];
  deny: string[];
}

export type LicenseStatus = "approved" | "denied" | "unknown";

export interface ReportEntry {
  name: string;
  version: string;
  license: string | null;
  status: LicenseStatus;
}

export interface Report {
  entries: ReportEntry[];
  summary: { approved: number; denied: number; unknown: number };
}

// License lookup: returns the SPDX id (e.g. "MIT") or null when unknown.
export type LicenseLookup = (dep: Dependency) => string | null;

// Parse a package.json string. Combines `dependencies` and `devDependencies`.
export function parsePackageJson(content: string): Dependency[] {
  let parsed: unknown;
  try {
    parsed = JSON.parse(content);
  } catch (e) {
    throw new Error(`Invalid package.json: ${(e as Error).message}`);
  }
  if (typeof parsed !== "object" || parsed === null) {
    throw new Error("package.json must be a JSON object");
  }
  const obj = parsed as Record<string, unknown>;
  const deps: Dependency[] = [];
  for (const key of ["dependencies", "devDependencies"] as const) {
    const block = obj[key];
    if (block === undefined) continue;
    if (typeof block !== "object" || block === null) {
      throw new Error(`'${key}' must be an object`);
    }
    for (const [name, version] of Object.entries(block as Record<string, unknown>)) {
      if (typeof version !== "string") {
        throw new Error(`Version for '${name}' must be a string`);
      }
      // Strip range prefixes like ^ ~ >= for a stable display version.
      const cleaned = version.replace(/^[\^~><=\s]+/, "").trim() || version;
      deps.push({ name, version: cleaned });
    }
  }
  return deps;
}

// Parse a requirements.txt-style string. Handles `pkg==1.0`, `pkg>=1.0`, and
// bare `pkg`. Comment lines (#) and blank lines are skipped.
export function parseRequirementsTxt(content: string): Dependency[] {
  const deps: Dependency[] = [];
  for (const rawLine of content.split(/\r?\n/)) {
    const line = rawLine.split("#")[0].trim();
    if (!line) continue;
    const m = line.match(/^([A-Za-z0-9_.\-]+)\s*([=<>!~]=?\s*[A-Za-z0-9_.\-*]+)?/);
    if (!m) {
      throw new Error(`Cannot parse requirement line: ${rawLine}`);
    }
    const name = m[1];
    const version = m[2] ? m[2].replace(/^[=<>!~\s]+/, "").trim() : "*";
    deps.push({ name, version });
  }
  return deps;
}

// Dispatches to the right parser based on the manifest filename.
export function parseManifest(filename: string, content: string): Dependency[] {
  if (filename.endsWith("package.json")) return parsePackageJson(content);
  if (filename.endsWith("requirements.txt")) return parseRequirementsTxt(content);
  throw new Error(`Unsupported manifest: ${filename}`);
}

// Status rules:
// - license unknown (null): "unknown"
// - license in deny list: "denied" (deny takes priority over allow)
// - license in allow list: "approved"
// - otherwise: "unknown" (not on either list — caller must decide)
export function classify(
  license: string | null,
  config: LicenseConfig
): LicenseStatus {
  if (license === null) return "unknown";
  const norm = license.trim();
  if (config.deny.some((d) => d.toLowerCase() === norm.toLowerCase())) {
    return "denied";
  }
  if (config.allow.some((a) => a.toLowerCase() === norm.toLowerCase())) {
    return "approved";
  }
  return "unknown";
}

export function checkLicenses(
  deps: Dependency[],
  lookup: LicenseLookup,
  config: LicenseConfig
): Report {
  const entries: ReportEntry[] = deps.map((dep) => {
    const license = lookup(dep);
    return {
      name: dep.name,
      version: dep.version,
      license,
      status: classify(license, config),
    };
  });
  const summary = { approved: 0, denied: 0, unknown: 0 };
  for (const e of entries) summary[e.status] += 1;
  return { entries, summary };
}

export function formatReport(report: Report): string {
  const lines: string[] = [];
  lines.push("Dependency License Compliance Report");
  lines.push("=====================================");
  for (const e of report.entries) {
    const lic = e.license ?? "UNKNOWN";
    lines.push(`- ${e.name}@${e.version} [${lic}] => ${e.status.toUpperCase()}`);
  }
  lines.push("-------------------------------------");
  lines.push(
    `Summary: approved=${report.summary.approved} denied=${report.summary.denied} unknown=${report.summary.unknown}`
  );
  return lines.join("\n");
}

// CLI entry point. Usage: bun run checker.ts <manifest> <config.json>
// On any "denied" entries, exits 1 so CI can gate on it.
async function main(): Promise<void> {
  const [manifestPath, configPath] = Bun.argv.slice(2);
  if (!manifestPath || !configPath) {
    console.error("Usage: bun run checker.ts <manifest> <license-config.json>");
    process.exit(2);
  }
  const manifest = await Bun.file(manifestPath).text();
  const configText = await Bun.file(configPath).text();
  const config = JSON.parse(configText) as LicenseConfig;
  const deps = parseManifest(manifestPath, manifest);
  // Production lookup uses an embedded fixture map keyed by `<name>` — see
  // FIXTURE_LICENSES below. This keeps the workflow runnable in act without
  // network access.
  const report = checkLicenses(deps, fixtureLookup, config);
  console.log(formatReport(report));
  if (report.summary.denied > 0) process.exit(1);
}

// A small embedded license database used by the CLI. Tests inject their own
// lookup, so this only matters for the workflow's smoke run.
export const FIXTURE_LICENSES: Record<string, string> = {
  "lodash": "MIT",
  "react": "MIT",
  "left-pad": "WTFPL",
  "evil-pkg": "GPL-3.0",
  "requests": "Apache-2.0",
  "pandas": "BSD-3-Clause",
  "secret-tool": "Proprietary",
};

export const fixtureLookup: LicenseLookup = (dep) =>
  FIXTURE_LICENSES[dep.name] ?? null;

if (import.meta.main) {
  await main();
}
