// JsonPlaceholderClient: fetches posts and comments from the JSONPlaceholder API.
// Supports pagination (using _page and _limit query parameters with x-total-count header),
// local caching via CacheService, and integrates with RetryHandler for resilience.

using System.Text.Json;

namespace RestApiClient;

public class JsonPlaceholderClient
{
    private readonly HttpClient _httpClient;
    private readonly CacheService _cache;
    private readonly int _pageSize;

    public JsonPlaceholderClient(HttpClient httpClient, CacheService cache, int pageSize = 10)
    {
        _httpClient = httpClient ?? throw new ArgumentNullException(nameof(httpClient));
        _cache = cache ?? throw new ArgumentNullException(nameof(cache));
        _pageSize = pageSize;
    }

    /// <summary>Fetch a single page of posts.</summary>
    public async Task<List<Post>> GetPostsAsync(int page, int pageSize)
    {
        var cacheKey = $"posts_page_{page}_size_{pageSize}";
        var cached = await _cache.LoadAsync<List<Post>>(cacheKey);
        if (cached != null) return cached;

        var response = await _httpClient.GetAsync($"/posts?_page={page}&_limit={pageSize}");
        await EnsureSuccessAsync(response, $"GET /posts?_page={page}");

        var json = await response.Content.ReadAsStringAsync();
        var posts = JsonSerializer.Deserialize<List<Post>>(json) ?? new List<Post>();

        await _cache.SaveAsync(cacheKey, posts);
        return posts;
    }

    /// <summary>Fetch all posts across all pages.</summary>
    public async Task<List<Post>> GetAllPostsAsync()
    {
        // Check if we already have the full result cached
        var fullCacheKey = "all_posts";
        var cached = await _cache.LoadAsync<List<Post>>(fullCacheKey);
        if (cached != null) return cached;

        var allPosts = new List<Post>();
        int page = 1;

        while (true)
        {
            var response = await _httpClient.GetAsync($"/posts?_page={page}&_limit={_pageSize}");
            await EnsureSuccessAsync(response, $"GET /posts page {page}");

            var json = await response.Content.ReadAsStringAsync();
            var posts = JsonSerializer.Deserialize<List<Post>>(json) ?? new List<Post>();

            if (posts.Count == 0) break;

            allPosts.AddRange(posts);

            // Use x-total-count header to determine if there are more pages
            var totalCount = GetTotalCount(response);
            if (totalCount.HasValue && allPosts.Count >= totalCount.Value)
                break;

            // If no header, stop when we get fewer results than page size
            if (!totalCount.HasValue && posts.Count < _pageSize)
                break;

            page++;
        }

        await _cache.SaveAsync(fullCacheKey, allPosts);
        return allPosts;
    }

    /// <summary>Fetch all comments for a specific post.</summary>
    public async Task<List<Comment>> GetCommentsForPostAsync(int postId)
    {
        var cacheKey = $"comments_post_{postId}";
        var cached = await _cache.LoadAsync<List<Comment>>(cacheKey);
        if (cached != null) return cached;

        var response = await _httpClient.GetAsync($"/posts/{postId}/comments");
        await EnsureSuccessAsync(response, $"GET /posts/{postId}/comments");

        var json = await response.Content.ReadAsStringAsync();
        var comments = JsonSerializer.Deserialize<List<Comment>>(json) ?? new List<Comment>();

        await _cache.SaveAsync(cacheKey, comments);
        return comments;
    }

    /// <summary>Fetch all posts with their associated comments.</summary>
    public async Task<List<PostWithComments>> GetAllPostsWithCommentsAsync()
    {
        var posts = await GetAllPostsAsync();
        var result = new List<PostWithComments>();

        foreach (var post in posts)
        {
            var comments = await GetCommentsForPostAsync(post.Id);
            result.Add(new PostWithComments { Post = post, Comments = comments });
        }

        return result;
    }

    /// <summary>Parse the x-total-count header for pagination.</summary>
    private static int? GetTotalCount(HttpResponseMessage response)
    {
        if (response.Headers.TryGetValues("x-total-count", out var values))
        {
            var value = values.FirstOrDefault();
            if (int.TryParse(value, out var count))
                return count;
        }
        return null;
    }

    /// <summary>Check response status and throw ApiException on failure.</summary>
    private static async Task EnsureSuccessAsync(HttpResponseMessage response, string context)
    {
        if (!response.IsSuccessStatusCode)
        {
            var body = await response.Content.ReadAsStringAsync();
            throw new ApiException(
                (int)response.StatusCode,
                $"API request failed: {context} returned {(int)response.StatusCode} {response.ReasonPhrase}. Body: {body}",
                body);
        }
    }
}
