// REST API Client Tests — JSONPlaceholder
// TDD methodology: each section follows RED → GREEN → REFACTOR
//
// Test order follows implementation order:
//   Cycle 1: Models (Post, Comment, PostWithComments)
//   Cycle 2: CacheService (file-backed JSON cache, via IFileSystem mock)
//   Cycle 3: RetryPolicy (exponential backoff with injectable sleep)
//   Cycle 4: ApiClient (HTTP calls, pagination, cache integration, retries)

using System.Text.Json;
using Moq;
using RestApiClient;
using Xunit;

// ============================================================================
// CYCLE 1: Model Tests
// RED  — Fails to compile: Post / Comment / PostWithComments don't exist
// GREEN — Create Models.cs with the three record types
// ============================================================================

public class ModelTests
{
    [Fact]
    public void Post_HasCorrectProperties()
    {
        var post = new Post(1, 2, "Test Title", "Test Body");
        Assert.Equal(1, post.Id);
        Assert.Equal(2, post.UserId);
        Assert.Equal("Test Title", post.Title);
        Assert.Equal("Test Body", post.Body);
    }

    [Fact]
    public void Post_CanBeDeserializedFromJson()
    {
        // JSONPlaceholder returns camelCase keys
        var json = """{"id":1,"userId":2,"title":"Hello","body":"World"}""";
        var post = JsonSerializer.Deserialize<Post>(json);
        Assert.NotNull(post);
        Assert.Equal(1, post.Id);
        Assert.Equal(2, post.UserId);
        Assert.Equal("Hello", post.Title);
        Assert.Equal("World", post.Body);
    }

    [Fact]
    public void Comment_HasCorrectProperties()
    {
        var c = new Comment(10, 1, "Alice", "alice@example.com", "Nice post");
        Assert.Equal(10, c.Id);
        Assert.Equal(1, c.PostId);
        Assert.Equal("Alice", c.Name);
        Assert.Equal("alice@example.com", c.Email);
        Assert.Equal("Nice post", c.Body);
    }

    [Fact]
    public void Comment_CanBeDeserializedFromJson()
    {
        var json = """{"id":5,"postId":3,"name":"Bob","email":"b@t.com","body":"Hi"}""";
        var comment = JsonSerializer.Deserialize<Comment>(json);
        Assert.NotNull(comment);
        Assert.Equal(5, comment.Id);
        Assert.Equal(3, comment.PostId);
        Assert.Equal("Bob", comment.Name);
    }

    [Fact]
    public void PostWithComments_WrapsPostAndCommentsList()
    {
        var post = new Post(1, 1, "Title", "Body");
        var comments = new List<Comment>
        {
            new(1, 1, "N", "e@t.com", "Cmnt")
        };
        var pwc = new PostWithComments(post, comments);

        Assert.Equal(post, pwc.Post);
        Assert.Single(pwc.Comments);
        Assert.Equal(1, pwc.Comments[0].Id);
    }

    [Fact]
    public void Post_ListCanBeDeserializedFromJsonArray()
    {
        var json = """
            [
              {"id":1,"userId":1,"title":"First","body":"B1"},
              {"id":2,"userId":1,"title":"Second","body":"B2"}
            ]
            """;
        var posts = JsonSerializer.Deserialize<List<Post>>(json);
        Assert.NotNull(posts);
        Assert.Equal(2, posts.Count);
        Assert.Equal("First", posts[0].Title);
        Assert.Equal("Second", posts[1].Title);
    }
}

// ============================================================================
// CYCLE 2: CacheService Tests
// RED  — Fails to compile: CacheService / IFileSystem don't exist
// GREEN — Create Interfaces.cs (IFileSystem) and CacheService.cs
// ============================================================================

public class CacheServiceTests
{
    // Use InMemoryFileSystem (defined at bottom) for all cache tests
    // so no actual disk I/O occurs
    private readonly InMemoryFileSystem _fs = new();
    private readonly CacheService _cache;

    public CacheServiceTests()
    {
        _cache = new CacheService(_fs, "/test/cache");
    }

    [Fact]
    public async Task GetAsync_ReturnNullOnCacheMiss()
    {
        var result = await _cache.GetAsync<List<Post>>("missing-key");
        Assert.Null(result);
    }

    [Fact]
    public async Task SetAsync_ThenGetAsync_ReturnsSameData()
    {
        var posts = new List<Post> { new(1, 1, "T", "B") };

        await _cache.SetAsync("posts", posts);
        var result = await _cache.GetAsync<List<Post>>("posts");

        Assert.NotNull(result);
        Assert.Single(result);
        Assert.Equal(1, result[0].Id);
        Assert.Equal("T", result[0].Title);
    }

