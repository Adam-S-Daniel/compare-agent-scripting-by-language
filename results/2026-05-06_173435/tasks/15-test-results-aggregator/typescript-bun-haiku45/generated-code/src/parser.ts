import { TestSuite, ParsedResults, TestCase } from './types';

function getAttr(text: string, name: string): string | undefined {
  // Match the attribute name as a whole word (word boundary at start, = at end)
  const match = text.match(new RegExp(`\\b${name}="([^"]*)"`));
  return match ? match[1] : undefined;
}

// Parse JUnit XML format test results
export function parseJunitXml(xmlContent: string, runId: string): ParsedResults {
  const results: TestSuite[] = [];

  // Extract suite content using a minimal regex - look for <testsuite with space or >
  let pos = 0;
  while (pos < xmlContent.length) {
    // Find <testsuite (not <testsuites)
    const suiteStart = xmlContent.indexOf('<testsuite', pos);
    if (suiteStart === -1) break;

    // Check if it's followed by space or >
    const nextChar = xmlContent[suiteStart + '<testsuite'.length];
    if (nextChar !== ' ' && nextChar !== '>') {
      // This is <testsuites or something else, skip
      pos = suiteStart + 1;
      continue;
    }

    const tagEnd = xmlContent.indexOf('>', suiteStart);
    const suiteTag = xmlContent.substring(suiteStart, tagEnd + 1);
    const suiteClose = xmlContent.indexOf('</testsuite>', suiteStart);
    if (suiteClose === -1) {
      pos = tagEnd + 1;
      continue;
    }

    const suiteContent = xmlContent.substring(tagEnd + 1, suiteClose);

    // Parse suite attributes
    const suiteName = getAttr(suiteTag, 'name') || 'Unknown';
    const testCount = parseInt(getAttr(suiteTag, 'tests') || '0', 10);
    const failureCount = parseInt(getAttr(suiteTag, 'failures') || '0', 10);
    const skippedCount = parseInt(getAttr(suiteTag, 'skipped') || '0', 10);
    const time = parseFloat(getAttr(suiteTag, 'time') || '0');

    const cases: TestCase[] = [];

    // Parse test cases - find all testcase elements
    let casePos = 0;
    while (casePos < suiteContent.length) {
      const caseStart = suiteContent.indexOf('<testcase', casePos);
      if (caseStart === -1) break;

      const caseTagEnd = suiteContent.indexOf('>', caseStart);
      const caseTag = suiteContent.substring(caseStart, caseTagEnd + 1);

      // Check if self-closing or has content
      let caseBody = '';
      let nextPos = caseTagEnd + 1;

      if (caseTag.endsWith('/>')) {
        // Self-closing tag
        casePos = caseTagEnd + 1;
      } else {
        // Find closing tag
        const caseCloseStart = suiteContent.indexOf('</testcase>', caseTagEnd);
        caseBody = suiteContent.substring(caseTagEnd + 1, caseCloseStart);
        casePos = caseCloseStart + '</testcase>'.length;
      }

      const className = getAttr(caseTag, 'classname') || 'Unknown';
      const testName = getAttr(caseTag, 'name') || 'Unknown';
      const duration = parseFloat(getAttr(caseTag, 'time') || '0') * 1000;

      let status: 'passed' | 'failed' | 'skipped' = 'passed';
      let message: string | undefined;

      if (caseBody.includes('<failure')) {
        status = 'failed';
        message = getAttr(caseBody, 'message');
      } else if (caseBody.includes('<skipped')) {
        status = 'skipped';
        message = getAttr(caseBody, 'message');
      }

      cases.push({
        name: testName,
        className,
        status,
        duration,
        message,
        runId,
      });
    }

    results.push({
      name: suiteName,
      tests: testCount,
      failures: failureCount,
      skipped: skippedCount,
      time,
      cases,
    });

    pos = suiteClose + '</testsuite>'.length;
  }

  return {
    format: 'junit',
    runId,
    results,
  };
}

// Parse JSON format test results
export function parseJsonResults(jsonContent: string, runId: string): ParsedResults {
  const jsonData = JSON.parse(jsonContent);

  const results: TestSuite[] = jsonData.suites.map((suite: any) => {
    const cases: TestCase[] = suite.cases.map((testCase: any) => ({
      name: testCase.name,
      className: testCase.className,
      status: testCase.status,
      duration: testCase.duration,
      message: testCase.message,
      runId,
    }));

    return {
      name: suite.name,
      tests: suite.tests,
      failures: suite.failures,
      skipped: suite.skipped,
      time: suite.time,
      cases,
    };
  });

  return {
    format: 'json',
    runId,
    results,
  };
}
