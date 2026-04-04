// Abstraction over file system operations — enables mock testing without touching disk.

namespace DirSyncLib;

/// <summary>
/// Abstraction over file-system I/O so tests can use an in-memory implementation
/// instead of touching real disk paths.
/// </summary>
public interface IFileSystem
{
    bool FileExists(string path);
    bool DirectoryExists(string path);

    /// <summary>Returns all file paths under <paramref name="directory"/> (recursive).</summary>
    IEnumerable<string> EnumerateFiles(string directory);

    byte[] ReadAllBytes(string path);

    void WriteAllBytes(string path, byte[] data);

    /// <summary>
    /// Copies a file from <paramref name="source"/> to <paramref name="destination"/>,
    /// creating any missing parent directories.
    /// </summary>
    void CopyFile(string source, string destination);

    void DeleteFile(string path);

    void CreateDirectory(string path);
}
