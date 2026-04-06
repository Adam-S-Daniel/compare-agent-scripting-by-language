// PR Label Assigner — .NET 10 file-based app
// Run with: dotnet run PrLabelAssigner.cs
//
// Given a list of changed file paths (simulating a PR), this tool applies labels
// based on configurable path-to-label mapping rules using glob patterns.
// Supports: glob patterns (**, *, ?), multiple labels per file, and
// priority-based conflict resolution.

using System.Text.RegularExpressions;

// ============================================================================
// Domain types
// ============================================================================

/// <param name="GlobPattern">Glob pattern to match file paths</param>
/// <param name="Label">Label to apply when pattern matches</param>
/// <param name="Priority">Priority for conflict resolution; lower = higher precedence</param>
record LabelRule(string GlobPattern, string Label, int Priority = int.MaxValue);

// ============================================================================
// Configuration: Define your path-to-label mapping rules here
// ============================================================================

var rules = new List<LabelRule>
{
    // Higher priority (lower number) = wins in conflicts
    new("docs/**",         "documentation", Priority: 1),
    new("src/api/**",      "api",           Priority: 2),
    new("src/core/**",     "core",          Priority: 3),
    new("**/*.test.*",     "tests",         Priority: 4),
    new("**/*.spec.*",     "tests",         Priority: 4),
    new(".github/**",      "ci/cd",         Priority: 5),
    new("*.md",            "documentation", Priority: 6),
    new("**/*.css",        "styles",        Priority: 7),
    new("**/*.html",       "frontend",      Priority: 8),
    new("src/**",          "backend",       Priority: 10),
};

// Conflict groups: within each group, only the highest-priority label survives
var conflictGroups = new List<IReadOnlySet<string>>
{
    new HashSet<string> { "backend", "api", "core" },
};

// ============================================================================
// Mock file list: simulating a PR's changed files
// ============================================================================

var changedFiles = new List<string>
{
    "docs/api-reference.md",
    "src/api/users/controller.cs",
    "src/api/users/controller.test.cs",
    "src/core/auth/middleware.cs",
    ".github/workflows/ci.yml",
    "README.md",
};

// ============================================================================
// Run the label assigner
// ============================================================================

Console.WriteLine("=== PR Label Assigner ===");
Console.WriteLine();
Console.WriteLine("Changed files:");
foreach (var file in changedFiles)
    Console.WriteLine($"  - {file}");

Console.WriteLine();

// Simple mode: all matching labels (no conflict resolution)
var allLabels = AssignLabels(changedFiles, rules);
Console.WriteLine("All matching labels (no conflict resolution):");
foreach (var label in allLabels)
    Console.WriteLine($"  [{label}]");

Console.WriteLine();

// Priority mode: with conflict resolution
var resolvedLabels = AssignLabelsWithPriority(changedFiles, rules, conflictGroups);
Console.WriteLine("Final labels (with priority conflict resolution):");
foreach (var label in resolvedLabels)
    Console.WriteLine($"  [{label}]");

Console.WriteLine();
Console.WriteLine($"Total labels assigned: {resolvedLabels.Count}");

// ============================================================================
// Show which rules matched which files (detailed breakdown)
// ============================================================================

Console.WriteLine();
Console.WriteLine("=== Detailed Matching Breakdown ===");
foreach (var file in changedFiles)
{
    var normalized = file.Replace('\\', '/');
    var matchingRules = rules.Where(r => GlobMatches(normalized, r.GlobPattern)).ToList();
    if (matchingRules.Count > 0)
    {
        Console.WriteLine($"  {file}:");
        foreach (var rule in matchingRules)
            Console.WriteLine($"    -> [{rule.Label}] (pattern: {rule.GlobPattern}, priority: {rule.Priority})");
    }
}

// ============================================================================
// Core logic functions (same as in test project)
// ============================================================================

static IReadOnlySet<string> AssignLabels(
    IEnumerable<string> changedFiles,
    IEnumerable<LabelRule> rules)
{
    if (changedFiles is null) throw new ArgumentNullException(nameof(changedFiles));
    if (rules is null) throw new ArgumentNullException(nameof(rules));

    var ruleList = rules.ToList();
    var labels = new SortedSet<string>(StringComparer.OrdinalIgnoreCase);

    foreach (var file in changedFiles)
    {
        if (string.IsNullOrWhiteSpace(file)) continue;
        var normalizedFile = file.Replace('\\', '/');

        foreach (var rule in ruleList)
        {
            if (GlobMatches(normalizedFile, rule.GlobPattern))
                labels.Add(rule.Label);
        }
    }

    return labels;
}

static IReadOnlySet<string> AssignLabelsWithPriority(
    IEnumerable<string> changedFiles,
    IEnumerable<LabelRule> rules,
    IEnumerable<IReadOnlySet<string>>? conflictGroups = null)
{
    if (changedFiles is null) throw new ArgumentNullException(nameof(changedFiles));
    if (rules is null) throw new ArgumentNullException(nameof(rules));

    var ruleList = rules.ToList();
    var groups = conflictGroups?.ToList() ?? new List<IReadOnlySet<string>>();
    var labelPriorities = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);

    foreach (var file in changedFiles)
    {
        if (string.IsNullOrWhiteSpace(file)) continue;
        var normalizedFile = file.Replace('\\', '/');

        foreach (var rule in ruleList)
        {
            if (GlobMatches(normalizedFile, rule.GlobPattern))
            {
                if (!labelPriorities.TryGetValue(rule.Label, out var existing) ||
                    rule.Priority < existing)
                {
                    labelPriorities[rule.Label] = rule.Priority;
                }
            }
        }
    }

    var result = new SortedSet<string>(StringComparer.OrdinalIgnoreCase);
    var handledLabels = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

    foreach (var group in groups)
    {
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
            result.Add(bestLabel);

        foreach (var label in group)
            handledLabels.Add(label);
    }

    foreach (var kvp in labelPriorities)
    {
        if (!handledLabels.Contains(kvp.Key))
            result.Add(kvp.Key);
    }

    return result;
}

static bool GlobMatches(string filePath, string pattern)
{
    var regex = GlobToRegex(pattern);
    return Regex.IsMatch(filePath, regex, RegexOptions.IgnoreCase);
}

static string GlobToRegex(string glob)
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
                    result.Append(".*");
                }
            }
            else
            {
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
