// TDD Step 4: End-to-end integration test using the sample CSV fixture.
// Exercises the full pipeline: parse CSV → filter → aggregate → write report.

using Xunit;

namespace EmployeeReport.Tests;

public class IntegrationTests
{
    private static string FixturePath(string filename) =>
        Path.Combine(
            Path.GetDirectoryName(typeof(IntegrationTests).Assembly.Location)!,
            "Fixtures", filename);

    [Fact]
    public void EndToEnd_SampleCsv_ProducesCorrectReport()
    {
        var csvPath = FixturePath("employees_sample.csv");
        var outputPath = Path.Combine(Path.GetTempPath(), $"report_{Guid.NewGuid()}.txt");

        try
        {
            // Run full pipeline
            var all = CsvParser.ParseFile(csvPath);
            var active = AggregateCalculator.FilterActive(all);
            ReportGenerator.WriteToFile(active, outputPath);

            // Verify report was created
            Assert.True(File.Exists(outputPath));
            var report = File.ReadAllText(outputPath);

            // Report must include title and department stats
            Assert.Contains("Employee Summary Report", report);
            Assert.Contains("Engineering", report);
            Assert.Contains("Marketing", report);
            Assert.Contains("HR", report);

            // Active employees only: 7 out of 10 in the fixture
            Assert.Contains("7", report);
        }
        finally
        {
            if (File.Exists(outputPath)) File.Delete(outputPath);
        }
    }

    [Fact]
    public void EndToEnd_AllInactiveFile_ProducesEmptyReport()
    {
        var csvPath = FixturePath("employees_all_inactive.csv");
        var outputPath = Path.Combine(Path.GetTempPath(), $"report_{Guid.NewGuid()}.txt");

        try
        {
            var all = CsvParser.ParseFile(csvPath);
            var active = AggregateCalculator.FilterActive(all);
            ReportGenerator.WriteToFile(active, outputPath);

            Assert.True(File.Exists(outputPath));
            var report = File.ReadAllText(outputPath);
            Assert.Contains("0", report);  // zero active employees
        }
        finally
        {
            if (File.Exists(outputPath)) File.Delete(outputPath);
        }
    }
}
