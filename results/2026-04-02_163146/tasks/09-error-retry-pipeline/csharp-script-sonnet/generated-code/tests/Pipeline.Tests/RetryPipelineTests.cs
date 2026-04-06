// RetryPipelineTests.cs
// TDD tests for the error-retry pipeline.
//
// Strategy:
//  • For the queue we use the real InMemoryQueue<T> — it is a thin, deterministic
//    wrapper around Queue<T> and safe to use directly in tests.
//  • For the processor and progress-reporter we use Moq so that we can precisely
//    control failure patterns without any real I/O.
//
// Red/green/refactor ordering is shown by the numbered test list. Tests were
// written BEFORE the production code they exercise.

using Moq;
using Pipeline.Core;
using Xunit;

public class RetryPipelineTests
{
    // Helper: build a pre-filled InMemoryQueue from a params array
    private static InMemoryQueue<string> Q(params string[] items)
    {
        var q = new InMemoryQueue<string>();
        foreach (var item in items) q.Enqueue(item);
        return q;
    }

    // ---------------------------------------------------------------------------
    // Test 1 — Empty queue → zero-count summary
    // ---------------------------------------------------------------------------
    [Fact]
    public void EmptyQueue_RunsPipeline_ReturnsZeroCounts()
    {
        var pipeline = new RetryPipeline<string>(
            Q(),                                         // empty source
            new Mock<IItemProcessor<string>>().Object,
            new RetryOptions { MaxRetries = 3, BaseDelayMs = 0 });

        var result = pipeline.Run();

        Assert.Equal(0, result.TotalProcessed);
        Assert.Equal(0, result.TotalFailed);
        Assert.Equal(0, result.DeadLetterCount);
    }

    // ---------------------------------------------------------------------------
    // Test 2 — All items succeed on first attempt
    // ---------------------------------------------------------------------------
    [Fact]
    public void AllItemsSucceed_ReportsCorrectCounts()
    {
        var mockProcessor = new Mock<IItemProcessor<string>>();
        mockProcessor.Setup(p => p.Process(It.IsAny<string>()))
            .Returns(ProcessResult.Success);

        var pipeline = new RetryPipeline<string>(
            Q("item-1", "item-2", "item-3"),
            mockProcessor.Object,
            new RetryOptions { MaxRetries = 3, BaseDelayMs = 0 });

        var result = pipeline.Run();

        Assert.Equal(3, result.TotalProcessed);
        Assert.Equal(0, result.TotalFailed);
        Assert.Equal(0, result.DeadLetterCount);
        Assert.Equal(0, result.TotalRetries);
    }

    // ---------------------------------------------------------------------------
    // Test 3 — Item that always fails is sent to dead-letter queue
    // ---------------------------------------------------------------------------
    [Fact]
    public void AlwaysFailingItem_ExceedsMaxRetries_GoesToDeadLetterQueue()
    {
        var mockProcessor = new Mock<IItemProcessor<string>>();
        mockProcessor.Setup(p => p.Process(It.IsAny<string>()))
            .Returns(ProcessResult.Failure);

        var dlq = new InMemoryQueue<string>();

        var pipeline = new RetryPipeline<string>(
            Q("bad-item"),
            mockProcessor.Object,
            new RetryOptions { MaxRetries = 3, BaseDelayMs = 0 },
            deadLetterQueue: dlq);

        var result = pipeline.Run();

        Assert.Equal(0, result.TotalProcessed);
        Assert.Equal(1, result.TotalFailed);
        Assert.Equal(1, result.DeadLetterCount);

        // Dead-letter queue should contain the failed item
        Assert.True(dlq.TryDequeue(out var dlqItem));
        Assert.Equal("bad-item", dlqItem);
    }

    // ---------------------------------------------------------------------------
    // Test 4 — Item succeeds after N retries (transient failure)
    // ---------------------------------------------------------------------------
    [Fact]
    public void TransientFailure_SucceedsOnRetry_NotSentToDlq()
    {
        int callCount = 0;
        var mockProcessor = new Mock<IItemProcessor<string>>();
        // Fail on first 2 attempts, succeed on the 3rd
        mockProcessor.Setup(p => p.Process(It.IsAny<string>()))
            .Returns(() => ++callCount < 3 ? ProcessResult.Failure : ProcessResult.Success);

        var pipeline = new RetryPipeline<string>(
            Q("flaky-item"),
            mockProcessor.Object,
            new RetryOptions { MaxRetries = 3, BaseDelayMs = 0 });

        var result = pipeline.Run();

        Assert.Equal(1, result.TotalProcessed);
        Assert.Equal(0, result.TotalFailed);
        Assert.Equal(0, result.DeadLetterCount);
        Assert.Equal(2, result.TotalRetries); // 2 retries before success
    }

    // ---------------------------------------------------------------------------
    // Test 5 — Retry count is exactly MaxRetries (not more, not less)
    // ---------------------------------------------------------------------------
    [Fact]
    public void ProcessorCalled_ExactlyMaxRetriesPlusOne_Times()
    {
        var mockProcessor = new Mock<IItemProcessor<string>>();
        mockProcessor.Setup(p => p.Process(It.IsAny<string>()))
            .Returns(ProcessResult.Failure);

        var pipeline = new RetryPipeline<string>(
            Q("bad-item"),
            mockProcessor.Object,
            new RetryOptions { MaxRetries = 4, BaseDelayMs = 0 });

        pipeline.Run();

        // 1 initial attempt + 4 retries = 5 total calls
        mockProcessor.Verify(p => p.Process("bad-item"), Times.Exactly(5));
    }

