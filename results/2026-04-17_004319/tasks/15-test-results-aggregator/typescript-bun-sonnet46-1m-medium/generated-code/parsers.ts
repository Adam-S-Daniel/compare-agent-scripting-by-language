// Parsers for JUnit XML and JSON test result formats.
// Both return TestSuite[] so the aggregator works uniformly.

import type { TestResult, TestSuite, TestStatus, JsonTestFixture } from './types';

// Parse XML attribute string into key/value map
function parseAttrs(attrStr: string): Record<string, string> {
  const attrs: Record<string, string> = {};
  const re = /(\w+)="([^"]*)"/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(attrStr)) !== null) {
    attrs[m[1]] = m[2];
  }
  return attrs;
}

// Extract text content from an element tag with given name
function extractTagContent(xml: string, tag: string): string | undefined {
  const re = new RegExp(`<${tag}[^>]*>([\\s\\S]*?)<\\/${tag}>`, 'i');
  const m = xml.match(re);
  return m?.[1];
}

// Parse a single <testcase ...> block into a TestResult
function parseTestCase(block: string, attrs: Record<string, string>, suiteName: string, source: string): TestResult {
  const testName = attrs.name ?? 'Unknown';
  const duration = parseFloat(attrs.time ?? '0');

  let status: TestStatus = 'passed';
  let errorMessage: string | undefined;

  // Self-closing testcase (<testcase .../>) has no block content
  if (block.length > 0) {
    if (/<failure/i.test(block) || /<error/i.test(block)) {
      status = 'failed';
      // Try to get the message attribute from <failure> or <error>
      const msgMatch = block.match(/<(?:failure|error)[^>]*message="([^"]*)"/i);
      if (msgMatch) {
        errorMessage = msgMatch[1];
      } else {
        // Fall back to inner text of the failure/error element
        const inner = extractTagContent(block, 'failure') ?? extractTagContent(block, 'error');
        errorMessage = inner?.trim();
      }
    } else if (/<skipped/i.test(block)) {
      status = 'skipped';
    }
  }

  return { suiteName, testName, status, duration, errorMessage, source };
}

// Parse JUnit XML content and return one TestSuite per <testsuite> element.
export function parseJUnitXML(content: string, source: string): TestSuite[] {
  const suites: TestSuite[] = [];

  // Match each <testsuite ...>...</testsuite> block (handles nested testsuites inside testsuites)
  const suiteRe = /<testsuite\s([^>]*)>([\s\S]*?)<\/testsuite>/gi;
  let suiteMatch: RegExpExecArray | null;

  while ((suiteMatch = suiteRe.exec(content)) !== null) {
    const suiteAttrs = parseAttrs(suiteMatch[1]);
    const suiteBody = suiteMatch[2];
    const suiteName = suiteAttrs.name ?? 'Unknown';
    const duration = parseFloat(suiteAttrs.time ?? '0');

    const results: TestResult[] = [];

    // Match each testcase: either self-closing or with child content
    // Group 1: attributes; Group 2: inner content if not self-closing
    const caseRe = /<testcase\s([^>]*?)(?:\s*\/>|>([\s\S]*?)<\/testcase>)/gi;
    let caseMatch: RegExpExecArray | null;

    while ((caseMatch = caseRe.exec(suiteBody)) !== null) {
      const attrs = parseAttrs(caseMatch[1]);
      const innerBlock = caseMatch[2] ?? '';
      results.push(parseTestCase(innerBlock, attrs, suiteName, source));
    }

    suites.push({ name: suiteName, source, duration, results });
  }

  return suites;
}

// Parse our custom JSON fixture format into TestSuite[]
export function parseJSONResults(content: string, source: string): TestSuite[] {
  let data: JsonTestFixture;
  try {
    data = JSON.parse(content) as JsonTestFixture;
  } catch (e) {
    throw new Error(`Failed to parse JSON fixture "${source}": ${(e as Error).message}`);
  }

  const results: TestResult[] = data.tests.map(t => ({
    suiteName: data.suiteName,
    testName: t.name,
    status: t.status,
    duration: t.duration,
    errorMessage: t.errorMessage,
    source,
  }));

  return [{ name: data.suiteName, source, duration: data.duration, results }];
}
