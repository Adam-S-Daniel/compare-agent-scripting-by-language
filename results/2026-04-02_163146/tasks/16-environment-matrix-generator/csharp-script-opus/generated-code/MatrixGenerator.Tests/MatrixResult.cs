/// <summary>
/// The result of matrix generation, containing all combinations and strategy settings.
/// </summary>
public class MatrixResult
{
    /// <summary>
    /// All matrix combinations after applying include/exclude rules.
    /// Each combination is a dictionary mapping dimension names to their values.
    /// </summary>
    public List<Dictionary<string, string>> Combinations { get; set; } = new();

    /// <summary>
    /// Maximum parallel jobs setting.
    /// </summary>
    public int? MaxParallel { get; set; }

    /// <summary>
    /// Fail-fast setting.
    /// </summary>
    public bool FailFast { get; set; } = true;
}