    // ---------------------------------------------------------------------------
    // Test 6 — Progress reporter receives Processed events
    // ---------------------------------------------------------------------------
    [Fact]
    public void ProgressReporter_ReceivesProcessedEvents()
    {
        var mockProcessor = new Mock<IItemProcessor<string>>();
        mockProcessor.Setup(p => p.Process(It.IsAny<string>()))
            .Returns(ProcessResult.Success);

        var mockReporter = new Mock<IProgressReporter>();

        var pipeline = new RetryPipeline<string>(
            Q("item-1", "item-2"),
            mockProcessor.Object,
            new RetryOptions { MaxRetries = 3, BaseDelayMs = 0 },
            progressReporter: mockReporter.Object);

        pipeline.Run();

        // One Processed event per item
        mockReporter.Verify(
            r => r.Report(It.Is<ProgressReport>(p => p.Status == ItemStatus.Processed)),
            Times.Exactly(2));
    }

    // ---------------------------------------------------------------------------
    // Test 7 — Progress reporter is notified on retry attempts
    // ---------------------------------------------------------------------------
    [Fact]
    public void ProgressReporter_ReceivesRetryEvent_WhenItemFails()
    {
        int callCount = 0;
        var mockProcessor = new Mock<IItemProcessor<string>>();
        // Fail once, then succeed
        mockProcessor.Setup(p => p.Process(It.IsAny<string>()))
            .Returns(() => ++callCount < 2 ? ProcessResult.Failure : ProcessResult.Success);

        var mockReporter = new Mock<IProgressReporter>();

        var pipeline = new RetryPipeline<string>(
            Q("flaky-item"),
            mockProcessor.Object,
            new RetryOptions { MaxRetries = 3, BaseDelayMs = 0 },
            progressReporter: mockReporter.Object);

        pipeline.Run();

        mockReporter.Verify(
            r => r.Report(It.Is<ProgressReport>(p => p.Status == ItemStatus.Retrying)),
            Times.Once);
        mockReporter.Verify(
            r => r.Report(It.Is<ProgressReport>(p => p.Status == ItemStatus.Processed)),
            Times.Once);
    }

    // ---------------------------------------------------------------------------
    // Test 8 — Mixed items: correct final summary counts
    // ---------------------------------------------------------------------------
    [Fact]
    public void MixedItems_ProduceCorrectFinalSummary()
    {
        // 3 items: 2 succeed, 1 always fails (→ dead-letter after MaxRetries=2)
        var mockProcessor = new Mock<IItemProcessor<string>>();
        mockProcessor.Setup(p => p.Process("ok-1")).Returns(ProcessResult.Success);
        mockProcessor.Setup(p => p.Process("ok-2")).Returns(ProcessResult.Success);
        mockProcessor.Setup(p => p.Process("bad-item")).Returns(ProcessResult.Failure);

        var pipeline = new RetryPipeline<string>(
            Q("ok-1", "bad-item", "ok-2"),
            mockProcessor.Object,
            new RetryOptions { MaxRetries = 2, BaseDelayMs = 0 });

        var result = pipeline.Run();

        Assert.Equal(2, result.TotalProcessed);
        Assert.Equal(1, result.TotalFailed);
        Assert.Equal(1, result.DeadLetterCount);
        Assert.Equal(2, result.TotalRetries); // bad-item retried MaxRetries=2 times
        Assert.Contains("bad-item", result.DeadLetterItems);
    }

    // ---------------------------------------------------------------------------
    // Test 9 — ToSummary() includes key information
    // ---------------------------------------------------------------------------
    [Fact]
    public void PipelineResult_ToSummary_ContainsAllFields()
    {
        var result = new PipelineResult(
            TotalProcessed: 5,
            TotalFailed: 2,
            TotalRetries: 3,
            DeadLetterCount: 2,
            DeadLetterItems: new[] { "item-a", "item-b" });

        var summary = result.ToSummary();

        Assert.Contains("5", summary);
        Assert.Contains("2", summary);
        Assert.Contains("3", summary);
        Assert.Contains("item-a", summary);
        Assert.Contains("item-b", summary);
    }

    // ---------------------------------------------------------------------------
    // Test 10 — InMemoryQueue Enqueue/TryDequeue round-trip
    // ---------------------------------------------------------------------------
    [Fact]
    public void InMemoryQueue_EnqueueThenDequeue_ReturnsItemsInFifoOrder()
    {
        var queue = new InMemoryQueue<int>();
        queue.Enqueue(1);
        queue.Enqueue(2);
        queue.Enqueue(3);

        Assert.Equal(3, queue.Count);

        Assert.True(queue.TryDequeue(out var a)); Assert.Equal(1, a);
        Assert.True(queue.TryDequeue(out var b)); Assert.Equal(2, b);
        Assert.True(queue.TryDequeue(out var c)); Assert.Equal(3, c);
        Assert.False(queue.TryDequeue(out _));    // empty
        Assert.Equal(0, queue.Count);
    }
}
