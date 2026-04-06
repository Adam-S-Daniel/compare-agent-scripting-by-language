// TDD GREEN: RetryPolicy created to make RetryPolicyTests pass.
//
// Design decisions:
// - The sleep function is injected via constructor so tests can pass a no-op
//   and never actually wait, while production uses Task.Delay.
// - Exponential delay formula: baseDelayMs × 2^attempt  (attempt starts at 0)
//   e.g. base=1000ms → 1000ms, 2000ms, 4000ms for 3 retries.
// - OperationCanceledException is re-thrown immediately without retry, so
//   callers can cancel a long-running fetch cleanly.
// - After maxRetries+1 total attempts the exception is wrapped in
//   RetryExhaustedException to give callers a clear signal.

namespace RestApiClient;

/// <summary>
/// Executes an async operation with exponential-backoff retry on failure.
/// </summary>
public class RetryPolicy
{
    private readonly int _maxRetries;
    private readonly int _baseDelayMs;
    private readonly Func<TimeSpan, CancellationToken, Task> _sleep;

    /// <summary>
    /// Production constructor — uses <see cref="Task.Delay(TimeSpan,CancellationToken)"/>
    /// for real backoff.
    /// </summary>
    public RetryPolicy(int maxRetries = 3, int baseDelayMs = 1000)
        : this(maxRetries, baseDelayMs, Task.Delay) { }

    /// <summary>
    /// Testable constructor — inject a custom sleep function (e.g. no-op)
    /// to avoid real delays in unit tests.
    /// </summary>
    public RetryPolicy(
        int maxRetries,
        int baseDelayMs,
        Func<TimeSpan, CancellationToken, Task> sleep)
    {
        _maxRetries  = maxRetries;
        _baseDelayMs = baseDelayMs;
        _sleep       = sleep;
    }

    /// <summary>
    /// Executes <paramref name="operation"/> and retries on failure with
    /// exponential backoff up to <c>maxRetries</c> times.
    /// </summary>
    /// <exception cref="RetryExhaustedException">
    /// Thrown when all attempts have failed; wraps the last exception.
    /// </exception>
    public async Task<T> ExecuteAsync<T>(
        Func<Task<T>> operation,
        CancellationToken ct = default)
    {
        Exception? lastEx = null;

        for (var attempt = 0; attempt <= _maxRetries; attempt++)
        {
            try
            {
                return await operation();
            }
            catch (OperationCanceledException)
            {
                // Never retry cancellations — propagate immediately
                throw;
            }
            catch (Exception ex)
            {
                lastEx = ex;

                if (attempt < _maxRetries)
                {
                    // Exponential backoff: base × 2^attempt
                    var delay = TimeSpan.FromMilliseconds(
                        _baseDelayMs * Math.Pow(2, attempt));
                    await _sleep(delay, ct);
                }
            }
        }

        throw new RetryExhaustedException(
            $"Operation failed after {_maxRetries + 1} attempt(s).", lastEx);
    }
}

/// <summary>
/// Thrown by <see cref="RetryPolicy.ExecuteAsync{T}"/> when all retry
/// attempts have been exhausted.
/// </summary>
public class RetryExhaustedException : Exception
{
    public RetryExhaustedException(string message, Exception? innerException = null)
        : base(message, innerException) { }
}
