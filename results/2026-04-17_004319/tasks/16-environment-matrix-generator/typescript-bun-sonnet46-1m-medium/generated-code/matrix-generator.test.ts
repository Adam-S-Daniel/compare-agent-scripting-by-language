// TDD: These tests are written FIRST (RED phase). They will fail until matrix-generator.ts
// is implemented. Each test group corresponds to one piece of functionality.

import { test, expect, describe } from 'bun:test';
import { existsSync, readFileSync } from 'fs';
import { resolve } from 'path';
import { spawnSync } from 'bun';

// Import the module under test — will fail to resolve until matrix-generator.ts exists
import { generateMatrix } from './matrix-generator';

const ROOT = import.meta.dir;

// ─── RED PHASE 1: Cartesian product of dimensions ────────────────────────────

describe('generateMatrix - cartesian product', () => {
  test('generates all OS × node combinations', () => {
    const result = generateMatrix({
      os: ['ubuntu-latest', 'windows-latest'],
      languages: { node: ['18', '20'] },
    });
    expect(result.success).toBe(true);
    if (!result.success) return;
    expect(result.summary.totalCombinations).toBe(4);
    expect(result.matrix.include).toContainEqual({ os: 'ubuntu-latest', node: '18' });
    expect(result.matrix.include).toContainEqual({ os: 'ubuntu-latest', node: '20' });
    expect(result.matrix.include).toContainEqual({ os: 'windows-latest', node: '18' });
    expect(result.matrix.include).toContainEqual({ os: 'windows-latest', node: '20' });
  });

  test('generates OS × node × python triplets', () => {
    const result = generateMatrix({
      os: ['ubuntu-latest'],
      languages: { node: ['18', '20'], python: ['3.11', '3.12'] },
    });
    expect(result.success).toBe(true);
    if (!result.success) return;
    expect(result.summary.totalCombinations).toBe(4); // 1 × 2 × 2
  });

  test('single-dimension produces one entry per value', () => {
    const result = generateMatrix({ os: ['ubuntu-latest', 'windows-latest'] });
    expect(result.success).toBe(true);
    if (!result.success) return;
    expect(result.summary.totalCombinations).toBe(2);
  });

  test('empty config produces a single empty entry', () => {
    const result = generateMatrix({});
    expect(result.success).toBe(true);
    if (!result.success) return;
    expect(result.summary.totalCombinations).toBe(1);
  });
});

// ─── RED PHASE 2: Exclude rules ──────────────────────────────────────────────

describe('generateMatrix - exclude rules', () => {
  test('removes entries matching exclude pattern', () => {
    const result = generateMatrix({
      os: ['ubuntu-latest', 'windows-latest'],
      languages: { node: ['18', '20'] },
      exclude: [{ os: 'windows-latest', node: '18' }],
    });
    expect(result.success).toBe(true);
    if (!result.success) return;
    expect(result.summary.totalCombinations).toBe(3);
    expect(result.matrix.include).not.toContainEqual({ os: 'windows-latest', node: '18' });
  });

  test('exclude pattern matches only exact key/value pairs', () => {
    const result = generateMatrix({
      os: ['ubuntu-latest', 'windows-latest'],
      languages: { node: ['18', '20'] },
      // Only remove ubuntu+18, not windows+18
      exclude: [{ os: 'ubuntu-latest', node: '18' }],
    });
    expect(result.success).toBe(true);
    if (!result.success) return;
    expect(result.summary.totalCombinations).toBe(3);
    expect(result.matrix.include).toContainEqual({ os: 'windows-latest', node: '18' });
  });

  test('multiple excludes all apply', () => {
    const result = generateMatrix({
      os: ['ubuntu-latest', 'windows-latest'],
      languages: { node: ['18', '20'] },
      exclude: [
        { os: 'windows-latest', node: '18' },
        { os: 'windows-latest', node: '20' },
      ],
    });
    expect(result.success).toBe(true);
    if (!result.success) return;
    expect(result.summary.totalCombinations).toBe(2);
  });
});

// ─── RED PHASE 3: Include rules ──────────────────────────────────────────────

describe('generateMatrix - include rules', () => {
  test('adds extra entries not in cartesian product', () => {
    const result = generateMatrix({
      os: ['ubuntu-latest'],
      languages: { node: ['18'] },
      include: [{ os: 'macos-latest', node: '22', experimental: true }],
    });
    expect(result.success).toBe(true);
    if (!result.success) return;
    expect(result.summary.totalCombinations).toBe(2);
    expect(result.matrix.include).toContainEqual({
      os: 'macos-latest',
      node: '22',
      experimental: true,
    });
  });

  test('does not duplicate an entry already in the product', () => {
    const result = generateMatrix({
      os: ['ubuntu-latest'],
      languages: { node: ['18'] },
      include: [{ os: 'ubuntu-latest', node: '18' }],
    });
    expect(result.success).toBe(true);
    if (!result.success) return;
    expect(result.summary.totalCombinations).toBe(1);
  });
});

// ─── RED PHASE 4: Max size validation ────────────────────────────────────────

