// TDD Cycle 2 - RED: Tests for local JSON file caching.
// The cache service stores API responses as JSON files on disk
// and retrieves them when available, avoiding redundant API calls.

using System.Text.Json;
using RestApiClient;

namespace RestApiClient.Tests;

public class CacheServiceTests : IDisposable
{
    private readonly string _cacheDir;
    private readonly CacheService _cache;

    public CacheServiceTests()
    {
        // Each test gets a unique temp directory to avoid conflicts
        _cacheDir = Path.Combine(Path.GetTempPath(), $"api_cache_test_{Guid.NewGuid():N}");
        _cache = new CacheService(_cacheDir);
    }

    public void Dispose()
    {
        if (Directory.Exists(_cacheDir))
            Directory.Delete(_cacheDir, recursive: true);
    }

    // RED: Cache should create the directory if it doesn't exist
    [Fact]
    public async Task Save_CreatesDirectoryIfNotExists()
    {
        var posts = new List<Post> { new() { Id = 1, Title = "Test" } };
        await _cache.SaveAsync("posts", posts);

        Assert.True(Directory.Exists(_cacheDir));
    }

    // RED: Saved data should be retrievable
    [Fact]
    public async Task SaveAndLoad_RoundTrips()
    {
        var posts = new List<Post>
        {
            new() { Id = 1, UserId = 1, Title = "First", Body = "Body1" },
            new() { Id = 2, UserId = 1, Title = "Second", Body = "Body2" }
        };

        await _cache.SaveAsync("posts_page_1", posts);
        var loaded = await _cache.LoadAsync<List<Post>>("posts_page_1");

        Assert.NotNull(loaded);
        Assert.Equal(2, loaded.Count);
        Assert.Equal("First", loaded[0].Title);
        Assert.Equal("Second", loaded[1].Title);
    }

    // RED: Loading a missing key returns null
    [Fact]
    public async Task Load_ReturnsNullForMissingKey()
    {
        var result = await _cache.LoadAsync<List<Post>>("nonexistent");
        Assert.Null(result);
    }

    // RED: Cache should report whether a key exists
    [Fact]
    public async Task Exists_ReturnsTrueForCachedData()
    {
        await _cache.SaveAsync("test_key", new Post { Id = 1 });

        Assert.True(_cache.Exists("test_key"));
        Assert.False(_cache.Exists("other_key"));
    }

    // RED: Cache files should be valid JSON on disk
    [Fact]
    public async Task Save_WritesValidJsonFile()
    {
        var post = new Post { Id = 42, Title = "Cached" };
        await _cache.SaveAsync("single_post", post);

        var filePath = Path.Combine(_cacheDir, "single_post.json");
        Assert.True(File.Exists(filePath));

        var json = await File.ReadAllTextAsync(filePath);
        var deserialized = JsonSerializer.Deserialize<Post>(json);
        Assert.NotNull(deserialized);
        Assert.Equal(42, deserialized.Id);
    }

    // RED: Cache should handle PostWithComments
    [Fact]
    public async Task SaveAndLoad_PostWithComments()
    {
        var data = new PostWithComments
        {
            Post = new Post { Id = 1, Title = "P" },
            Comments = new List<Comment>
            {
                new() { Id = 1, PostId = 1, Body = "C1" },
                new() { Id = 2, PostId = 1, Body = "C2" }
            }
        };

        await _cache.SaveAsync("post_1_with_comments", data);
        var loaded = await _cache.LoadAsync<PostWithComments>("post_1_with_comments");

        Assert.NotNull(loaded);
        Assert.Equal(1, loaded.Post.Id);
        Assert.Equal(2, loaded.Comments.Count);
    }
}
