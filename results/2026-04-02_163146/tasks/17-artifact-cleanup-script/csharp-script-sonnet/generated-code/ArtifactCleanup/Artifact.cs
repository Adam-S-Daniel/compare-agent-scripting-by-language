namespace ArtifactCleanup;

/// <summary>
/// Represents a CI/CD workflow artifact with its metadata.
/// Immutable record for safe use in collections and comparisons.
/// </summary>
/// <param name="Name">Artifact name (e.g., "build-output", "test-results").</param>
/// <param name="SizeBytes">Size of the artifact in bytes.</param>
/// <param name="CreatedAt">When the artifact was created (UTC recommended).</param>
/// <param name="WorkflowRunId">Identifier for the workflow run that produced this artifact.</param>
public record Artifact(
    string Name,
    long SizeBytes,
    DateTimeOffset CreatedAt,
    string WorkflowRunId
)
{
    /// <summary>Convenience property: size in megabytes.</summary>
    public double SizeMb => SizeBytes / (1024.0 * 1024.0);
}
