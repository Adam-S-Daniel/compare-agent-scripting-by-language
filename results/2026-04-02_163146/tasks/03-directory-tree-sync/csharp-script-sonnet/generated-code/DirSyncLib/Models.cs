// Core data models for directory sync

namespace DirSyncLib;

/// <summary>Describes the relationship of a file between two directories.</summary>
public enum FileStatus
{
    Identical,      // same hash in both trees
    Modified,       // exists in both, but different content
    SourceOnly,     // only in the source directory
    TargetOnly,     // only in the target directory
}

/// <summary>Result of comparing a single file path across two directory trees.</summary>
public record FileComparison(
    string RelativePath,
    FileStatus Status,
    string? SourceHash,
    string? TargetHash
);

/// <summary>What action to take for a file during sync.</summary>
public enum SyncAction
{
    Copy,       // copy from source → target (source-only file)
    Update,     // overwrite target with source (modified file)
    Delete,     // remove from target (target-only file)
}

/// <summary>A single operation within a sync plan.</summary>
public record SyncOperation(
    SyncAction Action,
    string RelativePath,
    string SourcePath,   // full absolute source path
    string TargetPath    // full absolute target path
);

/// <summary>The full set of operations needed to sync two directory trees.</summary>
public record SyncPlan(
    string SourceRoot,
    string TargetRoot,
    IReadOnlyList<SyncOperation> Operations
);

/// <summary>Summary of a completed (or dry-run) sync execution.</summary>
public record SyncResult(
    bool IsDryRun,
    int Copied,
    int Updated,
    int Deleted,
    int Skipped,
    IReadOnlyList<string> Errors
);
