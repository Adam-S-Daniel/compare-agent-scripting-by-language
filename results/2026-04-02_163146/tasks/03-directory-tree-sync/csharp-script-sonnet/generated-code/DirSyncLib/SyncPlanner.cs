// SyncPlanner: converts FileComparison results into a SyncPlan.
// The planner is pure (no I/O); it only transforms data.

namespace DirSyncLib;

public class SyncPlanner
{
    /// <summary>
    /// Builds a <see cref="SyncPlan"/> from directory comparison results.
    /// Identical files produce no operation.
    /// SourceOnly → Copy, Modified → Update, TargetOnly → Delete.
    /// </summary>
    public SyncPlan CreatePlan(
        IEnumerable<FileComparison> comparisons,
        string sourceRoot,
        string targetRoot)
    {
        var ops = new List<SyncOperation>();

        foreach (var c in comparisons)
        {
            var srcPath = $"{sourceRoot.TrimEnd('/')}/{c.RelativePath}";
            var tgtPath = $"{targetRoot.TrimEnd('/')}/{c.RelativePath}";

            SyncOperation? op = c.Status switch
            {
                FileStatus.SourceOnly => new SyncOperation(SyncAction.Copy,   c.RelativePath, srcPath, tgtPath),
                FileStatus.Modified   => new SyncOperation(SyncAction.Update, c.RelativePath, srcPath, tgtPath),
                FileStatus.TargetOnly => new SyncOperation(SyncAction.Delete, c.RelativePath, srcPath, tgtPath),
                FileStatus.Identical  => null,  // nothing to do
                _ => throw new InvalidOperationException($"Unknown status: {c.Status}")
            };

            if (op is not null)
                ops.Add(op);
        }

        return new SyncPlan(sourceRoot, targetRoot, ops);
    }
}
