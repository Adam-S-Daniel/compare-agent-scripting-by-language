// SyncExecutor: applies (or simulates) a SyncPlan against the filesystem.
// Both DryRun and Execute use the IFileSystem abstraction so tests can use MockFileSystem.

namespace DirSyncLib;

public class SyncExecutor(IFileSystem fileSystem)
{
    private readonly IFileSystem _fs = fileSystem;

    /// <summary>
    /// Dry-run: counts what would happen without actually modifying anything.
    /// Returns a <see cref="SyncResult"/> with <c>IsDryRun = true</c>.
    /// </summary>
    public SyncResult DryRun(SyncPlan plan)
    {
        int copied = 0, updated = 0, deleted = 0;

        foreach (var op in plan.Operations)
        {
            switch (op.Action)
            {
                case SyncAction.Copy:   copied++;  break;
                case SyncAction.Update: updated++; break;
                case SyncAction.Delete: deleted++; break;
            }
        }

        return new SyncResult(IsDryRun: true, copied, updated, deleted, Skipped: 0, []);
    }

    /// <summary>
    /// Execute mode: performs each operation in the plan.
    /// Errors are captured per-operation; execution continues after a failure.
    /// Returns a <see cref="SyncResult"/> with <c>IsDryRun = false</c>.
    /// </summary>
    public SyncResult Execute(SyncPlan plan)
    {
        int copied = 0, updated = 0, deleted = 0;
        var errors = new List<string>();

        foreach (var op in plan.Operations)
        {
            try
            {
                switch (op.Action)
                {
                    case SyncAction.Copy:
                        _fs.CopyFile(op.SourcePath, op.TargetPath);
                        copied++;
                        break;

                    case SyncAction.Update:
                        _fs.CopyFile(op.SourcePath, op.TargetPath);
                        updated++;
                        break;

                    case SyncAction.Delete:
                        _fs.DeleteFile(op.TargetPath);
                        deleted++;
                        break;
                }
            }
            catch (Exception ex)
            {
                errors.Add($"[{op.Action}] {op.RelativePath}: {ex.Message}");
            }
        }

        return new SyncResult(IsDryRun: false, copied, updated, deleted, Skipped: 0, errors);
    }
}
