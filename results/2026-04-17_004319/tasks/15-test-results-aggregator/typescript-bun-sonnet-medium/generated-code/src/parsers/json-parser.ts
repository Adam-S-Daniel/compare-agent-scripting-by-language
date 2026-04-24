// JSON test result parser
// Expected format: { suite: string, timestamp?: string, tests: [{name, status, duration, error?}] }
import type { ParsedResult, TestSuite, TestCase } from "../types";

interface JsonTestEntry {
  name: string;
  status: string;
  duration: number;
  error?: string;
}

interface JsonResultFile {
  suite: string;
  timestamp?: string;
  tests: JsonTestEntry[];
}

export function parseJSON(content: string, runId: string): ParsedResult {
  let data: JsonResultFile;
  try {
    data = JSON.parse(content) as JsonResultFile;
  } catch (e) {
    throw new Error(
      `Failed to parse JSON: ${e instanceof Error ? e.message : String(e)}`
    );
  }

  if (!data.suite || !Array.isArray(data.tests)) {
    throw new Error(
      'Invalid JSON format: must have "suite" string and "tests" array'
    );
  }

  const tests: TestCase[] = data.tests.map((t) => {
    const status: "passed" | "failed" | "skipped" =
      t.status === "passed"
        ? "passed"
        : t.status === "skipped"
          ? "skipped"
          : "failed";
    return {
      name: t.name,
      suiteName: data.suite,
      status,
      duration: t.duration ?? 0,
      error: t.error,
    };
  });

  const suite: TestSuite = {
    name: data.suite,
    tests,
    duration: tests.reduce((sum, t) => sum + t.duration, 0),
  };

  return { runId, format: "json", suites: [suite] };
}
