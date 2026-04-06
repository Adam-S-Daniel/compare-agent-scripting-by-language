"""
Cache module — Cycle 1 (green phase).

Stores arbitrary JSON-serialisable values as individual .json files in a
chosen directory.  A new Cache pointed at the same directory will find
files written by a previous instance (persistence).
"""

import json
import os


class Cache:
    """Disk-backed JSON cache.

    Each cache key maps to a file named ``<key>.json`` inside *cache_dir*.
    Keys must be valid filename components (no path separators).
    """

    def __init__(self, cache_dir: str) -> None:
        self._dir = cache_dir
        os.makedirs(cache_dir, exist_ok=True)

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _path(self, key: str) -> str:
        return os.path.join(self._dir, f"{key}.json")

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def get(self, key: str):
        """Return the cached value for *key*, or ``None`` if absent."""
        path = self._path(key)
        if not os.path.exists(path):
            return None
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)

    def set(self, key: str, value) -> None:
        """Persist *value* under *key*, overwriting any previous entry."""
        path = self._path(key)
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(value, fh, indent=2)

    def delete(self, key: str) -> None:
        """Remove the entry for *key*.  A no-op if *key* is not cached."""
        path = self._path(key)
        try:
            os.remove(path)
        except FileNotFoundError:
            pass
