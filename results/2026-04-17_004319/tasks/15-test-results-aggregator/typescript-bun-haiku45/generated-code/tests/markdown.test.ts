import { describe, it, expect } from "bun:test";
import { generateMarkdownSummary } from "../src/markdown";

describe("Markdown Summary Generator", () => {
  it("should generate markdown for aggregated results", () => {
    const aggregated = {
      totalTests: 30,
      totalPassed: 27,
      totalFailed: 2,
      totalSkipped: 1,
      totalDuration: 16.5,
      runCount: 3,
      avgPassRate: 90.0,
      avgFailRate: 6.67,
      avgDuration: 5.5,
    };

    const markdown = generateMarkdownSummary(aggregated);

    expect(markdown).toContain("Test Results Summary");
    expect(markdown).toContain("30");
    expect(markdown).toContain("27");
    expect(markdown).toContain("90.00%");
  });

  it("should include flaky tests section when provided", () => {
    const aggregated = {
      totalTests: 20,
      totalPassed: 19,
      totalFailed: 1,
      totalSkipped: 0,
      totalDuration: 10.0,
      runCount: 2,
      avgPassRate: 95.0,
      avgFailRate: 5.0,
      avgDuration: 5.0,
    };

    const flakyTests = [
      {
        testName: "test_flaky",
        passCount: 1,
        failCount: 1,
        totalRuns: 2,
        flakyRate: 50.0,
      },
    ];

    const markdown = generateMarkdownSummary(aggregated, flakyTests);

    expect(markdown).toContain("Flaky Tests");
    expect(markdown).toContain("test_flaky");
    expect(markdown).toContain("50.0%");
  });

  it("should format properly as GitHub Actions job summary", () => {
    const aggregated = {
      totalTests: 100,
      totalPassed: 95,
      totalFailed: 5,
      totalSkipped: 0,
      totalDuration: 45.5,
      runCount: 5,
      avgPassRate: 95.0,
      avgFailRate: 5.0,
      avgDuration: 9.1,
    };

    const markdown = generateMarkdownSummary(aggregated);

    // Should include emojis for status
    expect(markdown).toContain("✅");
    expect(markdown).toContain("❌");
  });
});
