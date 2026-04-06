// TDD GREEN: In-memory queue implementation backed by a standard Queue<T>.

namespace Pipeline;

public class InMemoryQueue : IQueue
{
    private readonly Queue<QueueItem> _items;

    public InMemoryQueue(IEnumerable<QueueItem> items)
    {
        _items = new Queue<QueueItem>(items);
    }

    public int Count => _items.Count;

    public QueueItem? Dequeue()
    {
        return _items.Count > 0 ? _items.Dequeue() : null;
    }
}
