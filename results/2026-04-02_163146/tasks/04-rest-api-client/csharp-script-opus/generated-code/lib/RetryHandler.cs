// RetryHandler: a DelegatingHandler that implements retry with exponential backoff.
// Retries on server errors (5xx), 429 Too Many Requests, and network exceptions.
// Client errors (4xx except 429) are NOT retried — they indicate a logic error.
// Delay doubles on each retry: initialDelay, initialDelay*2, initialDelay*4, ...

using System.Net;

namespace RestApiClient;

public class RetryHandler : DelegatingHandler
{
    private readonly int _maxRetries;
    private readonly int _initialDelayMs;

    public RetryHandler(int maxRetries = 3, int initialDelayMs = 1000)
    {
        _maxRetries = maxRetries;
        _initialDelayMs = initialDelayMs;
    }

    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
    {
        HttpResponseMessage? response = null;

        for (int attempt = 0; attempt <= _maxRetries; attempt++)
        {
            try
            {
                // Clone the request for retries (original request can only be sent once)
                using var clonedRequest = await CloneRequestAsync(request);
                response = await base.SendAsync(clonedRequest, cancellationToken);

                // Don't retry on success or non-retryable client errors
                if (response.IsSuccessStatusCode || !IsRetryable(response.StatusCode))
                    return response;
            }
            catch (HttpRequestException) when (attempt < _maxRetries)
            {
                // Network failure — will retry
            }

            // Wait with exponential backoff before retrying
            if (attempt < _maxRetries)
            {
                var delayMs = _initialDelayMs * (int)Math.Pow(2, attempt);
                await Task.Delay(delayMs, cancellationToken);
            }
        }

        // Return the last response (which was an error) after exhausting retries
        return response ?? new HttpResponseMessage(HttpStatusCode.ServiceUnavailable)
        {
            Content = new StringContent("All retry attempts exhausted with no response.")
        };
    }

    /// <summary>Determines if a status code warrants a retry.</summary>
    private static bool IsRetryable(HttpStatusCode statusCode)
    {
        return statusCode == HttpStatusCode.TooManyRequests
            || (int)statusCode >= 500;
    }

    /// <summary>
    /// Creates a copy of the request so we can send it multiple times.
    /// The original HttpRequestMessage cannot be sent more than once.
    /// </summary>
    private static async Task<HttpRequestMessage> CloneRequestAsync(HttpRequestMessage request)
    {
        var clone = new HttpRequestMessage(request.Method, request.RequestUri);

        if (request.Content != null)
        {
            var content = await request.Content.ReadAsByteArrayAsync();
            clone.Content = new ByteArrayContent(content);
            foreach (var header in request.Content.Headers)
                clone.Content.Headers.TryAddWithoutValidation(header.Key, header.Value);
        }

        foreach (var header in request.Headers)
            clone.Headers.TryAddWithoutValidation(header.Key, header.Value);

        clone.Version = request.Version;
        return clone;
    }
}
