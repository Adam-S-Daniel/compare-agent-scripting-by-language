// LabelRule: Represents a mapping from a glob pattern to a label with a priority.
// Lower priority number = higher precedence (applied first in conflict resolution).

namespace PrLabelAssigner;

/// <param name="GlobPattern">Glob pattern to match file paths (e.g., "docs/**", "*.test.*")</param>
/// <param name="Label">Label to apply when pattern matches</param>
/// <param name="Priority">Priority for conflict resolution; lower = higher precedence</param>
public record LabelRule(string GlobPattern, string Label, int Priority = int.MaxValue);
