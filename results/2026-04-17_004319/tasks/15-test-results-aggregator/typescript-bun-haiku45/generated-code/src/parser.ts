// Parser for test result files in JUnit XML and JSON formats
export interface ParsedResult {
  tests: number;
  passed: number;
  failed: number;
  skipped: number;
  duration: number;
}

// Parse JUnit XML format test results
export function parseJunitXml(xmlContent: string): ParsedResult {
  let passed = 0;
  let failed = 0;
  let skipped = 0;
  let totalDuration = 0;

  // Extract all testsuite time attributes
  const suiteTimeRegex = /<testsuite[^>]*time="([^"]+)"[^>]*>/g;
  let match;

  while ((match = suiteTimeRegex.exec(xmlContent)) !== null) {
    totalDuration += parseFloat(match[1]);
  }

  // Count test cases by looking for testcase tags and their child elements
  // Split by testcase opening tag to find each test
  const lines = xmlContent.split("\n");
  let inTestCase = false;
  let testCaseContent = "";
  let testCount = 0;

  for (const line of lines) {
    if (line.includes("<testcase")) {
      inTestCase = true;
      testCaseContent = line;

      // Handle self-closing testcase tags
      if (line.includes("/>")) {
        testCount++;
        passed++;
        inTestCase = false;
      }
    } else if (inTestCase) {
      testCaseContent += "\n" + line;

      if (line.includes("</testcase>")) {
        testCount++;
        // Check the accumulated content for failure/skipped
        if (testCaseContent.includes("<failure")) {
          failed++;
        } else if (testCaseContent.includes("<skipped")) {
          skipped++;
        } else {
          passed++;
        }
        inTestCase = false;
        testCaseContent = "";
      }
    }
  }

  return { tests: testCount, passed, failed, skipped, duration: totalDuration };
}

// Parse JSON format test results
export function parseJsonResults(jsonContent: string): ParsedResult {
  const data = JSON.parse(jsonContent);

  let passed = 0;
  let failed = 0;
  let skipped = 0;
  let totalDuration = 0; // in milliseconds

  if (Array.isArray(data.tests)) {
    for (const test of data.tests) {
      totalDuration += test.duration || 0;

      if (test.status === "passed") {
        passed++;
      } else if (test.status === "failed") {
        failed++;
      } else if (test.status === "skipped") {
        skipped++;
      }
    }
  }

  const tests = data.tests ? data.tests.length : 0;

  // Convert milliseconds to seconds
  const durationInSeconds = totalDuration / 1000;

  return { tests, passed, failed, skipped, duration: durationInSeconds };
}
