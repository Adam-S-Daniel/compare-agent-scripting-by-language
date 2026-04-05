// TDD: Tests for the core PipelineProcessor.
// Tests cover: successful processing, retry on failure, dead-letter on exhausted retries,
// progress reporting, and final summary generation.

using Xunit;
using Pipeline;
using NSubstitute;
using NSubstitute.ExceptionExtensions;

namespace PipelineTests;

public class PipelineProcessorTests
{
    // Helper to create a pipeline with common test setup
    private static (PipelineProcessor processor, IItemProcessor mockProcessor, InMemoryDeadLetterQueue dlq, MockProgressReporter reporter) CreatePipeline(
        QueueItem[] items, RetryPolicy? policy = null)
    {
        var queue = new InMemoryQueue(items);
        var mockProcessor = Substitute.For<IItemProcessor>();
        var dlq = new InMemoryDeadLetterQueue();
        var reporter = new MockProgressReporter();
        var retryPolicy = policy ?? new RetryPolicy { MaxRetries = 3, BaseDelay = TimeSpan.FromMilliseconds(1) };

        // Use zero-delay for tests to avoid slow test execution
        var processor = new PipelineProcessor(queue, mockProcessor, dlq, reporter, retryPolicy, useRealDelay: false);
        return (processor, mockProcessor, dlq, reporter);
    }

    // RED/GREEN: All items process successfully with no retries
    [Fact]
    public async Task ProcessAll_AllItemsSucceed_NoRetries()
    {
        var items = new[]
        {
            new QueueItem("1", "item-1"),
            new QueueItem("2", "item-2"),
            new QueueItem("3", "item-3"),
        };
        var (processor, mockProcessor, dlq, reporter) = CreatePipeline(items);

        // All items succeed (default NSubstitute behavior - no exception)
        var summary = await processor.ProcessAllAsync();

        Assert.Equal(3, summary.TotalItems);
        Assert.Equal(3, summary.Processed);
        Assert.Equal(0, summary.Failed);
        Assert.Equal(0, summary.TotalRetries);
        Assert.Empty(summary.DeadLetterItems);
    }

    // RED/GREEN: Item fails once then succeeds on retry
    [Fact]
    public async Task ProcessAll_ItemFailsOnceThenSucceeds_RetriesAndCompletes()
    {
        var items = new[] { new QueueItem("1", "retry-item") };
        var (processor, mockProcessor, dlq, reporter) = CreatePipeline(items);

        // First call throws, second call succeeds
        var callCount = 0;
        mockProcessor.ProcessAsync(Arg.Any<QueueItem>())
            .Returns(x =>
            {
                callCount++;
                if (callCount == 1)
                    throw new InvalidOperationException("Transient failure");
                return Task.CompletedTask;
            });

        var summary = await processor.ProcessAllAsync();

        Assert.Equal(1, summary.TotalItems);
        Assert.Equal(1, summary.Processed);
        Assert.Equal(0, summary.Failed);
        Assert.Equal(1, summary.TotalRetries);
    }

    // RED/GREEN: Item exhausts all retries and goes to dead-letter queue
    [Fact]
    public async Task ProcessAll_ItemExhaustsRetries_GoesToDeadLetterQueue()
    {
        var items = new[] { new QueueItem("1", "doomed-item") };
        var policy = new RetryPolicy { MaxRetries = 2, BaseDelay = TimeSpan.FromMilliseconds(1) };
        var (processor, mockProcessor, dlq, reporter) = CreatePipeline(items, policy);

        // Always fails
        mockProcessor.ProcessAsync(Arg.Any<QueueItem>())
            .ThrowsAsync(new InvalidOperationException("Permanent failure"));

        var summary = await processor.ProcessAllAsync();

        Assert.Equal(1, summary.TotalItems);
        Assert.Equal(0, summary.Processed);
        Assert.Equal(1, summary.Failed);
        Assert.Equal(2, summary.TotalRetries); // 2 retry attempts
        Assert.Single(summary.DeadLetterItems);
        Assert.Equal("1", summary.DeadLetterItems[0].Item.Id);
        Assert.Contains("Permanent failure", summary.DeadLetterItems[0].Reason);
    }

    // RED/GREEN: Mixed success and failure items
    [Fact]
    public async Task ProcessAll_MixedSuccessAndFailure_CorrectSummary()
    {
        var items = new[]
        {
            new QueueItem("ok-1", "good"),
            new QueueItem("fail-1", "bad"),
            new QueueItem("ok-2", "good"),
        };
        var policy = new RetryPolicy { MaxRetries = 1, BaseDelay = TimeSpan.FromMilliseconds(1) };
        var (processor, mockProcessor, dlq, reporter) = CreatePipeline(items, policy);

        // Only the "bad" payload item fails
        mockProcessor.ProcessAsync(Arg.Is<QueueItem>(i => i.Payload == "bad"))
            .ThrowsAsync(new InvalidOperationException("Bad item"));
        mockProcessor.ProcessAsync(Arg.Is<QueueItem>(i => i.Payload == "good"))
            .Returns(Task.CompletedTask);

        var summary = await processor.ProcessAllAsync();

        Assert.Equal(3, summary.TotalItems);
        Assert.Equal(2, summary.Processed);
        Assert.Equal(1, summary.Failed);
        Assert.Single(summary.DeadLetterItems);
        Assert.Equal("fail-1", summary.DeadLetterItems[0].Item.Id);
    }

