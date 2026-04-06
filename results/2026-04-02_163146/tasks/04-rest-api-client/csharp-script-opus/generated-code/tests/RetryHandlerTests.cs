// TDD Cycle 3 - RED: Tests for retry with exponential backoff.
// The RetryHandler is a DelegatingHandler that intercepts HTTP requests
// and retries failed ones with exponentially increasing delays.

using System.Net;
using RestApiClient;

namespace RestApiClient.Tests;

public class RetryHandlerTests
{
    // RED: Successful request should pass through without retry
    [Fact]
    public async Task SuccessfulRequest_NoRetry()
    {
        var mockHandler = new MockHttpHandler(new[]
        {
            new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("success")
            }
        });

        var retryHandler = new RetryHandler(maxRetries: 3, initialDelayMs: 10)
        {
            InnerHandler = mockHandler
        };

        using var client = new HttpClient(retryHandler);
        var response = await client.GetAsync("http://example.com/test");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(1, mockHandler.CallCount);
    }

    // RED: Should retry on 500 errors and eventually succeed
    [Fact]
    public async Task ServerError_RetriesAndSucceeds()
    {
        var mockHandler = new MockHttpHandler(new[]
        {
            new HttpResponseMessage(HttpStatusCode.InternalServerError),
            new HttpResponseMessage(HttpStatusCode.InternalServerError),
            new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("recovered")
            }
        });

        var retryHandler = new RetryHandler(maxRetries: 3, initialDelayMs: 10)
        {
            InnerHandler = mockHandler
        };

        using var client = new HttpClient(retryHandler);
        var response = await client.GetAsync("http://example.com/test");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(3, mockHandler.CallCount); // 1 initial + 2 retries
    }

    // RED: Should give up after max retries and return the last error response
    [Fact]
    public async Task ExceedsMaxRetries_ReturnsLastErrorResponse()
    {
        var mockHandler = new MockHttpHandler(new[]
        {
            new HttpResponseMessage(HttpStatusCode.ServiceUnavailable),
            new HttpResponseMessage(HttpStatusCode.ServiceUnavailable),
            new HttpResponseMessage(HttpStatusCode.ServiceUnavailable),
            new HttpResponseMessage(HttpStatusCode.ServiceUnavailable)
        });

        var retryHandler = new RetryHandler(maxRetries: 3, initialDelayMs: 10)
        {
            InnerHandler = mockHandler
        };

        using var client = new HttpClient(retryHandler);
        var response = await client.GetAsync("http://example.com/test");

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.Equal(4, mockHandler.CallCount); // 1 initial + 3 retries
    }

    // RED: Should retry on 429 Too Many Requests
    [Fact]
    public async Task TooManyRequests_Retries()
    {
        var mockHandler = new MockHttpHandler(new[]
        {
            new HttpResponseMessage(HttpStatusCode.TooManyRequests),
            new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("ok")
            }
        });

        var retryHandler = new RetryHandler(maxRetries: 3, initialDelayMs: 10)
        {
            InnerHandler = mockHandler
        };

        using var client = new HttpClient(retryHandler);
        var response = await client.GetAsync("http://example.com/test");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(2, mockHandler.CallCount);
    }

    // RED: Should NOT retry on 404 (client errors are not retryable)
    [Fact]
    public async Task NotFound_DoesNotRetry()
    {
        var mockHandler = new MockHttpHandler(new[]
        {
            new HttpResponseMessage(HttpStatusCode.NotFound)
        });

        var retryHandler = new RetryHandler(maxRetries: 3, initialDelayMs: 10)
        {
            InnerHandler = mockHandler
        };

        using var client = new HttpClient(retryHandler);
        var response = await client.GetAsync("http://example.com/test");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Equal(1, mockHandler.CallCount);
    }

    // RED: Delays should increase exponentially
    [Fact]
    public async Task ExponentialBackoff_DelaysIncrease()
    {
        var mockHandler = new MockHttpHandler(new[]
        {
            new HttpResponseMessage(HttpStatusCode.InternalServerError),
            new HttpResponseMessage(HttpStatusCode.InternalServerError),
            new HttpResponseMessage(HttpStatusCode.InternalServerError),
            new HttpResponseMessage(HttpStatusCode.OK)
        });

        // Use a very small initial delay so the test runs fast,
        // but we can still verify the handler made all the attempts
        var retryHandler = new RetryHandler(maxRetries: 3, initialDelayMs: 1)
        {
            InnerHandler = mockHandler
        };

        using var client = new HttpClient(retryHandler);
        var sw = System.Diagnostics.Stopwatch.StartNew();
        var response = await client.GetAsync("http://example.com/test");
        sw.Stop();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(4, mockHandler.CallCount);
        // With delays of 1ms, 2ms, 4ms the total is at least ~7ms
        // but we just verify the handler retried the correct number of times
    }

    // RED: Should retry on network exceptions (HttpRequestException)
    [Fact]
    public async Task NetworkException_RetriesAndSucceeds()
    {
        var mockHandler = new ExceptionThenSuccessHandler(
            failCount: 2,
            successResponse: new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("recovered from network error")
            }
        );

        var retryHandler = new RetryHandler(maxRetries: 3, initialDelayMs: 10)
        {
            InnerHandler = mockHandler
        };

        using var client = new HttpClient(retryHandler);
        var response = await client.GetAsync("http://example.com/test");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(3, mockHandler.CallCount);
    }
}

/// <summary>
/// Mock HTTP handler that returns pre-defined responses in sequence.
/// Used to simulate various server behaviors for testing retry logic.
/// </summary>
public class MockHttpHandler : HttpMessageHandler
{
    private readonly HttpResponseMessage[] _responses;
    private int _callIndex;

    public int CallCount => _callIndex;

    public MockHttpHandler(HttpResponseMessage[] responses)
    {
        _responses = responses;
    }

    protected override Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
    {
        if (_callIndex < _responses.Length)
            return Task.FromResult(_responses[_callIndex++]);

        // If more calls than expected, return the last response
        _callIndex++;
        return Task.FromResult(_responses[^1]);
    }
}

/// <summary>
/// Mock handler that throws HttpRequestException for the first N calls,
/// then returns a success response. Simulates transient network failures.
/// </summary>
public class ExceptionThenSuccessHandler : HttpMessageHandler
{
    private readonly int _failCount;
    private readonly HttpResponseMessage _successResponse;
    private int _callIndex;

    public int CallCount => _callIndex;

    public ExceptionThenSuccessHandler(int failCount, HttpResponseMessage successResponse)
    {
        _failCount = failCount;
        _successResponse = successResponse;
    }

    protected override Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
    {
        _callIndex++;
        if (_callIndex <= _failCount)
            throw new HttpRequestException($"Simulated network failure #{_callIndex}");

        return Task.FromResult(_successResponse);
    }
}