    [Fact]
    public async Task SetAsync_CallsEnsureDirectoryExists()
    {
        var mockFs = new Mock<IFileSystem>();
        mockFs.Setup(f => f.WriteAllTextAsync(It.IsAny<string>(), It.IsAny<string>()))
              .Returns(Task.CompletedTask);

        var cache = new CacheService(mockFs.Object, "/my/cache/dir");
        await cache.SetAsync("k", new List<Post>());

        mockFs.Verify(f => f.EnsureDirectoryExists("/my/cache/dir"), Times.Once);
    }

    [Fact]
    public async Task DifferentKeys_StoredInSeparateFiles()
    {
        var list1 = new List<Post> { new(1, 1, "T1", "B1") };
        var list2 = new List<Post> { new(2, 2, "T2", "B2") };

        await _cache.SetAsync("key-a", list1);
        await _cache.SetAsync("key-b", list2);

        var r1 = await _cache.GetAsync<List<Post>>("key-a");
        var r2 = await _cache.GetAsync<List<Post>>("key-b");

        Assert.Equal(1, r1![0].Id);
        Assert.Equal(2, r2![0].Id);
    }

    [Fact]
    public async Task Exists_ReturnsFalseBeforeSet()
    {
        Assert.False(_cache.Exists("never-set"));
    }

    [Fact]
    public async Task Exists_ReturnsTrueAfterSet()
    {
        await _cache.SetAsync("was-set", new List<Post>());
        Assert.True(_cache.Exists("was-set"));
    }

    [Fact]
    public async Task CanCacheAndRetrieveComments()
    {
        var comments = new List<Comment>
        {
            new(1, 5, "Alice", "a@t.com", "Great")
        };

        await _cache.SetAsync("comments-post5", comments);
        var result = await _cache.GetAsync<List<Comment>>("comments-post5");

        Assert.NotNull(result);
        Assert.Equal(1, result[0].Id);
        Assert.Equal(5, result[0].PostId);
    }
}

// ============================================================================
// CYCLE 3: RetryPolicy Tests
// RED  — Fails to compile: RetryPolicy / RetryExhaustedException don't exist
// GREEN — Create RetryPolicy.cs with configurable sleep for test speed
// ============================================================================

public class RetryPolicyTests
{
    // Inject a no-op sleep so tests never actually wait
    private static readonly Func<TimeSpan, CancellationToken, Task> NoSleep =
        (_, _) => Task.CompletedTask;

    [Fact]
    public async Task SucceedsImmediately_WhenOperationDoesNotThrow()
    {
        var policy = new RetryPolicy(3, 1000, NoSleep);

        var result = await policy.ExecuteAsync<int>(() => Task.FromResult(42));

        Assert.Equal(42, result);
    }

    [Fact]
    public async Task DoesNotCallSleep_OnFirstAttemptSuccess()
    {
        var sleepCount = 0;
        Func<TimeSpan, CancellationToken, Task> countingSleep = (_, _) =>
        {
            sleepCount++;
            return Task.CompletedTask;
        };

        var policy = new RetryPolicy(3, 100, countingSleep);
        await policy.ExecuteAsync<int>(() => Task.FromResult(1));

        Assert.Equal(0, sleepCount);
    }

    [Fact]
    public async Task RetriesUntilSuccess()
    {
        var callCount = 0;
        var policy = new RetryPolicy(3, 100, NoSleep);

        var result = await policy.ExecuteAsync<string>(() =>
        {
            callCount++;
            if (callCount < 3) throw new Exception("Transient failure");
            return Task.FromResult("ok");
        });

        Assert.Equal("ok", result);
        Assert.Equal(3, callCount);
    }

    [Fact]
    public async Task TotalAttempts_IsMaxRetriesPlusOne()
    {
        var callCount = 0;
        var policy = new RetryPolicy(maxRetries: 2, baseDelayMs: 100, sleep: NoSleep);

        try
        {
            await policy.ExecuteAsync<int>(() =>
            {
                callCount++;
                throw new Exception("Always fails");
            });
        }
        catch (RetryExhaustedException) { }

        // 1 initial attempt + 2 retries = 3 total
        Assert.Equal(3, callCount);
    }

    [Fact]
    public async Task ThrowsRetryExhaustedException_AfterAllRetries()
    {
        var policy = new RetryPolicy(3, 100, NoSleep);

        await Assert.ThrowsAsync<RetryExhaustedException>(async () =>
        {
            await policy.ExecuteAsync<string>(() =>
                throw new InvalidOperationException("Always fails"));
        });
    }

