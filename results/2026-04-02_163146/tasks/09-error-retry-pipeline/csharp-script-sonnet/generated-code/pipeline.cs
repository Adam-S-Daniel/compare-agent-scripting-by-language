// pipeline.cs  — .NET 10 file-based app (run with: dotnet run pipeline.cs)
//
// Demonstrates the error-retry pipeline end-to-end:
//   • InMemoryQueue filled with 10 items
//   • RandomFailureProcessor that fails ~40 % of the time
//   • Exponential-backoff retry (max 3 retries, 100 ms base delay)
//   • Dead-letter queue for permanently-failed items
//   • Console progress reporter
//   • Final summary
//
// All production types are defined inline so the file is self-contained.

using System;
using System.Collections.Generic;
using System.Threading;

// ─── Domain Enums ──────────────────────────────────────────────────────────

/// <summary>Result of a single processing attempt.</summary>
enum ProcessResult { Success, Failure }

/// <summary>Status emitted in progress events.</summary>
enum ItemStatus { Processed, Retrying, Failed }

// ─── Core Interfaces ───────────────────────────────────────────────────────

/// <summary>Mockable queue abstraction.</summary>
interface IQueue<T>
{
    void Enqueue(T item);
    bool TryDequeue(out T? item);
    int Count { get; }
}

/// <summary>Mockable item processor.</summary>
interface IItemProcessor<T>
{
    ProcessResult Process(T item);
}

/// <summary>Progress event payload.</summary>
record ProgressReport(
    string ItemKey,
    ItemStatus Status,
    int AttemptNumber,
    int ProcessedSoFar,
    int FailedSoFar
);

/// <summary>Mockable progress reporter.</summary>
interface IProgressReporter
{
    void Report(ProgressReport report);
}

// ─── Pipeline Configuration ────────────────────────────────────────────────

/// <summary>Retry behaviour settings.</summary>
class RetryOptions
{
    /// <summary>Maximum retry attempts after the initial failure.</summary>
    public int MaxRetries { get; init; } = 3;

    /// <summary>
    /// Base delay in ms for exponential backoff.
    /// Delay for retry N = BaseDelayMs × 2^(N-1).
    /// </summary>
    public int BaseDelayMs { get; init; } = 100;
}

// ─── Pipeline Result ───────────────────────────────────────────────────────

