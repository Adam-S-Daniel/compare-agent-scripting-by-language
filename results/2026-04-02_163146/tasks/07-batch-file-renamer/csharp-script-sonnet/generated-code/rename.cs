// rename.cs - Batch File Renamer
// Top-level statements for .NET 10 file-based apps
// Run with: dotnet run rename.cs <directory> <pattern> <replacement> [--preview] [--undo-script <path>]
//
// TDD APPROACH:
// 1. Tests (FileRenamer.Tests/) were written first as failing tests
// 2. This implementation was written to make those tests pass
// 3. Core logic is shared via the BatchFileRenamer class below

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

// ==========================================
// MAIN PROGRAM (TOP-LEVEL STATEMENTS)
// Note: In C# with top-level statements, type declarations must come AFTER
// ==========================================

// Parse command line arguments
if (args.Length < 3)
{
    Console.Error.WriteLine("Usage: dotnet run rename.cs <directory> <pattern> <replacement> [--preview] [--undo-script <path>]");
    Console.Error.WriteLine();
    Console.Error.WriteLine("Arguments:");
    Console.Error.WriteLine("  <directory>           Directory containing files to rename");
    Console.Error.WriteLine("  <pattern>             Regex pattern to match file names");
    Console.Error.WriteLine("  <replacement>         Replacement string (supports $1, $2 for capture groups)");
    Console.Error.WriteLine();
    Console.Error.WriteLine("Options:");
    Console.Error.WriteLine("  --preview             Show what would change without actually renaming");
    Console.Error.WriteLine("  --undo-script <path>  Generate a shell script to undo the renames");
    Console.Error.WriteLine();
    Console.Error.WriteLine("Examples:");
    Console.Error.WriteLine("  dotnet run rename.cs ./photos 'photo_(\\d+)\\.jpg' 'image_$1.jpg'");
    Console.Error.WriteLine("  dotnet run rename.cs ./photos 'photo_(\\d+)\\.jpg' 'image_$1.jpg' --preview");
    Console.Error.WriteLine("  dotnet run rename.cs ./photos 'photo_(\\d+)\\.jpg' 'image_$1.jpg' --undo-script undo.sh");
    Environment.Exit(1);
}

var directory = args[0];
var pattern = args[1];
var replacement = args[2];
var previewMode = args.Contains("--preview");
string? undoScriptPath = null;

// Parse --undo-script option
var undoScriptIndex = Array.IndexOf(args, "--undo-script");
if (undoScriptIndex >= 0 && undoScriptIndex + 1 < args.Length)
{
    undoScriptPath = args[undoScriptIndex + 1];
}

// Validate directory
if (!Directory.Exists(directory))
{
    Console.Error.WriteLine($"Error: Directory '{directory}' does not exist.");
    Environment.Exit(1);
}

// Validate regex pattern
try
{
    _ = new Regex(pattern);
}
catch (RegexParseException ex)
{
    Console.Error.WriteLine($"Error: Invalid regex pattern '{pattern}': {ex.Message}");
    Environment.Exit(1);
}

// Create renamer with real file system
var fileSystem = new RealFileSystem();
var renamer = new BatchFileRenamer(fileSystem);

