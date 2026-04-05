// TDD GREEN: Core pipeline processor that dequeues items, processes them with retry,
// sends permanently failed items to a dead-letter queue, and reports progress.

namespace Pipeline;

public class PipelineProcessor
{
    private readonly IQueue _queue;
    private readonly IItemProcessor _processor;
    private readonly IDeadLetterQueue _deadLetterQueue;
    private readonly IProgressReporter _reporter;
    private readonly RetryPolicy _retryPolicy;
    private readonly bool _useRealDelay;

    public PipelineProcessor(
        IQueue queue,
        IItemProcessor processor,
        IDeadLetterQueue deadLetterQueue,
        IProgressReporter reporter,
        RetryPolicy retryPolicy,
        bool useRealDelay = true)
    {
        _queue = queue ?? throw new ArgumentNullException(nameof(queue));
        _processor = processor ?? throw new ArgumentNullException(nameof(processor));
        _deadLetterQueue = deadLetterQueue ?? throw new ArgumentNullException(nameof(deadLetterQueue));
        _reporter = reporter ?? throw new ArgumentNullException(nameof(reporter));
        _retryPolicy = retryPolicy ?? throw new ArgumentNullException(nameof(retryPolicy));
        _useRealDelay = useRealDelay;
    }

    /// <summary>
    /// Processes all items from the queue with retry logic and produces a summary.
    /// </summary>
    public async Task<PipelineSummary> ProcessAllAsync()
    {
        int totalItems = 0;
        int processed = 0;
        int failed = 0;
        int totalRetries = 0;

        // Drain the queue item by item
        QueueItem? item;
        while ((item = _queue.Dequeue()) is not null)
        {
            totalItems++;
            var success = await ProcessWithRetryAsync(item, ref totalRetries);

            if (success)
            {
                processed++;
                _reporter.ReportProcessed(item);
            }
            else
            {
                failed++;
            }
        }

        var summary = new PipelineSummary(
            totalItems,
            processed,
            failed,
            totalRetries,
            _deadLetterQueue.GetAll());

        _reporter.ReportSummary(summary);
        return summary;
    }

    /// <summary>
    /// Attempts to process a single item, retrying on failure with exponential backoff.
    /// Returns true if the item was eventually processed successfully.
    /// </summary>
    private async Task<bool> ProcessWithRetryAsync(QueueItem item, ref int totalRetries)
    {
        int attempt = 0;

        while (true)
        {
            try
            {
                await _processor.ProcessAsync(item);
                return true; // Success
            }
            catch (Exception ex)
            {
                // Check if we can retry
                if (_retryPolicy.ShouldRetry(attempt))
                {
                    attempt++;
                    totalRetries++;
                    var delay = _retryPolicy.GetDelay(attempt - 1);
                    _reporter.ReportRetrying(item, attempt, _retryPolicy.MaxRetries, delay);

                    // Apply delay (skipped in tests for speed)
                    if (_useRealDelay)
                    {
                        await Task.Delay(delay);
                    }
                }
                else
                {
                    // Exhausted all retries - send to dead-letter queue
                    var reason = $"Failed after {attempt} retries: {ex.Message}";
                    _deadLetterQueue.Enqueue(item, reason);
                    _reporter.ReportFailed(item, reason);
                    return false;
                }
            }
        }
    }
}