/// <summary>Immutable summary returned after the pipeline drains the queue.</summary>
record PipelineResult(
    int TotalProcessed,
    int TotalFailed,
    int TotalRetries,
    int DeadLetterCount,
    IReadOnlyList<string> DeadLetterItems
)
{
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

// ─── Implementations ───────────────────────────────────────────────────────

/// <summary>Simple in-memory queue backed by Queue&lt;T&gt;.</summary>
class InMemoryQueue<T> : IQueue<T>
{
    private readonly Queue<T> _inner = new();

    public void Enqueue(T item) => _inner.Enqueue(item);

    public bool TryDequeue(out T? item)
    {
        if (_inner.TryDequeue(out var result)) { item = result; return true; }
        item = default;
        return false;
    }

    public int Count => _inner.Count;
}

/// <summary>
/// Processor that simulates random transient failures.
/// failureProbability = 0.0 → always succeeds; 1.0 → always fails.
/// </summary>
class RandomFailureProcessor : IItemProcessor<string>
{
    private readonly double _failureProbability;
    private readonly Random _rng;

    public RandomFailureProcessor(double failureProbability = 0.4, int seed = 42)
    {
        _failureProbability = failureProbability;
        _rng = new Random(seed);
    }

    public ProcessResult Process(string item)
    {
        Console.WriteLine($"  → Processing '{item}'...");
        return _rng.NextDouble() < _failureProbability
            ? ProcessResult.Failure
            : ProcessResult.Success;
    }
}

/// <summary>Reports progress to the console with colour-coded status lines.</summary>
class ConsoleProgressReporter : IProgressReporter
{
    public void Report(ProgressReport r)
    {
        var (icon, color) = r.Status switch
        {
            ItemStatus.Processed => ("✓", ConsoleColor.Green),
            ItemStatus.Retrying  => ("↻", ConsoleColor.Yellow),
            ItemStatus.Failed    => ("✗", ConsoleColor.Red),
            _                    => (" ", ConsoleColor.White),
        };

        Console.ForegroundColor = color;
        Console.WriteLine(
            $"  [{icon}] {r.ItemKey,-20} attempt={r.AttemptNumber}  " +
            $"processed={r.ProcessedSoFar}  failed={r.FailedSoFar}");
        Console.ResetColor();
    }
}

/// <summary>
/// Core pipeline: drain source queue, apply exponential-backoff retries,
/// route permanent failures to a dead-letter queue, emit progress events.
/// </summary>
class RetryPipeline<T>
{
    private readonly IQueue<T> _source;
    private readonly IItemProcessor<T> _processor;
    private readonly RetryOptions _options;
    private readonly IQueue<T>? _deadLetterQueue;
    private readonly IProgressReporter? _progressReporter;
    private readonly InMemoryQueue<T> _internalDlq = new();

    public RetryPipeline(
        IQueue<T> source,
        IItemProcessor<T> processor,
        RetryOptions options,
        IQueue<T>? deadLetterQueue = null,
        IProgressReporter? progressReporter = null)
    {
        _source = source;
        _processor = processor;
        _options = options;
        _deadLetterQueue = deadLetterQueue;
        _progressReporter = progressReporter;
    }

    public PipelineResult Run()
    {
        int processed = 0, failed = 0, retries = 0;
        var deadLetterItems = new List<string>();

        while (_source.TryDequeue(out var item))
        {
            if (item is null) continue;

            string itemKey = item.ToString() ?? "(null)";
            bool succeeded = false;

            // 1 initial attempt + up to MaxRetries retries
            for (int attempt = 0; attempt <= _options.MaxRetries; attempt++)
            {
                if (attempt > 0)
                {
                    // Exponential backoff: 100ms, 200ms, 400ms, …
                    int delayMs = _options.BaseDelayMs * (int)Math.Pow(2, attempt - 1);
                    if (delayMs > 0) Thread.Sleep(delayMs);

                    retries++;
                    _progressReporter?.Report(new ProgressReport(
                        itemKey, ItemStatus.Retrying, attempt, processed, failed));
                }

                if (_processor.Process(item) == ProcessResult.Success)
                {
                    succeeded = true;
                    processed++;
                    _progressReporter?.Report(new ProgressReport(
                        itemKey, ItemStatus.Processed, attempt, processed, failed));
                    break;
                }
            }

            if (!succeeded)
            {
                failed++;
                deadLetterItems.Add(itemKey);
                (_deadLetterQueue ?? _internalDlq).Enqueue(item);

                _progressReporter?.Report(new ProgressReport(
                    itemKey, ItemStatus.Failed, _options.MaxRetries, processed, failed));
            }
        }

        int dlqCount = _deadLetterQueue?.Count ?? _internalDlq.Count;

        return new PipelineResult(
            TotalProcessed: processed,
            TotalFailed: failed,
            TotalRetries: retries,
            DeadLetterCount: dlqCount,
            DeadLetterItems: deadLetterItems.AsReadOnly()
        );
    }
}

// ─── Entry Point (top-level statements) ────────────────────────────────────

Console.WriteLine("Error-Retry Pipeline Demo");
Console.WriteLine("=========================\n");

// Build a queue with 10 work items
var sourceQueue = new InMemoryQueue<string>();
for (int i = 1; i <= 10; i++)
    sourceQueue.Enqueue($"task-{i:D3}");

var deadLetterQueue = new InMemoryQueue<string>();
var reporter = new ConsoleProgressReporter();
var options = new RetryOptions { MaxRetries = 3, BaseDelayMs = 50 };

// Processor fails ~40% of the time (seeded so output is deterministic)
var processor = new RandomFailureProcessor(failureProbability: 0.4, seed: 12345);

var pipeline = new RetryPipeline<string>(
    sourceQueue, processor, options,
    deadLetterQueue: deadLetterQueue,
    progressReporter: reporter);

Console.WriteLine("Processing queue...\n");
var result = pipeline.Run();

Console.WriteLine();
Console.WriteLine(result.ToSummary());
