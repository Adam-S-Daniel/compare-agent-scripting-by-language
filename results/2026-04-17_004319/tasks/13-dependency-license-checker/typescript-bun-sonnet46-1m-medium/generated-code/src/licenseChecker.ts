import { readFileSync } from "fs";
import type {
  Dependency,
  LicenseConfig,
  LicenseStatus,
  DependencyReport,
  ComplianceReport,
} from "./types";
import { lookupLicense } from "./mockLicenses";

// Parse a package.json file and return its dependencies as name+version pairs.
// Version range prefixes (^, ~, >=, >, <=, <, =) are stripped.
export function parsePackageJson(filePath: string): Dependency[] {
  let content: string;
  try {
    content = readFileSync(filePath, "utf-8");
  } catch (err) {
    throw new Error(
      `Failed to read manifest file '${filePath}': ${(err as NodeJS.ErrnoException).message}`
    );
  }

  let pkg: Record<string, unknown>;
  try {
    pkg = JSON.parse(content);
  } catch {
    throw new Error(`Invalid JSON in manifest file '${filePath}'`);
  }

  const rawDeps = (pkg.dependencies ?? {}) as Record<string, string>;
  return Object.entries(rawDeps).map(([name, versionRange]) => ({
    name,
    version: versionRange.replace(/^[\^~>=<]+/, ""),
  }));
}

// Determine the compliance status of a single license string.
// deny list takes precedence over allow list so conflicting configs are safe.
export function determineLicenseStatus(
  license: string | null,
  config: LicenseConfig
): LicenseStatus {
  if (license === null) return "unknown";
  if (config.denyList.includes(license)) return "denied";
  if (config.allowList.includes(license)) return "approved";
  return "unknown";
}

// Run the full check pipeline over a list of dependencies.
// lookupFn defaults to the mock license DB; pass a custom function for testing.
export function checkDependencies(
  deps: Dependency[],
  config: LicenseConfig,
  lookupFn: (name: string) => string | null = lookupLicense
): ComplianceReport {
  const dependencies: DependencyReport[] = deps.map((dep) => {
    const license = lookupFn(dep.name);
    const status = determineLicenseStatus(license, config);
    return { name: dep.name, version: dep.version, license, status };
  });

  const summary = {
    total: dependencies.length,
    approved: dependencies.filter((d) => d.status === "approved").length,
    denied: dependencies.filter((d) => d.status === "denied").length,
    unknown: dependencies.filter((d) => d.status === "unknown").length,
  };

  return { dependencies, summary };
}

// Format a ComplianceReport as a human-readable text block for stdout/logs.
export function formatReport(report: ComplianceReport): string {
  const lines: string[] = [
    "DEPENDENCY LICENSE COMPLIANCE REPORT",
    "=====================================",
  ];

  for (const dep of report.dependencies) {
    const licenseStr = dep.license ?? "UNKNOWN";
    lines.push(`${dep.name}@${dep.version}: ${licenseStr} - ${dep.status.toUpperCase()}`);
  }

  lines.push("");
  lines.push(
    `SUMMARY: ${report.summary.approved} approved, ${report.summary.denied} denied, ${report.summary.unknown} unknown`
  );

  return lines.join("\n");
}

// CLI entry point — run with:  bun run src/licenseChecker.ts --config <cfg.json> --manifest <pkg.json>
if (import.meta.main) {
  const args = process.argv.slice(2);
  const flag = (name: string): string | undefined => {
    const idx = args.indexOf(name);
    return idx !== -1 ? args[idx + 1] : undefined;
  };

  const configPath = flag("--config");
  const manifestPath = flag("--manifest");

  if (!configPath || !manifestPath) {
    console.error(
      "Usage: bun run src/licenseChecker.ts --config <config.json> --manifest <package.json>"
    );
    process.exit(1);
  }

  try {
    const config: LicenseConfig = JSON.parse(readFileSync(configPath, "utf-8"));
    const deps = parsePackageJson(manifestPath);
    const report = checkDependencies(deps, config);
    console.log(formatReport(report));
    // Exit non-zero when denied dependencies are found (useful as a real CI gate)
    if (report.summary.denied > 0) process.exit(1);
  } catch (err) {
    console.error(`Error: ${(err as Error).message}`);
    process.exit(1);
  }
}
