import { readFile } from "fs/promises";
import { basename } from "path";
import type { TestResult, TestRun } from "./types";

// Minimal XML tag/attribute extractor -- avoids external dependencies
function getAttr(tag: string, attr: string): string {
  const re = new RegExp(`(?<![\\w-])${attr}\\s*=\\s*"([^"]*)"`, "i");
  const m = tag.match(re);
  return m ? m[1] : "";
}

function extractTags(xml: string, tagName: string): string[] {
  const results: string[] = [];
  const openRe = new RegExp(`<${tagName}[\\s>]`, "gi");
  let match: RegExpExecArray | null;
  while ((match = openRe.exec(xml)) !== null) {
    const start = match.index;
    // Self-closing tag
    const selfClose = xml.indexOf("/>", start);
    const childOpen = xml.indexOf(">", start);
    if (selfClose !== -1 && selfClose < childOpen + 1) {
      results.push(xml.slice(start, selfClose + 2));
    } else {
      const closeTag = `</${tagName}>`;
      const end = xml.indexOf(closeTag, start);
      if (end !== -1) {
        results.push(xml.slice(start, end + closeTag.length));
      }
    }
  }
  return results;
}

export function parseJUnitXML(xml: string, source: string): TestRun {
  const results: TestResult[] = [];
  const suites = extractTags(xml, "testsuite");

  for (const suite of suites) {
    const suiteName = getAttr(suite, "name");
    const cases = extractTags(suite, "testcase");

    for (const tc of cases) {
      const name = getAttr(tc, "name");
      const duration = parseFloat(getAttr(tc, "time") || "0");

      let status: TestResult["status"] = "passed";
      let error: string | undefined;

      if (tc.includes("<failure")) {
        status = "failed";
        const msgMatch = tc.match(/<failure[^>]*message="([^"]*)"/);
        error = msgMatch ? msgMatch[1] : "Unknown failure";
      } else if (tc.includes("<skipped")) {
        status = "skipped";
      }

      results.push({ name, suite: suiteName, status, duration, error });
    }
  }

  return { source, results };
}

interface JSONTestEntry {
  name: string;
  status: "passed" | "failed" | "skipped";
  duration: number;
  error?: string;
}

interface JSONTestSuite {
  name: string;
  tests: JSONTestEntry[];
}

interface JSONTestFile {
  testSuites: JSONTestSuite[];
}

export function parseJSON(json: string, source: string): TestRun {
  const data: JSONTestFile = JSON.parse(json);
  const results: TestResult[] = [];

  for (const suite of data.testSuites) {
    for (const t of suite.tests) {
      results.push({
        name: t.name,
        suite: suite.name,
        status: t.status,
        duration: t.duration,
        error: t.error,
      });
    }
  }

  return { source, results };
}

export async function parseFile(filePath: string): Promise<TestRun> {
  const content = await readFile(filePath, "utf-8");
  const name = basename(filePath);

  if (filePath.endsWith(".xml")) {
    return parseJUnitXML(content, name);
  } else if (filePath.endsWith(".json")) {
    return parseJSON(content, name);
  }

  throw new Error(`Unsupported file format: ${name}`);
}
