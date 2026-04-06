// Domain model: a single rule that maps a glob pattern to a label with a priority.
// Lower priority number = higher priority (applied/evaluated first).

namespace PrLabelAssigner;

/// <summary>
/// A rule that maps a glob pattern to a label.
/// </summary>
/// <param name="Pattern">Glob pattern (e.g. "docs/**", "*.test.*", "src/api/**")</param>
/// <param name="Label">The label to apply when the pattern matches (e.g. "documentation")</param>
/// <param name="Priority">Lower number = higher priority. Used to order rule evaluation
///   and resolve conflicts when multiple rules match the same file.</param>
public record LabelRule(string Pattern, string Label, int Priority);
