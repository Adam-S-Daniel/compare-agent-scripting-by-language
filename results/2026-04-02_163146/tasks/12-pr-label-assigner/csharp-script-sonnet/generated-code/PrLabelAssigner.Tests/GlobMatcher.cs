// GlobMatcher: converts glob patterns to regex and matches file paths.
//
// Supported syntax:
//   **   - matches any sequence of characters, including path separators (/)
//   *    - matches any sequence of characters EXCEPT path separators
//   ?    - matches any single character EXCEPT path separators
//   [..] - character classes (passed through to regex)
//
// Behavior for patterns without a slash:
//   If the pattern contains no '/' character, it is treated as a filename pattern
//   and matches against the basename at any directory depth (like .gitignore rules).
//   e.g. "*.test.*" matches "src/utils/helper.test.ts"
//
// Behavior for patterns with a slash:
//   The pattern is anchored to the start of the path.
//   e.g. "docs/**" matches "docs/readme.md" but NOT "other/docs/readme.md"

namespace PrLabelAssigner;

using System.Text;
using System.Text.RegularExpressions;

public static class GlobMatcher
{
    public static bool IsMatch(string path, string pattern)
    {
        // Normalize path separators to forward slash
        path = path.Replace('\\', '/');

        // If pattern has no directory component (no /), match against filename at any depth.
        // This mirrors .gitignore behaviour: a pattern without / matches the basename anywhere.
        // Internally, prepend "**/" to make it match at any depth.
        if (!pattern.Contains('/'))
        {
            pattern = "**/" + pattern;
        }

        string regexPattern = GlobToRegex(pattern);
        return Regex.IsMatch(path, regexPattern, RegexOptions.IgnoreCase);
    }

    /// <summary>
    /// Converts a glob pattern to an anchored regular expression string.
    /// </summary>
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
                    // "**" - matches anything including path separators
                    sb.Append(".*");
                    i += 2; // consume both *

                    // If followed by '/', consume the separator too so "**/" doesn't
                    // require a literal slash in the match (allowing zero segments).
                    // e.g. "docs/**" should match "docs/a" AND (conceptually) "docs"
                    // but standard glob treats "docs/**" as at least one level deep.
                    // We keep a strict interpretation: consume the '/' after ** so that
                    // "docs/**" matches "docs/readme.md" and "docs/a/b/c.md".
                    if (i < glob.Length && glob[i] == '/')
                    {
                        sb.Append("/?"); // make the separator optional to also match "docs/readme"
                        i++;
                    }
                }
                else
                {
                    // Single "*" - matches anything except '/'
                    sb.Append("[^/]*");
                    i++;
                }
            }
            else if (c == '?')
            {
                // "?" - matches any single char except '/'
                sb.Append("[^/]");
                i++;
            }
            else if (c == '[')
            {
                // Character class - find the closing ] and pass through
                int end = glob.IndexOf(']', i + 1);
                if (end == -1)
                {
                    // Malformed class - treat as literal
                    sb.Append(Regex.Escape(c.ToString()));
                    i++;
                }
                else
                {
                    sb.Append(glob[i..(end + 1)]);
                    i = end + 1;
                }
            }
            else
            {
                // Literal character - escape for regex
                sb.Append(Regex.Escape(c.ToString()));
                i++;
            }
        }

        sb.Append('$');
        return sb.ToString();
    }
}
