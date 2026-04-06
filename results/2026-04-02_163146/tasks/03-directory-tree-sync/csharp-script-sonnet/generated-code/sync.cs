// Directory Tree Sync Tool
// Usage:  dotnet run sync.cs -- <source> <target> [--dry-run]
//
// Compares two directory trees by SHA-256 hash, then either reports (dry-run)
// or performs the sync (execute mode: copies new/modified files, deletes orphans).
//
// Run with:  dotnet run sync.cs -- /path/to/source /path/to/target [--dry-run]

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;

// ============================================================
// MODELS
// ============================================================

enum FileStatus   { Identical, Modified, SourceOnly, TargetOnly }
enum SyncAction   { Copy, Update, Delete }

record FileComparison(string RelativePath, FileStatus Status, string? SourceHash, string? TargetHash);
record SyncOperation(SyncAction Action, string RelativePath, string SourcePath, string TargetPath);
record SyncPlan(string SourceRoot, string TargetRoot, IReadOnlyList<SyncOperation> Operations);
record SyncResult(bool IsDryRun, int Copied, int Updated, int Deleted, int Skipped, IReadOnlyList<string> Errors);

// ============================================================
// FILE SYSTEM ABSTRACTION
// ============================================================

interface IFileSystem
{
    bool FileExists(string path);
    bool DirectoryExists(string path);
    IEnumerable<string> EnumerateFiles(string directory);
    byte[] ReadAllBytes(string path);
    void CopyFile(string source, string destination);
    void DeleteFile(string path);
}

class RealFileSystem : IFileSystem
{
    public bool FileExists(string path) => File.Exists(path);
    public bool DirectoryExists(string path) => Directory.Exists(path);
    public IEnumerable<string> EnumerateFiles(string directory)
    {
        if (!Directory.Exists(directory)) return [];
        return Directory.EnumerateFiles(directory, "*", SearchOption.AllDirectories);
    }
    public byte[] ReadAllBytes(string path) => File.ReadAllBytes(path);
    public void CopyFile(string source, string destination)
    {
        var dir = Path.GetDirectoryName(destination);
        if (!string.IsNullOrEmpty(dir)) Directory.CreateDirectory(dir);
        File.Copy(source, destination, overwrite: true);
    }
    public void DeleteFile(string path) => File.Delete(path);
}

// ============================================================
// FILE HASHER
// ============================================================

class FileHasher(IFileSystem fs)
{
    public string ComputeHash(string filePath)
    {
        if (!fs.FileExists(filePath))
            throw new FileNotFoundException($"File not found: {filePath}", filePath);
        var bytes = fs.ReadAllBytes(filePath);
        return Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant();
    }
}

// ============================================================
// DIRECTORY COMPARER
// ============================================================

class DirectoryComparer(IFileSystem fs)
{
    private readonly FileHasher _hasher = new(fs);

    public IReadOnlyList<FileComparison> Compare(string sourceRoot, string targetRoot)
    {
        var srcFiles = GetRelativePaths(sourceRoot);
        var tgtFiles = GetRelativePaths(targetRoot);

        var allPaths = srcFiles.Keys.Union(tgtFiles.Keys, StringComparer.Ordinal)
                                    .OrderBy(p => p)
                                    .ToList();

        var results = new List<FileComparison>(allPaths.Count);

        foreach (var rel in allPaths)
        {
            bool inSrc = srcFiles.TryGetValue(rel, out var srcFull);
            bool inTgt = tgtFiles.TryGetValue(rel, out var tgtFull);

            string? srcHash = inSrc ? _hasher.ComputeHash(srcFull!) : null;
            string? tgtHash = inTgt ? _hasher.ComputeHash(tgtFull!) : null;

            FileStatus status = (inSrc, inTgt) switch
            {
                (true,  false)                         => FileStatus.SourceOnly,
                (false, true)                          => FileStatus.TargetOnly,
                (true,  true) when srcHash == tgtHash  => FileStatus.Identical,
                _                                      => FileStatus.Modified,
            };

            results.Add(new FileComparison(rel, status, srcHash, tgtHash));
        }

        return results;
    }

    private Dictionary<string, string> GetRelativePaths(string root)
    {
        var prefix = root.TrimEnd('/').TrimEnd('\\') + Path.DirectorySeparatorChar;
        var map = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var abs in fs.EnumerateFiles(root))
        {
            if (abs.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
                map[abs[prefix.Length..].Replace('\\', '/')] = abs;
        }
        return map;
    }
}

// ============================================================
// SYNC PLANNER
// ============================================================

class SyncPlanner
{
    public SyncPlan CreatePlan(IEnumerable<FileComparison> comparisons, string srcRoot, string tgtRoot)
    {
        var ops = new List<SyncOperation>();
        foreach (var c in comparisons)
        {
            var src = Path.Combine(srcRoot, c.RelativePath.Replace('/', Path.DirectorySeparatorChar));
            var tgt = Path.Combine(tgtRoot, c.RelativePath.Replace('/', Path.DirectorySeparatorChar));

            SyncOperation? op = c.Status switch
            {
                FileStatus.SourceOnly => new(SyncAction.Copy,   c.RelativePath, src, tgt),
                FileStatus.Modified   => new(SyncAction.Update, c.RelativePath, src, tgt),
                FileStatus.TargetOnly => new(SyncAction.Delete, c.RelativePath, src, tgt),
                _                     => null,
            };

            if (op is not null) ops.Add(op);
        }
        return new SyncPlan(srcRoot, tgtRoot, ops);
    }
}

