// Parser for JUnit XML and JSON test-result files.
//
// The JUnit parser is written by hand (no external dep). JUnit XML is narrow
// enough that a tiny regex-based walker is simpler and more predictable than
// pulling in a full DOM parser — we only care about `<testcase>` elements and
// their immediate child status markers (`<failure>`, `<error>`, `<skipped>`).
//
// For JSON we accept a flat object of shape `{ tests: TestResult[] }`. That
// format is native to this tool and is the format our fixtures use.

import { readFile } from "node:fs/promises";
import type { RunReport, TestResult, TestStatus } from "./types.ts";

// ---------- JUnit XML ----------

/**
 * Decode the five XML entities JUnit generators are allowed to produce.
 * JUnit XML doesn't use numeric character references in the wild for the
 * fields we care about, so we keep this intentionally minimal.
 */
function xmlUnescape(raw: string): string {
  return raw
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, "&");
}

/** Extract attribute value by name, or undefined if missing. */
function attr(tag: string, name: string): string | undefined {
  // Match either single- or double-quoted attribute values.
  const re = new RegExp(`\\b${name}\\s*=\\s*(?:"([^"]*)"|'([^']*)')`);
  const m = tag.match(re);
  if (!m) return undefined;
  return xmlUnescape(m[1] ?? m[2] ?? "");
}

/**
 * Parse a JUnit XML document into a RunReport.
 *
 * @throws Error annotated with the source filename if the XML is malformed
 *   enough to prevent extracting any testcase elements.
 */
export function parseJUnitXml(xml: string, source: string): RunReport {
  // Quick sanity check — every JUnit document has a testsuite(s) root.
  if (!/<testsuites?\b/i.test(xml)) {
    throw new Error(
      `Failed to parse JUnit XML in ${source}: no <testsuite> or <testsuites> root`,
    );
  }

  const tests: TestResult[] = [];
  // Iterate over every <testcase ...> ... </testcase> (or self-closed).
  // Using [\s\S]*? for the body so newlines inside are captured.
  const caseRe = /<testcase\b([^>]*?)(\/>|>([\s\S]*?)<\/testcase>)/g;
  for (const m of xml.matchAll(caseRe)) {
    const attrs = m[1];
    const body = m[3] ?? "";
    const name = attr(attrs, "name") ?? "<anonymous>";
    const className = attr(attrs, "classname");
    const timeStr = attr(attrs, "time");
    const durationMs = timeStr ? Math.round(parseFloat(timeStr) * 1000) : 0;

    let status: TestStatus = "passed";
    let failureMessage: string | undefined;
    const failMatch = body.match(/<(failure|error)\b([^>]*)(\/>|>([\s\S]*?)<\/\1>)/);
    const skipMatch = body.match(/<skipped\b([^>]*)(\/>|>[\s\S]*?<\/skipped>)/);
    if (failMatch) {
      status = "failed";
      failureMessage = attr(failMatch[2], "message") ?? xmlUnescape(failMatch[4] ?? "").trim();
    } else if (skipMatch) {
      status = "skipped";
    }

    tests.push({
      name: className ? `${className}.${name}` : name,
      status,
      durationMs,
      ...(failureMessage !== undefined ? { failureMessage } : {}),
    });
  }

  return { source, tests };
}

// ---------- JSON ----------

/**
 * Parse a JSON test result document of shape `{ tests: TestResult[] }`.
 */
export function parseJson(text: string, source: string): RunReport {
  let data: unknown;
  try {
    data = JSON.parse(text);
  } catch (e) {
    throw new Error(`Failed to parse JSON in ${source}: ${(e as Error).message}`);
  }
  if (!data || typeof data !== "object" || !Array.isArray((data as { tests: unknown }).tests)) {
    throw new Error(`Invalid JSON in ${source}: expected a "tests" array`);
  }
  const rawTests = (data as { tests: unknown[] }).tests;
  const tests: TestResult[] = rawTests.map((t, i) => {
    if (!t || typeof t !== "object") {
      throw new Error(`Invalid test entry at index ${i} in ${source}`);
    }
    const obj = t as Record<string, unknown>;
    const name = typeof obj.name === "string" ? obj.name : `<unnamed-${i}>`;
    const status = obj.status as TestStatus;
    if (status !== "passed" && status !== "failed" && status !== "skipped") {
      throw new Error(
        `Invalid status '${String(obj.status)}' for test '${name}' in ${source}`,
      );
    }
    const durationMs = typeof obj.durationMs === "number" ? obj.durationMs : 0;
    const failureMessage = typeof obj.failureMessage === "string" ? obj.failureMessage : undefined;
    return {
      name,
      status,
      durationMs,
      ...(failureMessage !== undefined ? { failureMessage } : {}),
    };
  });
  return { source, tests };
}

// ---------- Dispatch by extension ----------

/** Load and parse a file by extension (.xml -> JUnit, .json -> JSON). */
export async function parseFile(path: string): Promise<RunReport> {
  const lower = path.toLowerCase();
  // Check the extension BEFORE reading so a bad extension gives the clearer
  // error rather than surfacing an ENOENT from the filesystem.
  if (!lower.endsWith(".xml") && !lower.endsWith(".json")) {
    throw new Error(`Unsupported file extension: ${path}`);
  }
  const text = await readFile(path, "utf8");
  const source = path.split("/").pop() ?? path;
  if (lower.endsWith(".xml")) return parseJUnitXml(text, source);
  return parseJson(text, source);
}
