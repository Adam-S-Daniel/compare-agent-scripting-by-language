// PipelineResult.cs
// Immutable summary returned when the pipeline finishes draining the queue.

namespace Pipeline.Core;

public record PipelineResult(
    int TotalProcessed,
    int TotalFailed,
    int TotalRetries,
    int DeadLetterCount,
    IReadOnlyList<string> DeadLetterItems
)
{
    /// <summary>Human-readable summary suitable for console output.</summary>
    public string ToSummary() =>
        $"""
        ===== Pipeline Summary =====
        Processed successfully : {TotalProcessed}
        Failed (dead-lettered) : {TotalFailed}
        Total retries          : {TotalRetries}
        Dead-letter queue size : {DeadLetterCount}
        Dead-letter items      : {(DeadLetterItems.Count == 0 ? "(none)" : string.Join(", ", DeadLetterItems))}
        ============================
        """;
}
