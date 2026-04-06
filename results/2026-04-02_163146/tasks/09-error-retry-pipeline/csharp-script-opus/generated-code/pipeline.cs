// Error Retry Pipeline - .NET 10 file-based app
// Demonstrates: queue processing with exponential backoff retry, dead-letter queue,
// progress reporting, and final summary.
//
// Run with: dotnet run pipeline.cs
//
// All queue and processing operations use interfaces for mockability.
// The pipeline drains a queue, retries failures with exponential backoff,
// and routes permanently failed items to a dead-letter queue.

#nullable enable

// --- Domain types ---

/// <summary>Represents an item to be processed in the pipeline.</summary>
public record QueueItem(string Id, string Payload);

/// <summary>An entry in the dead-letter queue.</summary>
public record DeadLetterEntry(QueueItem Item, string Reason);

/// <summary>Summary of pipeline execution.</summary>
public record PipelineSummary(
    int TotalItems, int Processed, int Failed,
    int TotalRetries, IReadOnlyList<DeadLetterEntry> DeadLetterItems);

// --- Interfaces (all mockable) ---

public interface IQueue
{
    QueueItem? Dequeue();
    int Count { get; }
}

public interface IItemProcessor
{
    Task ProcessAsync(QueueItem item);
}

public interface IDeadLetterQueue
{
    void Enqueue(QueueItem item, string reason);
    IReadOnlyList<DeadLetterEntry> GetAll();
    int Count { get; }
}

public interface IProgressReporter
{
    void ReportProcessed(QueueItem item);
    void ReportRetrying(QueueItem item, int attempt, int maxRetries, TimeSpan delay);
    void ReportFailed(QueueItem item, string reason);
    void ReportSummary(PipelineSummary summary);
}

// --- Retry policy with exponential backoff ---

public class RetryPolicy
{
    public int MaxRetries { get; set; } = 3;
    public TimeSpan BaseDelay { get; set; } = TimeSpan.FromMilliseconds(100);

    /// <summary>Delay = BaseDelay * 2^attempt</summary>
    public TimeSpan GetDelay(int attempt) =>
        TimeSpan.FromMilliseconds(BaseDelay.TotalMilliseconds * Math.Pow(2, attempt));

    public bool ShouldRetry(int currentAttempt) => currentAttempt < MaxRetries;
}

// --- In-memory implementations ---

public class InMemoryQueue : IQueue
{
    private readonly Queue<QueueItem> _items;
    public InMemoryQueue(IEnumerable<QueueItem> items) => _items = new Queue<QueueItem>(items);
    public int Count => _items.Count;
    public QueueItem? Dequeue() => _items.Count > 0 ? _items.Dequeue() : null;
}

public class InMemoryDeadLetterQueue : IDeadLetterQueue
{
    private readonly List<DeadLetterEntry> _entries = new();
    public int Count => _entries.Count;
    public void Enqueue(QueueItem item, string reason) => _entries.Add(new DeadLetterEntry(item, reason));
    public IReadOnlyList<DeadLetterEntry> GetAll() => _entries.AsReadOnly();
}

// --- Console progress reporter ---

public class ConsoleProgressReporter : IProgressReporter
{
    public void ReportProcessed(QueueItem item) =>
        Console.WriteLine($"  [OK]    Processed item {item.Id}");

    public void ReportRetrying(QueueItem item, int attempt, int maxRetries, TimeSpan delay) =>
        Console.WriteLine($"  [RETRY] Item {item.Id} - attempt {attempt}/{maxRetries} (waiting {delay.TotalMilliseconds:F0}ms)");

    public void ReportFailed(QueueItem item, string reason) =>
        Console.WriteLine($"  [FAIL]  Item {item.Id} - {reason}");

    public void ReportSummary(PipelineSummary summary)
    {
        Console.WriteLine();
        Console.WriteLine("=== Pipeline Summary ===");
        Console.WriteLine($"  Total items:     {summary.TotalItems}");
        Console.WriteLine($"  Processed:       {summary.Processed}");
        Console.WriteLine($"  Failed:          {summary.Failed}");
        Console.WriteLine($"  Total retries:   {summary.TotalRetries}");
        if (summary.DeadLetterItems.Count > 0)
        {
            Console.WriteLine();
            Console.WriteLine("  Dead-letter queue:");
            foreach (var entry in summary.DeadLetterItems)
                Console.WriteLine($"    - {entry.Item.Id}: {entry.Reason}");
        }
        Console.WriteLine("========================");
    }
}