describe('generateMatrix - max size validation', () => {
  test('returns error when matrix exceeds maxSize', () => {
    const result = generateMatrix({
      os: ['ubuntu-latest', 'windows-latest', 'macos-latest'],
      languages: { node: ['16', '18', '20', '22'] },
      maxSize: 5,
    });
    expect(result.success).toBe(false);
    if (result.success) return;
    expect(result.error).toContain('exceeds maximum');
    expect(result.error).toContain('12');
    expect(result.error).toContain('5');
  });

  test('succeeds when matrix is exactly at maxSize', () => {
    const result = generateMatrix({
      os: ['ubuntu-latest', 'windows-latest'],
      languages: { node: ['18', '20'] },
      maxSize: 4,
    });
    expect(result.success).toBe(true);
  });

  test('default maxSize is 256', () => {
    const result = generateMatrix({ os: ['ubuntu-latest'] });
    expect(result.success).toBe(true);
    if (!result.success) return;
    expect(result.summary.maxSize).toBe(256);
  });
});

// ─── RED PHASE 5: Strategy options ───────────────────────────────────────────

describe('generateMatrix - strategy options', () => {
  test('includes max-parallel in strategy when specified', () => {
    const result = generateMatrix({ os: ['ubuntu-latest'], maxParallel: 4 });
    expect(result.success).toBe(true);
    if (!result.success) return;
    expect(result.strategy['max-parallel']).toBe(4);
  });

  test('omits max-parallel from strategy when not specified', () => {
    const result = generateMatrix({ os: ['ubuntu-latest'] });
    expect(result.success).toBe(true);
    if (!result.success) return;
    expect(result.strategy['max-parallel']).toBeUndefined();
  });

  test('sets fail-fast to false when specified', () => {
    const result = generateMatrix({ os: ['ubuntu-latest'], failFast: false });
    expect(result.success).toBe(true);
    if (!result.success) return;
    expect(result.strategy['fail-fast']).toBe(false);
  });

  test('default fail-fast is true', () => {
    const result = generateMatrix({ os: ['ubuntu-latest'] });
    expect(result.success).toBe(true);
    if (!result.success) return;
    expect(result.strategy['fail-fast']).toBe(true);
  });
});

// ─── RED PHASE 6: Feature flags ──────────────────────────────────────────────

describe('generateMatrix - feature flags', () => {
  test('constant boolean features are merged into every entry', () => {
    const result = generateMatrix({
      os: ['ubuntu-latest'],
      languages: { node: ['18', '20'] },
      features: { debug: true, experimental: false },
    });
    expect(result.success).toBe(true);
    if (!result.success) return;
    expect(result.summary.totalCombinations).toBe(2);
    for (const entry of result.matrix.include) {
      expect(entry.debug).toBe(true);
      expect(entry.experimental).toBe(false);
    }
  });

  test('array-valued features create an additional dimension', () => {
    const result = generateMatrix({
      os: ['ubuntu-latest'],
      features: { experimental: ['true', 'false'] },
    });
    expect(result.success).toBe(true);
    if (!result.success) return;
    expect(result.summary.totalCombinations).toBe(2);
  });
});

// ─── RED PHASE 7: Workflow structure tests ───────────────────────────────────

describe('workflow structure', () => {
  const workflowPath = resolve(ROOT, '.github/workflows/environment-matrix-generator.yml');

  test('workflow file exists', () => {
    expect(existsSync(workflowPath)).toBe(true);
  });

  test('workflow has push, pull_request, and workflow_dispatch triggers', () => {
    const content = readFileSync(workflowPath, 'utf-8');
    expect(content).toContain('push:');
    expect(content).toContain('pull_request:');
    expect(content).toContain('workflow_dispatch:');
  });

  test('workflow uses actions/checkout@v4', () => {
    const content = readFileSync(workflowPath, 'utf-8');
    expect(content).toContain('actions/checkout@v4');
  });

  test('workflow references generate-matrix.ts which exists', () => {
    const content = readFileSync(workflowPath, 'utf-8');
    expect(content).toContain('generate-matrix.ts');
    expect(existsSync(resolve(ROOT, 'generate-matrix.ts'))).toBe(true);
  });

  test('fixture files all exist', () => {
    const fixtures = [
      'simple',
      'with-exclude',
      'with-include',
      'max-size-exceeded',
      'full-config',
    ];
    for (const name of fixtures) {
      expect(existsSync(resolve(ROOT, `fixtures/${name}.json`))).toBe(true);
    }
  });

  test('actionlint passes on workflow file', () => {
    // Skip gracefully when actionlint is not installed (e.g. act container).
    const which = spawnSync(['which', 'actionlint'], { stdout: 'pipe', stderr: 'pipe' });
    if (which.exitCode !== 0) return;
    const result = spawnSync(['actionlint', workflowPath], { stdout: 'pipe', stderr: 'pipe' });
    const stderr = new TextDecoder().decode(result.stderr);
    if (result.exitCode !== 0) {
      console.error('actionlint output:', stderr);
    }
    expect(result.exitCode).toBe(0);
  });
});
