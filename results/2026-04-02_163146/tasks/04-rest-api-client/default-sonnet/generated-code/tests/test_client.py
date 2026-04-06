"""
TDD Cycles 2-4: REST API client tests.

Written BEFORE the implementation (red phase).  Covers:
  - Cycle 2: HTTP fetch + retry with exponential backoff
  - Cycle 3: Pagination (fetching all pages)
  - Cycle 4: Composite fetch (posts + their comments)
  - Cycle 5: Cache integration (hit vs miss)

All HTTP calls are mocked — no network access is performed.
"""

import json
import os
import sys
import tempfile
import time
import unittest
from unittest.mock import MagicMock, call, patch

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from client import (  # noqa: E402
    JSONPlaceholderClient,
    RetryExhaustedError,
    fetch_with_retry,
)


# ---------------------------------------------------------------------------
# Shared fixtures
# ---------------------------------------------------------------------------

SAMPLE_POSTS = [
    {"userId": 1, "id": i, "title": f"Post {i}", "body": "body"}
    for i in range(1, 6)
]

SAMPLE_COMMENTS = [
    {"postId": 1, "id": i, "name": f"Cmt {i}", "email": "a@b.c", "body": "x"}
    for i in range(1, 4)
]


def _make_response(data, status=200):
    """Helper: create a mock urllib response object.

    The context-manager protocol (with ... as response:) requires __enter__
    to return the object that binds to 'response'.  MagicMock's default
    __enter__.return_value is a fresh MagicMock (not self), so we explicitly
    point it back at the mock that has .read() configured.
    """
    resp = MagicMock()
    resp.status = status
    resp.read.return_value = json.dumps(data).encode()
    resp.__enter__.return_value = resp   # 'with urlopen(...) as r:' → r == resp
    resp.__exit__.return_value = False
    return resp


# ---------------------------------------------------------------------------
# Cycle 2a: fetch_with_retry — happy path
# ---------------------------------------------------------------------------

class TestFetchWithRetrySuccess(unittest.TestCase):
    """A successful HTTP call returns parsed JSON without retrying."""

    @patch("client.urllib.request.urlopen")
    def test_returns_parsed_json_on_200(self, mock_open):
        mock_open.return_value = _make_response(SAMPLE_POSTS)
        result = fetch_with_retry("https://example.com/posts")
        self.assertEqual(result, SAMPLE_POSTS)

    @patch("client.urllib.request.urlopen")
    def test_makes_exactly_one_request_on_success(self, mock_open):
        mock_open.return_value = _make_response([])
        fetch_with_retry("https://example.com/posts")
        self.assertEqual(mock_open.call_count, 1)


# ---------------------------------------------------------------------------
# Cycle 2b: fetch_with_retry — retry on transient failures
# ---------------------------------------------------------------------------

