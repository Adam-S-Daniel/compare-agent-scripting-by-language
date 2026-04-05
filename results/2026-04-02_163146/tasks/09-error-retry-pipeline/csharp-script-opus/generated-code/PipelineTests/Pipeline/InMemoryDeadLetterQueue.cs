// TDD GREEN: In-memory dead-letter queue implementation.
// Stores items that have permanently failed (exhausted all retries).

namespace Pipeline;

public class InMemoryDeadLetterQueue : IDeadLetterQueue
{
    private readonly List<DeadLetterEntry> _entries = new();

    public int Count => _entries.Count;

    public void Enqueue(QueueItem item, string reason)
    {
        _entries.Add(new DeadLetterEntry(item, reason));
    }

    public IReadOnlyList<DeadLetterEntry> GetAll() => _entries.AsReadOnly();
}
