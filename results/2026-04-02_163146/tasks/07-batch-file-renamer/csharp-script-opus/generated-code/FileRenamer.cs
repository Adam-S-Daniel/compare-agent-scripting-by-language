// =============================================================================
// FileRenamer.cs — Core library for batch file renaming with regex patterns
//
// Features:
//   - Regex-based file renaming with capture group support
//   - Preview mode: see what would change without actually renaming
//   - Conflict detection: catches collisions before any rename occurs
//   - Undo script generation: produces a bash script to reverse renames
//
// Design: Uses IFileSystem abstraction for testability (mock file system in tests).
// =============================================================================

using System.Text;
using System.Text.RegularExpressions;

namespace BatchFileRenamer;

// ---------------------------------------------------------------------------
// File system abstraction — allows testing with mock file systems
// ---------------------------------------------------------------------------
public interface IFileSystem
{
    IEnumerable<string> GetFiles(string directory);
    bool FileExists(string path);
    void RenameFile(string oldPath, string newPath);
    void WriteAllText(string path, string content);
}

/// <summary>
/// Real file system implementation for production use.
/// </summary>
public class RealFileSystem : IFileSystem
{
    public IEnumerable<string> GetFiles(string directory)
    {
        return Directory.GetFiles(directory);
    }

    public bool FileExists(string path) => File.Exists(path);

    public void RenameFile(string oldPath, string newPath)
    {
        File.Move(oldPath, newPath);
    }

    public void WriteAllText(string path, string content)
    {
        File.WriteAllText(path, content);
    }
}

// ---------------------------------------------------------------------------
// Data types for rename results
// ---------------------------------------------------------------------------

/// <summary>
/// Represents a single file rename operation (old name -> new name).
/// </summary>
public record RenameEntry(string OldName, string NewName, string OldPath, string NewPath);

/// <summary>
/// Represents a naming conflict where multiple files would map to the same name.
/// </summary>
public record ConflictInfo(string TargetName, List<string> SourceFiles);

/// <summary>
/// The result of a rename operation, including renames performed, conflicts, and metadata.
/// </summary>
public class RenameResult
{
    public List<RenameEntry> Renames { get; } = new();
    public List<ConflictInfo> Conflicts { get; } = new();
    public int RenamedCount { get; set; }
    public bool IsPreview { get; set; }
    public bool HasConflicts => Conflicts.Count > 0;
    public string Directory { get; set; } = "";
}

/// <summary>
/// Custom exception for rename-related errors with meaningful messages.
/// </summary>
public class RenameException : Exception
{
    public RenameException(string message) : base(message) { }
    public RenameException(string message, Exception inner) : base(message, inner) { }
}

// ---------------------------------------------------------------------------
// Core renamer logic
// ---------------------------------------------------------------------------
public class FileRenamer
{
    private readonly IFileSystem _fs;

    public FileRenamer(IFileSystem fileSystem)
    {
        _fs = fileSystem;
    }

