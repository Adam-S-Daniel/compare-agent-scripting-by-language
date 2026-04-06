// search-replace.cs — CLI entry point for the multi-file search-and-replace tool.
// Run with: dotnet run search-replace.cs [options]
//
// Usage:
//   dotnet run search-replace.cs --root <dir> --glob <pattern> --search <regex>
//       [--replace <text>] [--preview] [--backup] [--context <n>]
//
// Examples:
//   # Preview all matches of "TODO" in .cs files:
//   dotnet run search-replace.cs --root ./src --glob "**/*.cs" --search "TODO" --preview --context 2
//
//   # Replace "oldName" with "newName" in .txt files, creating backups:
//   dotnet run search-replace.cs --root . --glob "**/*.txt" --search "oldName" --replace "newName" --backup

#:package Microsoft.Extensions.FileSystemGlobbing@9.*

using System.Text;
using System.Text.RegularExpressions;
using Microsoft.Extensions.FileSystemGlobbing;
using Microsoft.Extensions.FileSystemGlobbing.Abstractions;

// ── Record / class definitions (same as the library) ──

record SearchMatch(string FilePath, int LineNumber, string LineText,
    string MatchedText, int MatchStart, int MatchLength);

record ReplacementRecord(string FilePath, int LineNumber,
    string OldText, string NewText);

record SummaryReport(int FilesSearched, int FilesMatched,
    int TotalMatches, int TotalReplacements,
    IReadOnlyList<ReplacementRecord> Replacements);

class SearchReplaceOptions
{
    public required string RootDirectory { get; init; }
    public required string GlobPattern { get; init; }
    public required string SearchPattern { get; init; }
    public string? Replacement { get; init; }
    public bool PreviewOnly { get; init; }
    public bool CreateBackups { get; init; }
    public int ContextLines { get; init; } = 0;
}

// ── Core engine ──

static class SearchReplaceTool
{
    public static IReadOnlyList<string> FindFiles(string rootDirectory, string globPattern)
    {
        if (!Directory.Exists(rootDirectory))
            throw new DirectoryNotFoundException($"Root directory does not exist: {rootDirectory}");

        var matcher = new Matcher();
        matcher.AddInclude(globPattern);
        var result = matcher.Execute(new DirectoryInfoWrapper(new DirectoryInfo(rootDirectory)));
        return result.Files
            .Select(f => Path.GetFullPath(Path.Combine(rootDirectory, f.Path)))
            .OrderBy(p => p).ToList();
    }

    public static IReadOnlyList<SearchMatch> SearchFile(string filePath, string regexPattern)
    {
        if (!File.Exists(filePath))
            throw new FileNotFoundException($"File not found: {filePath}", filePath);

        Regex regex;
        try { regex = new Regex(regexPattern); }
        catch (RegexParseException ex)
        { throw new ArgumentException($"Invalid regex pattern: {ex.Message}", nameof(regexPattern), ex); }

        var matches = new List<SearchMatch>();
        var lines = File.ReadAllLines(filePath);
        for (int i = 0; i < lines.Length; i++)
            foreach (Match m in regex.Matches(lines[i]))
                matches.Add(new SearchMatch(filePath, i + 1, lines[i], m.Value, m.Index, m.Length));
        return matches;
    }

    public static string BuildPreview(string filePath, string regexPattern, int contextLines)
    {
        var matches = SearchFile(filePath, regexPattern);
        if (matches.Count == 0) return "No matches found.";

        var lines = File.ReadAllLines(filePath);
        var sb = new StringBuilder();
        var printed = new HashSet<int>();

        foreach (var match in matches)
        {
            int idx = match.LineNumber - 1;
            int start = Math.Max(0, idx - contextLines);
            int end = Math.Min(lines.Length - 1, idx + contextLines);
            for (int i = start; i <= end; i++)
                if (printed.Add(i))
                    sb.AppendLine($"{(i == idx ? ">" : " ")} {i + 1}: {lines[i]}");
            if (match != matches[^1]) sb.AppendLine("  ---");
        }
        return sb.ToString();
    }

    public static string CreateBackup(string filePath)
    {
        if (!File.Exists(filePath))
            throw new FileNotFoundException($"File not found: {filePath}", filePath);
        var backupPath = filePath + ".bak";
        File.Copy(filePath, backupPath, overwrite: true);
        return backupPath;
    }

