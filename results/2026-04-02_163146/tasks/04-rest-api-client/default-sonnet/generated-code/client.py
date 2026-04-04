"""
REST API client for JSONPlaceholder — Cycles 2-5 (green phase).

Design:
  - fetch_with_retry: low-level HTTP function with exponential-backoff retry.
  - JSONPlaceholderClient: high-level client that handles pagination, caching,
    and composition of posts + comments.

Only stdlib is required (urllib, json, time, os).
"""

import json
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Any

from cache import Cache

BASE_URL = "https://jsonplaceholder.typicode.com"


# ---------------------------------------------------------------------------
# Custom exceptions
# ---------------------------------------------------------------------------

class RetryExhaustedError(Exception):
    """Raised when all retry attempts for an HTTP request have failed."""


# ---------------------------------------------------------------------------
# Cycle 2: Low-level HTTP fetch with exponential-backoff retry
# ---------------------------------------------------------------------------

def fetch_with_retry(
    url: str,
    *,
    max_retries: int = 3,
    backoff_base: float = 1.0,
) -> Any:
    """Fetch *url* and return parsed JSON.

    Retry strategy:
      - urllib.error.URLError (network issues) → always retry.
      - urllib.error.HTTPError with status >= 500 → transient; retry.
      - urllib.error.HTTPError with status 4xx → client error; raise immediately.

    Sleep between attempts: backoff_base * 2 ** attempt  (1 s, 2 s, 4 s …).

    Args:
        url: Fully-qualified URL to fetch.
        max_retries: Total number of attempts before giving up.
        backoff_base: Multiplier for the backoff sleep (seconds).

    Returns:
        Parsed JSON value (dict or list).

    Raises:
        RetryExhaustedError: When all attempts have been exhausted.
        urllib.error.HTTPError: On 4xx responses (not retried).
    """
    last_error: Exception | None = None

    for attempt in range(max_retries):
        try:
            with urllib.request.urlopen(url) as response:
                body = response.read()
                return json.loads(body)

        except urllib.error.HTTPError as exc:
            if exc.code < 500:
                # 4xx — client error; not a transient problem, don't retry
                raise
            # 5xx — transient server error; fall through to retry
            last_error = exc

        except urllib.error.URLError as exc:
            # Network-level failure (DNS, connection refused, timeout …)
            last_error = exc

        # Don't sleep after the final attempt
        if attempt < max_retries - 1:
            sleep_seconds = backoff_base * (2 ** attempt)
            time.sleep(sleep_seconds)

    raise RetryExhaustedError(
        f"All {max_retries} attempts failed for {url}. Last error: {last_error}"
    )


# ---------------------------------------------------------------------------
# Cycle 3–5: High-level client with pagination and caching
# ---------------------------------------------------------------------------

class JSONPlaceholderClient:
    """Client for the JSONPlaceholder REST API.

    Caches every network response to disk so repeated calls are free.
    Supports paginated collection fetches and composite post+comments retrieval.
    """

    def __init__(
        self,
        base_url: str = BASE_URL,
        cache: Cache | None = None,
        cache_dir: str = ".cache",
        max_retries: int = 3,
        backoff_base: float = 1.0,
    ) -> None:
        self._base = base_url.rstrip("/")
        self._cache = cache if cache is not None else Cache(cache_dir)
        self._max_retries = max_retries
        self._backoff_base = backoff_base

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _fetch(self, url: str) -> Any:
        """Thin wrapper that passes retry settings through."""
        return fetch_with_retry(
            url,
            max_retries=self._max_retries,
            backoff_base=self._backoff_base,
        )

    def _cached_fetch(self, cache_key: str, url: str) -> Any:
        """Return cached value if available; otherwise fetch and cache."""
        cached = self._cache.get(cache_key)
        if cached is not None:
            return cached
        data = self._fetch(url)
        self._cache.set(cache_key, data)
        return data

    # ------------------------------------------------------------------
    # Cycle 3: Pagination — get_all_posts
    # ------------------------------------------------------------------

    def get_all_posts(self, page_size: int = 10) -> list[dict]:
        """Fetch all posts, page by page, until an empty page is returned.

        Uses ``_start`` / ``_limit`` query parameters (JSONPlaceholder style).
        Each page is cached individually so re-runs skip the network entirely.

        Args:
            page_size: Number of posts per page.

        Returns:
            Flat list of all posts across all pages.
        """
        all_posts: list[dict] = []
        start = 0

        while True:
            params = urllib.parse.urlencode({"_start": start, "_limit": page_size})
            url = f"{self._base}/posts?{params}"
            cache_key = f"posts_start{start}_limit{page_size}"

            page = self._cached_fetch(cache_key, url)

            if not page:
                # Empty page → no more data
                break

            all_posts.extend(page)
            start += page_size

            # Optimisation: if the page was smaller than page_size, we're done
            if len(page) < page_size:
                break

        return all_posts

    # ------------------------------------------------------------------
    # Cycle 4: Single resource fetches
    # ------------------------------------------------------------------

    def get_post(self, post_id: int) -> dict:
        """Fetch a single post by ID (cached)."""
        cache_key = f"post_{post_id}"
        url = f"{self._base}/posts/{post_id}"
        return self._cached_fetch(cache_key, url)

    def get_comments_for_post(self, post_id: int) -> list[dict]:
        """Fetch all comments for a post by ID (cached)."""
        cache_key = f"comments_post_{post_id}"
        url = f"{self._base}/posts/{post_id}/comments"
        return self._cached_fetch(cache_key, url)

    def get_post_with_comments(self, post_id: int) -> dict:
        """Return ``{"post": <post>, "comments": [<comment>, …]}`` for *post_id*."""
        post = self.get_post(post_id)
        comments = self.get_comments_for_post(post_id)
        return {"post": post, "comments": comments}

    # ------------------------------------------------------------------
    # Cycle 4+5: Composite fetch — all posts with their comments
    # ------------------------------------------------------------------

    def get_posts_with_comments(self, page_size: int = 10) -> list[dict]:
        """Fetch every post and its comments; return as a combined list.

        Each element is ``{"post": <post dict>, "comments": [<comment>, …]}``.
        Results are cached so repeated calls are cheap.

        Args:
            page_size: Posts per page when paginating.

        Returns:
            List of post+comments dicts.
        """
        posts = self.get_all_posts(page_size=page_size)
        results = []
        for post in posts:
            post_id = post["id"]
            comments = self.get_comments_for_post(post_id)
            results.append({"post": post, "comments": comments})
        return results
