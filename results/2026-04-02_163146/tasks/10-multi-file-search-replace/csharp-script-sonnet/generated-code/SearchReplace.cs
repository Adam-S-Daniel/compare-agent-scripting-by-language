// SearchReplace.cs — .NET 10 file-based app (top-level statements)
// Self-contained single file: engine + CLI in one file for `dotnet run SearchReplace.cs`.
//
// Usage:
//   dotnet run SearchReplace.cs --dir <path> --glob <pattern> --search <regex> --replace <text>
//   dotnet run SearchReplace.cs --dir . --glob "**/*.txt" --search "foo" --replace "bar" --preview
//   dotnet run SearchReplace.cs --dir . --glob "**/*.cs" --search "OldName" --replace "NewName" --backup

#:sdk Microsoft.NET.Sdk
#:package Microsoft.Extensions.FileSystemGlobbing@10.0.0

using System.Text.RegularExpressions;
using Microsoft.Extensions.FileSystemGlobbing;
using Microsoft.Extensions.FileSystemGlobbing.Abstractions;

// ===================================================================
// TOP-LEVEL STATEMENTS — CLI entry point
// (Type declarations must come after top-level statements in C#)
// ===================================================================

string? rootDir = null;
string? globPattern = null;
string? searchPattern = null;
string? replacement = null;
bool preview = false;
bool createBackup = false;

for (int i = 0; i < args.Length; i++)
{
    switch (args[i])
    {
        case "--dir":     rootDir = args[++i]; break;
        case "--glob":    globPattern = args[++i]; break;
        case "--search":  searchPattern = args[++i]; break;
        case "--replace": replacement = args[++i]; break;
        case "--preview": preview = true; break;
        case "--backup":  createBackup = true; break;
        case "--help": case "-h":
            PrintUsage(); return 0;
        default:
            Console.Error.WriteLine($"Unknown argument: {args[i]}");
            PrintUsage(); return 1;
    }
}

if (rootDir is null || globPattern is null || searchPattern is null || replacement is null)
{
    Console.Error.WriteLine("Error: --dir, --glob, --search, and --replace are required.");
    PrintUsage();
    return 1;
}

if (!Directory.Exists(rootDir))
{
    Console.Error.WriteLine($"Error: Directory not found: {rootDir}");
    return 1;
}

Regex regex;
try { regex = new Regex(searchPattern, RegexOptions.Compiled); }
catch (RegexParseException ex)
{
    Console.Error.WriteLine($"Error: Invalid regex '{searchPattern}': {ex.Message}");
    return 1;
}

Console.WriteLine("=== Multi-file Search and Replace ===");
Console.WriteLine($"Root : {Path.GetFullPath(rootDir)}");
Console.WriteLine($"Glob : {globPattern}");
Console.WriteLine($"Find : {searchPattern}");
Console.WriteLine($"With : {replacement}");
Console.WriteLine($"Mode : {(preview ? "PREVIEW (read-only)" : "REPLACE")}");
Console.WriteLine($"Bak  : {(createBackup ? "yes (.bak)" : "no")}");
Console.WriteLine();

try
{
    var engine = new SearchReplaceEngine();
    var summary = engine.RunOnDirectory(rootDir, globPattern, regex, replacement, preview, createBackup);
    PrintSummary(summary);
    return 0;
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Error: {ex.Message}");
    return 1;
}

// Local helper functions (part of top-level program)
static void PrintSummary(RunSummary summary)
{
    if (summary.FileReports.Count == 0) { Console.WriteLine("No matches found."); return; }

    Console.WriteLine("=== Summary ===");
    Console.WriteLine($"Files with changes : {summary.FileReports.Count}");
    Console.WriteLine($"Total changes      : {summary.TotalChanges}");
    Console.WriteLine($"Mode               : {(summary.IsPreview ? "PREVIEW" : "APPLIED")}");
    Console.WriteLine();

    foreach (var report in summary.FileReports)
    {
        Console.WriteLine($"--- {report.FilePath} ---");
        if (report.BackupPath is not null)
            Console.WriteLine($"  Backup: {report.BackupPath}");
        foreach (var change in report.Changes)
        {
            Console.WriteLine($"  Line {change.LineNumber,5}:");
            Console.WriteLine($"    OLD: {change.OldText}");
            Console.WriteLine($"    NEW: {change.NewText}");
        }
        Console.WriteLine();
    }
}

static void PrintUsage()
{
    Console.Error.WriteLine("""
        Usage: dotnet run SearchReplace.cs [options]

        Required:
          --dir <path>       Root directory to search
          --glob <pattern>   Glob pattern (e.g. "**/*.cs")
          --search <regex>   Regex to search for
          --replace <text>   Replacement (supports $1, $2 capture groups)

        Optional:
          --preview          Show changes without modifying files
          --backup           Create .bak backups before modifying
          -h, --help         Show help
        """);
}