    [Fact]
    public async Task RetryExhaustedException_ContainsOriginalException()
    {
        var policy = new RetryPolicy(1, 100, NoSleep);
        var originalEx = new HttpRequestException("upstream down");

        var ex = await Assert.ThrowsAsync<RetryExhaustedException>(async () =>
        {
            await policy.ExecuteAsync<string>(() => throw originalEx);
        });

        Assert.Equal(originalEx, ex.InnerException);
    }

    [Fact]
    public async Task UsesExponentialBackoff()
    {
        // Capture the delays passed to the sleep function
        var delays = new List<TimeSpan>();
        Func<TimeSpan, CancellationToken, Task> captureSleep = (d, _) =>
        {
            delays.Add(d);
            return Task.CompletedTask;
        };

        var policy = new RetryPolicy(maxRetries: 3, baseDelayMs: 1000, sleep: captureSleep);

        try
        {
            await policy.ExecuteAsync<int>(() => throw new Exception("fail"));
        }
        catch (RetryExhaustedException) { }

        // Delays should be: 1000ms, 2000ms, 4000ms (2^0, 2^1, 2^2 × base)
        Assert.Equal(3, delays.Count);
        Assert.Equal(TimeSpan.FromMilliseconds(1000), delays[0]);
        Assert.Equal(TimeSpan.FromMilliseconds(2000), delays[1]);
        Assert.Equal(TimeSpan.FromMilliseconds(4000), delays[2]);
    }

    [Fact]
    public async Task CancellationToken_IsNotRetried()
    {
        var callCount = 0;
        var policy = new RetryPolicy(3, 100, NoSleep);

        await Assert.ThrowsAsync<OperationCanceledException>(async () =>
        {
            await policy.ExecuteAsync<int>(() =>
            {
                callCount++;
                throw new OperationCanceledException();
            });
        });

        // Must not retry on cancellation — exactly 1 attempt
        Assert.Equal(1, callCount);
    }
}

// ============================================================================
// CYCLE 4: ApiClient Tests
// RED  — Fails to compile: ApiClient doesn't exist
// GREEN — Create ApiClient.cs using IHttpService + CacheService + RetryPolicy
// ============================================================================

public class ApiClientTests
{
    // JSON fixtures mirroring JSONPlaceholder response shape
    private const string TwoPostsJson = """
        [
          {"id":1,"userId":1,"title":"Post One","body":"Body One"},
          {"id":2,"userId":1,"title":"Post Two","body":"Body Two"}
        ]
        """;

    private const string TwoCommentsJson = """
        [
          {"id":1,"postId":1,"name":"Alice","email":"a@t.com","body":"Comment A"},
          {"id":2,"postId":1,"name":"Bob","email":"b@t.com","body":"Comment B"}
        ]
        """;

    // Shared state set up fresh for each test
    private readonly Mock<IHttpService> _mockHttp = new();
    private readonly InMemoryFileSystem _fs = new();
    private readonly CacheService _cache;
    private readonly RetryPolicy _retry;
    private readonly ApiClient _sut;

    public ApiClientTests()
    {
        _cache = new CacheService(_fs, "/cache");
        // Use no-op sleep so retry tests don't block
        _retry = new RetryPolicy(3, 100, (_, _) => Task.CompletedTask);
        _sut = new ApiClient(_mockHttp.Object, _cache, _retry);
    }

    // --- Posts: cache miss → HTTP call ---

