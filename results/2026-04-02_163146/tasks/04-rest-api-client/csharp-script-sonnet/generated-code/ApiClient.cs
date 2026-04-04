// TDD GREEN: ApiClient created to make ApiClientTests pass.
//
// Design decisions:
// - Depends on IHttpService (mockable) + CacheService + RetryPolicy.
// - Cache-aside pattern: check cache first; on miss, fetch, then store.
// - Pagination uses JSONPlaceholder's _page / _limit query parameters.
//   Loop terminates when a page returns fewer items than pageSize (last page)
//   or an empty page (already past the end).
// - All public methods are async and accept an optional CancellationToken.

using System.Text.Json;

namespace RestApiClient;

/// <summary>
/// Client for the JSONPlaceholder REST API.
/// Supports pagination, transparent local caching, and retry with
/// exponential backoff on transient HTTP failures.
/// </summary>
public class ApiClient
{
    private readonly IHttpService  _http;
    private readonly CacheService  _cache;
    private readonly RetryPolicy   _retry;

    private const string BaseUrl = "https://jsonplaceholder.typicode.com";

    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNamingPolicy        = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true,
    };

    public ApiClient(IHttpService http, CacheService cache, RetryPolicy retry)
    {
        _http  = http;
        _cache = cache;
        _retry = retry;
    }

    // -------------------------------------------------------------------------
    // Public API
    // -------------------------------------------------------------------------

    /// <summary>
    /// Fetches a page of posts from <c>/posts?_page=…&amp;_limit=…</c>.
    /// Results are cached so repeated calls for the same page are free.
    /// </summary>
    /// <param name="page">1-based page number.</param>
    /// <param name="pageSize">Number of posts per page (maps to <c>_limit</c>).</param>
    public async Task<IReadOnlyList<Post>> GetPostsAsync(
        int page = 1, int pageSize = 10, CancellationToken ct = default)
    {
        var cacheKey = $"posts_p{page}_s{pageSize}";
        var cached   = await _cache.GetAsync<List<Post>>(cacheKey);
        if (cached is not null) return cached;

        var url  = $"{BaseUrl}/posts?_page={page}&_limit={pageSize}";
        var json = await _retry.ExecuteAsync(() => _http.GetAsync(url, ct), ct);

        var posts = JsonSerializer.Deserialize<List<Post>>(json, JsonOpts)
                    ?? new List<Post>();

        await _cache.SetAsync(cacheKey, posts);
        return posts;
    }

    /// <summary>
    /// Fetches all comments for a single post from <c>/posts/{postId}/comments</c>.
    /// Results are cached so repeated calls for the same post are free.
    /// </summary>
    public async Task<IReadOnlyList<Comment>> GetCommentsForPostAsync(
        int postId, CancellationToken ct = default)
    {
        var cacheKey = $"comments_post{postId}";
        var cached   = await _cache.GetAsync<List<Comment>>(cacheKey);
        if (cached is not null) return cached;

        var url      = $"{BaseUrl}/posts/{postId}/comments";
        var json     = await _retry.ExecuteAsync(() => _http.GetAsync(url, ct), ct);

        var comments = JsonSerializer.Deserialize<List<Comment>>(json, JsonOpts)
                       ?? new List<Comment>();

        await _cache.SetAsync(cacheKey, comments);
        return comments;
    }

    /// <summary>
    /// Fetches every post across all pages and joins each post with its comments.
    /// Pagination stops when a page is shorter than <paramref name="pageSize"/>
    /// (indicating the last page) or returns empty.
    /// </summary>
    public async Task<IReadOnlyList<PostWithComments>> GetAllPostsWithCommentsAsync(
        int pageSize = 10, CancellationToken ct = default)
    {
        var result = new List<PostWithComments>();
        var page   = 1;

        while (true)
        {
            var posts = await GetPostsAsync(page, pageSize, ct);
            if (posts.Count == 0) break;

            foreach (var post in posts)
            {
                var comments = await GetCommentsForPostAsync(post.Id, ct);
                result.Add(new PostWithComments(post, comments));
            }

            // A partial page means we've reached the end
            if (posts.Count < pageSize) break;
            page++;
        }

        return result;
    }
}
