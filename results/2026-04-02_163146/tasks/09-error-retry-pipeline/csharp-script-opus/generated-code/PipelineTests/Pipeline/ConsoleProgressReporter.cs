// Console-based progress reporter that prints status to stdout.

namespace Pipeline;

public class ConsoleProgressReporter : IProgressReporter
{
    public void ReportProcessed(QueueItem item)
    {
        Console.WriteLine($"  [OK]    Processed item {item.Id}");
    }

    public void ReportRetrying(QueueItem item, int attempt, int maxRetries, TimeSpan delay)
    {
        Console.WriteLine($"  [RETRY] Item {item.Id} - attempt {attempt}/{maxRetries} (waiting {delay.TotalMilliseconds:F0}ms)");
    }

    public void ReportFailed(QueueItem item, string reason)
    {
        Console.WriteLine($"  [FAIL]  Item {item.Id} - {reason}");
    }

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
            {
                Console.WriteLine($"    - {entry.Item.Id}: {entry.Reason}");
            }
        }

        Console.WriteLine("========================");
    }
}