    public static IReadOnlyList<ReplacementRecord> ReplaceInFile(
        string filePath, string regexPattern, string replacement)
    {
        if (!File.Exists(filePath))
            throw new FileNotFoundException($"File not found: {filePath}", filePath);

        var regex = new Regex(regexPattern);
        var lines = File.ReadAllLines(filePath);
        var records = new List<ReplacementRecord>();
        bool modified = false;

        for (int i = 0; i < lines.Length; i++)
        {
            foreach (Match m in regex.Matches(lines[i]))
                records.Add(new ReplacementRecord(filePath, i + 1, m.Value,
                    regex.Replace(m.Value, replacement)));
            var replaced = regex.Replace(lines[i], replacement);
            if (replaced != lines[i]) { lines[i] = replaced; modified = true; }
        }

        if (modified)
            File.WriteAllText(filePath, string.Join("\n", lines) + "\n");
        return records;
    }

    public static SummaryReport Run(SearchReplaceOptions options)
    {
        var files = FindFiles(options.RootDirectory, options.GlobPattern);
        var allReplacements = new List<ReplacementRecord>();
        int filesMatched = 0, totalMatches = 0;

        foreach (var file in files)
        {
            var matches = SearchFile(file, options.SearchPattern);
            if (matches.Count == 0) continue;
            filesMatched++;
            totalMatches += matches.Count;

            if (options.PreviewOnly)
            {
                if (options.Replacement is not null)
                {
                    var regex = new Regex(options.SearchPattern);
                    foreach (var match in matches)
                        allReplacements.Add(new ReplacementRecord(file, match.LineNumber,
                            match.MatchedText, regex.Replace(match.MatchedText, options.Replacement)));
                }
                continue;
            }

            if (options.CreateBackups) CreateBackup(file);
            if (options.Replacement is not null)
                allReplacements.AddRange(ReplaceInFile(file, options.SearchPattern, options.Replacement));
        }

        return new SummaryReport(files.Count, filesMatched, totalMatches,
            options.PreviewOnly ? 0 : allReplacements.Count, allReplacements);
    }
}

// ── CLI argument parsing and main logic ──

string? root = null, glob = null, search = null, replace = null;
bool preview = false, backup = false;
int context = 0;

for (int i = 0; i < args.Length; i++)
{
    switch (args[i])
    {
        case "--root":    root    = args[++i]; break;
        case "--glob":    glob    = args[++i]; break;
        case "--search":  search  = args[++i]; break;
        case "--replace": replace = args[++i]; break;
        case "--preview": preview = true;      break;
        case "--backup":  backup  = true;      break;
        case "--context": context = int.Parse(args[++i]); break;
        case "--help":
        case "-h":
            Console.WriteLine("Usage: dotnet run search-replace.cs --root <dir> --glob <pattern> --search <regex>");
            Console.WriteLine("       [--replace <text>] [--preview] [--backup] [--context <n>]");
            return;
        default:
            Console.Error.WriteLine($"Unknown argument: {args[i]}");
            Environment.Exit(1);
            break;
    }
}

if (root is null || glob is null || search is null)
{
    Console.Error.WriteLine("Error: --root, --glob, and --search are required.");
    Console.Error.WriteLine("Run with --help for usage information.");
    Environment.Exit(1);
    return;
}

try
{
    var options = new SearchReplaceOptions
    {
        RootDirectory = Path.GetFullPath(root),
        GlobPattern = glob,
        SearchPattern = search,
        Replacement = replace,
        PreviewOnly = preview,
        CreateBackups = backup,
        ContextLines = context
    };

    // If preview mode, show previews first
    if (preview)
    {
        Console.WriteLine("=== PREVIEW MODE (no files will be modified) ===\n");
        var files = SearchReplaceTool.FindFiles(options.RootDirectory, options.GlobPattern);
        foreach (var file in files)
        {
            var previewText = SearchReplaceTool.BuildPreview(file, search, context);
            if (!previewText.Contains("No matches"))
            {
                Console.WriteLine($"--- {file} ---");
                Console.WriteLine(previewText);
            }
        }
    }

    // Run the pipeline
    var report = SearchReplaceTool.Run(options);

    // Print summary report
    Console.WriteLine("=== SUMMARY REPORT ===");
    Console.WriteLine($"Files searched:    {report.FilesSearched}");
    Console.WriteLine($"Files matched:     {report.FilesMatched}");
    Console.WriteLine($"Total matches:     {report.TotalMatches}");
    Console.WriteLine($"Total replacements:{report.TotalReplacements}");

    if (report.Replacements.Count > 0)
    {
        Console.WriteLine("\nDetailed changes:");
        foreach (var r in report.Replacements)
        {
            Console.WriteLine($"  {r.FilePath}:{r.LineNumber}");
            Console.WriteLine($"    - {r.OldText}");
            Console.WriteLine($"    + {r.NewText}");
        }
    }

    if (preview && replace is not null)
        Console.WriteLine("\n(Preview only — no files were modified. Remove --preview to apply changes.)");
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Error: {ex.Message}");
    Environment.Exit(1);
}
