"""
Manual test runner - executes all assertions from test_label_assigner.py
without requiring pytest, for environments where pytest is sandboxed.
"""
import sys
sys.path.insert(0, '/home/passp/repos/compare-agent-scripting-by-language/workspaces/2026-04-02_163146/12-pr-label-assigner/default-sonnet')

from label_assigner import assign_labels, LabelRule, LabelConfig

passed = 0
failed = 0

def check(name, condition):
    global passed, failed
    if condition:
        print(f"  PASS: {name}")
        passed += 1
    else:
        print(f"  FAIL: {name}")
        failed += 1

print("=== TestGlobMatching ===")
r = LabelRule(pattern="docs/**", label="documentation")
check("docs_glob_matches_docs_file", r.matches("docs/README.md"))
check("docs_glob_does_not_match_src", not r.matches("src/main.py"))

r2 = LabelRule(pattern="*.test.*", label="tests")
check("wildcard_ext_matches_test_file", r2.matches("foo.test.js"))

r3 = LabelRule(pattern="**/*.test.*", label="tests")
check("wildcard_ext_matches_nested_test", r3.matches("src/components/Button.test.tsx"))

r4 = LabelRule(pattern="src/api/**", label="api")
check("api_glob_matches_api_file", r4.matches("src/api/users.py"))
check("api_glob_no_match_other_src", not r4.matches("src/utils/helpers.py"))

print("\n=== TestSingleFileLabeling ===")
cfg = LabelConfig(rules=[LabelRule(pattern="docs/**", label="documentation", priority=1)])
check("docs_file_gets_documentation_label", "documentation" in assign_labels(["docs/guide.md"], cfg))

cfg2 = LabelConfig(rules=[LabelRule(pattern="src/api/**", label="api", priority=1)])
check("src_api_file_gets_api_label", "api" in assign_labels(["src/api/routes.py"], cfg2))

check("non_matching_file_gets_no_labels", assign_labels(["src/main.py"], cfg) == [])

print("\n=== TestMultipleFilesLabeling ===")
cfg3 = LabelConfig(rules=[
    LabelRule(pattern="docs/**", label="documentation", priority=1),
    LabelRule(pattern="src/api/**", label="api", priority=2),
])
labels = assign_labels(["docs/README.md", "src/api/users.py"], cfg3)
check("multiple_files_collect_all_labels", "documentation" in labels and "api" in labels)

cfg4 = LabelConfig(rules=[LabelRule(pattern="docs/**", label="documentation", priority=1)])
labels4 = assign_labels(["docs/README.md", "docs/guide.md"], cfg4)
check("duplicate_labels_are_deduplicated", labels4.count("documentation") == 1)

cfg5 = LabelConfig(rules=[
    LabelRule(pattern="docs/**", label="documentation", priority=1),
    LabelRule(pattern="**/*.test.*", label="tests", priority=2),
])
labels5 = assign_labels(["docs/component.test.md"], cfg5)
check("multiple_labels_per_file", "documentation" in labels5 and "tests" in labels5)

print("\n=== TestPriorityOrdering ===")
cfg6 = LabelConfig(rules=[
    LabelRule(pattern="src/**", label="source", priority=1),
    LabelRule(pattern="src/api/**", label="api", priority=2),
], exclusive=True)
labels6 = assign_labels(["src/api/routes.py"], cfg6)
check("higher_priority_wins_exclusive", "api" in labels6 and "source" not in labels6)

cfg7 = LabelConfig(rules=[
    LabelRule(pattern="src/**", label="source", priority=1),
    LabelRule(pattern="src/api/**", label="api", priority=2),
], exclusive=False)
labels7 = assign_labels(["src/api/routes.py"], cfg7)
check("non_exclusive_applies_all_rules", "api" in labels7 and "source" in labels7)

cfg8 = LabelConfig(rules=[
    LabelRule(pattern="src/**", label="source", priority=1),
    LabelRule(pattern="src/api/**", label="api", priority=10),
    LabelRule(pattern="**/*.test.*", label="tests", priority=5),
])
labels8 = assign_labels(["src/api/foo.test.py"], cfg8)
check("labels_ordered_by_priority",
      labels8.index("api") < labels8.index("tests") < labels8.index("source"))

print("\n=== TestMockedPRScenarios ===")
cfg9 = LabelConfig(rules=[
    LabelRule(pattern="src/components/**", label="frontend", priority=3),
    LabelRule(pattern="**/*.test.*", label="tests", priority=2),
    LabelRule(pattern="docs/**", label="documentation", priority=1),
])
labels9 = assign_labels(["src/components/Button.tsx", "src/components/Button.test.tsx"], cfg9)
check("frontend_pr",
      "frontend" in labels9 and "tests" in labels9 and "documentation" not in labels9)

cfg10 = LabelConfig(rules=[
    LabelRule(pattern="src/api/**", label="api", priority=3),
    LabelRule(pattern="**/*.test.*", label="tests", priority=2),
    LabelRule(pattern="docs/**", label="documentation", priority=1),
])
labels10 = assign_labels(
    ["src/api/users.py", "src/api/auth.py", "src/api/test_users.py", "docs/api-reference.md"],
    cfg10,
)
check("backend_api_pr", "api" in labels10 and "documentation" in labels10)

check("empty_file_list_returns_empty", assign_labels([], cfg10) == [])
check("no_rules_returns_empty", assign_labels(["src/main.py"], LabelConfig(rules=[])) == [])

print("\n=== TestErrorHandling ===")
try:
    LabelRule(pattern="[invalid", label="bad")
    check("invalid_glob_pattern_raises_value_error", False)
except ValueError as e:
    check("invalid_glob_pattern_raises_value_error", "Invalid glob pattern" in str(e))

try:
    LabelRule(pattern="docs/**", label="")
    check("empty_label_raises_value_error", False)
except ValueError as e:
    check("empty_label_raises_value_error", "Label cannot be empty" in str(e))

try:
    LabelRule(pattern="", label="docs")
    check("empty_pattern_raises_value_error", False)
except ValueError as e:
    check("empty_pattern_raises_value_error", "Pattern cannot be empty" in str(e))

print(f"\n{'='*40}")
print(f"Results: {passed} passed, {failed} failed")
sys.exit(0 if failed == 0 else 1)
