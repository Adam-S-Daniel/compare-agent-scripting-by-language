namespace TestAggregator.Models;

/// <summary>A test that passed in some runs and failed in others across the matrix.</summary>
public record FlakyTest(
    string Name,
    string ClassName,
    int PassCount,
    int FailCount,
    IReadOnlyList<string> FailingFiles
);
