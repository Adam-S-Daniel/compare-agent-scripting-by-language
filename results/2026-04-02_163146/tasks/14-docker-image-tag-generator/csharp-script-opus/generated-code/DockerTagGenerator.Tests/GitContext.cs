// GitContext: Represents the git context used to generate Docker image tags.
// This is our "model" — all inputs needed for tag generation are captured here.

namespace DockerTagGenerator;

/// <summary>
/// Represents the git context from which Docker image tags are generated.
/// All fields are mock inputs — in a real CI/CD pipeline these would come
/// from environment variables (e.g., GITHUB_REF, GITHUB_SHA, etc.).
/// </summary>
public class GitContext
{
    /// <summary>Branch name (e.g., "main", "feature/my-feature").</summary>
    public string BranchName { get; set; } = string.Empty;

    /// <summary>Full commit SHA (40 hex chars).</summary>
    public string CommitSha { get; set; } = string.Empty;

    /// <summary>Git tags pointing at the current commit (e.g., "v1.2.3").</summary>
    public string[] Tags { get; set; } = Array.Empty<string>();

    /// <summary>PR number, if this build is for a pull request.</summary>
    public int? PrNumber { get; set; }

    /// <summary>Returns the first 7 characters of CommitSha (short SHA).</summary>
    public string ShortSha => CommitSha.Length >= 7
        ? CommitSha[..7]
        : CommitSha;
}
