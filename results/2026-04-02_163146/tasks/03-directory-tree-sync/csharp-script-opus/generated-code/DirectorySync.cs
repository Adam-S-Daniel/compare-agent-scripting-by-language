// DirectorySync.cs — .NET 10 file-based app entry point.
// Run with: dotnet run DirectorySync.cs -- <source> <target> [--execute]
//
// By default operates in dry-run mode (report only).
// Pass --execute to perform the actual sync.

using System;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Collections.Generic;
using System.Text;

// --- Parse arguments ---
if (args.Length < 2)
{
    Console.Error.WriteLine("Usage: dotnet run DirectorySync.cs -- <source-dir> <target-dir> [--execute]");
    Console.Error.WriteLine();
    Console.Error.WriteLine("Options:");
    Console.Error.WriteLine("  --execute   Perform the sync (default is dry-run/report only)");
    return 1;
}

var sourcePath = Path.GetFullPath(args[0]);
var targetPath = Path.GetFullPath(args[1]);
var executeMode = args.Any(a => a.Equals("--execute", StringComparison.OrdinalIgnoreCase));

try
{
    // Validate directories
    if (!Directory.Exists(sourcePath))
    {
        Console.Error.WriteLine($"Error: Source directory not found: {sourcePath}");
        return 1;
    }
    if (!Directory.Exists(targetPath))
    {
        Console.Error.WriteLine($"Error: Target directory not found: {targetPath}");
        return 1;
    }

    // Compare directories
    Console.WriteLine($"Comparing directories...");
    Console.WriteLine($"  Source: {sourcePath}");
    Console.WriteLine($"  Target: {targetPath}");
    Console.WriteLine();

    var comparison = CompareDirectories(sourcePath, targetPath);

    // Build sync plan
    var plan = BuildSyncPlan(comparison);

    // Print the dry-run report
    Console.WriteLine(GenerateReport(plan));

    if (executeMode)
    {
        Console.WriteLine("Executing sync...");
        ExecutePlan(plan, sourcePath, targetPath);
        Console.WriteLine("Sync complete.");
    }
    else
    {
        Console.WriteLine("(Dry-run mode — no files were modified. Use --execute to sync.)");
    }

    return 0;
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Error: {ex.Message}");
    return 1;
}

// --- Inline helper methods for the file-based app ---
// (The test project uses the same logic via separate class files.)

static ComparisonData CompareDirectories(string source, string target)
{
    var result = new ComparisonData();
    var sourceFiles = GetRelFiles(source);
    var targetFiles = GetRelFiles(target);
    var targetSet = new HashSet<string>(targetFiles);
    var sourceSet = new HashSet<string>(sourceFiles);

    foreach (var f in sourceFiles.Where(f => !targetSet.Contains(f)))
        result.SourceOnly.Add(f);
    foreach (var f in targetFiles.Where(f => !sourceSet.Contains(f)))
        result.TargetOnly.Add(f);
    foreach (var f in sourceFiles.Where(f => targetSet.Contains(f)))
    {
        if (HashFile(Path.Combine(source, f)) == HashFile(Path.Combine(target, f)))
            result.Identical.Add(f);
        else
            result.Different.Add(f);
    }
    return result;
}

static List<string> GetRelFiles(string root) =>
    Directory.Exists(root)
        ? Directory.GetFiles(root, "*", SearchOption.AllDirectories)
            .Select(f => Path.GetRelativePath(root, f))
            .OrderBy(f => f).ToList()
        : new List<string>();

static string HashFile(string path)
{
    using var s = File.OpenRead(path);
    return Convert.ToHexString(SHA256.HashData(s));
}

static List<SyncItem> BuildSyncPlan(ComparisonData comp)
{
    var actions = new List<SyncItem>();
    foreach (var f in comp.SourceOnly) actions.Add(new SyncItem("COPY", f));
    foreach (var f in comp.Different) actions.Add(new SyncItem("UPDATE", f));
    foreach (var f in comp.TargetOnly) actions.Add(new SyncItem("DELETE", f));
    return actions;
}

static string GenerateReport(List<SyncItem> plan)
{
    var sb = new StringBuilder();
    sb.AppendLine("=== Directory Sync Plan ===");
    sb.AppendLine();
    var copies = plan.Where(a => a.Action == "COPY").ToList();
    var updates = plan.Where(a => a.Action == "UPDATE").ToList();
    var deletes = plan.Where(a => a.Action == "DELETE").ToList();

    if (copies.Count > 0)
    {
        sb.AppendLine($"Files to copy ({copies.Count}):");
        foreach (var a in copies) sb.AppendLine($"  COPY   {a.Path}");
        sb.AppendLine();
    }
    if (updates.Count > 0)
    {
        sb.AppendLine($"Files to update ({updates.Count}):");
        foreach (var a in updates) sb.AppendLine($"  UPDATE {a.Path}");
        sb.AppendLine();
    }
    if (deletes.Count > 0)
    {
        sb.AppendLine($"Files to delete ({deletes.Count}):");
        foreach (var a in deletes) sb.AppendLine($"  DELETE {a.Path}");
        sb.AppendLine();
    }
    if (plan.Count == 0) sb.AppendLine("No actions needed — directories are already in sync.");
    else sb.AppendLine($"Total: {copies.Count} copy, {updates.Count} update, {deletes.Count} delete");
    return sb.ToString();
}

static void ExecutePlan(List<SyncItem> plan, string source, string target)
{
    foreach (var item in plan)
    {
        switch (item.Action)
        {
            case "COPY":
            case "UPDATE":
                var src = Path.Combine(source, item.Path);
                var dst = Path.Combine(target, item.Path);
                var dir = Path.GetDirectoryName(dst);
                if (dir != null && !Directory.Exists(dir)) Directory.CreateDirectory(dir);
                File.Copy(src, dst, overwrite: true);
                Console.WriteLine($"  {item.Action}: {item.Path}");
                break;
            case "DELETE":
                var tgt = Path.Combine(target, item.Path);
                if (File.Exists(tgt)) File.Delete(tgt);
                Console.WriteLine($"  DELETE: {item.Path}");
                break;
        }
    }
}

// Simple data types for the file-based app (separate from the test project's types)
record ComparisonData
{
    public List<string> SourceOnly { get; set; } = new();
    public List<string> TargetOnly { get; set; } = new();
    public List<string> Identical { get; set; } = new();
    public List<string> Different { get; set; } = new();
}

record SyncItem(string Action, string Path);
