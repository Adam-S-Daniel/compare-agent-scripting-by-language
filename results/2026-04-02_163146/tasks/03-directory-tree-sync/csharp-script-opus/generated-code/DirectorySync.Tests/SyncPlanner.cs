// SyncPlanner: Generates a sync plan from a directory comparison.
// The plan describes what actions are needed to make target match source,
// without performing any modifications (dry-run mode is just reading the plan).

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

/// <summary>Types of sync actions that can be performed.</summary>
public enum SyncActionType
{
    /// <summary>Copy a file from source to target (new file).</summary>
    Copy,

    /// <summary>Update a file in target with source's version (content differs).</summary>
    Update,

    /// <summary>Delete a file from target (not in source).</summary>
    Delete
}

/// <summary>A single action in the sync plan.</summary>
public class SyncAction
{
    public SyncActionType Type { get; set; }
    public string RelativePath { get; set; } = "";

    public override string ToString() => Type switch
    {
        SyncActionType.Copy => $"  COPY   {RelativePath}",
        SyncActionType.Update => $"  UPDATE {RelativePath}",
        SyncActionType.Delete => $"  DELETE {RelativePath}",
        _ => $"  ???    {RelativePath}"
    };
}

/// <summary>
/// A sync plan: an ordered list of actions to make target match source.
/// </summary>
public class SyncPlan
{
    public List<SyncAction> Actions { get; set; } = new();

    /// <summary>
    /// Generate a human-readable dry-run report of the planned actions.
    /// </summary>
    public string GenerateReport()
    {
        var sb = new StringBuilder();
        sb.AppendLine("=== Directory Sync Plan ===");
        sb.AppendLine();

        var copies = Actions.Where(a => a.Type == SyncActionType.Copy).ToList();
        var updates = Actions.Where(a => a.Type == SyncActionType.Update).ToList();
        var deletes = Actions.Where(a => a.Type == SyncActionType.Delete).ToList();

        if (copies.Count > 0)
        {
            sb.AppendLine($"Files to copy ({copies.Count}):");
            foreach (var a in copies) sb.AppendLine(a.ToString());
            sb.AppendLine();
        }

        if (updates.Count > 0)
        {
            sb.AppendLine($"Files to update ({updates.Count}):");
            foreach (var a in updates) sb.AppendLine(a.ToString());
            sb.AppendLine();
        }

        if (deletes.Count > 0)
        {
            sb.AppendLine($"Files to delete ({deletes.Count}):");
            foreach (var a in deletes) sb.AppendLine(a.ToString());
            sb.AppendLine();
        }

        if (Actions.Count == 0)
        {
            sb.AppendLine("No actions needed — directories are already in sync.");
        }
        else
        {
            sb.AppendLine($"Total: {copies.Count} copy, {updates.Count} update, {deletes.Count} delete");
        }

        return sb.ToString();
    }
}

/// <summary>
/// Creates a sync plan by comparing source and target directories.
/// </summary>
public static class SyncPlanner
{
    /// <summary>
    /// Compare directories and produce a plan of actions needed.
    /// This is a pure read operation — no files are modified.
    /// </summary>
    public static SyncPlan CreatePlan(string sourcePath, string targetPath)
    {
        var comparison = DirectoryComparer.Compare(sourcePath, targetPath);
        var plan = new SyncPlan();

        // Files only in source need to be copied to target
        foreach (var file in comparison.SourceOnly)
            plan.Actions.Add(new SyncAction { Type = SyncActionType.Copy, RelativePath = file });

        // Files with different content need to be updated
        foreach (var file in comparison.Different)
            plan.Actions.Add(new SyncAction { Type = SyncActionType.Update, RelativePath = file });

        // Files only in target need to be deleted
        foreach (var file in comparison.TargetOnly)
            plan.Actions.Add(new SyncAction { Type = SyncActionType.Delete, RelativePath = file });

        return plan;
    }
}
