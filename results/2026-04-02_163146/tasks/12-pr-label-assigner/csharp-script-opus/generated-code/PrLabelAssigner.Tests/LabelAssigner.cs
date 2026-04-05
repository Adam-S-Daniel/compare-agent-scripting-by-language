// LabelAssigner: Core logic for assigning PR labels based on changed file paths.
// Uses glob pattern matching with configurable rules and priority-based conflict resolution.

using System.Text.RegularExpressions;

namespace PrLabelAssigner;

public static class LabelAssigner
{
    /// <summary>
    /// Assigns labels to a PR based on changed file paths and configured rules.
    /// Each file is matched against all rules; matching labels are collected.
    /// When rules conflict (same file matches multiple rules targeting the same label group),
    /// the rule with the lowest priority number wins.
    /// </summary>
    /// <param name="changedFiles">List of changed file paths in the PR</param>
    /// <param name="rules">Ordered list of label rules with glob patterns</param>
    /// <returns>Deduplicated, sorted set of labels to apply</returns>
    public static IReadOnlySet<string> AssignLabels(
        IEnumerable<string> changedFiles,
        IEnumerable<LabelRule> rules)
    {
        if (changedFiles is null) throw new ArgumentNullException(nameof(changedFiles));
        if (rules is null) throw new ArgumentNullException(nameof(rules));

        var ruleList = rules.ToList();
        var labels = new SortedSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var file in changedFiles)
        {
            if (string.IsNullOrWhiteSpace(file))
                continue;

            // Normalize path separators to forward slash
            var normalizedFile = file.Replace('\\', '/');

            foreach (var rule in ruleList)
            {
                if (GlobMatches(normalizedFile, rule.GlobPattern))
                {
                    labels.Add(rule.Label);
                }
            }
        }

        return labels;
    }

    /// <summary>
    /// Assigns labels with priority-based conflict resolution.
    /// When multiple rules match the same file and map to the same label group,
    /// only the highest-priority (lowest number) rule's label is kept.
    /// </summary>
    /// <param name="changedFiles">List of changed file paths</param>
    /// <param name="rules">Label rules with priorities</param>
    /// <param name="conflictGroups">
    /// Groups of labels that conflict — only the highest-priority match within
    /// each group is kept. Labels not in any group are always included.
    /// </param>
    /// <returns>Final set of labels after conflict resolution</returns>
    public static IReadOnlySet<string> AssignLabelsWithPriority(
        IEnumerable<string> changedFiles,
        IEnumerable<LabelRule> rules,
        IEnumerable<IReadOnlySet<string>>? conflictGroups = null)
    {
        if (changedFiles is null) throw new ArgumentNullException(nameof(changedFiles));
        if (rules is null) throw new ArgumentNullException(nameof(rules));

        var ruleList = rules.ToList();
        var groups = conflictGroups?.ToList() ?? new List<IReadOnlySet<string>>();

        // Collect all (label, best-priority) pairs across all files
        var labelPriorities = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);

        foreach (var file in changedFiles)
        {
            if (string.IsNullOrWhiteSpace(file))
                continue;

            var normalizedFile = file.Replace('\\', '/');

            foreach (var rule in ruleList)
            {
                if (GlobMatches(normalizedFile, rule.GlobPattern))
                {
                    // Track the best (lowest) priority for each label
                    if (!labelPriorities.TryGetValue(rule.Label, out var existing) ||
                        rule.Priority < existing)
                    {
                        labelPriorities[rule.Label] = rule.Priority;
                    }
                }
            }
        }

        // Resolve conflicts within groups: keep only the highest-priority label per group
        var result = new SortedSet<string>(StringComparer.OrdinalIgnoreCase);
        var handledLabels = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var group in groups)
        {
            // Find the label in this group with the best (lowest) priority
            string? bestLabel = null;
            int bestPriority = int.MaxValue;

            foreach (var label in group)
            {
                if (labelPriorities.TryGetValue(label, out var priority) && priority < bestPriority)
                {
                    bestPriority = priority;
                    bestLabel = label;
                }
            }

            if (bestLabel is not null)
            {
                result.Add(bestLabel);
            }

            // Mark all labels in this group as handled
            foreach (var label in group)
                handledLabels.Add(label);
        }

        // Add all remaining labels not in any conflict group
        foreach (var kvp in labelPriorities)
        {
            if (!handledLabels.Contains(kvp.Key))
                result.Add(kvp.Key);
        }

        return result;
    }

    /// <summary>
    /// Matches a file path against a glob pattern.
    /// Supported patterns:
    ///   ** — matches any number of path segments (including zero)
    ///   *  — matches any characters within a single path segment
    ///   ?  — matches a single character
    /// </summary>
    public static bool GlobMatches(string filePath, string pattern)
    {
        // Convert glob to regex
        var regex = GlobToRegex(pattern);
        return Regex.IsMatch(filePath, regex, RegexOptions.IgnoreCase);
    }

    /// <summary>
    /// Converts a glob pattern to a regular expression string.
    /// </summary>
    internal static string GlobToRegex(string glob)
    {
        var result = new System.Text.StringBuilder("^");
        int i = 0;

        while (i < glob.Length)
        {
            char c = glob[i];

            if (c == '*')
            {
                if (i + 1 < glob.Length && glob[i + 1] == '*')
                {
                    // ** — match any path segments
                    i += 2;
                    if (i >= glob.Length)
                    {
                        // ** at end of pattern: match anything remaining
                        result.Append(".*");
                    }
                    else if (glob[i] == '/')
                    {
                        // **/ in middle: match zero or more directory segments
                        i++;
                        result.Append("(.*/)?");
                    }
                    else
                    {
                        // ** not followed by / (unusual but handle it)
                        result.Append(".*");
                    }
                }
                else
                {
                    // * — match within single segment (no slashes)
                    result.Append("[^/]*");
                    i++;
                }
            }
            else if (c == '?')
            {
                result.Append("[^/]");
                i++;
            }
            else if (c == '.')
            {
                result.Append("\\.");
                i++;
            }
            else if (c == '{')
            {
                result.Append('(');
                i++;
            }
            else if (c == '}')
            {
                result.Append(')');
                i++;
            }
            else if (c == ',')
            {
                result.Append('|');
                i++;
            }
            else
            {
                result.Append(c);
                i++;
            }
        }

        result.Append('$');
        return result.ToString();
    }
}
