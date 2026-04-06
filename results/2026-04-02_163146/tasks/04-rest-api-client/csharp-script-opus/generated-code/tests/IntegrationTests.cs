// TDD Cycle 6 - RED: Integration tests that exercise the full pipeline:
// API client with retry handler, pagination, caching, and comment fetching.
// All HTTP is mocked — no real network calls.

using System.Net;
using System.Text.Json;
using RestApiClient;

namespace RestApiClient.Tests;

public class IntegrationTests : IDisposable
{
    private readonly string _cacheDir;

    public IntegrationTests()
    {
        _cacheDir = Path.Combine(Path.GetTempPath(), $"integration_test_{Guid.NewGuid():N}");
    }

    public void Dispose()
    {
        if (Directory.Exists(_cacheDir))
            Directory.Delete(_cacheDir, recursive: true);
    }

    // RED: Full pipeline — fetch paginated posts, fetch comments for each,
    // verify caching, verify data integrity
    [Fact]
    public async Task FullPipeline_FetchPostsAndComments_WithCaching()
    {
        // Setup: 4 posts across 2 pages, each with some comments
        var page1 = new List<Post>
        {
            new() { Id = 1, UserId = 1, Title = "Post 1", Body = "Body 1" },
            new() { Id = 2, UserId = 1, Title = "Post 2", Body = "Body 2" }
        };
        var page2 = new List<Post>
        {
            new() { Id = 3, UserId = 2, Title = "Post 3", Body = "Body 3" },
            new() { Id = 4, UserId = 2, Title = "Post 4", Body = "Body 4" }
        };
        var comments1 = new List<Comment>
        {
            new() { Id = 1, PostId = 1, Name = "C1", Email = "a@b.com", Body = "Comment 1" }
        };
        var comments2 = new List<Comment>
        {
            new() { Id = 2, PostId = 2, Name = "C2", Email = "b@c.com", Body = "Comment 2" },
            new() { Id = 3, PostId = 2, Name = "C3", Email = "c@d.com", Body = "Comment 3" }
        };
        var comments3 = new List<Comment>();
        var comments4 = new List<Comment>
        {
            new() { Id = 4, PostId = 4, Name = "C4", Email = "d@e.com", Body = "Comment 4" }
        };

        var handler = new JsonMockHandler();
        handler.MapGet("/posts?_page=1&_limit=2", page1, totalCount: 4);
        handler.MapGet("/posts?_page=2&_limit=2", page2, totalCount: 4);
        handler.MapGet("/posts/1/comments", comments1);
        handler.MapGet("/posts/2/comments", comments2);
        handler.MapGet("/posts/3/comments", comments3);
        handler.MapGet("/posts/4/comments", comments4);

        // Use retry handler in the pipeline (like production)
        var retryHandler = new RetryHandler(maxRetries: 2, initialDelayMs: 1)
        {
            InnerHandler = handler
        };

        var httpClient = new HttpClient(retryHandler)
        {
            BaseAddress = new Uri("https://jsonplaceholder.typicode.com")
        };
        var cache = new CacheService(_cacheDir);
        var client = new JsonPlaceholderClient(httpClient, cache, pageSize: 2);

        // Act: fetch everything
        var result = await client.GetAllPostsWithCommentsAsync();

        // Assert: correct data structure
        Assert.Equal(4, result.Count);
        Assert.Single(result[0].Comments);
        Assert.Equal(2, result[1].Comments.Count);
        Assert.Empty(result[2].Comments);
        Assert.Single(result[3].Comments);

        // Verify cache files were written
        Assert.True(cache.Exists("all_posts"));
        Assert.True(cache.Exists("comments_post_1"));
        Assert.True(cache.Exists("comments_post_2"));
        Assert.True(cache.Exists("comments_post_3"));
        Assert.True(cache.Exists("comments_post_4"));

        // Second call should use cache (verify no additional API calls)
        var callsBefore = handler.GetCallCount("/posts?_page=1&_limit=2");
        var result2 = await client.GetAllPostsWithCommentsAsync();
        Assert.Equal(4, result2.Count);
        Assert.Equal(callsBefore, handler.GetCallCount("/posts?_page=1&_limit=2"));
    }

