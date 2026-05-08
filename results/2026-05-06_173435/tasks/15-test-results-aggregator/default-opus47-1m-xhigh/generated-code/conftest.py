# Place the workspace root on sys.path so `from aggregator import ...` works
# when pytest is invoked from anywhere (the parent repo's pyproject.toml
# would otherwise own the rootdir).
import sys
from pathlib import Path

WORKSPACE = Path(__file__).resolve().parent
if str(WORKSPACE) not in sys.path:
    sys.path.insert(0, str(WORKSPACE))
