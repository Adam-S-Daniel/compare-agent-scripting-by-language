// DirectoryComparer: Compares two directory trees using SHA-256 content hashes.
// Categorizes files as: SourceOnly, TargetOnly, Identical, or Different.

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;

/// <summary>
/// Result of comparing two directory trees.
/// </summary>
public class ComparisonResult
{
    /// <summary>Files that exist only in the source directory.</summary>
    public List<string> SourceOnly { get; set; } = new();

    /// <summary>Files that exist only in the target directory.</summary>
    public List<string> TargetOnly { get; set; } = new();

    /// <summary>Files that exist in both with identical content (same SHA-256 hash).</summary>
    public List<string> Identical { get; set; } = new();

    /// <summary>Files that exist in both but have different content.</summary>
    public List<string> Different { get; set; } = new();
}

/// <summary>
/// Compares two directory trees by computing SHA-256 hashes of file contents.
/// </summary>
public static class DirectoryComparer
{
    /// <summary>
    /// Compare source and target directory trees.
    /// </summary>
    /// <param name="sourcePath">Absolute path to the source directory.</param>
    /// <param name="targetPath">Absolute path to the target directory.</param>
    /// <returns>A ComparisonResult categorizing all files.</returns>
    public static ComparisonResult Compare(string sourcePath, string targetPath)
    {
        // Validate directories exist
        if (!Directory.Exists(sourcePath))
            throw new DirectoryNotFoundException($"Source directory not found: {sourcePath}");
        if (!Directory.Exists(targetPath))
            throw new DirectoryNotFoundException($"Target directory not found: {targetPath}");

        var result = new ComparisonResult();

        // Get all relative file paths from both directories
        var sourceFiles = GetRelativeFiles(sourcePath);
        var targetFiles = GetRelativeFiles(targetPath);

        var sourceSet = new HashSet<string>(sourceFiles);
        var targetSet = new HashSet<string>(targetFiles);

        // Files only in source
        foreach (var file in sourceFiles.Where(f => !targetSet.Contains(f)))
            result.SourceOnly.Add(file);

        // Files only in target
        foreach (var file in targetFiles.Where(f => !sourceSet.Contains(f)))
            result.TargetOnly.Add(file);

        // Files in both — compare by SHA-256 hash
        foreach (var file in sourceFiles.Where(f => targetSet.Contains(f)))
        {
            var sourceHash = ComputeSha256(Path.Combine(sourcePath, file));
            var targetHash = ComputeSha256(Path.Combine(targetPath, file));

            if (sourceHash == targetHash)
                result.Identical.Add(file);
            else
                result.Different.Add(file);
        }

        return result;
    }

    /// <summary>
    /// Get all files under a directory as relative paths (using OS-appropriate separators).
    /// </summary>
    private static List<string> GetRelativeFiles(string rootPath)
    {
        if (!Directory.Exists(rootPath))
            return new List<string>();

        return Directory.GetFiles(rootPath, "*", SearchOption.AllDirectories)
            .Select(f => Path.GetRelativePath(rootPath, f))
            .OrderBy(f => f)
            .ToList();
    }

    /// <summary>
    /// Compute SHA-256 hash of a file's contents, returned as a hex string.
    /// </summary>
    private static string ComputeSha256(string filePath)
    {
        using var stream = File.OpenRead(filePath);
        var hash = SHA256.HashData(stream);
        return Convert.ToHexString(hash);
    }
}
