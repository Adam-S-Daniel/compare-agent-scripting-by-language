#!/usr/bin/env bun
// CLI entry point for the dependency license checker.
// Usage: bun run src/index.ts --manifest <path> --config <path> --mock-db <path>
import { parseArgs } from 'util';
import { parsePackageJson } from './parser';
import { createMockLicenseLookup } from './license-lookup';
import { checkDependencies } from './checker';
import { generateReport, formatReportText } from './reporter';
import type { LicenseConfig } from './types';

const { values } = parseArgs({
  args: Bun.argv.slice(2),
  options: {
    manifest: { type: 'string', default: 'fixtures/package.json' },
    config: { type: 'string', default: 'fixtures/license-config.json' },
    'mock-db': { type: 'string', default: 'fixtures/mock-db.json' },
  },
});

async function main(): Promise<void> {
  const manifestPath = values['manifest'] as string;
  const configPath = values['config'] as string;
  const mockDbPath = values['mock-db'] as string;

  let manifestContent: string;
  let configContent: string;
  let mockDbContent: string;

  try {
    manifestContent = await Bun.file(manifestPath).text();
  } catch {
    console.error(`Error: Cannot read manifest file: ${manifestPath}`);
    process.exit(1);
  }

  try {
    configContent = await Bun.file(configPath).text();
  } catch {
    console.error(`Error: Cannot read config file: ${configPath}`);
    process.exit(1);
  }

  try {
    mockDbContent = await Bun.file(mockDbPath).text();
  } catch {
    console.error(`Error: Cannot read mock-db file: ${mockDbPath}`);
    process.exit(1);
  }

  let deps;
  try {
    deps = parsePackageJson(manifestContent);
  } catch (e) {
    console.error(`Error: Invalid manifest JSON: ${(e as Error).message}`);
    process.exit(1);
  }

  const licenseConfig: LicenseConfig = JSON.parse(configContent);
  const mockDb: Record<string, string> = JSON.parse(mockDbContent);
  const lookup = createMockLicenseLookup(mockDb);

  const results = await checkDependencies(deps, licenseConfig, lookup);
  const report = generateReport(results);
  const text = formatReportText(report);

  console.log(text);
}

main();
