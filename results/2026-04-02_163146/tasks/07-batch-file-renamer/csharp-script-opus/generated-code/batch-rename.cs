// =============================================================================
// batch-rename.cs — CLI for batch file renaming using regex patterns
//
// Usage:
//   dotnet run batch-rename.cs <directory> <pattern> <replacement> [--preview] [--undo-file <path>]
//
// Examples:
//   dotnet run batch-rename.cs ./photos "photo_(\d+)" "img_$1" --preview
//   dotnet run batch-rename.cs ./photos "photo_(\d+)" "img_$1" --undo-file undo.sh
//   dotnet run batch-rename.cs ./docs "\.jpeg$" ".jpg"
//
// Features:
//   - Regex-based renaming with capture groups ($1, $2, etc.)
//   - Preview mode: shows what would change without doing it
//   - Conflict detection: warns if two files would get the same name
//   - Undo script: generates a bash script to reverse all renames
//
// Run with: dotnet run batch-rename.cs
// =============================================================================

#nullable enable
using System;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Collections.Generic;

// Re-use types from the FileRenamer library (inlined for file-based app compatibility)

// ---------------------------------------------------------------------------
// Parse command-line arguments
// ---------------------------------------------------------------------------
if (args.Length < 3)
{
    PrintUsage();
    return 1;
}

var directory = args[0];
var pattern = args[1];
var replacement = args[2];
var preview = args.Contains("--preview");
var undoFileIndex = Array.IndexOf(args, "--undo-file");
var undoFile = undoFileIndex >= 0 && undoFileIndex + 1 < args.Length
    ? args[undoFileIndex + 1]
    : null;

// ---------------------------------------------------------------------------
// Validate inputs
// ---------------------------------------------------------------------------
if (!Directory.Exists(directory))
{
    Console.Error.WriteLine($"Error: Directory not found: {directory}");
    return 1;
}

Regex regex;
try
{
    regex = new Regex(pattern);
}
catch (RegexParseException ex)
{
    Console.Error.WriteLine($"Error: Invalid regex pattern: {ex.Message}");
    return 1;
}

if (string.IsNullOrEmpty(pattern))
{
    Console.Error.WriteLine("Error: Pattern cannot be empty.");
    return 1;
}

// ---------------------------------------------------------------------------
// Scan files and compute renames
// ---------------------------------------------------------------------------
var files = Directory.GetFiles(directory);
var proposedRenames = new List<(string OldPath, string NewPath, string OldName, string NewName)>();

foreach (var filePath in files)
{
    var fileName = Path.GetFileName(filePath);
    var newName = regex.Replace(fileName, replacement);

    if (newName == fileName)
        continue;

    var newPath = Path.Combine(directory, newName);
    proposedRenames.Add((filePath, newPath, fileName, newName));
}

if (proposedRenames.Count == 0)
{
    Console.WriteLine("No files match the pattern. Nothing to rename.");
    return 0;
}

// ---------------------------------------------------------------------------
// Conflict detection
// ---------------------------------------------------------------------------
var conflicts = new List<(string TargetName, List<string> Sources)>();

// Check for duplicate target names among proposed renames
var duplicateTargets = proposedRenames
    .GroupBy(r => r.NewName)
    .Where(g => g.Count() > 1);

foreach (var group in duplicateTargets)
{
    conflicts.Add((group.Key, group.Select(r => r.OldName).ToList()));
}

// Check for collision with existing files not being renamed
var renamingFrom = new HashSet<string>(proposedRenames.Select(r => r.OldPath));
foreach (var rename in proposedRenames)
{
    if (File.Exists(rename.NewPath) && !renamingFrom.Contains(rename.NewPath))
    {
        if (!conflicts.Any(c => c.TargetName == rename.NewName))
        {
            conflicts.Add((rename.NewName, new List<string> { rename.OldName, rename.NewName + " (existing)" }));
        }
    }
}

if (conflicts.Count > 0)
{
    Console.Error.WriteLine("CONFLICTS DETECTED — no files were renamed:");
    foreach (var conflict in conflicts)
    {
        Console.Error.WriteLine($"  Target \"{conflict.TargetName}\" claimed by: {string.Join(", ", conflict.Sources)}");
    }
    return 1;
}

// ---------------------------------------------------------------------------
// Preview or execute
// ---------------------------------------------------------------------------
if (preview)
{
    Console.WriteLine($"Preview — {proposedRenames.Count} file(s) would be renamed:");
    foreach (var r in proposedRenames)
    {
        Console.WriteLine($"  {r.OldName} -> {r.NewName}");
    }
}
else
{
    Console.WriteLine($"Renaming {proposedRenames.Count} file(s)...");
    foreach (var r in proposedRenames)
    {
        File.Move(r.OldPath, r.NewPath);
        Console.WriteLine($"  {r.OldName} -> {r.NewName}");
    }
    Console.WriteLine("Done.");
}

// ---------------------------------------------------------------------------
// Generate undo script if requested
// ---------------------------------------------------------------------------
if (undoFile != null && !preview)
{
    var sb = new StringBuilder();
    sb.AppendLine("#!/bin/bash");
    sb.AppendLine("# Undo script — reverses batch file renames");
    sb.AppendLine($"# Generated at: {DateTime.UtcNow:yyyy-MM-dd HH:mm:ss} UTC");
    sb.AppendLine();
    sb.AppendLine("set -e");
    sb.AppendLine();

    foreach (var r in proposedRenames)
    {
        var escapedNew = $"\"{r.NewPath.Replace("\\", "\\\\").Replace("\"", "\\\"")}\"";
        var escapedOld = $"\"{r.OldPath.Replace("\\", "\\\\").Replace("\"", "\\\"")}\"";
        sb.AppendLine($"mv {escapedNew} {escapedOld}");
    }

    sb.AppendLine();
    sb.AppendLine($"echo \"Undo complete: {proposedRenames.Count} file(s) restored.\"");

    File.WriteAllText(undoFile, sb.ToString());
    Console.WriteLine($"Undo script saved to: {undoFile}");
}
else if (undoFile != null && preview)
{
    Console.WriteLine("(Undo script not generated in preview mode.)");
}

return 0;

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------
static void PrintUsage()
{
    Console.WriteLine("Batch File Renamer — rename files using regex patterns");
    Console.WriteLine();
    Console.WriteLine("Usage:");
    Console.WriteLine("  dotnet run batch-rename.cs <directory> <pattern> <replacement> [options]");
    Console.WriteLine();
    Console.WriteLine("Options:");
    Console.WriteLine("  --preview           Show what would change without renaming");
    Console.WriteLine("  --undo-file <path>  Generate an undo script at the given path");
    Console.WriteLine();
    Console.WriteLine("Examples:");
    Console.WriteLine("  dotnet run batch-rename.cs ./photos \"photo_(\\d+)\" \"img_$1\" --preview");
    Console.WriteLine("  dotnet run batch-rename.cs ./docs \"\\.jpeg$\" \".jpg\" --undo-file undo.sh");
}
