// SearchReplaceTool.cs — Core library for recursive multi-file search and replace.
// Provides: glob-based file matching, regex search with context, preview mode,
// backup creation, and a summary report of all changes.
//
// TDD GREEN phase: implementing each method to make the corresponding tests pass.

using System.Text;
using System.Text.RegularExpressions;
using Microsoft.Extensions.FileSystemGlobbing;
using Microsoft.Extensions.FileSystemGlobbing.Abstractions;

/// <summary>Represents a single match found during a search operation.</summary>
public record SearchMatch(
    string FilePath,
    int LineNumber,
    string LineText,
    string MatchedText,
    int MatchStart,
    int MatchLength);

/// <summary>Represents one replacement that was (or would be) made.</summary>
public record ReplacementRecord(
    string FilePath,
    int LineNumber,
    string OldText,
    string NewText);

/// <summary>Summary report produced after a search-and-replace operation.</summary>
public record SummaryReport(
    int FilesSearched,
    int FilesMatched,
    int TotalMatches,
    int TotalReplacements,
    IReadOnlyList<ReplacementRecord> Replacements);

/// <summary>Options controlling the behaviour of the search-and-replace tool.</summary>
public class SearchReplaceOptions
{
    public required string RootDirectory { get; init; }
    public required string GlobPattern { get; init; }
    public required string SearchPattern { get; init; }
    public string? Replacement { get; init; }
    public bool PreviewOnly { get; init; }
    public bool CreateBackups { get; init; }
    public int ContextLines { get; init; } = 0;
}

/// <summary>Core search-and-replace engine.</summary>
public static class SearchReplaceTool
{
    /// <summary>
    /// Find files matching a glob pattern under the given root directory.
    /// Uses Microsoft.Extensions.FileSystemGlobbing for robust glob support.
    /// </summary>
    public static IReadOnlyList<string> FindFiles(string rootDirectory, string globPattern)
    {
        if (!Directory.Exists(rootDirectory))
            throw new DirectoryNotFoundException(
                $"Root directory does not exist: {rootDirectory}");

        var matcher = new Matcher();
        matcher.AddInclude(globPattern);

        var result = matcher.Execute(new DirectoryInfoWrapper(new DirectoryInfo(rootDirectory)));

        // Return absolute paths sorted for deterministic output
        return result.Files
            .Select(f => Path.GetFullPath(Path.Combine(rootDirectory, f.Path)))
            .OrderBy(p => p)
            .ToList();
    }

    /// <summary>
    /// Search a single file for all regex matches, returning match details.
    /// </summary>
    public static IReadOnlyList<SearchMatch> SearchFile(string filePath, string regexPattern)
    {
        if (!File.Exists(filePath))
            throw new FileNotFoundException(
                $"File not found: {filePath}", filePath);

        Regex regex;
        try
        {
            regex = new Regex(regexPattern);
        }
        catch (RegexParseException ex)
        {
            throw new ArgumentException(
                $"Invalid regex pattern: {ex.Message}", nameof(regexPattern), ex);
        }

        var matches = new List<SearchMatch>();
        var lines = File.ReadAllLines(filePath);

        for (int i = 0; i < lines.Length; i++)
        {
            foreach (Match m in regex.Matches(lines[i]))
            {
                matches.Add(new SearchMatch(
                    FilePath: filePath,
                    LineNumber: i + 1, // 1-based
                    LineText: lines[i],
                    MatchedText: m.Value,
                    MatchStart: m.Index,
                    MatchLength: m.Length));
            }
        }

        return matches;
    }

    /// <summary>
    /// Build a preview string showing matches with surrounding context lines.
    /// Does not modify the file — read-only operation.
    /// </summary>
    public static string BuildPreview(string filePath, string regexPattern, int contextLines)
    {
        var matches = SearchFile(filePath, regexPattern);
        if (matches.Count == 0)
            return "No matches found.";

        var lines = File.ReadAllLines(filePath);
        var sb = new StringBuilder();
        // Track which lines we've already printed to avoid duplicates
        var printedLines = new HashSet<int>();

        foreach (var match in matches)
        {
            int lineIdx = match.LineNumber - 1; // 0-based
            int start = Math.Max(0, lineIdx - contextLines);
            int end = Math.Min(lines.Length - 1, lineIdx + contextLines);

            for (int i = start; i <= end; i++)
            {
                if (printedLines.Add(i)) // only print each line once
                {
                    // Mark the matching line with ">", context with " "
                    var marker = (i == lineIdx) ? ">" : " ";
                    sb.AppendLine($"{marker} {i + 1}: {lines[i]}");
                }
            }

            // Separator between match groups
            if (match != matches[^1])
                sb.AppendLine("  ---");
        }

        return sb.ToString();
    }

