namespace ArtifactCleanup;

/// <summary>
/// Represents a build/CI artifact with metadata used for retention decisions.
/// </summary>
public record Artifact(
    string Name,
    long SizeBytes,
    DateTime CreatedAt,
    string WorkflowRunId
);
