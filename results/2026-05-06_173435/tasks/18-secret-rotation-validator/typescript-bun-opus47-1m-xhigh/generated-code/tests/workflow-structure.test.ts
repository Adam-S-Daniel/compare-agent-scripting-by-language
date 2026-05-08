// Workflow structure tests.
//
// These run synchronously (no `act` / Docker required) and are designed to
// catch obvious wiring problems before paying for an end-to-end run:
//   - the YAML actually parses
//   - the workflow declares the triggers and permissions we expect
//   - every script the workflow references actually exists on disk
//   - actionlint passes cleanly
//
// They live alongside the act-driven tests in the same `bun test` invocation
// so a single command verifies both static structure and runtime behavior.

import { describe, expect, test } from 'bun:test';
import { existsSync, readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { join } from 'node:path';
import YAML from 'yaml';

const WORKFLOW_PATH = '.github/workflows/secret-rotation-validator.yml';

interface ParsedWorkflow {
  name: string;
  on: Record<string, unknown>;
  permissions: Record<string, string>;
  jobs: Record<string, {
    name?: string;
    'runs-on': string;
    steps: Array<{
      name?: string;
      uses?: string;
      run?: string;
      with?: Record<string, unknown>;
    }>;
  }>;
}

describe('workflow YAML structure', () => {
  const raw = readFileSync(WORKFLOW_PATH, 'utf8');
  const parsed = YAML.parse(raw) as ParsedWorkflow;

  test('workflow file exists and parses', () => {
    expect(parsed).toBeDefined();
    expect(typeof parsed).toBe('object');
  });

  test('has a descriptive name', () => {
    expect(parsed.name).toBe('Secret Rotation Validator');
  });

  test('declares push, pull_request, schedule, and workflow_dispatch triggers', () => {
    expect(parsed.on).toBeDefined();
    expect(parsed.on).toHaveProperty('push');
    expect(parsed.on).toHaveProperty('pull_request');
    expect(parsed.on).toHaveProperty('schedule');
    expect(parsed.on).toHaveProperty('workflow_dispatch');
  });

  test('grants only the read contents permission', () => {
    expect(parsed.permissions).toEqual({ contents: 'read' });
  });

  test('defines a validate-rotation job on ubuntu-latest', () => {
    expect(parsed.jobs).toHaveProperty('validate-rotation');
    const job = parsed.jobs['validate-rotation']!;
    expect(job['runs-on']).toBe('ubuntu-latest');
  });

  test('uses checkout@v4 and oven-sh/setup-bun@v2', () => {
    const steps = parsed.jobs['validate-rotation']!.steps;
    const uses = steps.map((s) => s.uses).filter(Boolean) as string[];
    expect(uses).toContain('actions/checkout@v4');
    expect(uses.some((u) => u.startsWith('oven-sh/setup-bun@v2'))).toBe(true);
  });

  test('runs the validator via ci-run.ts', () => {
    const steps = parsed.jobs['validate-rotation']!.steps;
    const runSteps = steps.map((s) => s.run).filter(Boolean) as string[];
    expect(runSteps.some((r) => r.includes('bun run ci-run.ts'))).toBe(true);
  });
});

describe('workflow file references', () => {
  test('every script the workflow references exists on disk', () => {
    expect(existsSync('validator.ts')).toBe(true);
    expect(existsSync('ci-run.ts')).toBe(true);
    expect(existsSync('fixtures/secrets.json')).toBe(true);
    expect(existsSync('package.json')).toBe(true);
    expect(existsSync('tsconfig.json')).toBe(true);
  });
});

describe('actionlint validation', () => {
  test('actionlint passes on the workflow', () => {
    const result = spawnSync('actionlint', [WORKFLOW_PATH], { encoding: 'utf8' });
    if (result.status !== 0) {
      // Surface actionlint's complaint in the assertion message rather than
      // forcing the developer to re-run actionlint manually.
      throw new Error(`actionlint failed (exit ${result.status}):\n${result.stdout}\n${result.stderr}`);
    }
    expect(result.status).toBe(0);
  });
});

describe('default fixture sanity', () => {
  test('default fixture is a non-empty array of well-formed records', () => {
    const fixture = JSON.parse(readFileSync(join('fixtures', 'secrets.json'), 'utf8'));
    expect(Array.isArray(fixture)).toBe(true);
    expect(fixture.length).toBeGreaterThan(0);
    for (const s of fixture) {
      expect(typeof s.name).toBe('string');
      expect(typeof s.lastRotated).toBe('string');
      expect(typeof s.rotationPolicyDays).toBe('number');
      expect(Array.isArray(s.requiredBy)).toBe(true);
    }
  });
});
