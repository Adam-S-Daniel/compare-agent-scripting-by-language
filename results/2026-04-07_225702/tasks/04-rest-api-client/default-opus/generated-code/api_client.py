"""REST API client for JSONPlaceholder.

Fetches posts and comments with pagination, retry/backoff, and local JSON caching.
"""

import json
import os
import time
import requests

BASE_URL = "https://jsonplaceholder.typicode.com"
MAX_RETRIES = 3
BACKOFF_BASE = 1  # seconds; delays will be 1, 2, 4, ...
DEFAULT_CACHE_DIR = "cache"


class ApiError(Exception):
    """Raised when an API call fails after all retries are exhausted."""
    pass


# -- Cache helpers --

def _read_cache(cache_dir, key):
    """Return cached JSON data for key, or None if not cached."""
    if cache_dir is None:
        return None
    path = os.path.join(cache_dir, f"{key}.json")
    if os.path.isfile(path):
        with open(path, "r") as f:
            return json.load(f)
    return None


def _write_cache(cache_dir, key, data):
    """Write data to a JSON cache file. No-op if cache_dir is None."""
    if cache_dir is None:
        return
    os.makedirs(cache_dir, exist_ok=True)
    path = os.path.join(cache_dir, f"{key}.json")
    with open(path, "w") as f:
        json.dump(data, f, indent=2)


# -- HTTP with retry --

def _request_with_retry(url, params):
    """Make a GET request with exponential backoff on transient failures.

    Retries on connection errors and 5xx server errors. Raises ApiError
    after MAX_RETRIES consecutive failures.
    """
    last_exc = None
    for attempt in range(MAX_RETRIES + 1):  # attempt 0 is the initial try
        try:
            resp = requests.get(url, params=params)
            resp.raise_for_status()
            return resp.json()
        except (requests.exceptions.ConnectionError, requests.exceptions.HTTPError) as exc:
            last_exc = exc
            # Don't retry client errors (4xx) — only server/connection problems
            if isinstance(exc, requests.exceptions.HTTPError):
                if exc.response is not None and exc.response.status_code < 500:
                    raise ApiError(f"Client error {exc.response.status_code}: {exc}") from exc
            if attempt < MAX_RETRIES:
                delay = BACKOFF_BASE * (2 ** attempt)
                time.sleep(delay)

    raise ApiError(f"Failed after {MAX_RETRIES} retries: {last_exc}") from last_exc


# -- Public API --

def fetch_posts(start=0, limit=10, cache_dir=DEFAULT_CACHE_DIR):
    """Fetch posts with pagination. Results are cached locally as JSON."""
    cache_key = f"posts_{start}_{limit}"
    cached = _read_cache(cache_dir, cache_key)
    if cached is not None:
        return cached

    data = _request_with_retry(
        f"{BASE_URL}/posts",
        params={"_start": start, "_limit": limit},
    )
    _write_cache(cache_dir, cache_key, data)
    return data


def fetch_comments(post_id, cache_dir=DEFAULT_CACHE_DIR):
    """Fetch comments for a post. Results are cached locally as JSON."""
    cache_key = f"comments_post_{post_id}"
    cached = _read_cache(cache_dir, cache_key)
    if cached is not None:
        return cached

    data = _request_with_retry(
        f"{BASE_URL}/comments",
        params={"postId": post_id},
    )
    _write_cache(cache_dir, cache_key, data)
    return data


def fetch_all_posts_with_comments(cache_dir=DEFAULT_CACHE_DIR, page_size=10):
    """Fetch all posts (paginated) and their comments. Returns list of dicts.

    Each dict has the post fields plus a 'comments' key with the comment list.
    Stops paginating when a page returns fewer results than page_size.
    """
    all_posts = []
    start = 0
    while True:
        page = fetch_posts(start=start, limit=page_size, cache_dir=cache_dir)
        if not page:
            break
        for post in page:
            comments = fetch_comments(post_id=post["id"], cache_dir=cache_dir)
            post["comments"] = comments
            all_posts.append(post)
        if len(page) < page_size:
            break  # last page
        start += page_size
    return all_posts


if __name__ == "__main__":
    # Quick demo: fetch first 5 posts with their comments
    posts = fetch_all_posts_with_comments(page_size=5)
    for p in posts[:5]:
        print(f"Post {p['id']}: {p['title']} ({len(p['comments'])} comments)")
