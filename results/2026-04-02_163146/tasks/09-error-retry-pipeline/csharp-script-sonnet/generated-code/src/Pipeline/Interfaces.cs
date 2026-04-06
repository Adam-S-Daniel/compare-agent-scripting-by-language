// Interfaces.cs
// Core abstractions for the retry pipeline.
// All interfaces are designed to be mockable so tests don't need real I/O.

namespace Pipeline.Core;

/// <summary>Result of processing a single queue item.</summary>
public enum ProcessResult { Success, Failure }

/// <summary>Status emitted during progress reporting.</summary>
public enum ItemStatus { Processed, Retrying, Failed }

/// <summary>Generic queue abstraction — enqueue and dequeue operations.</summary>
public interface IQueue<T>
{
    void Enqueue(T item);
    bool TryDequeue(out T? item);
    int Count { get; }
}

/// <summary>Processor abstraction — transforms/handles a single queue item.</summary>
public interface IItemProcessor<T>
{
    ProcessResult Process(T item);
}

/// <summary>Progress event emitted for each state change in the pipeline.</summary>
public record ProgressReport(
    string ItemKey,
    ItemStatus Status,
    int AttemptNumber,
    int ProcessedSoFar,
    int FailedSoFar
);

/// <summary>Called by the pipeline whenever an item changes state.</summary>
public interface IProgressReporter
{
    void Report(ProgressReport report);
}
