// TDD Cycles 4 & 5 - RED: Tests for the JsonPlaceholderClient.
// Tests cover pagination, fetching posts and comments, caching integration,
// and error handling. All HTTP calls are mocked via a custom handler.

using System.Net;
using System.Text.Json;
using RestApiClient;

namespace RestApiClient.Tests;

public class ApiClientTests : IDisposable
{
    private readonly string _cacheDir;

    public ApiClientTests()
    {
        _cacheDir = Path.Combine(Path.GetTempPath(), $"api_test_{Guid.NewGuid():N}");
    }

    public void Dispose()
    {
        if (Directory.Exists(_cacheDir))
            Directory.Delete(_cacheDir, recursive: true);
    }

    // --- Pagination Tests (Cycle 4) ---

    // RED: Should fetch a single page of posts
    [Fact]
    public async Task GetPosts_FetchesSinglePage()
    {
        var posts = Enumerable.Range(1, 5)
            .Select(i => new Post { Id = i, UserId = 1, Title = $"Post {i}", Body = "Body" })
            .ToList();

        var handler = new JsonMockHandler();
        handler.MapGet("/posts?_page=1&_limit=10", posts, totalCount: 5);

        var client = CreateClient(handler);
        var result = await client.GetPostsAsync(page: 1, pageSize: 10);

        Assert.Equal(5, result.Count);
        Assert.Equal("Post 1", result[0].Title);
    }

    // RED: Should paginate through all posts when there are multiple pages
    [Fact]
    public async Task GetAllPosts_PaginatesThroughAllPages()
    {
        var page1 = Enumerable.Range(1, 3)
            .Select(i => new Post { Id = i, UserId = 1, Title = $"Post {i}" })
            .ToList();
        var page2 = Enumerable.Range(4, 2)
            .Select(i => new Post { Id = i, UserId = 1, Title = $"Post {i}" })
            .ToList();

        var handler = new JsonMockHandler();
        handler.MapGet("/posts?_page=1&_limit=3", page1, totalCount: 5);
        handler.MapGet("/posts?_page=2&_limit=3", page2, totalCount: 5);

        var client = CreateClient(handler, pageSize: 3);
        var result = await client.GetAllPostsAsync();

        Assert.Equal(5, result.Count);
        Assert.Equal("Post 1", result[0].Title);
        Assert.Equal("Post 5", result[4].Title);
    }

    // RED: Should handle empty result set
    [Fact]
    public async Task GetAllPosts_HandlesEmptyResult()
    {
        var handler = new JsonMockHandler();
        handler.MapGet("/posts?_page=1&_limit=10", new List<Post>(), totalCount: 0);

        var client = CreateClient(handler);
        var result = await client.GetAllPostsAsync();

        Assert.Empty(result);
    }

    // --- Comment Fetching Tests (Cycle 5) ---

    // RED: Should fetch comments for a specific post
    [Fact]
    public async Task GetComments_FetchesForPost()
    {
        var comments = new List<Comment>
        {
            new() { Id = 1, PostId = 42, Name = "C1", Email = "a@b.com", Body = "Body1" },
            new() { Id = 2, PostId = 42, Name = "C2", Email = "c@d.com", Body = "Body2" }
        };

        var handler = new JsonMockHandler();
        handler.MapGet("/posts/42/comments", comments);

        var client = CreateClient(handler);
        var result = await client.GetCommentsForPostAsync(42);

        Assert.Equal(2, result.Count);
        Assert.Equal("C1", result[0].Name);
        Assert.All(result, c => Assert.Equal(42, c.PostId));
    }

    // RED: Should fetch posts with their comments combined
    [Fact]
    public async Task GetPostsWithComments_CombinesData()
    {
        var posts = new List<Post>
        {
            new() { Id = 1, UserId = 1, Title = "P1" },
            new() { Id = 2, UserId = 1, Title = "P2" }
        };
        var comments1 = new List<Comment>
        {
            new() { Id = 1, PostId = 1, Name = "C1" }
        };
        var comments2 = new List<Comment>
        {
            new() { Id = 2, PostId = 2, Name = "C2" },
            new() { Id = 3, PostId = 2, Name = "C3" }
        };

        var handler = new JsonMockHandler();
        handler.MapGet("/posts?_page=1&_limit=10", posts, totalCount: 2);
        handler.MapGet("/posts/1/comments", comments1);
        handler.MapGet("/posts/2/comments", comments2);

        var client = CreateClient(handler);
        var result = await client.GetAllPostsWithCommentsAsync();

        Assert.Equal(2, result.Count);
        Assert.Single(result[0].Comments);
        Assert.Equal(2, result[1].Comments.Count);
    }

    // --- Caching Tests ---

    // RED: Should cache posts and not re-fetch on second call
    [Fact]
    public async Task GetAllPosts_UsesCacheOnSecondCall()
    {
        var posts = new List<Post>
        {
            new() { Id = 1, UserId = 1, Title = "Cached" }
        };

        var handler = new JsonMockHandler();
        handler.MapGet("/posts?_page=1&_limit=10", posts, totalCount: 1);

        var client = CreateClient(handler);

        // First call — hits the API
        var result1 = await client.GetAllPostsAsync();
        Assert.Single(result1);
        Assert.Equal(1, handler.GetCallCount("/posts?_page=1&_limit=10"));

        // Second call — should use cache, no additional API call
        var result2 = await client.GetAllPostsAsync();
        Assert.Single(result2);
        Assert.Equal(1, handler.GetCallCount("/posts?_page=1&_limit=10"));
    }

