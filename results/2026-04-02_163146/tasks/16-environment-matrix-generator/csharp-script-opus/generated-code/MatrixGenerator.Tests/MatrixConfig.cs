/// <summary>
/// Configuration for generating a GitHub Actions strategy.matrix.
/// Mirrors the structure of the strategy section in a GitHub Actions workflow.
/// </summary>
public class MatrixConfig
{
    /// <summary>
    /// The matrix dimensions: each key is a variable name, each value is a list of options.
    /// Example: { "os": ["ubuntu-latest", "windows-latest"], "node": ["18", "20"] }
    /// </summary>
    public Dictionary<string, List<string>> Matrix { get; set; } = new();

    /// <summary>
    /// Additional combinations to include beyond the Cartesian product.
    /// Each entry is a dictionary of dimension -> value pairs.
    /// </summary>
    public List<Dictionary<string, string>> Include { get; set; } = new();

    /// <summary>
    /// Combinations to exclude from the Cartesian product.
    /// Each entry specifies dimension -> value pairs to match for exclusion.
    /// </summary>
    public List<Dictionary<string, string>> Exclude { get; set; } = new();

    /// <summary>
    /// Maximum number of parallel jobs. 0 or null means no limit.
    /// </summary>
    public int? MaxParallel { get; set; }

    /// <summary>
    /// Whether to cancel all in-progress jobs if any matrix job fails.
    /// Defaults to true (matching GitHub Actions default).
    /// </summary>
    public bool FailFast { get; set; } = true;

    /// <summary>
    /// Maximum allowed matrix size. GitHub Actions limits to 256.
    /// </summary>
    public int MaxMatrixSize { get; set; } = 256;
}
