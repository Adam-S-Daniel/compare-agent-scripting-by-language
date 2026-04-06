// Real file system implementation using System.IO.
// In tests, this is replaced by InMemoryFileSystem (defined in ApiClientTests.cs)
// so tests never touch the real disk.

namespace RestApiClient;

/// <summary>
/// Delegates all file-system operations to <see cref="System.IO"/> APIs.
/// </summary>
public class FileSystemService : IFileSystem
{
    public bool FileExists(string path) => File.Exists(path);

    public Task<string> ReadAllTextAsync(string path)
        => File.ReadAllTextAsync(path);

    public Task WriteAllTextAsync(string path, string content)
        => File.WriteAllTextAsync(path, content);

    public void EnsureDirectoryExists(string path)
        => Directory.CreateDirectory(path);
}
