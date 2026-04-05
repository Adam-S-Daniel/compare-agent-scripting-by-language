// Interfaces for the pipeline - all queue and processing operations are mockable.

namespace Pipeline;

/// <summary>
/// Represents an item to be processed in the pipeline.
/// </summary>
public record QueueItem(string Id, string Payload);

/// <summary>
/// Mockable queue that provides items for processing.
/// </summary>
public interface IQueue
{
    /// <summary>Attempts to dequeue the next item. Returns null when empty.</summary>
    QueueItem? Dequeue();

    /// <summary>Returns the count of items remaining.</summary>
    int Count { get; }
}

/// <summary>
/// Mockable processor that handles individual queue items.
/// Can throw exceptions to simulate failures.
/// </summary>
public interface IItemProcessor
{
    /// <summary>Processes a single item. Throws on failure.</summary>
    Task ProcessAsync(QueueItem item);
}

/// <summary>
/// Dead-letter queue for items that have exhausted all retries.
/// </summary>
public interface IDeadLetterQueue
{
    /// <summary>Sends a failed item to the dead-letter queue with the failure reason.</summary>
    void Enqueue(QueueItem item, string reason);

    /// <summary>Returns all items currently in the dead-letter queue.</summary>
    IReadOnlyList<DeadLetterEntry> GetAll();

    /// <summary>Count of items in the dead-letter queue.</summary>
    int Count { get; }
}

/// <summary>
/// An entry in the dead-letter queue containing the failed item and reason.
/// </summary>
public record DeadLetterEntry(QueueItem Item, string Reason);

/// <summary>
/// Reports progress of pipeline processing.
/// </summary>
public interface IProgressReporter
{
    void ReportProcessed(QueueItem item);
    void ReportRetrying(QueueItem item, int attempt, int maxRetries, TimeSpan delay);
    void ReportFailed(QueueItem item, string reason);
    void ReportSummary(PipelineSummary summary);
}

/// <summary>
/// Summary of pipeline execution results.
/// </summary>
public record PipelineSummary(
    int TotalItems,
    int Processed,
    int Failed,
    int TotalRetries,
    IReadOnlyList<DeadLetterEntry> DeadLetterItems);
