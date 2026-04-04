// Interfaces that enable dependency injection and test mocking.
// Every external I/O dependency (HTTP, file system) is behind an interface
// so tests can swap in controlled fakes without touching real infrastructure.

namespace RestApiClient;

/// <summary>
/// Abstraction over HTTP GET operations.
/// Production implementation uses HttpClient; tests use Moq.
/// </summary>
public interface IHttpService
{
    /// <summary>Fetches the response body from <paramref name="url"/> as a string.</summary>
    Task<string> GetAsync(string url, CancellationToken ct = default);
}

/// <summary>
/// Abstraction over file-system operations needed by CacheService.
/// Production implementation delegates to System.IO; tests use InMemoryFileSystem.
/// </summary>
public interface IFileSystem
{
    bool FileExists(string path);
    Task<string> ReadAllTextAsync(string path);
    Task WriteAllTextAsync(string path, string content);
    /// <summary>Creates the directory (and any parents) if it does not exist.</summary>
    void EnsureDirectoryExists(string path);
}
