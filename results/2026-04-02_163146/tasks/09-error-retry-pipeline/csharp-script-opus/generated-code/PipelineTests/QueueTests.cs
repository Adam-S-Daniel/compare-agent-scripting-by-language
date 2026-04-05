// TDD: Tests for the in-memory queue implementation.

using Xunit;
using Pipeline;

namespace PipelineTests;

public class QueueTests
{
    [Fact]
    public void InMemoryQueue_StartsWithProvidedItems()
    {
        var items = new[] { new QueueItem("1", "a"), new QueueItem("2", "b") };
        var queue = new InMemoryQueue(items);

        Assert.Equal(2, queue.Count);
    }

    [Fact]
    public void InMemoryQueue_Dequeue_ReturnsItemsInOrder()
    {
        var items = new[] { new QueueItem("1", "first"), new QueueItem("2", "second") };
        var queue = new InMemoryQueue(items);

        var first = queue.Dequeue();
        var second = queue.Dequeue();

        Assert.Equal("1", first!.Id);
        Assert.Equal("2", second!.Id);
    }

    [Fact]
    public void InMemoryQueue_Dequeue_ReturnsNullWhenEmpty()
    {
        var queue = new InMemoryQueue(Array.Empty<QueueItem>());

        Assert.Null(queue.Dequeue());
    }

    [Fact]
    public void InMemoryQueue_Count_DecrementsOnDequeue()
    {
        var queue = new InMemoryQueue(new[] { new QueueItem("1", "a") });

        Assert.Equal(1, queue.Count);
        queue.Dequeue();
        Assert.Equal(0, queue.Count);
    }
}
