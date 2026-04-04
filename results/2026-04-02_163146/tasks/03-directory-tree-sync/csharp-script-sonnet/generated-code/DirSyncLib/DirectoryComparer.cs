// DirectoryComparer: walks two directory trees and returns a diff.
// Uses IFileSystem for I/O so tests can pass a MockFileSystem.

namespace DirSyncLib;

public class DirectoryComparer(IFileSystem fileSystem)
{
    private readonly IFileSystem _fs = fileSystem;
    private readonly FileHasher _hasher = new(fileSystem);

    /// <summary>
    /// Compares all files under <paramref name="sourceRoot"/> and <paramref name="targetRoot"/>
    /// and returns one <see cref="FileComparison"/> per unique relative path encountered.
    /// </summary>
    public IReadOnlyList<FileComparison> Compare(string sourceRoot, string targetRoot)
    {
        // Collect relative paths from each tree
        var sourceFiles = GetRelativePaths(sourceRoot);
        var targetFiles = GetRelativePaths(targetRoot);

        var allPaths = sourceFiles.Keys.Union(targetFiles.Keys, StringComparer.Ordinal)
                                       .OrderBy(p => p, StringComparer.Ordinal)
                                       .ToList();

        var results = new List<FileComparison>(allPaths.Count);

        foreach (var relativePath in allPaths)
        {
            var inSource = sourceFiles.TryGetValue(relativePath, out var srcFull);
            var inTarget = targetFiles.TryGetValue(relativePath, out var tgtFull);

            string? srcHash = inSource ? _hasher.ComputeHash(srcFull!) : null;
            string? tgtHash = inTarget ? _hasher.ComputeHash(tgtFull!) : null;

            FileStatus status = (inSource, inTarget) switch
            {
                (true, false) => FileStatus.SourceOnly,
                (false, true) => FileStatus.TargetOnly,
                (true, true) when srcHash == tgtHash => FileStatus.Identical,
                _ => FileStatus.Modified,
            };

            results.Add(new FileComparison(relativePath, status, srcHash, tgtHash));
        }

        return results;
    }

    // Returns a mapping from relative path → absolute path for all files under root
    private Dictionary<string, string> GetRelativePaths(string root)
    {
        var rootPrefix = root.TrimEnd('/') + "/";
        var map = new Dictionary<string, string>(StringComparer.Ordinal);

        foreach (var absPath in _fs.EnumerateFiles(root))
        {
            var normalized = absPath.Replace('\\', '/');
            var normalizedRoot = rootPrefix.Replace('\\', '/');

            if (normalized.StartsWith(normalizedRoot, StringComparison.Ordinal))
            {
                var rel = normalized[normalizedRoot.Length..];
                map[rel] = absPath;
            }
        }

        return map;
    }
}
