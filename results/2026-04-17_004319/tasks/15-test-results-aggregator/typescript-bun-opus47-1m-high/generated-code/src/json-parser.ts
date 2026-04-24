// JSON report parser. Accepts two shapes:
//   1. Canonical: { suites: [{ name, tests: [{ classname, name, status, duration, failureMessage? }] }] }
//   2. Jest-like: { testResults: [{ name, assertionResults: [{ fullName, status, duration (ms), failureMessages? }] }] }
import type { ParsedReport, TestCase, TestStatus } from "./types";

function normalizeStatus(s: unknown): TestStatus {
  const lower = String(s).toLowerCase();
  if (lower === "passed" || lower === "pass" || lower === "ok") return "passed";
  if (lower === "failed" || lower === "fail" || lower === "error") return "failed";
  if (lower === "skipped" || lower === "skip" || lower === "pending") return "skipped";
  throw new Error(`JSON parse error: unrecognized status '${s}'`);
}

export function parseJsonReport(raw: string): ParsedReport {
  let obj: unknown;
  try {
    obj = JSON.parse(raw);
  } catch (e) {
    throw new Error(`JSON parse error: ${(e as Error).message}`);
  }
  if (!obj || typeof obj !== "object") {
    throw new Error("JSON parse error: expected an object at the top level");
  }
  const o = obj as Record<string, unknown>;

  if (Array.isArray(o.suites)) {
    return { suites: o.suites.map(parseCanonicalSuite) };
  }
  if (Array.isArray(o.testResults)) {
    return { suites: o.testResults.map(parseJestSuite) };
  }
  throw new Error(
    "JSON parse error: unrecognized shape (expected top-level 'suites' or 'testResults')",
  );
}

function parseCanonicalSuite(s: unknown): { name: string; tests: TestCase[] } {
  const suite = s as Record<string, unknown>;
  const name = String(suite.name ?? "unknown");
  const tests = Array.isArray(suite.tests) ? suite.tests : [];
  return {
    name,
    tests: tests.map((t) => {
      const tc = t as Record<string, unknown>;
      return {
        classname: String(tc.classname ?? ""),
        name: String(tc.name ?? ""),
        status: normalizeStatus(tc.status),
        duration: Number(tc.duration ?? 0),
        failureMessage:
          typeof tc.failureMessage === "string" ? tc.failureMessage : undefined,
      };
    }),
  };
}

function parseJestSuite(s: unknown): { name: string; tests: TestCase[] } {
  const suite = s as Record<string, unknown>;
  const name = String(suite.name ?? "unknown");
  const assertions = Array.isArray(suite.assertionResults) ? suite.assertionResults : [];
  return {
    name,
    tests: assertions.map((a) => {
      const ar = a as Record<string, unknown>;
      const msgs = Array.isArray(ar.failureMessages) ? (ar.failureMessages as string[]) : [];
      // Jest durations are milliseconds; normalize to seconds.
      const durMs = Number(ar.duration ?? 0);
      return {
        classname: String(ar.ancestorTitles && Array.isArray(ar.ancestorTitles)
          ? (ar.ancestorTitles as string[]).join(" > ")
          : name),
        name: String(ar.fullName ?? ar.title ?? ""),
        status: normalizeStatus(ar.status),
        duration: durMs / 1000,
        failureMessage: msgs.length > 0 ? msgs[0] : undefined,
      };
    }),
  };
}
