// SyncExecutor: Executes a sync plan, performing the actual file operations.
// Copies, updates, and deletes files to make target match source.

using System;
using System.IO;

/// <summary>
/// Executes sync plan actions: copy, update, and delete files.
/// </summary>
public static class SyncExecutor
{
    /// <summary>
    /// Execute all actions in the sync plan.
    /// </summary>
    /// <param name="plan">The plan to execute.</param>
    /// <param name="sourcePath">Absolute path to the source directory.</param>
    /// <param name="targetPath">Absolute path to the target directory.</param>
    public static void Execute(SyncPlan plan, string sourcePath, string targetPath)
    {
        if (!Directory.Exists(sourcePath))
            throw new DirectoryNotFoundException($"Source directory not found: {sourcePath}");
        if (!Directory.Exists(targetPath))
            throw new DirectoryNotFoundException($"Target directory not found: {targetPath}");

        foreach (var action in plan.Actions)
        {
            switch (action.Type)
            {
                case SyncActionType.Copy:
                case SyncActionType.Update:
                    CopyFile(sourcePath, targetPath, action.RelativePath);
                    break;

                case SyncActionType.Delete:
                    DeleteFile(targetPath, action.RelativePath);
                    break;

                default:
                    throw new InvalidOperationException($"Unknown sync action type: {action.Type}");
            }
        }
    }

    /// <summary>
    /// Copy a file from source to target, creating directories as needed.
    /// </summary>
    private static void CopyFile(string sourcePath, string targetPath, string relativePath)
    {
        var sourceFile = Path.Combine(sourcePath, relativePath);
        var targetFile = Path.Combine(targetPath, relativePath);

        if (!File.Exists(sourceFile))
            throw new FileNotFoundException($"Source file not found: {sourceFile}");

        // Ensure target directory exists
        var targetDir = Path.GetDirectoryName(targetFile);
        if (targetDir != null && !Directory.Exists(targetDir))
            Directory.CreateDirectory(targetDir);

        File.Copy(sourceFile, targetFile, overwrite: true);
    }

    /// <summary>
    /// Delete a file from the target directory.
    /// </summary>
    private static void DeleteFile(string targetPath, string relativePath)
    {
        var targetFile = Path.Combine(targetPath, relativePath);
        if (File.Exists(targetFile))
            File.Delete(targetFile);
    }
}