class TestFetchWithRetryBackoff(unittest.TestCase):
    """Transient errors are retried with exponential backoff."""

    @patch("client.time.sleep")          # prevent actual sleeping in tests
    @patch("client.urllib.request.urlopen")
    def test_retries_on_url_error(self, mock_open, mock_sleep):
        import urllib.error
        # Fail twice, succeed on third attempt
        mock_open.side_effect = [
            urllib.error.URLError("timeout"),
            urllib.error.URLError("timeout"),
            _make_response({"ok": True}),
        ]
        result = fetch_with_retry("https://example.com/posts", max_retries=3)
        self.assertEqual(result, {"ok": True})
        self.assertEqual(mock_open.call_count, 3)

    @patch("client.time.sleep")
    @patch("client.urllib.request.urlopen")
    def test_sleep_durations_double_each_retry(self, mock_open, mock_sleep):
        """Backoff: 1 s, 2 s, 4 s … (base ** attempt)."""
        import urllib.error
        mock_open.side_effect = [
            urllib.error.URLError("err"),
            urllib.error.URLError("err"),
            _make_response([]),
        ]
        fetch_with_retry("https://example.com/posts", max_retries=3, backoff_base=1)
        # sleep called for attempts 0 and 1 (not for the final success)
        sleep_args = [c.args[0] for c in mock_sleep.call_args_list]
        self.assertEqual(sleep_args, [1, 2])   # 1**1, 1**2 … base=1 → 1*2^n pattern
        # More precisely: sleep(base * 2**attempt) for attempt in [0,1]
        # With backoff_base=1: sleep(1), sleep(2)

    @patch("client.time.sleep")
    @patch("client.urllib.request.urlopen")
    def test_raises_retry_exhausted_after_max_retries(self, mock_open, mock_sleep):
        import urllib.error
        mock_open.side_effect = urllib.error.URLError("always fails")
        with self.assertRaises(RetryExhaustedError) as ctx:
            fetch_with_retry("https://example.com/posts", max_retries=3)
        # Error message should mention the URL
        self.assertIn("example.com", str(ctx.exception))

    @patch("client.time.sleep")
    @patch("client.urllib.request.urlopen")
    def test_http_error_503_is_retried(self, mock_open, mock_sleep):
        """5xx responses (treated as transient) trigger retries."""
        import urllib.error
        http_err = urllib.error.HTTPError(
            url="https://example.com", code=503,
            msg="Service Unavailable", hdrs=None, fp=None
        )
        mock_open.side_effect = [http_err, _make_response([{"id": 1}])]
        result = fetch_with_retry("https://example.com/posts", max_retries=2)
        self.assertEqual(result, [{"id": 1}])

    @patch("client.time.sleep")
    @patch("client.urllib.request.urlopen")
    def test_http_error_404_is_not_retried(self, mock_open, mock_sleep):
        """4xx client errors should NOT be retried — raise immediately."""
        import urllib.error
        http_err = urllib.error.HTTPError(
            url="https://example.com/posts/999", code=404,
            msg="Not Found", hdrs=None, fp=None
        )
        mock_open.side_effect = http_err
        with self.assertRaises(urllib.error.HTTPError):
            fetch_with_retry("https://example.com/posts/999", max_retries=5)
        self.assertEqual(mock_open.call_count, 1)  # tried only once


# ---------------------------------------------------------------------------
# Cycle 3: Pagination
# ---------------------------------------------------------------------------

class TestPagination(unittest.TestCase):
    """Client collects all pages when the API paginates results."""

    def _make_client(self, tmpdir):
        from cache import Cache
        return JSONPlaceholderClient(cache=Cache(tmpdir))

    @patch("client.fetch_with_retry")
    def test_fetches_single_page_when_result_is_small(self, mock_fetch):
        # Fewer items than page_size → only one request
        mock_fetch.return_value = SAMPLE_POSTS[:3]
        with tempfile.TemporaryDirectory() as d:
            client = self._make_client(d)
            posts = client.get_all_posts(page_size=10)
        self.assertEqual(posts, SAMPLE_POSTS[:3])
        self.assertEqual(mock_fetch.call_count, 1)

    @patch("client.fetch_with_retry")
    def test_fetches_multiple_pages_until_empty(self, mock_fetch):
        """Pagination stops when an empty page is returned."""
        page1 = SAMPLE_POSTS[:2]
        page2 = SAMPLE_POSTS[2:4]
        page3 = []   # sentinel: no more data
        mock_fetch.side_effect = [page1, page2, page3]
        with tempfile.TemporaryDirectory() as d:
            client = self._make_client(d)
            posts = client.get_all_posts(page_size=2)
        self.assertEqual(posts, SAMPLE_POSTS[:4])
        self.assertEqual(mock_fetch.call_count, 3)

    @patch("client.fetch_with_retry")
    def test_pagination_uses_start_and_limit_params(self, mock_fetch):
        """URL query string must include _start and _limit."""
        mock_fetch.side_effect = [SAMPLE_POSTS[:2], []]
        with tempfile.TemporaryDirectory() as d:
            client = self._make_client(d)
            client.get_all_posts(page_size=2)
        first_url = mock_fetch.call_args_list[0].args[0]
        self.assertIn("_start=0", first_url)
        self.assertIn("_limit=2", first_url)


