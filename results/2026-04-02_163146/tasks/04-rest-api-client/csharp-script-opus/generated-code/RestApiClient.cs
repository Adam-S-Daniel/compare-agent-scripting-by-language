// REST API Client — .NET 10 file-based app
// Fetches posts and comments from JSONPlaceholder, with retry, pagination, and caching.
// Run with: dotnet run RestApiClient.cs
//
// This is the main entry point that demonstrates the full pipeline:
// 1. Creates an HttpClient with retry/backoff handler
// 2. Fetches all posts (paginated)
// 3. Fetches comments for each post
// 4. Caches results locally as JSON files
// 5. Displays a summary

#:package System.Text.Json@*

using System.Net;
using System.Net.Http;
using System.Text.Json;
using System.Text.Json.Serialization;

// --- Configuration ---
var baseUrl = "https://jsonplaceholder.typicode.com";
var cacheDir = Path.Combine(Directory.GetCurrentDirectory(), ".api_cache");
var pageSize = 10;
var maxRetries = 3;
var initialDelayMs = 1000;

Console.WriteLine("=== JSONPlaceholder REST API Client ===");
Console.WriteLine($"Base URL: {baseUrl}");
Console.WriteLine($"Cache dir: {cacheDir}");
Console.WriteLine();

// --- Build the HTTP pipeline with retry support ---
var retryHandler = new RetryDelegatingHandler(maxRetries, initialDelayMs)
{
    InnerHandler = new HttpClientHandler()
};
using var httpClient = new HttpClient(retryHandler)
{
    BaseAddress = new Uri(baseUrl)
};

var cache = new FileCacheService(cacheDir);
var client = new ApiClient(httpClient, cache, pageSize);

try
{
    // Fetch all posts with pagination
    Console.WriteLine("Fetching all posts (paginated)...");
    var posts = await client.GetAllPostsAsync();
    Console.WriteLine($"  Fetched {posts.Count} posts.");

    // Fetch comments for each post
    Console.WriteLine("Fetching comments for each post...");
    var postsWithComments = new List<PostData>();
    foreach (var post in posts)
    {
        var comments = await client.GetCommentsForPostAsync(post.Id);
        postsWithComments.Add(new PostData { Post = post, Comments = comments });
    }
    Console.WriteLine($"  Fetched comments for {postsWithComments.Count} posts.");

    // Save the combined result
    await cache.SaveAsync("all_posts_with_comments", postsWithComments);

    // Display summary
    Console.WriteLine();
    Console.WriteLine("=== Summary ===");
    Console.WriteLine($"Total posts: {postsWithComments.Count}");
    Console.WriteLine($"Total comments: {postsWithComments.Sum(p => p.Comments.Count)}");
    Console.WriteLine();

    // Show first 5 posts as a sample
    Console.WriteLine("First 5 posts:");
    foreach (var pwc in postsWithComments.Take(5))
    {
        Console.WriteLine($"  [{pwc.Post.Id}] {pwc.Post.Title}");
        Console.WriteLine($"       {pwc.Comments.Count} comments");
    }

    Console.WriteLine();
    Console.WriteLine($"Results cached in: {cacheDir}");
    Console.WriteLine("Done.");
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Error: {ex.Message}");
    Environment.ExitCode = 1;
}

// === Types (inline for file-based app) ===

public class PostRecord
{
    [JsonPropertyName("userId")] public int UserId { get; set; }
    [JsonPropertyName("id")] public int Id { get; set; }
    [JsonPropertyName("title")] public string Title { get; set; } = "";
    [JsonPropertyName("body")] public string Body { get; set; } = "";
}

public class CommentRecord
{
    [JsonPropertyName("postId")] public int PostId { get; set; }
    [JsonPropertyName("id")] public int Id { get; set; }
    [JsonPropertyName("name")] public string Name { get; set; } = "";
    [JsonPropertyName("email")] public string Email { get; set; } = "";
    [JsonPropertyName("body")] public string Body { get; set; } = "";
}

public class PostData
{
    [JsonPropertyName("post")] public PostRecord Post { get; set; } = new();
    [JsonPropertyName("comments")] public List<CommentRecord> Comments { get; set; } = new();
}

// === Cache Service ===

