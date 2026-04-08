# TDD approach: write failing tests first, then implement minimum code to pass.
# Each test group follows the red->green->refactor cycle.

import json
import os
import time
import shutil
import unittest
from unittest.mock import patch, MagicMock, call

# The module we will build — doesn't exist yet (RED phase for all tests).
import api_client


CACHE_DIR = "test_cache"


class TestFetchPosts(unittest.TestCase):
    """Cycle 1: Fetching posts from the API."""

    def setUp(self):
        os.makedirs(CACHE_DIR, exist_ok=True)

    def tearDown(self):
        shutil.rmtree(CACHE_DIR, ignore_errors=True)

    @patch("api_client.requests.get")
    def test_fetch_posts_returns_list(self, mock_get):
        """fetch_posts() should return a list of post dicts."""
        mock_get.return_value = MagicMock(
            status_code=200,
            json=lambda: [{"id": 1, "title": "Post 1"}, {"id": 2, "title": "Post 2"}],
            raise_for_status=lambda: None,
        )
        client = api_client.APIClient(cache_dir=CACHE_DIR)
        posts = client.fetch_posts()
        self.assertIsInstance(posts, list)
        self.assertEqual(len(posts), 2)
        self.assertEqual(posts[0]["id"], 1)

    @patch("api_client.requests.get")
    def test_fetch_posts_calls_correct_url(self, mock_get):
        """fetch_posts() should call the JSONPlaceholder posts endpoint."""
        mock_get.return_value = MagicMock(
            status_code=200,
            json=lambda: [],
            raise_for_status=lambda: None,
        )
        client = api_client.APIClient(cache_dir=CACHE_DIR)
        client.fetch_posts()
        mock_get.assert_called_once()
        url = mock_get.call_args[0][0]
        self.assertIn("jsonplaceholder.typicode.com/posts", url)


class TestFetchComments(unittest.TestCase):
    """Cycle 2: Fetching comments for a specific post."""

    def setUp(self):
        os.makedirs(CACHE_DIR, exist_ok=True)

    def tearDown(self):
        shutil.rmtree(CACHE_DIR, ignore_errors=True)

    @patch("api_client.requests.get")
    def test_fetch_comments_returns_list(self, mock_get):
        """fetch_comments(post_id) should return comments for that post."""
        mock_get.return_value = MagicMock(
            status_code=200,
            json=lambda: [{"id": 10, "postId": 3, "body": "Nice post!"}],
            raise_for_status=lambda: None,
        )
        client = api_client.APIClient(cache_dir=CACHE_DIR)
        comments = client.fetch_comments(post_id=3)
        self.assertIsInstance(comments, list)
        self.assertEqual(comments[0]["postId"], 3)

    @patch("api_client.requests.get")
    def test_fetch_comments_calls_correct_url(self, mock_get):
        """fetch_comments() should hit the /posts/{id}/comments endpoint."""
        mock_get.return_value = MagicMock(
            status_code=200,
            json=lambda: [],
            raise_for_status=lambda: None,
        )
        client = api_client.APIClient(cache_dir=CACHE_DIR)
        client.fetch_comments(post_id=7)
        url = mock_get.call_args[0][0]
        self.assertIn("posts/7/comments", url)


