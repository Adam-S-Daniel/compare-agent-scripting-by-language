// TDD GREEN: CacheService created to make CacheServiceTests pass.
//
// Design decisions:
// - Depends on IFileSystem so tests never touch real disk.
// - Keys are hashed (MD5) to produce safe, collision-resistant filenames.
// - Serializes/deserializes with System.Text.Json using camelCase policy,
//   matching the shape returned by JSONPlaceholder.

using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace RestApiClient;

/// <summary>
/// Caches arbitrary objects as JSON files in a local directory.
/// All file I/O is delegated to <see cref="IFileSystem"/> for testability.
/// </summary>
public class CacheService
{
    private readonly IFileSystem _fs;
    private readonly string _cacheDir;

    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNamingPolicy        = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true,
    };

    public CacheService(IFileSystem fileSystem, string cacheDirectory)
    {
        _fs       = fileSystem;
        _cacheDir = cacheDirectory;
    }

    /// <summary>
    /// Returns the cached value for <paramref name="key"/>, or
    /// <c>null</c> if it has not been cached yet (cache miss).
    /// </summary>
    public async Task<T?> GetAsync<T>(string key) where T : class
    {
        var path = CachePath(key);
        if (!_fs.FileExists(path)) return null;

        var json = await _fs.ReadAllTextAsync(path);
        return JsonSerializer.Deserialize<T>(json, JsonOpts);
    }

    /// <summary>Serializes <paramref name="value"/> and writes it to cache.</summary>
    public async Task SetAsync<T>(string key, T value) where T : class
    {
        // Ensure cache directory exists before first write
        _fs.EnsureDirectoryExists(_cacheDir);

        var path = CachePath(key);
        var json = JsonSerializer.Serialize(value, JsonOpts);
        await _fs.WriteAllTextAsync(path, json);
    }

    /// <summary>Returns <c>true</c> if a cache entry exists for <paramref name="key"/>.</summary>
    public bool Exists(string key) => _fs.FileExists(CachePath(key));

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    /// <summary>
    /// Converts a logical cache key into a filesystem path.
    /// MD5 is used purely for name-safety — not for security.
    /// </summary>
    private string CachePath(string key)
    {
        using var md5  = MD5.Create();
        var hashBytes  = md5.ComputeHash(Encoding.UTF8.GetBytes(key));
        var hash       = Convert.ToHexString(hashBytes);
        return Path.Combine(_cacheDir, $"{hash}.json");
    }
}