public class FileCacheService
{
    private readonly string _dir;
    private static readonly JsonSerializerOptions _opts = new() { WriteIndented = true };

    public FileCacheService(string directory) => _dir = directory;

    public async Task SaveAsync<T>(string key, T data)
    {
        Directory.CreateDirectory(_dir);
        await File.WriteAllTextAsync(
            Path.Combine(_dir, $"{key}.json"),
            JsonSerializer.Serialize(data, _opts));
    }

    public async Task<T?> LoadAsync<T>(string key) where T : class
    {
        var path = Path.Combine(_dir, $"{key}.json");
        if (!File.Exists(path)) return null;
        return JsonSerializer.Deserialize<T>(await File.ReadAllTextAsync(path));
    }

    public bool Exists(string key) => File.Exists(Path.Combine(_dir, $"{key}.json"));
}

// === Retry Handler ===

public class RetryDelegatingHandler : DelegatingHandler
{
    private readonly int _maxRetries;
    private readonly int _initialDelayMs;

    public RetryDelegatingHandler(int maxRetries, int initialDelayMs)
    {
        _maxRetries = maxRetries;
        _initialDelayMs = initialDelayMs;
    }

    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken ct)
    {
        HttpResponseMessage? response = null;
        for (int i = 0; i <= _maxRetries; i++)
        {
            try
            {
                var clone = new HttpRequestMessage(request.Method, request.RequestUri);
                foreach (var h in request.Headers)
                    clone.Headers.TryAddWithoutValidation(h.Key, h.Value);
                response = await base.SendAsync(clone, ct);
                if (response.IsSuccessStatusCode || ((int)response.StatusCode < 500 && response.StatusCode != HttpStatusCode.TooManyRequests))
                    return response;
            }
            catch (HttpRequestException) when (i < _maxRetries) { }

            if (i < _maxRetries)
            {
                var delay = _initialDelayMs * (int)Math.Pow(2, i);
                Console.WriteLine($"  Retry {i + 1}/{_maxRetries} after {delay}ms...");
                await Task.Delay(delay, ct);
            }
        }
        return response ?? new HttpResponseMessage(HttpStatusCode.ServiceUnavailable);
    }
}

// === API Client ===

public class ApiClient
{
    private readonly HttpClient _http;
    private readonly FileCacheService _cache;
    private readonly int _pageSize;

    public ApiClient(HttpClient http, FileCacheService cache, int pageSize)
    {
        _http = http;
        _cache = cache;
        _pageSize = pageSize;
    }

    public async Task<List<PostRecord>> GetAllPostsAsync()
    {
        var cached = await _cache.LoadAsync<List<PostRecord>>("all_posts");
        if (cached != null) { Console.WriteLine("  (using cached posts)"); return cached; }

        var all = new List<PostRecord>();
        int page = 1;
        while (true)
        {
            var resp = await _http.GetAsync($"/posts?_page={page}&_limit={_pageSize}");
            if (!resp.IsSuccessStatusCode)
                throw new Exception($"Failed to fetch posts page {page}: {(int)resp.StatusCode}");

            var posts = JsonSerializer.Deserialize<List<PostRecord>>(
                await resp.Content.ReadAsStringAsync()) ?? new();
            if (posts.Count == 0) break;
            all.AddRange(posts);

            // Check total count header for pagination
            if (resp.Headers.TryGetValues("x-total-count", out var vals) &&
                int.TryParse(vals.FirstOrDefault(), out var total) &&
                all.Count >= total)
                break;
            if (posts.Count < _pageSize) break;
            page++;
        }

        await _cache.SaveAsync("all_posts", all);
        return all;
    }

    public async Task<List<CommentRecord>> GetCommentsForPostAsync(int postId)
    {
        var key = $"comments_post_{postId}";
        var cached = await _cache.LoadAsync<List<CommentRecord>>(key);
        if (cached != null) return cached;

        var resp = await _http.GetAsync($"/posts/{postId}/comments");
        if (!resp.IsSuccessStatusCode)
            throw new Exception($"Failed to fetch comments for post {postId}: {(int)resp.StatusCode}");

        var comments = JsonSerializer.Deserialize<List<CommentRecord>>(
            await resp.Content.ReadAsStringAsync()) ?? new();
        await _cache.SaveAsync(key, comments);
        return comments;
    }
}