# ---------------------------------------------------------------------------
# Cycle 4: Fetch posts with comments
# ---------------------------------------------------------------------------

class TestFetchPostsWithComments(unittest.TestCase):
    """Client can fetch posts and attach their comments."""

    def _make_client(self, tmpdir):
        from cache import Cache
        return JSONPlaceholderClient(cache=Cache(tmpdir))

    @patch("client.fetch_with_retry")
    def test_get_post_with_comments_returns_combined_dict(self, mock_fetch):
        post = SAMPLE_POSTS[0]
        mock_fetch.side_effect = [post, SAMPLE_COMMENTS]
        with tempfile.TemporaryDirectory() as d:
            client = self._make_client(d)
            result = client.get_post_with_comments(post_id=1)
        self.assertEqual(result["post"], post)
        self.assertEqual(result["comments"], SAMPLE_COMMENTS)

    @patch("client.fetch_with_retry")
    def test_get_posts_with_comments_combines_all(self, mock_fetch):
        """get_posts_with_comments returns a list of {post, comments} dicts."""
        posts = SAMPLE_POSTS[:2]
        cmts_p1 = SAMPLE_COMMENTS[:2]
        cmts_p2 = SAMPLE_COMMENTS[2:]

        # Calls (3 total):
        #   1. Paginate posts (_start=0, _limit=10) → 2 posts, which is < page_size=10
        #      so the early-exit optimisation kicks in and no sentinel page is fetched.
        #   2. Comments for post 1 → cmts_p1
        #   3. Comments for post 2 → cmts_p2
        mock_fetch.side_effect = [posts, cmts_p1, cmts_p2]

        with tempfile.TemporaryDirectory() as d:
            client = self._make_client(d)
            results = client.get_posts_with_comments(page_size=10)

        self.assertEqual(len(results), 2)
        self.assertEqual(results[0]["post"]["id"], posts[0]["id"])
        self.assertEqual(results[0]["comments"], cmts_p1)
        self.assertEqual(results[1]["post"]["id"], posts[1]["id"])
        self.assertEqual(results[1]["comments"], cmts_p2)


# ---------------------------------------------------------------------------
# Cycle 5: Cache integration
# ---------------------------------------------------------------------------

class TestCacheIntegration(unittest.TestCase):
    """Client caches results so a second call skips the network."""

    def _make_client(self, tmpdir):
        from cache import Cache
        return JSONPlaceholderClient(cache=Cache(tmpdir))

    @patch("client.fetch_with_retry")
    def test_cached_post_not_fetched_twice(self, mock_fetch):
        post = SAMPLE_POSTS[0]
        mock_fetch.return_value = post
        with tempfile.TemporaryDirectory() as d:
            client = self._make_client(d)
            r1 = client.get_post(post_id=1)
            r2 = client.get_post(post_id=1)   # second call — should hit cache
        self.assertEqual(r1, post)
        self.assertEqual(r2, post)
        # fetch_with_retry called only once despite two get_post() calls
        self.assertEqual(mock_fetch.call_count, 1)

    @patch("client.fetch_with_retry")
    def test_cached_comments_not_fetched_twice(self, mock_fetch):
        mock_fetch.return_value = SAMPLE_COMMENTS
        with tempfile.TemporaryDirectory() as d:
            client = self._make_client(d)
            client.get_comments_for_post(post_id=1)
            client.get_comments_for_post(post_id=1)
        self.assertEqual(mock_fetch.call_count, 1)

    @patch("client.fetch_with_retry")
    def test_different_post_ids_are_cached_separately(self, mock_fetch):
        mock_fetch.side_effect = [SAMPLE_POSTS[0], SAMPLE_POSTS[1]]
        with tempfile.TemporaryDirectory() as d:
            client = self._make_client(d)
            r1 = client.get_post(post_id=1)
            r2 = client.get_post(post_id=2)
        self.assertNotEqual(r1["id"], r2["id"])
        self.assertEqual(mock_fetch.call_count, 2)


if __name__ == "__main__":
    unittest.main()
