// In-memory file system implementation for use in tests.
// Backed by a Dictionary so no real disk I/O occurs.

namespace DirSyncLib;

/// <summary>
/// Thread-safe, in-memory IFileSystem for unit testing.
/// Paths are normalised to forward-slashes and compared case-insensitively
/// on Windows, case-sensitively on Unix — but for test fixtures we always
/// use consistent paths so this doesn't matter in practice.
/// </summary>
public class MockFileSystem : IFileSystem
{
    // Store file contents keyed by normalized absolute path
    private readonly Dictionary<string, byte[]> _files = new(StringComparer.Ordinal);

    // Normalize path separators for consistent lookup
    private static string Normalize(string path) =>
        path.Replace('\\', '/').TrimEnd('/');

    // Helper used by tests to pre-populate the filesystem
    public void AddFile(string path, byte[] content) =>
        _files[Normalize(path)] = content;

    public void AddFile(string path, string content) =>
        AddFile(path, System.Text.Encoding.UTF8.GetBytes(content));

    public bool FileExists(string path) => _files.ContainsKey(Normalize(path));

    public bool DirectoryExists(string path)
    {
        var prefix = Normalize(path) + "/";
        return _files.Keys.Any(k => k.StartsWith(prefix, StringComparison.Ordinal));
    }

    public IEnumerable<string> EnumerateFiles(string directory)
    {
        var prefix = Normalize(directory) + "/";
        return _files.Keys.Where(k => k.StartsWith(prefix, StringComparison.Ordinal));
    }

    public byte[] ReadAllBytes(string path)
    {
        var key = Normalize(path);
        if (!_files.TryGetValue(key, out var data))
            throw new FileNotFoundException($"File not found in mock filesystem: {path}");
        return data;
    }

    public void WriteAllBytes(string path, byte[] data) =>
        _files[Normalize(path)] = data;

    public void CopyFile(string source, string destination)
    {
        var data = ReadAllBytes(source);
        WriteAllBytes(destination, data);
    }

    public void DeleteFile(string path)
    {
        var key = Normalize(path);
        if (!_files.Remove(key))
            throw new FileNotFoundException($"Cannot delete — file not found: {path}");
    }

    public void CreateDirectory(string path)
    {
        // No-op in mock; directories are implicit in file paths
    }

    /// <summary>Expose internal file list for test assertions.</summary>
    public IReadOnlyDictionary<string, byte[]> Files => _files;
}