    // RED: Should cache comments per post
    [Fact]
    public async Task GetComments_UsesCacheOnSecondCall()
    {
        var comments = new List<Comment>
        {
            new() { Id = 1, PostId = 5, Name = "Cached Comment" }
        };

        var handler = new JsonMockHandler();
        handler.MapGet("/posts/5/comments", comments);

        var client = CreateClient(handler);

        var r1 = await client.GetCommentsForPostAsync(5);
        Assert.Single(r1);
        Assert.Equal(1, handler.GetCallCount("/posts/5/comments"));

        var r2 = await client.GetCommentsForPostAsync(5);
        Assert.Single(r2);
        Assert.Equal(1, handler.GetCallCount("/posts/5/comments"));
    }

    // --- Error Handling ---

    // RED: Should throw a meaningful error when API returns 404
    [Fact]
    public async Task GetPosts_ThrowsOnNotFound()
    {
        var handler = new JsonMockHandler();
        handler.MapError("/posts?_page=1&_limit=10", HttpStatusCode.NotFound);

        var client = CreateClient(handler);

        var ex = await Assert.ThrowsAsync<ApiException>(
            () => client.GetPostsAsync(page: 1, pageSize: 10));
        Assert.Contains("404", ex.Message);
    }

    // RED: Should throw on unexpected errors
    [Fact]
    public async Task GetComments_ThrowsOnServerError()
    {
        var handler = new JsonMockHandler();
        // After retries are exhausted, client should throw
        handler.MapError("/posts/1/comments", HttpStatusCode.InternalServerError);

        // Use a retry handler with very short delays for testing
        var retryHandler = new RetryHandler(maxRetries: 1, initialDelayMs: 1)
        {
            InnerHandler = handler
        };

        var httpClient = new HttpClient(retryHandler)
        {
            BaseAddress = new Uri("https://jsonplaceholder.typicode.com")
        };
        var cache = new CacheService(_cacheDir);
        var client = new JsonPlaceholderClient(httpClient, cache, pageSize: 10);

        var ex = await Assert.ThrowsAsync<ApiException>(
            () => client.GetCommentsForPostAsync(1));
        Assert.Contains("500", ex.Message);
    }

    private JsonPlaceholderClient CreateClient(JsonMockHandler handler, int pageSize = 10)
    {
        var httpClient = new HttpClient(handler)
        {
            BaseAddress = new Uri("https://jsonplaceholder.typicode.com")
        };
        var cache = new CacheService(_cacheDir);
        return new JsonPlaceholderClient(httpClient, cache, pageSize: pageSize);
    }
}

/// <summary>
/// Mock HTTP handler that returns JSON responses based on URL path+query.
/// Supports mapping paths to JSON data or error status codes.
/// Tracks call counts per path for verifying caching behavior.
/// </summary>
public class JsonMockHandler : HttpMessageHandler
{
    private readonly Dictionary<string, (string json, int totalCount)> _mappings = new();
    private readonly Dictionary<string, HttpStatusCode> _errors = new();
    private readonly Dictionary<string, int> _callCounts = new();

    public void MapGet<T>(string pathAndQuery, T data, int totalCount = -1)
    {
        var json = JsonSerializer.Serialize(data);
        _mappings[pathAndQuery] = (json, totalCount);
    }

    public void MapError(string pathAndQuery, HttpStatusCode statusCode)
    {
        _errors[pathAndQuery] = statusCode;
    }

    public int GetCallCount(string pathAndQuery)
    {
        return _callCounts.GetValueOrDefault(pathAndQuery, 0);
    }

    protected override Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
    {
        var pathAndQuery = request.RequestUri!.PathAndQuery;

        // Track calls for cache verification
        _callCounts[pathAndQuery] = _callCounts.GetValueOrDefault(pathAndQuery, 0) + 1;

        // Check for error mappings first
        if (_errors.TryGetValue(pathAndQuery, out var errorCode))
        {
            return Task.FromResult(new HttpResponseMessage(errorCode)
            {
                Content = new StringContent($"{{\"error\": \"{errorCode}\"}}")
            });
        }

        // Check for data mappings
        if (_mappings.TryGetValue(pathAndQuery, out var mapping))
        {
            var response = new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(mapping.json, System.Text.Encoding.UTF8, "application/json")
            };

            // Add x-total-count header for pagination support
            if (mapping.totalCount >= 0)
                response.Headers.Add("x-total-count", mapping.totalCount.ToString());

            return Task.FromResult(response);
        }

        // Unmapped path — return 404
        return Task.FromResult(new HttpResponseMessage(HttpStatusCode.NotFound)
        {
            Content = new StringContent($"No mock mapping for {pathAndQuery}")
        });
    }
}
