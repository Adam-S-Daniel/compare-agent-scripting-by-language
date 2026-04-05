#!/usr/bin/env python3
"""
Verify GlobMatcher regex logic by simulating the C# implementation in Python.
This mirrors the C# GlobMatcher.GlobToRegex method exactly.
"""
import re

def glob_to_regex(glob: str) -> str:
    """Mirror of GlobMatcher.GlobToRegex in C#"""
    sb = ["^"]
    i = 0
    while i < len(glob):
        c = glob[i]
        if c == '*':
            if i + 1 < len(glob) and glob[i + 1] == '*':
                sb.append(".*")
                i += 2
                if i < len(glob) and glob[i] == '/':
                    sb.append("/?")
                    i += 1
            else:
                sb.append("[^/]*")
                i += 1
        elif c == '?':
            sb.append("[^/]")
            i += 1
        elif c == '[':
            end = glob.find(']', i + 1)
            if end == -1:
                sb.append(re.escape(c))
                i += 1
            else:
                sb.append(glob[i:end+1])
                i = end + 1
        else:
            sb.append(re.escape(c))
            i += 1
    sb.append('$')
    return ''.join(sb)

def is_match(path: str, pattern: str) -> bool:
    """Mirror of GlobMatcher.IsMatch in C#"""
    path = path.replace('\\', '/')
    if '/' not in pattern:
        pattern = "**/" + pattern
    regex = glob_to_regex(pattern)
    return bool(re.match(regex, path, re.IGNORECASE))

# Run all test cases
tests = [
    # (path, pattern, expected, test_name)
    ("docs/readme.md",                          "docs/**",      True,  "DoubleStarPattern_MatchesFileInSubdirectory"),
    ("docs/guide.md",                           "docs/**",      True,  "DoubleStarPattern_MatchesFileDirectlyInDirectory"),
    ("docs/api/reference.md",                   "docs/**",      True,  "DoubleStarPattern_MatchesNestedSubdirectoryFile"),
    ("src/main.cs",                             "docs/**",      False, "DoubleStarPattern_DoesNotMatchFileOutsideDirectory"),
    ("docs/readme.md",                          "*.md",         True,  "PatternWithoutSlash_MatchesFileAtAnyDepth"),
    ("readme.md",                               "*.md",         True,  "PatternWithoutSlash_MatchesFileAtRootLevel"),
    ("src/utils/helper.cs",                     "src/*.cs",     False, "PatternWithSlash_SingleStar_DoesNotCrossDirectoryBoundary"),
    ("src/main.cs",                             "src/*.cs",     True,  "PatternWithSlash_SingleStar_MatchesAtCorrectLevel"),
    ("src/utils/helper.test.ts",                "*.test.*",     True,  "PatternWithoutSlash_MatchesFilenameAtAnyDepth"),
    ("helper.test.ts",                          "*.test.*",     True,  "PatternWithoutSlash_MatchesFileAtRoot"),
    ("src/utils/helper.cs",                     "*.test.*",     False, "PatternWithoutSlash_DoesNotMatchNonMatchingFile"),
    ("src/api/endpoint.cs",                     "src/api/**",   True,  "ExactPath_MatchesExactFile"),
    ("src/api/v2/controllers/UserController.cs","src/api/**",   True,  "DeepPath_MatchesUnderApiDirectory"),
    ("src/v1/main.cs",                          "src/v?/main.cs", True, "QuestionMark_MatchesSingleCharacter"),
    ("src/v12/main.cs",                         "src/v?/main.cs", False,"QuestionMark_DoesNotMatchZeroOrMultipleChars"),
    # Additional coverage
    ("src/api/controller.cs",                   "**/*.cs",      True,  "DoubleStar_CSharpFiles_MatchAnywhere"),
    ("README.md",                               "*.md",         True,  "ReadmeMd_MatchesMarkdownPattern"),
    ("src/utils/validator.test.ts",             "*.test.*",     True,  "NestedTestFile_MatchesTestPattern"),
    ("src/api/v2/UserController.cs",            "src/**",       True,  "SrcAll_MatchesDeepApiFile"),
    (".github/workflows/ci.yml",                ".github/**",   True,  "GithubActionsFile_MatchesGithubPattern"),
]

passed = 0
failed = 0
for path, pattern, expected, name in tests:
    result = is_match(path, pattern)
    status = "PASS" if result == expected else "FAIL"
    if result != expected:
        regex = glob_to_regex(pattern if '/' in pattern else "**/" + pattern)
        print(f"{status}: {name}")
        print(f"       path='{path}' pattern='{pattern}' regex='{regex}'")
        print(f"       expected={expected} got={result}")
        failed += 1
    else:
        print(f"{status}: {name}")
        passed += 1

print(f"\nResults: {passed} passed, {failed} failed")

# Full mock PR test
print("\n=== Full Mock PR Test ===")
rules = [
    ("docs/**",    "documentation", 1),
    ("src/api/**", "api",           2),
    ("*.test.*",   "tests",         3),
    ("src/**",     "source",        4),
    ("*.md",       "markdown",      5),
]
changed_files = [
    "docs/getting-started.md",
    "src/api/v2/UserController.cs",
    "src/utils/validator.test.ts",
    "src/models/User.cs",
    "README.md",
]
labels = set()
sorted_rules = sorted(rules, key=lambda r: r[2])
for file_path in changed_files:
    for pattern, label, priority in sorted_rules:
        if is_match(file_path, pattern):
            labels.add(label)

print(f"Changed files: {changed_files}")
print(f"Assigned labels: {sorted(labels)}")
expected_labels = {"documentation", "api", "tests", "source", "markdown"}
assert labels == expected_labels, f"Expected {expected_labels}, got {labels}"
print("Mock PR test PASSED!")