    /// <summary>
    /// Create a backup copy of a file (adds .bak extension).
    /// Returns the path of the backup file.
    /// </summary>
    public static string CreateBackup(string filePath)
    {
        if (!File.Exists(filePath))
            throw new FileNotFoundException(
                $"File not found: {filePath}", filePath);

        var backupPath = filePath + ".bak";
        File.Copy(filePath, backupPath, overwrite: true);
        return backupPath;
    }

    /// <summary>
    /// Perform search-and-replace on a single file.
    /// Reads the file, finds all matches line by line, records each replacement,
    /// then writes the modified content back.
    /// </summary>
    public static IReadOnlyList<ReplacementRecord> ReplaceInFile(
        string filePath, string regexPattern, string replacement)
    {
        if (!File.Exists(filePath))
            throw new FileNotFoundException(
                $"File not found: {filePath}", filePath);

        var regex = new Regex(regexPattern);
        var lines = File.ReadAllLines(filePath);
        var records = new List<ReplacementRecord>();
        var modified = false;

        for (int i = 0; i < lines.Length; i++)
        {
            // Collect all matches on this line before replacing
            foreach (Match m in regex.Matches(lines[i]))
            {
                records.Add(new ReplacementRecord(
                    FilePath: filePath,
                    LineNumber: i + 1,
                    OldText: m.Value,
                    NewText: regex.Replace(m.Value, replacement)));
            }

            var replaced = regex.Replace(lines[i], replacement);
            if (replaced != lines[i])
            {
                lines[i] = replaced;
                modified = true;
            }
        }

        // Only write back if something changed
        if (modified)
        {
            // Preserve the original line ending style (write lines joined by \n)
            File.WriteAllText(filePath, string.Join("\n", lines) + "\n");
        }

        return records;
    }

    /// <summary>
    /// Run the full search-and-replace pipeline:
    /// 1. Find files matching the glob pattern
    /// 2. Search each file for the regex pattern
    /// 3. Optionally preview matches with context
    /// 4. Optionally create backups before modifying
    /// 5. Perform replacements (unless preview-only)
    /// 6. Produce a summary report
    /// </summary>
    public static SummaryReport Run(SearchReplaceOptions options)
    {
        // Step 1: find matching files
        var files = FindFiles(options.RootDirectory, options.GlobPattern);
        var allReplacements = new List<ReplacementRecord>();
        int filesMatched = 0;
        int totalMatches = 0;

        foreach (var file in files)
        {
            // Step 2: search for matches
            var matches = SearchFile(file, options.SearchPattern);
            if (matches.Count == 0)
                continue;

            filesMatched++;
            totalMatches += matches.Count;

            // Preview mode: record what would be replaced but don't modify
            if (options.PreviewOnly)
            {
                // If a replacement string is provided, record what would happen
                if (options.Replacement is not null)
                {
                    var regex = new Regex(options.SearchPattern);
                    foreach (var match in matches)
                    {
                        allReplacements.Add(new ReplacementRecord(
                            FilePath: file,
                            LineNumber: match.LineNumber,
                            OldText: match.MatchedText,
                            NewText: regex.Replace(match.MatchedText, options.Replacement)));
                    }
                }
                continue;
            }

            // Step 3: create backup before modifying
            if (options.CreateBackups)
                CreateBackup(file);

            // Step 4: perform replacements
            if (options.Replacement is not null)
            {
                var records = ReplaceInFile(file, options.SearchPattern, options.Replacement);
                allReplacements.AddRange(records);
            }
        }

        return new SummaryReport(
            FilesSearched: files.Count,
            FilesMatched: filesMatched,
            TotalMatches: totalMatches,
            TotalReplacements: options.PreviewOnly ? 0 : allReplacements.Count,
            Replacements: allReplacements);
    }
}
