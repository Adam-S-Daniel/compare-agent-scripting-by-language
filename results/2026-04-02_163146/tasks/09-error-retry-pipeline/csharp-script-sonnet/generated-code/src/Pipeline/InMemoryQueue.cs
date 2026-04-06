// InMemoryQueue.cs
// Simple in-memory queue that implements IQueue<T>.
// Used as the default dead-letter queue and in the demo script.

namespace Pipeline.Core;

public class InMemoryQueue<T> : IQueue<T>
{
    private readonly Queue<T> _inner = new();

    public void Enqueue(T item) => _inner.Enqueue(item);

    public bool TryDequeue(out T? item)
    {
        if (_inner.TryDequeue(out var result))
        {
            item = result;
            return true;
        }
        item = default;
        return false;
    }

    public int Count => _inner.Count;
}
