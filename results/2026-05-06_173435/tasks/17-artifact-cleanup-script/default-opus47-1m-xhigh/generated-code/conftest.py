# Makes the workspace root importable so `tests/` can `import cleanup`.
# Without this, pytest is invoked from the larger repo root and can't find
# our flat-layout module. This file's presence also pins the pytest rootdir.
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
