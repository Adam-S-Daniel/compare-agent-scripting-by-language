// Real HTTP service implementation using HttpClient.
// In production, one HttpClient instance is reused per ApiClient.
// In tests, this entire class is replaced by a Moq mock of IHttpService.

namespace RestApiClient;

/// <summary>
/// Wraps <see cref="HttpClient"/> and implements <see cref="IHttpService"/>.
/// Throws <see cref="HttpRequestException"/> with a descriptive message on
/// non-success HTTP status codes.
/// </summary>
public class HttpService : IHttpService
{
    private readonly HttpClient _client;

    /// <summary>Production constructor — creates a shared HttpClient.</summary>
    public HttpService() : this(new HttpClient()) { }

    /// <summary>
    /// Injectable constructor — pass a pre-configured HttpClient
    /// (e.g. one created from IHttpClientFactory).
    /// </summary>
    public HttpService(HttpClient client)
    {
        _client = client;
    }

    /// <inheritdoc/>
    public async Task<string> GetAsync(string url, CancellationToken ct = default)
    {
        HttpResponseMessage response;
        try
        {
            response = await _client.GetAsync(url, ct);
        }
        catch (HttpRequestException ex)
        {
            throw new HttpRequestException(
                $"HTTP request to '{url}' failed: {ex.Message}", ex, ex.StatusCode);
        }

        if (!response.IsSuccessStatusCode)
        {
            throw new HttpRequestException(
                $"HTTP {(int)response.StatusCode} {response.ReasonPhrase} fetching '{url}'",
                inner: null,
                statusCode: response.StatusCode);
        }

        return await response.Content.ReadAsStringAsync(ct);
    }
}
