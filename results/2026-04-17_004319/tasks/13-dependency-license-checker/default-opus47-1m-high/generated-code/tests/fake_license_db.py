"""Deterministic stand-in for a real license registry.

The real checker would query npm/PyPI/Libraries.io. Tests inject this fake so
they run offline and are reproducible.
"""

from __future__ import annotations

from typing import Dict, Optional


class FakeLicenseDB:
    """Dict-backed license lookup. Missing packages return None."""

    def __init__(self, licenses: Dict[str, str]) -> None:
        self._licenses = dict(licenses)

    def get_license(self, name: str, version: str) -> Optional[str]:
        # Version is ignored in the fake — the real registry would care.
        return self._licenses.get(name)
