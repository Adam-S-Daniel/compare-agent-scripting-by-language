// CacheService: stores and retrieves API responses as local JSON files.
// Each cache entry is a separate .json file keyed by a logical name.
// This avoids redundant API calls when data has already been fetched.

using System.Text.Json;

namespace RestApiClient;

public class CacheService
{
    private readonly string _cacheDirectory;

    private static readonly JsonSerializerOptions _jsonOptions = new()
    {
        WriteIndented = true
    };

    public CacheService(string cacheDirectory)
    {
        _cacheDirectory = cacheDirectory ?? throw new ArgumentNullException(nameof(cacheDirectory));
    }

    /// <summary>Save data to a JSON cache file under the given key.</summary>
    public async Task SaveAsync<T>(string key, T data)
    {
        Directory.CreateDirectory(_cacheDirectory);
        var filePath = GetFilePath(key);
        var json = JsonSerializer.Serialize(data, _jsonOptions);
        await File.WriteAllTextAsync(filePath, json);
    }

    /// <summary>Load cached data for the given key, or null if not cached.</summary>
    public async Task<T?> LoadAsync<T>(string key) where T : class
    {
        var filePath = GetFilePath(key);
        if (!File.Exists(filePath))
            return null;

        var json = await File.ReadAllTextAsync(filePath);
        return JsonSerializer.Deserialize<T>(json);
    }

    /// <summary>Check whether a cache entry exists for the given key.</summary>
    public bool Exists(string key) => File.Exists(GetFilePath(key));

    private string GetFilePath(string key) => Path.Combine(_cacheDirectory, $"{key}.json");
}