class TestPagination(unittest.TestCase):
    """Cycle 3: Pagination support via _start/_limit query params."""

    def setUp(self):
        os.makedirs(CACHE_DIR, exist_ok=True)

    def tearDown(self):
        shutil.rmtree(CACHE_DIR, ignore_errors=True)

    @patch("api_client.requests.get")
    def test_fetch_posts_page_passes_pagination_params(self, mock_get):
        """fetch_posts(page=2, per_page=5) should pass _start and _limit params."""
        mock_get.return_value = MagicMock(
            status_code=200,
            json=lambda: [],
            raise_for_status=lambda: None,
        )
        client = api_client.APIClient(cache_dir=CACHE_DIR)
        client.fetch_posts(page=2, per_page=5)
        params = mock_get.call_args[1].get("params", {})
        self.assertEqual(params.get("_start"), 5)   # page 2 starts at index 5
        self.assertEqual(params.get("_limit"), 5)

    @patch("api_client.requests.get")
    def test_fetch_all_posts_aggregates_pages(self, mock_get):
        """fetch_all_posts() should keep fetching pages until an empty page is returned."""
        page1 = [{"id": i} for i in range(1, 4)]   # 3 items
        page2 = [{"id": i} for i in range(4, 7)]   # 3 items
        page3 = []                                   # signals end

        mock_get.side_effect = [
            MagicMock(status_code=200, json=lambda p=p: p, raise_for_status=lambda: None)
            for p in [page1, page2, page3]
        ]
        client = api_client.APIClient(cache_dir=CACHE_DIR)
        all_posts = client.fetch_all_posts(per_page=3)
        self.assertEqual(len(all_posts), 6)


class TestRetryWithBackoff(unittest.TestCase):
    """Cycle 4: Retry with exponential backoff on transient failures."""

    def setUp(self):
        os.makedirs(CACHE_DIR, exist_ok=True)

    def tearDown(self):
        shutil.rmtree(CACHE_DIR, ignore_errors=True)

    @patch("api_client.time.sleep")   # prevent actual sleeping in tests
    @patch("api_client.requests.get")
    def test_retries_on_server_error(self, mock_get, mock_sleep):
        """Should retry up to max_retries times on 5xx errors then raise."""
        import requests

        error_response = MagicMock(status_code=500)
        error_response.raise_for_status.side_effect = requests.HTTPError("500 Server Error")

        mock_get.return_value = error_response

        client = api_client.APIClient(cache_dir=CACHE_DIR, max_retries=3)
        with self.assertRaises(requests.HTTPError):
            client.fetch_posts()

        # 1 initial attempt + 3 retries = 4 total calls
        self.assertEqual(mock_get.call_count, 4)

    @patch("api_client.time.sleep")
    @patch("api_client.requests.get")
    def test_backoff_sleep_doubles_each_retry(self, mock_get, mock_sleep):
        """Sleep durations should follow exponential backoff: 1s, 2s, 4s, ..."""
        import requests

        error_response = MagicMock(status_code=500)
        error_response.raise_for_status.side_effect = requests.HTTPError("500")

        mock_get.return_value = error_response

        client = api_client.APIClient(cache_dir=CACHE_DIR, max_retries=3)
        with self.assertRaises(requests.HTTPError):
            client.fetch_posts()

        sleep_calls = [c[0][0] for c in mock_sleep.call_args_list]
        # Backoff: 1, 2, 4 seconds
        self.assertEqual(sleep_calls, [1, 2, 4])

    @patch("api_client.time.sleep")
    @patch("api_client.requests.get")
    def test_succeeds_after_transient_failure(self, mock_get, mock_sleep):
        """Should succeed if a retry eventually returns 200."""
        import requests

        error_response = MagicMock(status_code=500)
        error_response.raise_for_status.side_effect = requests.HTTPError("500")

        ok_response = MagicMock(
            status_code=200,
            json=lambda: [{"id": 1}],
            raise_for_status=lambda: None,
        )

        mock_get.side_effect = [error_response, ok_response]

        client = api_client.APIClient(cache_dir=CACHE_DIR, max_retries=3)
        posts = client.fetch_posts()
        self.assertEqual(len(posts), 1)
        self.assertEqual(mock_get.call_count, 2)