if (previewMode)
{
    // Preview mode: show what would change without modifying anything
    Console.WriteLine($"PREVIEW MODE - No files will be renamed");
    Console.WriteLine($"Directory: {directory}");
    Console.WriteLine($"Pattern:   {pattern}");
    Console.WriteLine($"Replace:   {replacement}");
    Console.WriteLine();

    var previews = renamer.Preview(directory, pattern, replacement);

    if (previews.Count == 0)
    {
        Console.WriteLine("No files match the pattern.");
    }
    else
    {
        Console.WriteLine($"Files that would be renamed ({previews.Count} total):");
        foreach (var preview in previews)
        {
            Console.WriteLine($"  {Path.GetFileName(preview.OldPath)} -> {Path.GetFileName(preview.NewPath)}");
        }

        // Check for conflicts even in preview mode
        var conflicts = renamer.DetectConflicts(directory, pattern, replacement);
        if (conflicts.Any())
        {
            Console.WriteLine();
            Console.WriteLine($"WARNING: {conflicts.Count} conflict(s) detected:");
            foreach (var conflict in conflicts)
            {
                Console.WriteLine($"  CONFLICT: {conflict.ConflictingNewPath}");
                Console.WriteLine($"    Reason: {conflict.Reason}");
                foreach (var source in conflict.SourcePaths)
                {
                    Console.WriteLine($"    Source:  {source}");
                }
            }
        }
    }
}
else
{
    // Execute mode: perform the renames
    Console.WriteLine($"Renaming files in: {directory}");
    Console.WriteLine($"Pattern:  {pattern}");
    Console.WriteLine($"Replace:  {replacement}");
    Console.WriteLine();

    // Check for conflicts before executing
    var conflicts = renamer.DetectConflicts(directory, pattern, replacement);
    if (conflicts.Any())
    {
        Console.Error.WriteLine($"ERROR: {conflicts.Count} conflict(s) detected. Aborting.");
        foreach (var conflict in conflicts)
        {
            Console.Error.WriteLine($"  CONFLICT: {conflict.ConflictingNewPath}");
            Console.Error.WriteLine($"    Reason: {conflict.Reason}");
            foreach (var source in conflict.SourcePaths)
            {
                Console.Error.WriteLine($"    Source:  {source}");
            }
        }
        Console.Error.WriteLine();
        Console.Error.WriteLine("Use --preview to see planned renames without executing.");
        Environment.Exit(2);
    }

    try
    {
        var results = renamer.Execute(directory, pattern, replacement);

        if (results.Count == 0)
        {
            Console.WriteLine("No files match the pattern.");
        }
        else
        {
            var successCount = results.Count(r => r.Success);
            var failCount = results.Count(r => !r.Success);

            foreach (var result in results)
            {
                if (result.Success)
                {
                    Console.WriteLine($"  RENAMED: {Path.GetFileName(result.OldPath)} -> {Path.GetFileName(result.NewPath)}");
                }
                else
                {
                    Console.Error.WriteLine($"  FAILED:  {Path.GetFileName(result.OldPath)} -> {Path.GetFileName(result.NewPath)}: {result.ErrorMessage}");
                }
            }

            Console.WriteLine();
            Console.WriteLine($"Summary: {successCount} renamed, {failCount} failed");

            // Generate undo script if requested
            if (undoScriptPath != null)
            {
                var successfulRenames = results.Where(r => r.Success).ToList();
                renamer.GenerateUndoScript(successfulRenames, undoScriptPath);
                Console.WriteLine($"Undo script written to: {undoScriptPath}");
            }
        }
    }
    catch (InvalidOperationException ex)
    {
        Console.Error.WriteLine($"ERROR: {ex.Message}");
        Environment.Exit(2);
    }
}

// ==========================================
// INTERFACES AND MODELS
// (must come AFTER top-level statements in C# file-based apps)
// ==========================================

/// <summary>
/// Interface for file system operations, enabling mock implementations for testing.
/// </summary>
public interface IFileSystem
{
    IEnumerable<string> GetFiles(string directory);
    void RenameFile(string oldPath, string newPath);
    bool FileExists(string path);
    void WriteAllText(string path, string content);
}

/// <summary>
/// Represents the result of a file rename operation.
/// </summary>
public class RenameResult
{
    public string OldPath { get; set; } = string.Empty;
    public string NewPath { get; set; } = string.Empty;
    public bool Success { get; set; }
    public string? ErrorMessage { get; set; }
}

/// <summary>
/// Represents a detected rename conflict.
/// </summary>
public class RenameConflict
{
    public string ConflictingNewPath { get; set; } = string.Empty;
    public List<string> SourcePaths { get; set; } = new List<string>();
    public string Reason { get; set; } = string.Empty;
}

// ==========================================
// REAL FILE SYSTEM IMPLEMENTATION
// ==========================================

/// <summary>
/// Real file system implementation for production use.
/// </summary>
public class RealFileSystem : IFileSystem
{
    public IEnumerable<string> GetFiles(string directory)
    {
        return Directory.GetFiles(directory);
    }

    public void RenameFile(string oldPath, string newPath)
    {
        File.Move(oldPath, newPath);
    }

    public bool FileExists(string path)
    {
        return File.Exists(path);
    }

    public void WriteAllText(string path, string content)
    {
        File.WriteAllText(path, content);
    }
}

// ==========================================
// BATCH FILE RENAMER CORE LOGIC
// ==========================================

/// <summary>
/// Core batch file renamer that uses regex patterns to rename files.
/// Takes an IFileSystem dependency for testability.
/// </summary>
public class BatchFileRenamer
{
    private readonly IFileSystem _fileSystem;

    public BatchFileRenamer(IFileSystem fileSystem)
    {
        _fileSystem = fileSystem;
    }

