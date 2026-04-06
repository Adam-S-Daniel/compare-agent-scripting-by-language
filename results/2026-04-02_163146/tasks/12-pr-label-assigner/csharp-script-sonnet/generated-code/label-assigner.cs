// PR Label Assigner - .NET 10 file-based app (top-level statements)
// Run with: dotnet run label-assigner.cs
//
// Given a list of changed file paths (simulating a PR's changed files),
// applies labels based on configurable path-to-label mapping rules.
//
// Supports:
//   - Glob patterns: **, *, ?, character classes
//   - Multiple labels per file/PR
//   - Priority ordering (lower number = higher priority)
//   - Graceful error handling

using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

// ── Domain model ─────────────────────────────────────────────────────────────

/// <summary>
/// A rule mapping a glob pattern to a label with an evaluation priority.
/// </summary>
record LabelRule(string Pattern, string Label, int Priority);

// ── Glob matching ─────────────────────────────────────────────────────────────

/// <summary>
/// Converts glob patterns to regex and matches file paths.
///
/// Supported syntax:
///   **  matches any characters including path separators
///   *   matches any characters except path separators
///   ?   matches a single character except path separators
///
/// If the pattern contains no '/' it is treated as a filename pattern that
/// matches at any directory depth (like .gitignore rules).
/// </summary>
static class GlobMatcher
{
    public static bool IsMatch(string path, string pattern)
    {
        path = path.Replace('\\', '/');

        // Pattern without / → match basename at any depth
        if (!pattern.Contains('/'))
            pattern = "**/" + pattern;

        return Regex.IsMatch(path, GlobToRegex(pattern), RegexOptions.IgnoreCase);
    }

    private static string GlobToRegex(string glob)
    {
        var sb = new StringBuilder("^");
        int i = 0;

        while (i < glob.Length)
        {
            char c = glob[i];

            if (c == '*')
            {
                if (i + 1 < glob.Length && glob[i + 1] == '*')
                {
                    sb.Append(".*");
                    i += 2;
                    if (i < glob.Length && glob[i] == '/')
                    {
                        sb.Append("/?");
                        i++;
                    }
                }
                else
                {
                    sb.Append("[^/]*");
                    i++;
                }
            }
            else if (c == '?')
            {
                sb.Append("[^/]");
                i++;
            }
            else if (c == '[')
            {
                int end = glob.IndexOf(']', i + 1);
                if (end == -1) { sb.Append(Regex.Escape(c.ToString())); i++; }
                else           { sb.Append(glob[i..(end + 1)]); i = end + 1; }
            }
            else
            {
                sb.Append(Regex.Escape(c.ToString()));
                i++;
            }
        }

        sb.Append('$');
        return sb.ToString();
    }
}

// ── Label assigner ────────────────────────────────────────────────────────────

/// <summary>
/// Assigns labels to a PR based on its changed file paths and a set of rules.
/// Rules are evaluated in priority order; all matching rules contribute labels.
/// </summary>
class LabelAssigner
{
    private readonly IReadOnlyList<LabelRule> _rules;

    public LabelAssigner(IEnumerable<LabelRule> rules)
    {
        _rules = rules
            .OrderBy(r => r.Priority)
            .ThenBy(r => r.Pattern)
            .ToList()
            .AsReadOnly();
    }

    public IReadOnlySet<string> AssignLabels(IEnumerable<string> filePaths)
    {
        var labels = new SortedSet<string>(StringComparer.Ordinal);

        foreach (var filePath in filePaths)
        {
            foreach (var rule in _rules)
            {
                if (GlobMatcher.IsMatch(filePath, rule.Pattern))
                    labels.Add(rule.Label);
            }
        }

        return labels;
    }
}

// ── Main program ──────────────────────────────────────────────────────────────

try
{
    // Configurable label rules (in a real tool these would come from a YAML config file)
    var rules = new List<LabelRule>
    {
        new("docs/**",             "documentation", Priority: 1),
        new("src/api/**",          "api",           Priority: 2),
        new("*.test.*",            "tests",         Priority: 3),
        new("**/*.spec.*",         "tests",         Priority: 3),
        new("src/**",              "source",        Priority: 4),
        new("*.md",                "markdown",      Priority: 5),
        new(".github/**",          "ci/cd",         Priority: 6),
        new("Dockerfile*",         "docker",        Priority: 7),
        new("docker-compose*",     "docker",        Priority: 7),
        new("**/*.cs",             "csharp",        Priority: 8),
        new("**/*.ts",             "typescript",    Priority: 8),
        new("**/*.py",             "python",        Priority: 8),
    };

    // Mock PR changed files (in a real tool these come from GitHub API or git diff)
    var changedFiles = new List<string>
    {
        "docs/getting-started.md",
        "docs/api/reference.md",
        "src/api/v2/UserController.cs",
        "src/api/v2/UserController.test.cs",
        "src/models/User.cs",
        "src/utils/validator.ts",
        "README.md",
        ".github/workflows/ci.yml",
    };

    Console.WriteLine("PR Label Assigner");
    Console.WriteLine("=================");
    Console.WriteLine();
    Console.WriteLine("Changed files:");
    foreach (var file in changedFiles)
        Console.WriteLine($"  {file}");

    Console.WriteLine();
    Console.WriteLine("Label rules (in priority order):");
    foreach (var rule in rules.OrderBy(r => r.Priority))
        Console.WriteLine($"  [{rule.Priority}] {rule.Pattern,-30} → {rule.Label}");

    var assigner = new LabelAssigner(rules);
    var labels = assigner.AssignLabels(changedFiles);

    Console.WriteLine();
    Console.WriteLine($"Assigned labels ({labels.Count}):");
    foreach (var label in labels)
        Console.WriteLine($"  ✓ {label}");

    // Output as JSON-like structure for scripting integration
    Console.WriteLine();
    Console.WriteLine("JSON output:");
    Console.WriteLine($"{{\"labels\": [{string.Join(", ", labels.Select(l => $"\"{l}\""))}]}}");
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Error: {ex.Message}");
    Environment.Exit(1);
}
