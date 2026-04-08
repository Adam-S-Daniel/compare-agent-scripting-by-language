"""Tests for the JSONPlaceholder REST API client.

TDD approach: each test is written FIRST (red), then code is added to make it pass (green),
then refactored as needed.
"""

import json
import os
import pytest
import requests
from unittest.mock import patch, MagicMock

# Cycle 1 (RED): Fetch posts from the API
class TestFetchPosts:
    """Test that we can fetch posts with pagination support."""

    @patch("api_client.requests.get")
    def test_fetch_posts_returns_list(self, mock_get):
        """Fetching posts should return a list of post dicts."""
        from api_client import fetch_posts

        mock_get.return_value = MagicMock(
            status_code=200,
            json=lambda: [{"id": 1, "title": "foo", "body": "bar", "userId": 1}],
        )
        posts = fetch_posts(cache_dir=None)
        assert isinstance(posts, list)
        assert posts[0]["id"] == 1

    @patch("api_client.requests.get")
    def test_fetch_posts_pagination(self, mock_get):
        """Fetching posts should support _start and _limit query params."""
        from api_client import fetch_posts

        mock_get.return_value = MagicMock(
            status_code=200,
            json=lambda: [{"id": 11, "title": "page2", "body": "b", "userId": 2}],
        )
        posts = fetch_posts(start=10, limit=10, cache_dir=None)
        mock_get.assert_called_once()
        call_args = mock_get.call_args
        assert call_args[1]["params"]["_start"] == 10
        assert call_args[1]["params"]["_limit"] == 10


# Cycle 2 (RED): Fetch comments for a specific post
class TestFetchComments:
    """Test fetching comments associated with a post."""

    @patch("api_client.requests.get")
    def test_fetch_comments_for_post(self, mock_get):
        """Should fetch comments filtered by postId."""
        from api_client import fetch_comments

        mock_get.return_value = MagicMock(
            status_code=200,
            json=lambda: [
                {"id": 1, "postId": 1, "name": "c1", "email": "a@b.com", "body": "hi"}
            ],
        )
        comments = fetch_comments(post_id=1, cache_dir=None)
        assert isinstance(comments, list)
        assert comments[0]["postId"] == 1
        call_args = mock_get.call_args
        assert call_args[1]["params"]["postId"] == 1

    @patch("api_client.requests.get")
    def test_fetch_comments_empty(self, mock_get):
        """Should return empty list when post has no comments."""
        from api_client import fetch_comments

        mock_get.return_value = MagicMock(status_code=200, json=lambda: [])
        comments = fetch_comments(post_id=999, cache_dir=None)
        assert comments == []