    /// <summary>
    /// Preview what files would be renamed without actually renaming them.
    /// Returns a list of planned renames (preview mode - no changes made).
    /// </summary>
    public List<RenameResult> Preview(string directory, string pattern, string replacement)
    {
        var files = _fileSystem.GetFiles(directory);
        var results = new List<RenameResult>();

        foreach (var filePath in files)
        {
            var fileName = Path.GetFileName(filePath);
            var dirPath = Path.GetDirectoryName(filePath) ?? directory;

            if (Regex.IsMatch(fileName, pattern))
            {
                var newFileName = Regex.Replace(fileName, pattern, replacement);
                // Normalize path separators for cross-platform consistency
                var newFilePath = Path.Combine(dirPath, newFileName).Replace('\\', '/');

                results.Add(new RenameResult
                {
                    OldPath = filePath,
                    NewPath = newFilePath,
                    Success = true
                });
            }
        }

        return results;
    }

    /// <summary>
    /// Detect naming conflicts: cases where two files would get the same new name,
    /// or where the target name already exists as a non-renamed file.
    /// </summary>
    public List<RenameConflict> DetectConflicts(string directory, string pattern, string replacement)
    {
        var plannedRenames = Preview(directory, pattern, replacement);
        var conflicts = new List<RenameConflict>();

        // Check for duplicates within the planned renames (two sources -> same target)
        var groupedByNewPath = plannedRenames
            .GroupBy(r => r.NewPath)
            .Where(g => g.Count() > 1);

        foreach (var group in groupedByNewPath)
        {
            conflicts.Add(new RenameConflict
            {
                ConflictingNewPath = group.Key,
                SourcePaths = group.Select(r => r.OldPath).ToList(),
                Reason = "Multiple files would be renamed to the same path"
            });
        }

        // Check for conflicts with existing files that are NOT being renamed
        var renamedOldPaths = new HashSet<string>(plannedRenames.Select(r => r.OldPath));

        foreach (var rename in plannedRenames)
        {
            // If the target already exists AND it's not one of the files being renamed
            if (_fileSystem.FileExists(rename.NewPath) && !renamedOldPaths.Contains(rename.NewPath))
            {
                if (!conflicts.Any(c => c.ConflictingNewPath == rename.NewPath))
                {
                    conflicts.Add(new RenameConflict
                    {
                        ConflictingNewPath = rename.NewPath,
                        SourcePaths = new List<string> { rename.OldPath },
                        Reason = "Target file already exists"
                    });
                }
            }
        }

        return conflicts;
    }

    /// <summary>
    /// Execute the batch rename operation.
    /// Throws InvalidOperationException if conflicts are detected.
    /// </summary>
    public List<RenameResult> Execute(string directory, string pattern, string replacement)
    {
        // Safety check: detect conflicts before making any changes
        var conflicts = DetectConflicts(directory, pattern, replacement);
        if (conflicts.Any())
        {
            var conflictDetails = string.Join(", ",
                conflicts.Select(c => $"'{c.ConflictingNewPath}' ({c.Reason})"));
            throw new InvalidOperationException(
                $"Cannot rename files due to conflicts: {conflictDetails}");
        }

        var plannedRenames = Preview(directory, pattern, replacement);
        var results = new List<RenameResult>();

        foreach (var planned in plannedRenames)
        {
            try
            {
                _fileSystem.RenameFile(planned.OldPath, planned.NewPath);
                results.Add(new RenameResult
                {
                    OldPath = planned.OldPath,
                    NewPath = planned.NewPath,
                    Success = true
                });
            }
            catch (Exception ex)
            {
                results.Add(new RenameResult
                {
                    OldPath = planned.OldPath,
                    NewPath = planned.NewPath,
                    Success = false,
                    ErrorMessage = ex.Message
                });
            }
        }

        return results;
    }

    /// <summary>
    /// Generate a bash script that reverses the given renames (undo capability).
    /// Optionally writes the script to a file.
    /// </summary>
    public string GenerateUndoScript(List<RenameResult> results, string? outputPath = null)
    {
        var sb = new StringBuilder();
        sb.AppendLine("#!/bin/bash");
        sb.AppendLine("# Undo script generated by BatchFileRenamer");
        sb.AppendLine($"# Generated at: {DateTime.UtcNow:yyyy-MM-dd HH:mm:ss} UTC");
        sb.AppendLine();
        sb.AppendLine("set -e  # Exit on error");
        sb.AppendLine();

        // Generate reverse mv commands: new name -> old name
        foreach (var result in results.Where(r => r.Success))
        {
            sb.AppendLine($"mv \"{result.NewPath}\" \"{result.OldPath}\"");
        }

        var script = sb.ToString();

        if (outputPath != null)
        {
            _fileSystem.WriteAllText(outputPath, script);
        }

        return script;
    }
}
