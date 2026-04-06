"""
TDD Cycle 1: Cache module tests.

Red phase: these tests are written BEFORE the implementation exists,
so they will fail on first run.
"""

import json
import os
import sys
import tempfile
import unittest

# Allow importing from parent directory
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from cache import Cache  # noqa: E402 — intentional: path manipulation above


class TestCacheInit(unittest.TestCase):
    """Cache can be created with a directory path."""

    def test_cache_creates_directory_if_missing(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            cache_dir = os.path.join(tmpdir, "cache")
            self.assertFalse(os.path.exists(cache_dir))
            Cache(cache_dir)
            self.assertTrue(os.path.exists(cache_dir))

    def test_cache_accepts_existing_directory(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            # Should not raise
            cache = Cache(tmpdir)
            self.assertIsNotNone(cache)


class TestCacheGetMiss(unittest.TestCase):
    """Cache returns None for keys that have never been stored."""

    def test_get_returns_none_for_missing_key(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            cache = Cache(tmpdir)
            result = cache.get("nonexistent_key")
            self.assertIsNone(result)


class TestCacheSetAndGet(unittest.TestCase):
    """Cache stores and retrieves arbitrary JSON-serialisable data."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.cache = Cache(self.tmpdir)

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmpdir)

    def test_set_then_get_returns_same_dict(self):
        data = {"id": 1, "title": "Hello"}
        self.cache.set("posts_1", data)
        result = self.cache.get("posts_1")
        self.assertEqual(result, data)

    def test_set_then_get_returns_same_list(self):
        data = [{"id": 1}, {"id": 2}]
        self.cache.set("comments_list", data)
        result = self.cache.get("comments_list")
        self.assertEqual(result, data)

    def test_set_overwrites_existing_entry(self):
        self.cache.set("key", {"version": 1})
        self.cache.set("key", {"version": 2})
        self.assertEqual(self.cache.get("key"), {"version": 2})

    def test_cache_persists_to_disk_as_json_file(self):
        self.cache.set("posts_page_1", [{"id": 1}])
        # The cache file should exist on disk
        cache_file = os.path.join(self.tmpdir, "posts_page_1.json")
        self.assertTrue(os.path.exists(cache_file))

    def test_cache_file_contains_valid_json(self):
        payload = {"id": 42, "title": "Test post"}
        self.cache.set("post_42", payload)
        cache_file = os.path.join(self.tmpdir, "post_42.json")
        with open(cache_file) as f:
            on_disk = json.load(f)
        self.assertEqual(on_disk, payload)

    def test_new_cache_instance_reads_files_written_by_previous_instance(self):
        """Persistence: a second Cache object pointing at the same dir sees data."""
        self.cache.set("shared_key", {"hello": "world"})
        cache2 = Cache(self.tmpdir)
        self.assertEqual(cache2.get("shared_key"), {"hello": "world"})


class TestCacheClear(unittest.TestCase):
    """Cache can delete a specific entry."""

    def test_delete_removes_entry(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            cache = Cache(tmpdir)
            cache.set("k", {"v": 1})
            cache.delete("k")
            self.assertIsNone(cache.get("k"))

    def test_delete_missing_key_does_not_raise(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            cache = Cache(tmpdir)
            # Must not raise
            cache.delete("never_set")


if __name__ == "__main__":
    unittest.main()
