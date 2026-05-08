// test-runner.ts
//
// Runs a single fixture through generateMatrix() and prints structured
// output the harness can grep for: matrix JSON between MATRIX_OUTPUT_BEGIN/END
// markers, error JSON between ERROR_BEGIN/END markers, and a TEST_PASS or
// TEST_FAIL line.
//
// A fixture is a JSON object of shape:
//   {
//     "name": "basic",
//     "expectSuccess": true,
//     "expectedSize": 4,           // when expectSuccess is true
//     "expectedError": "...",      // when expectSuccess is false (substring match)
//     "config": { ... }            // the actual MatrixConfig
//   }
//
// Exits 0 on PASS (whether the underlying generator succeeded or
// gracefully reported the expected error), and 1 on any FAIL so the
// workflow correctly surfaces real test failures.

import { readFileSync } from "node:fs";
import {
  generateMatrix,
  MatrixSizeError,
  MatrixValidationError,
  type MatrixResult,
} from "./matrix";

interface Fixture {
  name: string;
  expectSuccess: boolean;
  expectedSize?: number;
  expectedError?: string;
  config: unknown;
}

function parseFixture(path: string): Fixture {
  const raw = readFileSync(path, "utf-8");
  const obj = JSON.parse(raw) as Record<string, unknown>;
  if (typeof obj.name !== "string") {
    throw new Error(`fixture ${path} missing string "name"`);
  }
  if (typeof obj.expectSuccess !== "boolean") {
    throw new Error(`fixture ${path} missing boolean "expectSuccess"`);
  }
  return {
    name: obj.name,
    expectSuccess: obj.expectSuccess,
    expectedSize:
      typeof obj.expectedSize === "number" ? obj.expectedSize : undefined,
    expectedError:
      typeof obj.expectedError === "string" ? obj.expectedError : undefined,
    config: obj.config,
  };
}

function printPass(name: string): void {
  console.log(`=== TEST_PASS: ${name} ===`);
}

function printFail(name: string, reason: string): void {
  console.log(`=== TEST_FAIL: ${name} ===`);
  console.log(`Reason: ${reason}`);
}

function runFixture(fixture: Fixture): boolean {
  const { name, expectSuccess, expectedSize, expectedError, config } = fixture;

  console.log(`=== TEST_BEGIN: ${name} ===`);
  console.log("Input config:");
  console.log(JSON.stringify(config, null, 2));

  let result: MatrixResult | undefined;
  let caught: Error | undefined;

  try {
    result = generateMatrix(config);
  } catch (e) {
    caught = e instanceof Error ? e : new Error(String(e));
  }

  if (result) {
    console.log("=== MATRIX_OUTPUT_BEGIN ===");
    console.log(JSON.stringify(result, null, 2));
    console.log("=== MATRIX_OUTPUT_END ===");
  } else if (caught) {
    console.log("=== ERROR_BEGIN ===");
    console.log(`${caught.name}: ${caught.message}`);
    console.log("=== ERROR_END ===");
  }

  if (expectSuccess) {
    if (!result) {
      printFail(
        name,
        `expected success but generator threw: ${caught?.name}: ${caught?.message}`,
      );
      return false;
    }
    if (typeof expectedSize === "number" && result.size !== expectedSize) {
      printFail(
        name,
        `size mismatch: expected ${expectedSize}, got ${result.size}`,
      );
      return false;
    }
    printPass(name);
    return true;
  }

  // expectSuccess === false → we want the generator to throw a known error.
  if (result) {
    printFail(
      name,
      `expected failure but generator returned a matrix of size ${result.size}`,
    );
    return false;
  }
  if (!caught) {
    printFail(name, "expected failure but no error was caught");
    return false;
  }
  // Only treat MatrixValidationError / MatrixSizeError as expected failures.
  if (
    !(caught instanceof MatrixValidationError) &&
    !(caught instanceof MatrixSizeError)
  ) {
    printFail(
      name,
      `unexpected error type: ${caught.name}: ${caught.message}`,
    );
    return false;
  }
  if (
    typeof expectedError === "string" &&
    !caught.message.includes(expectedError)
  ) {
    printFail(
      name,
      `error message mismatch: expected substring "${expectedError}", got "${caught.message}"`,
    );
    return false;
  }
  printPass(name);
  return true;
}

function main(): never {
  const path = process.argv[2];
  if (!path) {
    console.error("Usage: bun run test-runner.ts <fixture.json>");
    process.exit(1);
  }
  const fixture = parseFixture(path);
  const ok = runFixture(fixture);
  process.exit(ok ? 0 : 1);
}

if (import.meta.main) {
  main();
}
