// FileHasher: computes SHA-256 content hashes via the IFileSystem abstraction.
// Using an interface here means tests can supply an in-memory filesystem
// instead of reading real files from disk.

using System.Security.Cryptography;

namespace DirSyncLib;

public class FileHasher(IFileSystem fileSystem)
{
    private readonly IFileSystem _fs = fileSystem;

    /// <summary>
    /// Returns the lowercase hex-encoded SHA-256 hash of the file at <paramref name="filePath"/>.
    /// Throws <see cref="FileNotFoundException"/> if the file doesn't exist.
    /// </summary>
    public string ComputeHash(string filePath)
    {
        if (!_fs.FileExists(filePath))
            throw new FileNotFoundException($"Cannot hash — file not found: {filePath}", filePath);

        var bytes = _fs.ReadAllBytes(filePath);
        var hashBytes = SHA256.HashData(bytes);
        return Convert.ToHexString(hashBytes).ToLowerInvariant();
    }
}
