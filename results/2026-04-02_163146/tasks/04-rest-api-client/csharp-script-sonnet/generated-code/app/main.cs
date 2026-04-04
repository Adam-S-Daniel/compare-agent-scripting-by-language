// REST API Client — JSONPlaceholder Demo
// .NET 10 file-based app style: top-level statements, no class/Main boilerplate.
//
// Run from this directory:
//   dotnet run --project app/
//
// Features demonstrated:
//   • Pagination  — fetches posts page-by-page until no more remain
//   • Caching     — second fetch of the same page is served from local JSON files
//   • Retry       — up to 3 attempts with exponential backoff on HTTP failures

using RestApiClient;

Console.WriteLine("JSONPlaceholder REST API Client");
Console.WriteLine("================================");

// Wire up dependencies manually (no DI container needed for a script)
var cacheDir   = Path.Combine(Directory.GetCurrentDirectory(), ".cache");
var fileSystem = new FileSystemService();
var cache      = new CacheService(fileSystem, cacheDir);
var retry      = new RetryPolicy(maxRetries: 3, baseDelayMs: 500);
var http       = new HttpService();
var client     = new ApiClient(http, cache, retry);

Console.WriteLine($"Cache directory : {cacheDir}");
Console.WriteLine();

try
{
    // ---- 1. Fetch first two pages of posts (5 per page) ----
    Console.WriteLine("Fetching posts (page 1 & 2, 5 per page)...");
    var allPosts = new List<Post>();

    for (var page = 1; page <= 2; page++)
    {
        var posts = await client.GetPostsAsync(page, pageSize: 5);
        if (posts.Count == 0) break;
        allPosts.AddRange(posts);
        Console.WriteLine($"  Page {page}: {posts.Count} post(s)");
    }

    Console.WriteLine($"\nTotal posts fetched: {allPosts.Count}");

    // ---- 2. Print first 3 titles ----
    Console.WriteLine("\nSample posts:");
    foreach (var p in allPosts.Take(3))
        Console.WriteLine($"  [{p.Id,3}] {p.Title}");

    // ---- 3. Fetch comments for the first post ----
    var firstPost = allPosts[0];
    Console.WriteLine($"\nFetching comments for post #{firstPost.Id}...");
    var comments = await client.GetCommentsForPostAsync(firstPost.Id);
    Console.WriteLine($"  {comments.Count} comment(s) found.");
    if (comments.Count > 0)
        Console.WriteLine($"  First comment from: {comments[0].Name} <{comments[0].Email}>");

    // ---- 4. Demonstrate cache hit (second fetch is instant) ----
    Console.WriteLine("\nRe-fetching page 1 (should be served from cache)...");
    var sw = System.Diagnostics.Stopwatch.StartNew();
    var cachedPosts = await client.GetPostsAsync(1, pageSize: 5);
    sw.Stop();
    Console.WriteLine($"  {cachedPosts.Count} post(s) in {sw.ElapsedMilliseconds} ms " +
                      $"(cache file: {cacheDir})");

    Console.WriteLine("\nDone. Run again to see all responses served from cache.");
}
catch (RetryExhaustedException ex)
{
    Console.Error.WriteLine($"\nError: all retry attempts exhausted.\n{ex.Message}");
    if (ex.InnerException is not null)
        Console.Error.WriteLine($"Caused by: {ex.InnerException.Message}");
    Environment.Exit(1);
}
catch (Exception ex)
{
    Console.Error.WriteLine($"\nUnexpected error: {ex.Message}");
    Environment.Exit(1);
}