    // RED/GREEN: Progress reporter receives correct callbacks
    [Fact]
    public async Task ProcessAll_ReportsProgressForEachItem()
    {
        var items = new[] { new QueueItem("1", "item") };
        var (processor, mockProcessor, dlq, reporter) = CreatePipeline(items);

        await processor.ProcessAllAsync();

        Assert.Single(reporter.ProcessedItems);
        Assert.Equal("1", reporter.ProcessedItems[0].Id);
        Assert.Single(reporter.Summaries);
    }

    // RED/GREEN: Progress reporter receives retry notifications
    [Fact]
    public async Task ProcessAll_ReportsRetryAttempts()
    {
        var items = new[] { new QueueItem("1", "flaky") };
        var policy = new RetryPolicy { MaxRetries = 3, BaseDelay = TimeSpan.FromMilliseconds(1) };
        var (processor, mockProcessor, dlq, reporter) = CreatePipeline(items, policy);

        var callCount = 0;
        mockProcessor.ProcessAsync(Arg.Any<QueueItem>())
            .Returns(x =>
            {
                callCount++;
                if (callCount <= 2) throw new Exception("Transient");
                return Task.CompletedTask;
            });

        await processor.ProcessAllAsync();

        // Should have 2 retry reports (attempt 1 and attempt 2 before success on attempt 3)
        Assert.Equal(2, reporter.RetryReports.Count);
        Assert.Equal(1, reporter.RetryReports[0].Attempt);
        Assert.Equal(2, reporter.RetryReports[1].Attempt);
    }

    // RED/GREEN: Progress reporter receives failure notification for dead-lettered items
    [Fact]
    public async Task ProcessAll_ReportsFailureForDeadLetteredItems()
    {
        var items = new[] { new QueueItem("1", "doomed") };
        var policy = new RetryPolicy { MaxRetries = 0, BaseDelay = TimeSpan.FromMilliseconds(1) };
        var (processor, mockProcessor, dlq, reporter) = CreatePipeline(items, policy);

        mockProcessor.ProcessAsync(Arg.Any<QueueItem>())
            .ThrowsAsync(new InvalidOperationException("Dead"));

        await processor.ProcessAllAsync();

        Assert.Single(reporter.FailedItems);
        Assert.Equal("1", reporter.FailedItems[0].Item.Id);
    }

    // RED/GREEN: Empty queue produces zero-count summary
    [Fact]
    public async Task ProcessAll_EmptyQueue_ProducesEmptySummary()
    {
        var (processor, _, _, reporter) = CreatePipeline(Array.Empty<QueueItem>());

        var summary = await processor.ProcessAllAsync();

        Assert.Equal(0, summary.TotalItems);
        Assert.Equal(0, summary.Processed);
        Assert.Equal(0, summary.Failed);
        Assert.Equal(0, summary.TotalRetries);
        Assert.Empty(summary.DeadLetterItems);
    }

    // RED/GREEN: Summary is reported via progress reporter
    [Fact]
    public async Task ProcessAll_ReportsSummaryAtEnd()
    {
        var items = new[] { new QueueItem("1", "a"), new QueueItem("2", "b") };
        var (processor, _, _, reporter) = CreatePipeline(items);

        await processor.ProcessAllAsync();

        Assert.Single(reporter.Summaries);
        Assert.Equal(2, reporter.Summaries[0].TotalItems);
        Assert.Equal(2, reporter.Summaries[0].Processed);
    }
}

/// <summary>
/// Test double that captures all progress reports for assertion.
/// </summary>
public class MockProgressReporter : IProgressReporter
{
    public List<QueueItem> ProcessedItems { get; } = new();
    public List<(QueueItem Item, int Attempt, int MaxRetries, TimeSpan Delay)> RetryReports { get; } = new();
    public List<(QueueItem Item, string Reason)> FailedItems { get; } = new();
    public List<PipelineSummary> Summaries { get; } = new();

    public void ReportProcessed(QueueItem item) => ProcessedItems.Add(item);

    public void ReportRetrying(QueueItem item, int attempt, int maxRetries, TimeSpan delay)
        => RetryReports.Add((item, attempt, maxRetries, delay));

    public void ReportFailed(QueueItem item, string reason)
        => FailedItems.Add((item, reason));

    public void ReportSummary(PipelineSummary summary) => Summaries.Add(summary);
}