// ============================================================
// SYNC EXECUTOR
// ============================================================

class SyncExecutor(IFileSystem fs)
{
    public SyncResult DryRun(SyncPlan plan)
    {
        int c = 0, u = 0, d = 0;
        foreach (var op in plan.Operations)
        {
            switch (op.Action)
            {
                case SyncAction.Copy:   c++; break;
                case SyncAction.Update: u++; break;
                case SyncAction.Delete: d++; break;
            }
        }
        return new SyncResult(true, c, u, d, 0, []);
    }

    public SyncResult Execute(SyncPlan plan)
    {
        int c = 0, u = 0, d = 0;
        var errors = new List<string>();

        foreach (var op in plan.Operations)
        {
            try
            {
                switch (op.Action)
                {
                    case SyncAction.Copy:
                        fs.CopyFile(op.SourcePath, op.TargetPath);
                        c++;
                        break;
                    case SyncAction.Update:
                        fs.CopyFile(op.SourcePath, op.TargetPath);
                        u++;
                        break;
                    case SyncAction.Delete:
                        fs.DeleteFile(op.TargetPath);
                        d++;
                        break;
                }
            }
            catch (Exception ex)
            {
                errors.Add($"[{op.Action}] {op.RelativePath}: {ex.Message}");
            }
        }

        return new SyncResult(false, c, u, d, 0, errors);
    }
}

// ============================================================
// TOP-LEVEL ENTRY POINT
// ============================================================

if (args.Length < 2)
{
    Console.Error.WriteLine("Usage: dotnet run sync.cs -- <source> <target> [--dry-run]");
    Environment.Exit(1);
}

string sourceRoot = args[0];
string targetRoot = args[1];
bool dryRun = args.Contains("--dry-run", StringComparer.OrdinalIgnoreCase);

if (!Directory.Exists(sourceRoot))
{
    Console.Error.WriteLine($"Error: source directory not found: {sourceRoot}");
    Environment.Exit(1);
}

if (!Directory.Exists(targetRoot))
{
    Console.Error.WriteLine($"Error: target directory not found: {targetRoot}");
    Environment.Exit(1);
}

Console.WriteLine($"Directory Sync Tool");
Console.WriteLine($"  Source : {sourceRoot}");
Console.WriteLine($"  Target : {targetRoot}");
Console.WriteLine($"  Mode   : {(dryRun ? "DRY RUN (no changes)" : "EXECUTE")}");
Console.WriteLine();

var realFs   = new RealFileSystem();
var comparer = new DirectoryComparer(realFs);
var planner  = new SyncPlanner();
var executor = new SyncExecutor(realFs);

Console.WriteLine("Comparing directories...");
var comparisons = comparer.Compare(sourceRoot, targetRoot);

// Print comparison report
int identical = 0, modified = 0, srcOnly = 0, tgtOnly = 0;
foreach (var c in comparisons)
{
    var icon = c.Status switch
    {
        FileStatus.Identical  => "  =",
        FileStatus.Modified   => "  ~",
        FileStatus.SourceOnly => "  +",
        FileStatus.TargetOnly => "  -",
        _ => "  ?"
    };
    Console.WriteLine($"{icon} {c.RelativePath}");
    switch (c.Status)
    {
        case FileStatus.Identical:  identical++; break;
        case FileStatus.Modified:   modified++;  break;
        case FileStatus.SourceOnly: srcOnly++;   break;
        case FileStatus.TargetOnly: tgtOnly++;   break;
    }
}

Console.WriteLine();
Console.WriteLine($"Summary: {identical} identical, {modified} modified, {srcOnly} source-only, {tgtOnly} target-only");
Console.WriteLine();

var plan = planner.CreatePlan(comparisons, sourceRoot, targetRoot);

if (plan.Operations.Count == 0)
{
    Console.WriteLine("Trees are already in sync. Nothing to do.");
    Environment.Exit(0);
}

Console.WriteLine($"Sync plan ({plan.Operations.Count} operations):");
foreach (var op in plan.Operations)
{
    var desc = op.Action switch
    {
        SyncAction.Copy   => $"COPY   {op.RelativePath}",
        SyncAction.Update => $"UPDATE {op.RelativePath}",
        SyncAction.Delete => $"DELETE {op.RelativePath}",
        _ => $"? {op.RelativePath}"
    };
    Console.WriteLine($"  {desc}");
}

Console.WriteLine();

SyncResult result;
if (dryRun)
{
    result = executor.DryRun(plan);
    Console.WriteLine("[DRY RUN] No files were modified.");
}
else
{
    result = executor.Execute(plan);
    Console.WriteLine("Sync complete.");
}

Console.WriteLine($"  Copied:  {result.Copied}");
Console.WriteLine($"  Updated: {result.Updated}");
Console.WriteLine($"  Deleted: {result.Deleted}");

if (result.Errors.Count > 0)
{
    Console.WriteLine($"\n{result.Errors.Count} error(s):");
    foreach (var err in result.Errors)
        Console.WriteLine($"  ERROR: {err}");
    Environment.Exit(2);
}