    [Fact]
    public async Task GetPostsAsync_FetchesFromApiOnCacheMiss()
    {
        _mockHttp.Setup(h => h.GetAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
                 .ReturnsAsync(TwoPostsJson);

        var posts = await _sut.GetPostsAsync(1, 10);

        Assert.Equal(2, posts.Count);
        Assert.Equal(1, posts[0].Id);
        Assert.Equal("Post One", posts[0].Title);
    }

    // --- Posts: cache hit → no HTTP call ---

    [Fact]
    public async Task GetPostsAsync_UsesCacheOnSubsequentCalls()
    {
        _mockHttp.Setup(h => h.GetAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
                 .ReturnsAsync(TwoPostsJson);

        // First call populates the cache
        await _sut.GetPostsAsync(1, 10);
        // Second call should read from cache
        var posts = await _sut.GetPostsAsync(1, 10);

        // HTTP must be called only once
        _mockHttp.Verify(h => h.GetAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()),
                         Times.Once);
        Assert.Equal(2, posts.Count);
    }

    // --- Pagination query parameters ---

    [Fact]
    public async Task GetPostsAsync_SendsCorrectPaginationParameters()
    {
        _mockHttp.Setup(h => h.GetAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
                 .ReturnsAsync("[]");

        await _sut.GetPostsAsync(page: 3, pageSize: 7);

        // URL must contain _page=3 and _limit=7
        _mockHttp.Verify(h => h.GetAsync(
            It.Is<string>(u => u.Contains("_page=3") && u.Contains("_limit=7")),
            It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task GetPostsAsync_DefaultsToPageOneAndTen()
    {
        _mockHttp.Setup(h => h.GetAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
                 .ReturnsAsync("[]");

        await _sut.GetPostsAsync();

        _mockHttp.Verify(h => h.GetAsync(
            It.Is<string>(u => u.Contains("_page=1") && u.Contains("_limit=10")),
            It.IsAny<CancellationToken>()), Times.Once);
    }

    // --- Comments ---

    [Fact]
    public async Task GetCommentsForPostAsync_FetchesCorrectEndpoint()
    {
        _mockHttp.Setup(h => h.GetAsync(
            It.Is<string>(u => u.Contains("/posts/1/comments")),
            It.IsAny<CancellationToken>()))
            .ReturnsAsync(TwoCommentsJson);

        var comments = await _sut.GetCommentsForPostAsync(1);

        Assert.Equal(2, comments.Count);
        Assert.Equal(1, comments[0].PostId);
        Assert.Equal("Alice", comments[0].Name);
    }

    [Fact]
    public async Task GetCommentsForPostAsync_CachesResult()
    {
        _mockHttp.Setup(h => h.GetAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
                 .ReturnsAsync(TwoCommentsJson);

        await _sut.GetCommentsForPostAsync(5);
        await _sut.GetCommentsForPostAsync(5);

        _mockHttp.Verify(h => h.GetAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()),
                         Times.Once);
    }

    // --- Retry integration ---

    [Fact]
    public async Task GetPostsAsync_RetriesTransientHttpFailures()
    {
        var callCount = 0;
        _mockHttp.Setup(h => h.GetAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
                 .Returns((string _, CancellationToken _) =>
                 {
                     callCount++;
                     if (callCount < 3)
                         return Task.FromException<string>(
                             new HttpRequestException("Server error"));
                     return Task.FromResult(TwoPostsJson);
                 });

        var posts = await _sut.GetPostsAsync(1, 10);

        Assert.Equal(2, posts.Count);
        Assert.Equal(3, callCount); // 2 failures + 1 success
    }

    // --- Full pagination loop ---

    [Fact]
    public async Task GetAllPostsWithCommentsAsync_StopsOnPartialPage()
    {
        // Page 1 returns 2 posts — less than pageSize=5 → last page, stop paginating
        _mockHttp.Setup(h => h.GetAsync(
            It.Is<string>(u => u.Contains("_page=1")),
            It.IsAny<CancellationToken>()))
            .ReturnsAsync(TwoPostsJson);

        _mockHttp.Setup(h => h.GetAsync(
            It.Is<string>(u => u.Contains("/posts/1/comments")),
            It.IsAny<CancellationToken>()))
            .ReturnsAsync(TwoCommentsJson);

        _mockHttp.Setup(h => h.GetAsync(
            It.Is<string>(u => u.Contains("/posts/2/comments")),
            It.IsAny<CancellationToken>()))
            .ReturnsAsync("[]");

        var result = await _sut.GetAllPostsWithCommentsAsync(pageSize: 5);

        Assert.Equal(2, result.Count);
        Assert.Equal(1, result[0].Post.Id);
        Assert.Equal(2, result[0].Comments.Count); // post 1 has 2 comments
        Assert.Empty(result[1].Comments);           // post 2 has no comments

        // Page 2 should never be requested (partial page = last page)
        _mockHttp.Verify(h => h.GetAsync(
            It.Is<string>(u => u.Contains("_page=2")),
            It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task GetAllPostsWithCommentsAsync_StopsOnEmptyPage()
    {
        // Empty response → stop immediately
        _mockHttp.Setup(h => h.GetAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
                 .ReturnsAsync("[]");

        var result = await _sut.GetAllPostsWithCommentsAsync(pageSize: 10);

        Assert.Empty(result);
    }
}

// ============================================================================
// Test Infrastructure — InMemoryFileSystem
//
// Implements IFileSystem using a Dictionary, allowing CacheService tests
// to run without touching the real file system.
// ============================================================================

public class InMemoryFileSystem : IFileSystem
{
    private readonly Dictionary<string, string> _files = new();

    public bool FileExists(string path) => _files.ContainsKey(path);

    public Task<string> ReadAllTextAsync(string path)
    {
        if (!_files.TryGetValue(path, out var content))
            throw new FileNotFoundException($"Mock file not found: {path}");
        return Task.FromResult(content);
    }

    public Task WriteAllTextAsync(string path, string content)
    {
        _files[path] = content;
        return Task.CompletedTask;
    }

    // No-op: there's no real directory to create in memory
    public void EnsureDirectoryExists(string path) { }
}
