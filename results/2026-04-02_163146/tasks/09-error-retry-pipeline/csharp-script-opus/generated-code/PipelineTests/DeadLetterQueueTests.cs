// TDD RED then GREEN: Tests for the in-memory dead-letter queue implementation.

using Xunit;
using Pipeline;

namespace PipelineTests;

public class DeadLetterQueueTests
{
    // RED: Test that new DLQ starts empty
    [Fact]
    public void DeadLetterQueue_StartsEmpty()
    {
        var dlq = new InMemoryDeadLetterQueue();

        Assert.Equal(0, dlq.Count);
        Assert.Empty(dlq.GetAll());
    }

    // RED: Test enqueueing an item
    [Fact]
    public void DeadLetterQueue_Enqueue_AddsItem()
    {
        var dlq = new InMemoryDeadLetterQueue();
        var item = new QueueItem("1", "test-payload");

        dlq.Enqueue(item, "Max retries exceeded");

        Assert.Equal(1, dlq.Count);
        var entries = dlq.GetAll();
        Assert.Single(entries);
        Assert.Equal("1", entries[0].Item.Id);
        Assert.Equal("Max retries exceeded", entries[0].Reason);
    }

    // RED: Test enqueueing multiple items
    [Fact]
    public void DeadLetterQueue_Enqueue_TracksMultipleItems()
    {
        var dlq = new InMemoryDeadLetterQueue();

        dlq.Enqueue(new QueueItem("1", "p1"), "Error A");
        dlq.Enqueue(new QueueItem("2", "p2"), "Error B");
        dlq.Enqueue(new QueueItem("3", "p3"), "Error C");

        Assert.Equal(3, dlq.Count);
        var entries = dlq.GetAll();
        Assert.Equal(3, entries.Count);
    }
}