    // RED: Pipeline with transient failures — retry handler recovers
    [Fact]
    public async Task Pipeline_WithTransientFailures_RecoversViaRetry()
    {
        // Use a handler that fails once then succeeds for the posts endpoint
        var handler = new TransientFailureHandler(failEveryNth: 1);
        handler.MapGet("/posts?_page=1&_limit=10",
            new List<Post> { new() { Id = 1, Title = "Recovered" } },
            totalCount: 1);
        handler.MapGet("/posts/1/comments",
            new List<Comment> { new() { Id = 1, PostId = 1, Body = "Comment" } });

        var retryHandler = new RetryHandler(maxRetries: 3, initialDelayMs: 1)
        {
            InnerHandler = handler
        };

        var httpClient = new HttpClient(retryHandler)
        {
            BaseAddress = new Uri("https://jsonplaceholder.typicode.com")
        };
        var cache = new CacheService(_cacheDir);
        var client = new JsonPlaceholderClient(httpClient, cache, pageSize: 10);

        var result = await client.GetAllPostsWithCommentsAsync();

        Assert.Single(result);
        Assert.Equal("Recovered", result[0].Post.Title);
        Assert.Single(result[0].Comments);
    }

    // RED: Verify cached data can be loaded from disk as valid JSON
    [Fact]
    public async Task CachedData_IsValidJsonOnDisk()
    {
        var posts = new List<Post>
        {
            new() { Id = 1, UserId = 1, Title = "Persisted", Body = "Body" }
        };

        var handler = new JsonMockHandler();
        handler.MapGet("/posts?_page=1&_limit=10", posts, totalCount: 1);
        handler.MapGet("/posts/1/comments", new List<Comment>());

        var httpClient = new HttpClient(handler)
        {
            BaseAddress = new Uri("https://jsonplaceholder.typicode.com")
        };
        var cache = new CacheService(_cacheDir);
        var client = new JsonPlaceholderClient(httpClient, cache, pageSize: 10);

        await client.GetAllPostsWithCommentsAsync();

        // Read the cached file directly from disk and verify it's valid JSON
        var cachedJson = await File.ReadAllTextAsync(Path.Combine(_cacheDir, "all_posts.json"));
        var loadedPosts = JsonSerializer.Deserialize<List<Post>>(cachedJson);
        Assert.NotNull(loadedPosts);
        Assert.Single(loadedPosts);
        Assert.Equal("Persisted", loadedPosts[0].Title);
    }
}

/// <summary>
/// Mock handler that injects transient 503 errors on the first request to each path,
/// then succeeds on subsequent attempts. Simulates realistic flaky API behavior.
/// </summary>
public class TransientFailureHandler : HttpMessageHandler
{
    private readonly int _failEveryNth;
    private readonly Dictionary<string, (string json, int totalCount)> _mappings = new();
    private readonly Dictionary<string, int> _callCounts = new();

    public TransientFailureHandler(int failEveryNth)
    {
        _failEveryNth = failEveryNth;
    }

    public void MapGet<T>(string pathAndQuery, T data, int totalCount = -1)
    {
        _mappings[pathAndQuery] = (JsonSerializer.Serialize(data), totalCount);
    }

    protected override Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
    {
        var path = request.RequestUri!.PathAndQuery;
        var count = _callCounts.GetValueOrDefault(path, 0) + 1;
        _callCounts[path] = count;

        // Fail on every Nth call (1st call fails, 2nd succeeds, etc.)
        if (count <= _failEveryNth)
        {
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.ServiceUnavailable)
            {
                Content = new StringContent("Transient failure")
            });
        }

        if (_mappings.TryGetValue(path, out var mapping))
        {
            var response = new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(mapping.json, System.Text.Encoding.UTF8, "application/json")
            };
            if (mapping.totalCount >= 0)
                response.Headers.Add("x-total-count", mapping.totalCount.ToString());
            return Task.FromResult(response);
        }

        return Task.FromResult(new HttpResponseMessage(HttpStatusCode.NotFound));
    }
}