# Cycle 3 (RED): Retry with exponential backoff
class TestRetry:
    """Test that HTTP requests are retried on transient failures."""

    @patch("api_client.time.sleep")  # mock sleep so tests run instantly
    @patch("api_client.requests.get")
    def test_retries_on_server_error(self, mock_get, mock_sleep):
        """Should retry on 500 errors and succeed when the server recovers."""
        from api_client import fetch_posts

        # First two calls fail with 500, third succeeds
        fail_resp = MagicMock(status_code=500)
        fail_resp.raise_for_status.side_effect = requests.exceptions.HTTPError(
            response=fail_resp
        )
        ok_resp = MagicMock(
            status_code=200,
            json=lambda: [{"id": 1, "title": "t", "body": "b", "userId": 1}],
        )
        ok_resp.raise_for_status = MagicMock()  # no exception
        mock_get.side_effect = [fail_resp, fail_resp, ok_resp]

        posts = fetch_posts(cache_dir=None)
        assert len(posts) == 1
        assert mock_get.call_count == 3

    @patch("api_client.time.sleep")
    @patch("api_client.requests.get")
    def test_retries_on_connection_error(self, mock_get, mock_sleep):
        """Should retry on connection errors."""
        from api_client import fetch_posts

        ok_resp = MagicMock(
            status_code=200,
            json=lambda: [{"id": 1, "title": "t", "body": "b", "userId": 1}],
        )
        ok_resp.raise_for_status = MagicMock()
        mock_get.side_effect = [
            requests.exceptions.ConnectionError("refused"),
            ok_resp,
        ]
        posts = fetch_posts(cache_dir=None)
        assert len(posts) == 1
        assert mock_get.call_count == 2

    @patch("api_client.time.sleep")
    @patch("api_client.requests.get")
    def test_gives_up_after_max_retries(self, mock_get, mock_sleep):
        """Should raise after exhausting all retries."""
        from api_client import fetch_posts, ApiError

        fail_resp = MagicMock(status_code=500)
        fail_resp.raise_for_status.side_effect = requests.exceptions.HTTPError(
            response=fail_resp
        )
        mock_get.return_value = fail_resp

        with pytest.raises(ApiError, match="Failed after"):
            fetch_posts(cache_dir=None)

    @patch("api_client.time.sleep")
    @patch("api_client.requests.get")
    def test_exponential_backoff_delays(self, mock_get, mock_sleep):
        """Sleep durations should increase exponentially: 1s, 2s, 4s."""
        from api_client import fetch_posts, ApiError

        fail_resp = MagicMock(status_code=500)
        fail_resp.raise_for_status.side_effect = requests.exceptions.HTTPError(
            response=fail_resp
        )
        mock_get.return_value = fail_resp

        with pytest.raises(ApiError):
            fetch_posts(cache_dir=None)

        # Verify exponential backoff: base * 2^attempt => 1, 2, 4
        sleep_calls = [c.args[0] for c in mock_sleep.call_args_list]
        assert sleep_calls == [1, 2, 4]


# Cycle 4 (RED): Local JSON caching
class TestCache:
    """Test that results are cached to local JSON files and served from cache."""

    @pytest.fixture(autouse=True)
    def use_tmp_cache(self, tmp_path):
        """Point cache_dir to a temp directory for each test."""
        self.cache_dir = tmp_path / "cache"
        self.cache_dir.mkdir()

    @patch("api_client.time.sleep")
    @patch("api_client.requests.get")
    def test_posts_cached_to_file(self, mock_get, mock_sleep):
        """Fetching posts should write a JSON cache file."""
        from api_client import fetch_posts

        mock_get.return_value = MagicMock(
            status_code=200,
            json=lambda: [{"id": 1, "title": "cached", "body": "b", "userId": 1}],
        )
        mock_get.return_value.raise_for_status = MagicMock()

        fetch_posts(cache_dir=str(self.cache_dir))
        cache_file = self.cache_dir / "posts_0_10.json"
        assert cache_file.exists()
        data = json.loads(cache_file.read_text())
        assert data[0]["title"] == "cached"

    @patch("api_client.time.sleep")
    @patch("api_client.requests.get")
    def test_posts_served_from_cache(self, mock_get, mock_sleep):
        """Second call should return cached data without hitting the network."""
        from api_client import fetch_posts

        mock_get.return_value = MagicMock(
            status_code=200,
            json=lambda: [{"id": 1, "title": "fresh", "body": "b", "userId": 1}],
        )
        mock_get.return_value.raise_for_status = MagicMock()

        # First call populates cache
        fetch_posts(cache_dir=str(self.cache_dir))
        assert mock_get.call_count == 1

        # Second call should NOT make a network request
        result = fetch_posts(cache_dir=str(self.cache_dir))
        assert mock_get.call_count == 1  # still 1 — served from cache
        assert result[0]["title"] == "fresh"

    @patch("api_client.time.sleep")
    @patch("api_client.requests.get")
    def test_comments_cached_to_file(self, mock_get, mock_sleep):
        """Fetching comments should write a JSON cache file keyed by post_id."""
        from api_client import fetch_comments

        mock_get.return_value = MagicMock(
            status_code=200,
            json=lambda: [{"id": 1, "postId": 5, "body": "comment"}],
        )
        mock_get.return_value.raise_for_status = MagicMock()

        fetch_comments(post_id=5, cache_dir=str(self.cache_dir))
        cache_file = self.cache_dir / "comments_post_5.json"
        assert cache_file.exists()

    @patch("api_client.time.sleep")
    @patch("api_client.requests.get")
    def test_no_cache_when_dir_is_none(self, mock_get, mock_sleep):
        """When cache_dir is None, no caching should occur."""
        from api_client import fetch_posts

        mock_get.return_value = MagicMock(
            status_code=200,
            json=lambda: [{"id": 1, "title": "t", "body": "b", "userId": 1}],
        )
        mock_get.return_value.raise_for_status = MagicMock()

        fetch_posts(cache_dir=None)
        # cache_dir doesn't exist so nothing should be written
        assert not list(self.cache_dir.iterdir())