// ===================================================================
// TYPE DECLARATIONS — must come after top-level statements in C#
// These are inlined here so the file is self-contained for dotnet run.
// The same types exist in SearchReplaceEngine.cs (with public modifier)
// for use by the test project.
// ===================================================================

/// <summary>A line in a file that matches the search pattern.</summary>
record MatchResult(
    string FilePath,
    int LineNumber,
    string LineText,
    IReadOnlyList<string> ContextBefore,
    IReadOnlyList<string> ContextAfter
);

/// <summary>One search-and-replace change on a single line.</summary>
record ChangeRecord(int LineNumber, string OldText, string NewText);

/// <summary>All changes made (or that would be made) to one file.</summary>
record FileReport(
    string FilePath,
    IReadOnlyList<ChangeRecord> Changes,
    string? BackupPath
);

/// <summary>Overall summary of a directory-wide run.</summary>
record RunSummary(IReadOnlyList<FileReport> FileReports, bool IsPreview)
{
    public int TotalChanges => FileReports.Sum(r => r.Changes.Count);
}

/// <summary>Core engine: file discovery, matching, preview, and replace.</summary>
class SearchReplaceEngine
{
    /// <summary>Recursively find files matching a glob pattern.</summary>
    public IEnumerable<string> FindFiles(string rootDirectory, string globPattern)
    {
        var matcher = new Matcher();
        matcher.AddInclude(globPattern);
        var result = matcher.Execute(
            new DirectoryInfoWrapper(new DirectoryInfo(rootDirectory)));
        return result.Files
            .Select(f => Path.Combine(rootDirectory, f.Path))
            .OrderBy(f => f);
    }

    /// <summary>Yield each matching line with optional context lines before/after.</summary>
    public IEnumerable<MatchResult> FindMatches(
        string filePath, Regex pattern, int contextLines = 0)
    {
        var lines = File.ReadAllLines(filePath);
        for (int i = 0; i < lines.Length; i++)
        {
            if (!pattern.IsMatch(lines[i])) continue;

            var before = Enumerable.Range(Math.Max(0, i - contextLines), Math.Min(contextLines, i))
                                   .Select(b => lines[b]).ToList();
            var after  = Enumerable.Range(i + 1, Math.Min(contextLines, lines.Length - 1 - i))
                                   .Select(a => lines[a]).ToList();

            yield return new MatchResult(filePath, i + 1, lines[i], before, after);
        }
    }

    /// <summary>Preview: return what would change without touching the file.</summary>
    public FileReport PreviewReplace(string filePath, Regex pattern, string replacement)
        => new FileReport(filePath, BuildChanges(filePath, pattern, replacement), null);

    /// <summary>Apply replacement. Optionally creates a .bak backup first.</summary>
    public FileReport PerformReplace(
        string filePath, Regex pattern, string replacement, bool createBackup)
    {
        var changes = BuildChanges(filePath, pattern, replacement);
        if (changes.Count == 0) return new FileReport(filePath, changes, null);

        string? backupPath = null;
        if (createBackup)
        {
            backupPath = filePath + ".bak";
            File.Copy(filePath, backupPath, overwrite: true);
        }

        var lines = File.ReadAllLines(filePath);
        for (int i = 0; i < lines.Length; i++)
            lines[i] = pattern.Replace(lines[i], replacement);
        File.WriteAllLines(filePath, lines);

        return new FileReport(filePath, changes, backupPath);
    }

    /// <summary>Run across all glob-matched files in a directory.</summary>
    public RunSummary RunOnDirectory(
        string rootDirectory, string globPattern, Regex searchPattern,
        string replacement, bool preview, bool createBackup)
    {
        var reports = FindFiles(rootDirectory, globPattern)
            .Select(file => preview
                ? PreviewReplace(file, searchPattern, replacement)
                : PerformReplace(file, searchPattern, replacement, createBackup))
            .Where(r => r.Changes.Count > 0)
            .ToList();

        return new RunSummary(reports, preview);
    }

    private static List<ChangeRecord> BuildChanges(
        string filePath, Regex pattern, string replacement)
    {
        var lines = File.ReadAllLines(filePath);
        var changes = new List<ChangeRecord>();
        for (int i = 0; i < lines.Length; i++)
        {
            if (pattern.IsMatch(lines[i]))
                changes.Add(new ChangeRecord(i + 1, lines[i], pattern.Replace(lines[i], replacement)));
        }
        return changes;
    }
}
