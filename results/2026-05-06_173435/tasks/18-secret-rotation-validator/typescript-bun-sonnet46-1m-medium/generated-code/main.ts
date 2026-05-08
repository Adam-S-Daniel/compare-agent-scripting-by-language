// Secret Rotation Validator — CLI entry point
// Usage: bun run main.ts [--config <file>] [--format json|markdown]

import { generateReport, type ValidatorConfig } from './validator';
import { formatJSON, formatMarkdown } from './formatter';
import { readFileSync } from 'fs';

interface CliArgs {
  configFile: string;
  format: 'json' | 'markdown';
}

function parseArgs(argv: string[]): CliArgs {
  let configFile = 'secrets-config.json';
  let format: 'json' | 'markdown' = 'markdown';

  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--config' && argv[i + 1]) {
      configFile = argv[++i];
    } else if (argv[i] === '--format' && argv[i + 1]) {
      const f = argv[++i];
      if (f !== 'json' && f !== 'markdown') {
        console.error(`Error: unknown format "${f}". Use "json" or "markdown".`);
        process.exit(1);
      }
      format = f;
    }
  }

  return { configFile, format };
}

function loadConfig(path: string): ValidatorConfig {
  let raw: string;
  try {
    raw = readFileSync(path, 'utf-8');
  } catch {
    console.error(`Error: cannot read config file "${path}"`);
    process.exit(1);
  }

  let config: ValidatorConfig;
  try {
    config = JSON.parse(raw) as ValidatorConfig;
  } catch {
    console.error(`Error: "${path}" is not valid JSON`);
    process.exit(1);
  }

  return config;
}

function main(): void {
  const { configFile, format } = parseArgs(process.argv.slice(2));
  const config = loadConfig(configFile);

  let report;
  try {
    report = generateReport(config);
  } catch (err) {
    console.error(`Error: ${(err as Error).message}`);
    process.exit(1);
  }

  const output = format === 'json' ? formatJSON(report) : formatMarkdown(report);
  console.log(output);
}

main();
