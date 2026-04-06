// LabelAssigner: the core engine that assigns labels to a set of changed files.
//
// Algorithm:
//   1. Sort rules by priority (ascending; lower number = evaluated first).
//   2. For each file path, test every rule in priority order.
//   3. When a rule's glob pattern matches the file path, add the rule's label to the result set.
//   4. Deduplicate labels (a HashSet handles this automatically).
//   5. Return the final label set.
//
// Design decisions:
//   - Multiple labels CAN be applied to a single PR (union of all matching rule labels).
//   - Priority controls evaluation order but does NOT suppress other labels.
//     All matching rules contribute their labels regardless of priority.
//   - Labels are case-sensitive and returned as a sorted, read-only set.

namespace PrLabelAssigner;

public class LabelAssigner
{
    // Rules sorted by priority (lower number = higher priority = evaluated first)
    private readonly IReadOnlyList<LabelRule> _rules;

    public LabelAssigner(IEnumerable<LabelRule> rules)
    {
        _rules = rules
            .OrderBy(r => r.Priority)
            .ThenBy(r => r.Pattern) // stable secondary sort for determinism
            .ToList()
            .AsReadOnly();
    }

    /// <summary>
    /// Assigns labels to a PR based on its changed file paths.
    /// </summary>
    /// <param name="filePaths">The list of file paths changed in the PR.</param>
    /// <returns>A read-only, deduplicated set of labels to apply.</returns>
    public IReadOnlySet<string> AssignLabels(IEnumerable<string> filePaths)
    {
        var labels = new SortedSet<string>(StringComparer.Ordinal);

        foreach (var filePath in filePaths)
        {
            foreach (var rule in _rules)
            {
                if (GlobMatcher.IsMatch(filePath, rule.Pattern))
                {
                    labels.Add(rule.Label);
                }
            }
        }

        return labels;
    }
}
