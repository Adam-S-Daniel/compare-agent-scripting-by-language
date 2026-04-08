# REST API Client for JSONPlaceholder
# ====================================
# TDD implementation: each feature was driven by a failing test.
#
# Architecture:
#   - APIClient class encapsulates all HTTP, caching, and retry logic.
#   - requests.get is the sole HTTP call site — easy to mock in tests.
#   - time.sleep is the sole sleep call site — easy to mock in tests.
#   - Cache files live in a configurable directory (default: "cache/").

import json
import os
import time

import requests

BASE_URL = "https://jsonplaceholder.typicode.com"


class APIClient:
    """Client for the JSONPlaceholder REST API.

    Provides:
    - Fetching posts and comments with optional pagination.
    - Retry with exponential backoff on transient failures.
    - Local JSON file caching to avoid redundant network calls.
    """

    def __init__(self, base_url: str = BASE_URL, cache_dir: str = "cache", max_retries: int = 3):
        self.base_url = base_url.rstrip("/")
        self.cache_dir = cache_dir
        self.max_retries = max_retries
        os.makedirs(self.cache_dir, exist_ok=True)

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def fetch_posts(self, page: int = 1, per_page: int = 100, force_refresh: bool = False):
        """Fetch a single page of posts.

        Args:
            page: 1-based page number.
            per_page: Number of posts per page.
            force_refresh: Bypass cache and fetch fresh data.

        Returns:
            List of post dicts.
        """
        cache_key = f"posts_page{page}_per{per_page}.json"
        return self._fetch(
            url=f"{self.base_url}/posts",
            params={"_start": (page - 1) * per_page, "_limit": per_page},
            cache_key=cache_key,
            force_refresh=force_refresh,
        )

    def fetch_comments(self, post_id: int, force_refresh: bool = False):
        """Fetch all comments for a specific post.

        Args:
            post_id: The ID of the post whose comments to fetch.
            force_refresh: Bypass cache and fetch fresh data.

        Returns:
            List of comment dicts.
        """
        cache_key = f"comments_post_{post_id}.json"
        return self._fetch(
            url=f"{self.base_url}/posts/{post_id}/comments",
            params={},
            cache_key=cache_key,
            force_refresh=force_refresh,
        )

    def fetch_all_posts(self, per_page: int = 100, force_refresh: bool = False):
        """Fetch every post by iterating pages until an empty page is returned.

        Args:
            per_page: Posts per page for each request.
            force_refresh: Bypass cache on every page request.

        Returns:
            Aggregated list of all post dicts across all pages.
        """
        all_posts = []
        page = 1
        while True:
            # Use a plain page-keyed cache so repeated calls stay cheap.
            cache_key = f"posts_page{page}_per{per_page}.json"
            page_data = self._fetch(
                url=f"{self.base_url}/posts",
                params={"_start": (page - 1) * per_page, "_limit": per_page},
                cache_key=cache_key,
                force_refresh=force_refresh,
            )
            if not page_data:
                break  # empty page signals end of data
            all_posts.extend(page_data)
            page += 1
        return all_posts

    def fetch_posts_with_comments(self, force_refresh: bool = False):
        """Fetch posts and attach their comments under a 'comments' key.

        Args:
            force_refresh: Bypass cache for all requests.

        Returns:
            List of post dicts, each containing a 'comments' list.
        """
        posts = self.fetch_posts(force_refresh=force_refresh)
        for post in posts:
            post["comments"] = self.fetch_comments(
                post_id=post["id"], force_refresh=force_refresh
            )
        return posts

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    def _fetch(self, url: str, params: dict, cache_key: str, force_refresh: bool = False):
        """Core fetch with caching and retry logic.

        Checks the cache first (unless force_refresh), then makes an HTTP
        GET request with exponential backoff retry on failure.

        Args:
            url: Full URL to request.
            params: Query parameters dict.
            cache_key: Filename to use inside cache_dir.
            force_refresh: Skip cache read; always hit the network.

        Returns:
            Parsed JSON data (list or dict).

        Raises:
            requests.HTTPError: If all retries are exhausted.
        """
        cache_path = os.path.join(self.cache_dir, cache_key)

        # --- Cache read ---
        if not force_refresh and os.path.exists(cache_path):
            with open(cache_path) as f:
                return json.load(f)

        # --- Network fetch with retry + backoff ---
        data = self._get_with_retry(url, params)

        # --- Cache write ---
        with open(cache_path, "w") as f:
            json.dump(data, f, indent=2)

        return data

    def _get_with_retry(self, url: str, params: dict):
        """Perform an HTTP GET with exponential backoff retry.

        Retry strategy:
          - On requests.HTTPError (4xx/5xx), wait and retry.
          - Sleep duration doubles each attempt: 1s, 2s, 4s, 8s, ...
          - After max_retries retries the last exception propagates.

        Args:
            url: URL to GET.
            params: Query parameters.

        Returns:
            Parsed JSON response body.

        Raises:
            requests.HTTPError: After all retries are exhausted.
        """
        delay = 1  # initial backoff in seconds
        last_exc = None

        for attempt in range(self.max_retries + 1):
            try:
                response = requests.get(url, params=params)
                response.raise_for_status()  # raises HTTPError on 4xx/5xx
                return response.json()
            except requests.HTTPError as exc:
                last_exc = exc
                if attempt < self.max_retries:
                    # Exponential backoff before next retry
                    time.sleep(delay)
                    delay *= 2

        # All retries exhausted — surface the last error with context.
        raise last_exc
