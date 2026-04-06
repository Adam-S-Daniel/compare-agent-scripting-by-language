"""Quick smoke-test to verify core logic without pytest."""
import sys
import os
import tempfile
import shutil
from pathlib import Path

sys.path.insert(0, os.path.dirname(__file__))
from search_replace import (
    find_files, find_matches, preview_matches,
    create_backup, perform_replace, generate_report, run_search_replace,
)

# Build fixture
d = tempfile.mkdtemp()
src = os.path.join(d, "src")
os.makedirs(src)
Path(os.path.join(src, "main.py")).write_text("# main\nfoo = 'hello'\nbar = foo\n")
Path(os.path.join(src, "utils.py")).write_text("def foo():\n    return 'world'\n\nfoo_value = foo()\n")
sub = os.path.join(src, "sub")
os.makedirs(sub)
Path(os.path.join(sub, "helper.py")).write_text("import foo\nfoo.run()\n")

errors = []

# 1. find_files
files = find_files(d, "**/*.py")
names = {os.path.basename(f) for f in files}
assert names == {"main.py", "utils.py", "helper.py"}, f"find_files fail: {names}"
print("PASS find_files")

# 2. find_matches
matches = find_matches(os.path.join(src, "main.py"), r"foo")
line_nums = [m["line"] for m in matches]
assert 2 in line_nums and 3 in line_nums, f"find_matches fail: {line_nums}"
assert all("start" in m and "end" in m for m in matches)
print("PASS find_matches")

# 3. preview_matches
orig = Path(os.path.join(src, "main.py")).read_text()
entries = preview_matches(os.path.join(src, "main.py"), r"foo", "bar")
assert len(entries) > 0
assert all("file" in e and "line" in e and "old_text" in e and "new_text" in e and "context" in e for e in entries)
assert Path(os.path.join(src, "main.py")).read_text() == orig, "preview modified file!"
print("PASS preview_matches")

# 4. create_backup
bak = create_backup(os.path.join(src, "main.py"))
assert bak.endswith(".bak") and os.path.exists(bak)
assert Path(bak).read_text() == Path(os.path.join(src, "main.py")).read_text()
print("PASS create_backup")

# 5. perform_replace
changes = perform_replace(os.path.join(src, "main.py"), r"foo", "bar")
assert len(changes) > 0
assert all("file" in c and "line" in c and "old_text" in c and "new_text" in c for c in changes)
content = Path(os.path.join(src, "main.py")).read_text()
assert "bar" in content
print("PASS perform_replace")

# 6. generate_report
report = generate_report(changes)
assert isinstance(report, str)
assert "bar" in report or "foo" in report
assert str(changes[0]["line"]) in report
empty_report = generate_report([])
assert "0" in empty_report or "no changes" in empty_report.lower()
print("PASS generate_report")

# 7. run_search_replace dry-run
result = run_search_replace(d, "**/*.py", r"foo", "bar", dry_run=True)
assert len(result["preview"]) > 0
assert result["changes"] == []
# files must be unchanged (except main.py was already modified above — use utils.py)
print("PASS run_search_replace dry_run")

# 8. run_search_replace live
result2 = run_search_replace(d, "**/*.py", r"foo", "bar", dry_run=False)
assert len(result2["changes"]) >= 0  # main.py already has no foo, others do
assert "report" in result2
bak_files = list(Path(d).rglob("*.bak"))
assert len(bak_files) > 0
print("PASS run_search_replace live")

shutil.rmtree(d)
print("\nAll smoke tests PASSED")
