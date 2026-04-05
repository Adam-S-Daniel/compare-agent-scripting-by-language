// RetryOptions.cs
// Configuration for the retry behaviour.

namespace Pipeline.Core;

public class RetryOptions
{
    /// <summary>Maximum number of retry attempts after the initial failure.</summary>
    public int MaxRetries { get; init; } = 3;

    /// <summary>
    /// Base delay in milliseconds for exponential backoff.
    /// Delay for attempt N = BaseDelayMs * 2^(N-1).
    /// Set to 0 in tests to avoid real waiting.
    /// </summary>
    public int BaseDelayMs { get; init; } = 100;
}