# Cycle 5 (RED): Fetch all posts with comments (integration of pagination + comments)
class TestFetchAllPostsWithComments:
    """Test the top-level function that paginates through all posts and fetches comments."""

    @patch("api_client.time.sleep")
    @patch("api_client.requests.get")
    def test_fetches_posts_and_attaches_comments(self, mock_get, mock_sleep):
        """Should page through posts and attach comments to each."""
        from api_client import fetch_all_posts_with_comments

        # Page 1: 2 posts (page_size=2), page 2: 1 post (less than page_size => stop)
        page1 = [
            {"id": 1, "title": "p1", "body": "b", "userId": 1},
            {"id": 2, "title": "p2", "body": "b", "userId": 1},
        ]
        page2 = [{"id": 3, "title": "p3", "body": "b", "userId": 1}]
        comments_1 = [{"id": 10, "postId": 1, "body": "c1"}]
        comments_2 = []
        comments_3 = [{"id": 20, "postId": 3, "body": "c3"}]

        # requests.get is called: posts page1, comments 1, comments 2,
        #                          posts page2, comments 3
        def make_resp(data):
            r = MagicMock(status_code=200, json=lambda: data)
            r.raise_for_status = MagicMock()
            return r

        mock_get.side_effect = [
            make_resp(page1), make_resp(comments_1), make_resp(comments_2),
            make_resp(page2), make_resp(comments_3),
        ]

        result = fetch_all_posts_with_comments(cache_dir=None, page_size=2)
        assert len(result) == 3
        assert result[0]["comments"] == comments_1
        assert result[1]["comments"] == comments_2
        assert result[2]["comments"] == comments_3

    @patch("api_client.time.sleep")
    @patch("api_client.requests.get")
    def test_stops_on_empty_page(self, mock_get, mock_sleep):
        """Should stop when a page returns zero results."""
        from api_client import fetch_all_posts_with_comments

        mock_get.return_value = MagicMock(
            status_code=200, json=lambda: []
        )
        mock_get.return_value.raise_for_status = MagicMock()

        result = fetch_all_posts_with_comments(cache_dir=None, page_size=10)
        assert result == []
        assert mock_get.call_count == 1  # only the first posts request

    @patch("api_client.time.sleep")
    @patch("api_client.requests.get")
    def test_error_propagates(self, mock_get, mock_sleep):
        """ApiError during fetch should propagate up."""
        from api_client import fetch_all_posts_with_comments, ApiError

        fail_resp = MagicMock(status_code=500)
        fail_resp.raise_for_status.side_effect = requests.exceptions.HTTPError(
            response=fail_resp
        )
        mock_get.return_value = fail_resp

        with pytest.raises(ApiError):
            fetch_all_posts_with_comments(cache_dir=None)


# Cycle 6 (RED): Client errors (4xx) should fail immediately without retrying
class TestClientErrors:
    """4xx errors are not transient — they should not be retried."""

    @patch("api_client.time.sleep")
    @patch("api_client.requests.get")
    def test_404_raises_immediately(self, mock_get, mock_sleep):
        """A 404 should raise ApiError on the first attempt, no retries."""
        from api_client import fetch_posts, ApiError

        fail_resp = MagicMock(status_code=404)
        fail_resp.raise_for_status.side_effect = requests.exceptions.HTTPError(
            response=fail_resp
        )
        mock_get.return_value = fail_resp

        with pytest.raises(ApiError, match="Client error 404"):
            fetch_posts(cache_dir=None)

        # Should have called the API exactly once — no retries
        assert mock_get.call_count == 1
        mock_sleep.assert_not_called()