    /// <summary>
    /// Execute a batch rename operation using a regex pattern and replacement string.
    /// </summary>
    /// <param name="directory">Directory containing files to rename.</param>
    /// <param name="pattern">Regex pattern to match against file names (not full paths).</param>
    /// <param name="replacement">Replacement string (supports $1, $2 capture group refs).</param>
    /// <param name="preview">If true, shows what would change without renaming.</param>
    /// <returns>A RenameResult with details of what was (or would be) renamed.</returns>
    public RenameResult Execute(string directory, string pattern, string replacement, bool preview)
    {
        // Validate inputs
        if (string.IsNullOrEmpty(pattern))
            throw new RenameException("Pattern cannot be empty.");

        Regex regex;
        try
        {
            regex = new Regex(pattern);
        }
        catch (RegexParseException ex)
        {
            throw new RenameException($"Invalid regex pattern: {ex.Message}", ex);
        }

        var result = new RenameResult
        {
            IsPreview = preview,
            Directory = directory
        };

        // Get all files in the directory
        var files = _fs.GetFiles(directory).ToList();

        // Build the list of proposed renames by applying the regex to each file name
        var proposedRenames = new List<RenameEntry>();

        foreach (var filePath in files)
        {
            var fileName = Path.GetFileName(filePath);
            var newName = regex.Replace(fileName, replacement);

            // Skip files where the name doesn't change
            if (newName == fileName)
                continue;

            var newPath = Path.Combine(
                Path.GetDirectoryName(filePath) ?? directory,
                newName);

            proposedRenames.Add(new RenameEntry(fileName, newName, filePath, newPath));
        }

        result.Renames.AddRange(proposedRenames);

        // --- Conflict detection ---
        // Check 1: Two source files mapping to the same target name
        var duplicateTargets = proposedRenames
            .GroupBy(r => r.NewName)
            .Where(g => g.Count() > 1);

        foreach (var group in duplicateTargets)
        {
            result.Conflicts.Add(new ConflictInfo(
                group.Key,
                group.Select(r => r.OldName).ToList()));
        }

        // Check 2: A target name matches an existing file that is NOT being renamed
        var renamingFrom = new HashSet<string>(proposedRenames.Select(r => r.OldPath));
        foreach (var rename in proposedRenames)
        {
            // If the target already exists and it's not one of the files we're renaming away from
            if (_fs.FileExists(rename.NewPath) && !renamingFrom.Contains(rename.NewPath))
            {
                // Only add if not already reported as a duplicate-target conflict
                if (!result.Conflicts.Any(c => c.TargetName == rename.NewName))
                {
                    result.Conflicts.Add(new ConflictInfo(
                        rename.NewName,
                        new List<string> { rename.OldName, rename.NewName + " (existing)" }));
                }
            }
        }

        // If there are conflicts, do not rename anything
        if (result.HasConflicts)
            return result;

        // If preview mode, return without actually renaming
        if (preview)
            return result;

        // --- Perform the renames ---
        foreach (var rename in proposedRenames)
        {
            _fs.RenameFile(rename.OldPath, rename.NewPath);
            result.RenamedCount++;
        }

        return result;
    }

    /// <summary>
    /// Generate a bash undo script that reverses all renames in the result.
    /// </summary>
    public string GenerateUndoScript(RenameResult result)
    {
        var sb = new StringBuilder();
        sb.AppendLine("#!/bin/bash");
        sb.AppendLine("# Undo script — reverses batch file renames");
        sb.AppendLine($"# Generated at: {DateTime.UtcNow:yyyy-MM-dd HH:mm:ss} UTC");
        sb.AppendLine($"# Directory: {result.Directory}");
        sb.AppendLine();

        if (result.Renames.Count == 0 || result.RenamedCount == 0)
        {
            sb.AppendLine("echo \"No renames to undo.\"");
            return sb.ToString();
        }

        sb.AppendLine("set -e");
        sb.AppendLine();

        // Reverse each rename: mv new -> old
        foreach (var rename in result.Renames)
        {
            var escapedNew = EscapeForBash(rename.NewPath);
            var escapedOld = EscapeForBash(rename.OldPath);
            sb.AppendLine($"mv {escapedNew} {escapedOld}");
        }

        sb.AppendLine();
        sb.AppendLine($"echo \"Undo complete: {result.RenamedCount} file(s) restored.\"");

        return sb.ToString();
    }

    /// <summary>
    /// Save the undo script to a file.
    /// </summary>
    public void SaveUndoScript(RenameResult result, string outputPath)
    {
        var script = GenerateUndoScript(result);
        _fs.WriteAllText(outputPath, script);
    }

    /// <summary>
    /// Escape a file path for safe use in a bash script (wrap in double quotes).
    /// </summary>
    private static string EscapeForBash(string path)
    {
        // Wrap in double quotes to handle spaces and special characters
        var escaped = path.Replace("\\", "\\\\").Replace("\"", "\\\"");
        return $"\"{escaped}\"";
    }
}