class TestCaching(unittest.TestCase):
    """Cycle 5: Caching responses to local JSON files."""

    def setUp(self):
        os.makedirs(CACHE_DIR, exist_ok=True)

    def tearDown(self):
        shutil.rmtree(CACHE_DIR, ignore_errors=True)

    @patch("api_client.requests.get")
    def test_posts_are_written_to_cache(self, mock_get):
        """After a successful fetch, posts should be saved to a JSON file."""
        mock_get.return_value = MagicMock(
            status_code=200,
            json=lambda: [{"id": 1, "title": "Hello"}],
            raise_for_status=lambda: None,
        )
        client = api_client.APIClient(cache_dir=CACHE_DIR)
        client.fetch_posts()

        # Default call is page=1, per_page=100 — cache key reflects that.
        cache_file = os.path.join(CACHE_DIR, "posts_page1_per100.json")
        self.assertTrue(os.path.exists(cache_file))
        with open(cache_file) as f:
            data = json.load(f)
        self.assertEqual(data[0]["id"], 1)

    @patch("api_client.requests.get")
    def test_comments_are_written_to_cache(self, mock_get):
        """After fetching comments, they should be saved keyed by post id."""
        mock_get.return_value = MagicMock(
            status_code=200,
            json=lambda: [{"id": 5, "postId": 2, "body": "Good"}],
            raise_for_status=lambda: None,
        )
        client = api_client.APIClient(cache_dir=CACHE_DIR)
        client.fetch_comments(post_id=2)

        cache_file = os.path.join(CACHE_DIR, "comments_post_2.json")
        self.assertTrue(os.path.exists(cache_file))

    @patch("api_client.requests.get")
    def test_cache_is_used_on_second_call(self, mock_get):
        """Second call for the same resource should read from cache, not HTTP."""
        mock_get.return_value = MagicMock(
            status_code=200,
            json=lambda: [{"id": 1}],
            raise_for_status=lambda: None,
        )
        client = api_client.APIClient(cache_dir=CACHE_DIR)
        client.fetch_posts()   # first call → HTTP
        client.fetch_posts()   # second call → cache

        # HTTP should only have been called once
        self.assertEqual(mock_get.call_count, 1)

    @patch("api_client.requests.get")
    def test_cache_bypass_forces_fresh_fetch(self, mock_get):
        """Passing force_refresh=True should bypass the cache."""
        mock_get.return_value = MagicMock(
            status_code=200,
            json=lambda: [{"id": 1}],
            raise_for_status=lambda: None,
        )
        client = api_client.APIClient(cache_dir=CACHE_DIR)
        client.fetch_posts()
        client.fetch_posts(force_refresh=True)

        self.assertEqual(mock_get.call_count, 2)


class TestFetchPostsWithComments(unittest.TestCase):
    """Cycle 6: High-level helper that combines posts + comments."""

    def setUp(self):
        os.makedirs(CACHE_DIR, exist_ok=True)

    def tearDown(self):
        shutil.rmtree(CACHE_DIR, ignore_errors=True)

    @patch("api_client.requests.get")
    def test_fetch_posts_with_comments_structure(self, mock_get):
        """fetch_posts_with_comments() should return posts, each with a 'comments' key."""
        posts_data = [{"id": 1, "title": "A"}, {"id": 2, "title": "B"}]
        comments_1 = [{"id": 10, "postId": 1, "body": "x"}]
        comments_2 = [{"id": 11, "postId": 2, "body": "y"}]

        mock_get.side_effect = [
            MagicMock(status_code=200, json=lambda: posts_data, raise_for_status=lambda: None),
            MagicMock(status_code=200, json=lambda: comments_1, raise_for_status=lambda: None),
            MagicMock(status_code=200, json=lambda: comments_2, raise_for_status=lambda: None),
        ]

        client = api_client.APIClient(cache_dir=CACHE_DIR)
        result = client.fetch_posts_with_comments()

        self.assertEqual(len(result), 2)
        self.assertIn("comments", result[0])
        self.assertEqual(result[0]["comments"][0]["body"], "x")
        self.assertEqual(result[1]["comments"][0]["body"], "y")


if __name__ == "__main__":
    unittest.main(verbosity=2)
