import { parsePackageJson, parseRequirementsTxt } from "./parser";
import { checkLicenses } from "./checker";
import { generateReport } from "./reporter";
import { createMockLookup } from "./mock-lookup";
import type { LicenseConfig } from "./types";

async function main(): Promise<void> {
  const manifestPath = process.argv[2];
  const configPath = process.argv[3];

  if (!manifestPath || !configPath) {
    console.error("Usage: bun run license-checker.ts <manifest-path> <config-path>");
    process.exit(1);
  }

  const manifestFile = Bun.file(manifestPath);
  const configFile = Bun.file(configPath);

  if (!(await manifestFile.exists())) {
    console.error(`Error: manifest file not found: ${manifestPath}`);
    process.exit(1);
  }
  if (!(await configFile.exists())) {
    console.error(`Error: config file not found: ${configPath}`);
    process.exit(1);
  }

  const manifestContent = await manifestFile.text();
  const configContent = await configFile.text();
  const config: LicenseConfig = JSON.parse(configContent);

  const isPackageJson = manifestPath.endsWith("package.json");
  const deps = isPackageJson
    ? parsePackageJson(manifestContent)
    : parseRequirementsTxt(manifestContent);

  const mockLicenses: Record<string, string> = {
    lodash: "MIT",
    express: "MIT",
    react: "MIT",
    typescript: "Apache-2.0",
    webpack: "MIT",
    requests: "Apache-2.0",
    flask: "BSD-3-Clause",
    numpy: "BSD-3-Clause",
    "gpl-tool": "GPL-3.0",
  };
  const lookup = createMockLookup(mockLicenses);

  const report = await checkLicenses(deps, config, lookup);
  const output = generateReport(report);

  console.log(output);

  if (report.summary.denied > 0) {
    process.exit(2);
  }
}

main();
