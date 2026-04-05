// RetryPipeline.cs
// Core pipeline logic: drain a queue, process each item with exponential-backoff
// retries, send permanently-failed items to a dead-letter queue, and emit
// progress events throughout.

using System.Threading;

namespace Pipeline.Core;

public class RetryPipeline<T>
{
    private readonly IQueue<T> _source;
    private readonly IItemProcessor<T> _processor;
    private readonly RetryOptions _options;
    private readonly IQueue<T>? _deadLetterQueue;
    private readonly IProgressReporter? _progressReporter;

    // Internal default DLQ used when no external one is injected
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

    /// <summary>
    /// Drains the source queue, processing each item with retries.
    /// Returns a summary once the queue is empty.
    /// </summary>
    public PipelineResult Run()
    {
        int processed = 0;
        int failed = 0;
        int retries = 0;
        var deadLetterItems = new List<string>();

        while (_source.TryDequeue(out var item))
        {
            if (item is null) continue;

            string itemKey = item.ToString() ?? "(null)";
            bool succeeded = false;

            // Attempt: initial + up to MaxRetries additional attempts
            for (int attempt = 0; attempt <= _options.MaxRetries; attempt++)
            {
                if (attempt > 0)
                {
                    // Exponential backoff delay before retrying
                    int delayMs = _options.BaseDelayMs * (int)Math.Pow(2, attempt - 1);
                    if (delayMs > 0)
                        Thread.Sleep(delayMs);

                    retries++;
                    _progressReporter?.Report(new ProgressReport(
                        itemKey, ItemStatus.Retrying, attempt, processed, failed));
                }

                var result = _processor.Process(item);

                if (result == ProcessResult.Success)
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

                // Route to dead-letter queue (injected or internal)
                var dlq = _deadLetterQueue ?? _internalDlq;
                dlq.Enqueue(item);

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
