#!/usr/bin/env bun
// Thin shim invoked by the GitHub Actions workflow.
//
// Reads optional ./test-config.json (lets the test harness pin warningDays /
// format / now without modifying the workflow), falls back to defaults, and
// then calls validator.ts as a child process.
//
// Output is wrapped in delimiter markers so the test harness can extract the
// validator's stdout from act's interleaved log output.

import { existsSync } from 'node:fs';
import { run as runValidator } from './validator.ts';

interface TestConfig {
  secretsPath?: string;
  warningDays?: number;
  format?: 'markdown' | 'json';
  now?: string;
}

const START_MARKER = '===VALIDATOR-OUTPUT-START===';
const END_MARKER = '===VALIDATOR-OUTPUT-END===';

async function loadConfig(): Promise<TestConfig> {
  if (!existsSync('test-config.json')) return {};
  try {
    return (await Bun.file('test-config.json').json()) as TestConfig;
  } catch (e) {
    console.error(`Warning: failed to read test-config.json: ${(e as Error).message}`);
    return {};
  }
}

const cfg = await loadConfig();

const args: string[] = ['--secrets', cfg.secretsPath ?? 'fixtures/secrets.json'];
args.push('--warning-days', String(cfg.warningDays ?? 14));
args.push('--format', cfg.format ?? 'markdown');
if (cfg.now) args.push('--now', cfg.now);

console.log(`ci-run: invoking validator with args: ${args.join(' ')}`);
console.log(START_MARKER);
const { stdout, exitCode } = runValidator(args);
console.log(stdout);
console.log(END_MARKER);

process.exit(exitCode);
