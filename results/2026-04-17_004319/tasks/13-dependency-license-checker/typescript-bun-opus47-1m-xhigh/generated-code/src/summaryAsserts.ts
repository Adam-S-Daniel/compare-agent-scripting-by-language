#!/usr/bin/env bun
// Read a compliance report JSON document from stdin, emit ASSERT:key=value
// lines for each summary counter. Used by the CI workflow so the test
// harness can grep for exact expected values in act output.
//
// Why a dedicated script: inline `bun -e '...'` inside a YAML run: step
// is a minefield of quoting. A tiny file is clearer and unit-testable.

import type { ComplianceReport } from "./types.ts";

const input = await Bun.stdin.text();
let report: ComplianceReport;
try {
  report = JSON.parse(input) as ComplianceReport;
} catch (err) {
  const msg = err instanceof Error ? err.message : String(err);
  console.error(`summaryAsserts: could not parse JSON from stdin: ${msg}`);
  process.exit(1);
}

const s = report.summary;
console.log(`ASSERT:approved=${s.approved}`);
console.log(`ASSERT:denied=${s.denied}`);
console.log(`ASSERT:unknown=${s.unknown}`);
console.log(`ASSERT:total=${s.total}`);
