// Pipeline retry policy - exponential backoff with configurable max retries.
// TDD GREEN: Implement just enough to pass the retry policy tests.

namespace Pipeline;

/// <summary>
/// Configures retry behavior with exponential backoff.
/// </summary>
public class RetryPolicy
{
    public int MaxRetries { get; set; } = 3;
    public TimeSpan BaseDelay { get; set; } = TimeSpan.FromMilliseconds(100);

    /// <summary>
    /// Calculates the delay for a given retry attempt using exponential backoff.
    /// Delay = BaseDelay * 2^attempt
    /// </summary>
    public TimeSpan GetDelay(int attempt)
    {
        var multiplier = Math.Pow(2, attempt);
        return TimeSpan.FromMilliseconds(BaseDelay.TotalMilliseconds * multiplier);
    }

    /// <summary>
    /// Returns true if another retry attempt should be made.
    /// </summary>
    public bool ShouldRetry(int currentAttempt)
    {
        return currentAttempt < MaxRetries;
    }
}
