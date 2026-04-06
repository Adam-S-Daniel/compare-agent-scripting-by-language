// SearchReplaceEngine.cs
// Shared implementation used by both the CLI script and the test project.
// This file contains the core logic for multi-file search and replace.

using System.Text.RegularExpressions;
using Microsoft.Extensions.FileSystemGlobbing;
using Microsoft.Extensions.FileSystemGlobbing.Abstractions;

namespace SearchReplace;

// -----------------------------------------------------------------------
// Domain models
// -----------------------------------------------------------------------

/// <summary>Represents a single line match found in a file.</summary>
public record MatchResult(
    string FilePath,
    int LineNumber,
    string LineText,
    IReadOnlyList<string> ContextBefore,
    IReadOnlyList<string> ContextAfter
);

/// <summary>Represents a single search-and-replace change.</summary>
public record ChangeRecord(
    int LineNumber,
    string OldText,
    string NewText
);

/// <summary>Report for a single file after processing.</summary>
public record FileReport(
    string FilePath,
    IReadOnlyList<ChangeRecord> Changes,
    string? BackupPath
);

/// <summary>Summary of all files processed in a directory run.</summary>
public record RunSummary(
    IReadOnlyList<FileReport> FileReports,
    bool IsPreview
)
{
    public int TotalChanges => FileReports.Sum(r => r.Changes.Count);
}

// -----------------------------------------------------------------------
// Engine
// -----------------------------------------------------------------------

/// <summary>
/// Core engine for multi-file search and replace operations.
/// Supports: glob file matching, regex search, preview mode,
/// backup creation, and change reporting.
/// </summary>
public class SearchReplaceEngine
{
    // -----------------------------------------------------------------------
    // 1. File discovery via glob pattern
    // -----------------------------------------------------------------------

    /// <summary>
    /// Recursively find files under <paramref name="rootDirectory"/> that match
    /// the given <paramref name="globPattern"/> (e.g. "**/*.cs").
    /// </summary>
    public IEnumerable<string> FindFiles(string rootDirectory, string globPattern)
    {
        // Use Microsoft.Extensions.FileSystemGlobbing for glob support
        var matcher = new Matcher();
        matcher.AddInclude(globPattern);

        var result = matcher.Execute(
            new DirectoryInfoWrapper(new DirectoryInfo(rootDirectory)));

        return result.Files
            .Select(f => Path.Combine(rootDirectory, f.Path))
            .OrderBy(f => f);
    }

    // -----------------------------------------------------------------------
    // 2. Find matches within a single file
    // -----------------------------------------------------------------------

    /// <summary>
    /// Find all lines in <paramref name="filePath"/> that match the regex.
    /// Optionally returns <paramref name="contextLines"/> lines before/after each match.
    /// </summary>
    public IEnumerable<MatchResult> FindMatches(
        string filePath,
        Regex pattern,
        int contextLines = 0)
    {
        var lines = File.ReadAllLines(filePath);

        for (int i = 0; i < lines.Length; i++)
        {
            if (pattern.IsMatch(lines[i]))
            {
                // Collect context before
                var before = new List<string>();
                for (int b = Math.Max(0, i - contextLines); b < i; b++)
                    before.Add(lines[b]);

                // Collect context after
                var after = new List<string>();
                for (int a = i + 1; a <= Math.Min(lines.Length - 1, i + contextLines); a++)
                    after.Add(lines[a]);

                yield return new MatchResult(
                    FilePath: filePath,
                    LineNumber: i + 1,        // 1-based
                    LineText: lines[i],
                    ContextBefore: before,
                    ContextAfter: after
                );
            }
        }
    }

    // -----------------------------------------------------------------------
    // 3. Preview replace — show what WOULD change, do not modify file
    // -----------------------------------------------------------------------

    /// <summary>
    /// Returns a <see cref="FileReport"/> describing what would change if
    /// <paramref name="replacement"/> were applied to all matches in the file,
    /// without actually modifying the file.
    /// </summary>
    public FileReport PreviewReplace(string filePath, Regex pattern, string replacement)
    {
        var changes = BuildChanges(filePath, pattern, replacement);
        return new FileReport(filePath, changes, BackupPath: null);
    }

    // -----------------------------------------------------------------------
    // 4. Perform replace — optionally create backup, modify file, return report
    // -----------------------------------------------------------------------

    /// <summary>
    /// Apply <paramref name="replacement"/> to all matches in the file.
    /// If <paramref name="createBackup"/> is true, a backup copy is made first.
    /// Returns a report of all changes made.
    /// </summary>
    public FileReport PerformReplace(
        string filePath,
        Regex pattern,
        string replacement,
        bool createBackup)
    {
        var changes = BuildChanges(filePath, pattern, replacement);

        // No changes — nothing to do
        if (changes.Count == 0)
            return new FileReport(filePath, changes, BackupPath: null);

        // Create backup if requested
        string? backupPath = null;
        if (createBackup)
        {
            backupPath = filePath + ".bak";
            File.Copy(filePath, backupPath, overwrite: true);
        }

        // Apply changes: read all lines, replace, write back
        var lines = File.ReadAllLines(filePath);
        for (int i = 0; i < lines.Length; i++)
        {
            lines[i] = pattern.Replace(lines[i], replacement);
        }
        File.WriteAllLines(filePath, lines);

        return new FileReport(filePath, changes, BackupPath: backupPath);
    }

    // -----------------------------------------------------------------------
    // 5. Run on an entire directory — glob + process all matching files
    // -----------------------------------------------------------------------

    /// <summary>
    /// Runs search-and-replace (or preview) across all files under
    /// <paramref name="rootDirectory"/> matching <paramref name="globPattern"/>.
    /// </summary>
    public RunSummary RunOnDirectory(
        string rootDirectory,
        string globPattern,
        Regex searchPattern,
        string replacement,
        bool preview,
        bool createBackup)
    {
        var files = FindFiles(rootDirectory, globPattern);
        var reports = new List<FileReport>();

        foreach (var file in files)
        {
            FileReport report;
            if (preview)
                report = PreviewReplace(file, searchPattern, replacement);
            else
                report = PerformReplace(file, searchPattern, replacement, createBackup);

            // Only include files that had at least one match
            if (report.Changes.Count > 0)
                reports.Add(report);
        }

        return new RunSummary(reports, IsPreview: preview);
    }

    // -----------------------------------------------------------------------
    // Private helpers
    // -----------------------------------------------------------------------

    /// <summary>
    /// Build the list of <see cref="ChangeRecord"/>s for a file without
    /// actually modifying it (used by both preview and perform).
    /// </summary>
    private static List<ChangeRecord> BuildChanges(
        string filePath, Regex pattern, string replacement)
    {
        var lines = File.ReadAllLines(filePath);
        var changes = new List<ChangeRecord>();

        for (int i = 0; i < lines.Length; i++)
        {
            var original = lines[i];
            if (pattern.IsMatch(original))
            {
                var replaced = pattern.Replace(original, replacement);
                changes.Add(new ChangeRecord(
                    LineNumber: i + 1,
                    OldText: original,
                    NewText: replaced
                ));
            }
        }

        return changes;
    }
}