// --- Simulated processor that randomly fails ---

public class RandomFailureProcessor : IItemProcessor
{
    private readonly Random _rng;
    private readonly double _failureRate;

    public RandomFailureProcessor(double failureRate = 0.4, int? seed = null)
    {
        _failureRate = failureRate;
        _rng = seed.HasValue ? new Random(seed.Value) : new Random();
    }

    public Task ProcessAsync(QueueItem item)
    {
        if (_rng.NextDouble() < _failureRate)
            throw new InvalidOperationException($"Random processing error for item {item.Id}");

        return Task.CompletedTask;
    }
}

// --- Pipeline processor ---

public class PipelineProcessor
{
    private readonly IQueue _queue;
    private readonly IItemProcessor _processor;
    private readonly IDeadLetterQueue _deadLetterQueue;
    private readonly IProgressReporter _reporter;
    private readonly RetryPolicy _retryPolicy;

    public PipelineProcessor(
        IQueue queue, IItemProcessor processor, IDeadLetterQueue deadLetterQueue,
        IProgressReporter reporter, RetryPolicy retryPolicy)
    {
        _queue = queue;
        _processor = processor;
        _deadLetterQueue = deadLetterQueue;
        _reporter = reporter;
        _retryPolicy = retryPolicy;
    }

    public async Task<PipelineSummary> ProcessAllAsync()
    {
        int totalItems = 0, processed = 0, failed = 0, totalRetries = 0;

        QueueItem? item;
        while ((item = _queue.Dequeue()) is not null)
        {
            totalItems++;
            if (await ProcessWithRetryAsync(item, ref totalRetries))
            {
                processed++;
                _reporter.ReportProcessed(item);
            }
            else
            {
                failed++;
            }
        }

        var summary = new PipelineSummary(totalItems, processed, failed, totalRetries, _deadLetterQueue.GetAll());
        _reporter.ReportSummary(summary);
        return summary;
    }

    private async Task<bool> ProcessWithRetryAsync(QueueItem item, ref int totalRetries)
    {
        int attempt = 0;
        while (true)
        {
            try
            {
                await _processor.ProcessAsync(item);
                return true;
            }
            catch (Exception ex)
            {
                if (_retryPolicy.ShouldRetry(attempt))
                {
                    attempt++;
                    totalRetries++;
                    var delay = _retryPolicy.GetDelay(attempt - 1);
                    _reporter.ReportRetrying(item, attempt, _retryPolicy.MaxRetries, delay);
                    await Task.Delay(delay);
                }
                else
                {
                    var reason = $"Failed after {attempt} retries: {ex.Message}";
                    _deadLetterQueue.Enqueue(item, reason);
                    _reporter.ReportFailed(item, reason);
                    return false;
                }
            }
        }
    }
}

// --- Main entry point ---

Console.WriteLine("Error Retry Pipeline Demo");
Console.WriteLine("=========================");
Console.WriteLine();

// Create 10 items to process
var items = Enumerable.Range(1, 10)
    .Select(i => new QueueItem($"ITEM-{i:D3}", $"payload-{i}"))
    .ToArray();

var queue = new InMemoryQueue(items);
var dlq = new InMemoryDeadLetterQueue();
var reporter = new ConsoleProgressReporter();

// Use a seeded random processor for reproducible demo output (40% failure rate)
var processor = new RandomFailureProcessor(failureRate: 0.4, seed: 42);

// Configure retry: up to 3 retries with 50ms base delay (short for demo)
var retryPolicy = new RetryPolicy { MaxRetries = 3, BaseDelay = TimeSpan.FromMilliseconds(50) };

var pipeline = new PipelineProcessor(queue, processor, dlq, reporter, retryPolicy);

Console.WriteLine($"Processing {items.Length} items (max {retryPolicy.MaxRetries} retries, {retryPolicy.BaseDelay.TotalMilliseconds}ms base delay)...");
Console.WriteLine();

var summary = await pipeline.ProcessAllAsync();

// Exit with non-zero code if any items failed permanently
return summary.Failed > 0 ? 1 : 0;
