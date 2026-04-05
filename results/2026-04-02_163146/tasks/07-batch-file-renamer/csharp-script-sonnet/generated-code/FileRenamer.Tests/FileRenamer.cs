// FileRenamer.cs - Core implementation of the batch file renamer
// Implements IFileSystem interface for testability with mock file systems

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

namespace FileRenamer.Tests
{
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
        /// Returns a list of planned renames.
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
        /// or where the target name already exists in the file system.
        /// </summary>
        public List<RenameConflict> DetectConflicts(string directory, string pattern, string replacement)
        {
            var plannedRenames = Preview(directory, pattern, replacement);
            var conflicts = new List<RenameConflict>();

            // Check for duplicates within the planned renames
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

            // Check for conflicts with existing files (files that are NOT being renamed)
            var renamedOldPaths = new HashSet<string>(plannedRenames.Select(r => r.OldPath));

            foreach (var rename in plannedRenames)
            {
                // If the target file already exists AND it's not one of the files being renamed
                if (_fileSystem.FileExists(rename.NewPath) && !renamedOldPaths.Contains(rename.NewPath))
                {
                    // Check if we already reported this conflict
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
            // Check for conflicts first
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
        /// Generate a shell script that reverses the given renames.
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

            // Generate reverse rename commands (new -> old)
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
}
