"""
REST API client for JSONPlaceholder (https://jsonplaceholder.typicode.com).

Features:
  - Fetch posts and their comments with pagination support
  - Retry with exponential backoff on transient failures
  - Local JSON file caching to avoid redundant network calls

Built with TDD — every public function was tested before being implemented.
Uses only Python stdlib (urllib, json, os, time) — no external dependencies.
"""

import json
import os
import time
import urllib.request
import urllib.error

# ── Default configuration ────────────────────────────────────────────────────

BASE_URL = "https://jsonplaceholder.typicode.com"
DEFAULT_MAX_RETRIES = 3
DEFAULT_BASE_DELAY = 1.0  # seconds
DEFAULT_CACHE_DIR = "cache"
DEFAULT_PAGE_SIZE = 10  # JSONPlaceholder default _limit


# ── Retry with exponential backoff ───────────────────────────────────────────
# Wraps any callable, retrying on exception with delays of base * 2^attempt.


def retry_request(fn, max_retries=DEFAULT_MAX_RETRIES, base_delay=DEFAULT_BASE_DELAY):
    """
    Call *fn* up to *max_retries* times.  On each failure, sleep for
    base_delay * 2^attempt seconds before retrying.  If all attempts fail,
    the last exception is re-raised.
    """
    last_exception = None
    for attempt in range(max_retries):
        try:
            return fn()
        except Exception as exc:
            last_exception = exc
            # Don't sleep after the final failed attempt
            if attempt < max_retries - 1:
                delay = base_delay * (2 ** attempt)
                time.sleep(delay)
    raise last_exception


# ── Low-level HTTP helper ────────────────────────────────────────────────────
# Isolated so tests can mock `_http_get_json` without touching the network.


def _http_get_json(url):
    """Fetch *url* and return the parsed JSON body."""
    req = urllib.request.Request(url, headers={"Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        body = resp.read().decode("utf-8")
        return json.loads(body)


# ── Caching layer ────────────────────────────────────────────────────────────
# Stores and retrieves JSON responses keyed by a sanitised cache key.


def _cache_path(cache_dir, key):
    """Return the filesystem path for a given cache key."""
    # Replace characters that are unsafe in filenames
    safe = key.replace("/", "_").replace("?", "_").replace("&", "_").replace("=", "_")
    return os.path.join(cache_dir, f"{safe}.json")


def load_from_cache(cache_dir, key):
    """Return cached data for *key*, or None if not cached."""
    path = _cache_path(cache_dir, key)
    if os.path.isfile(path):
        with open(path, "r") as f:
            return json.load(f)
    return None


def save_to_cache(cache_dir, key, data):
    """Persist *data* to the cache under *key*."""
    os.makedirs(cache_dir, exist_ok=True)
    path = _cache_path(cache_dir, key)
    with open(path, "w") as f:
        json.dump(data, f, indent=2)


# ── Pagination ───────────────────────────────────────────────────────────────
# JSONPlaceholder supports `_start` and `_limit` query parameters.


def fetch_paginated(endpoint, page_size=DEFAULT_PAGE_SIZE, max_retries=DEFAULT_MAX_RETRIES,
                    base_delay=DEFAULT_BASE_DELAY, cache_dir=None):
    """
    Fetch all items from *endpoint* using pagination (_start / _limit).
    Returns the full list of items across all pages.

    If *cache_dir* is given, each page is cached individually and the
    aggregated result is also cached under a combined key.
    """
    all_items = []
    start = 0

    while True:
        page_url = f"{BASE_URL}/{endpoint}?_start={start}&_limit={page_size}"
        cache_key = f"{endpoint}_start{start}_limit{page_size}"

        # Try cache first
        page_data = None
        if cache_dir:
            page_data = load_from_cache(cache_dir, cache_key)

        if page_data is None:
            page_data = retry_request(
                lambda url=page_url: _http_get_json(url),
                max_retries=max_retries,
                base_delay=base_delay,
            )
            if cache_dir:
                save_to_cache(cache_dir, cache_key, page_data)

        if not page_data:
            # Empty page means we've fetched everything
            break

        all_items.extend(page_data)
        start += page_size

        # If we got fewer items than page_size, this was the last page
        if len(page_data) < page_size:
            break

    return all_items


# ── High-level API ───────────────────────────────────────────────────────────


def fetch_posts(page_size=DEFAULT_PAGE_SIZE, max_retries=DEFAULT_MAX_RETRIES,
                base_delay=DEFAULT_BASE_DELAY, cache_dir=None):
    """Fetch all posts from JSONPlaceholder, paginated and optionally cached."""
    return fetch_paginated("posts", page_size=page_size, max_retries=max_retries,
                           base_delay=base_delay, cache_dir=cache_dir)


def fetch_comments_for_post(post_id, max_retries=DEFAULT_MAX_RETRIES,
                            base_delay=DEFAULT_BASE_DELAY, cache_dir=None):
    """Fetch all comments for a single post."""
    url = f"{BASE_URL}/posts/{post_id}/comments"
    cache_key = f"posts_{post_id}_comments"

    if cache_dir:
        cached = load_from_cache(cache_dir, cache_key)
        if cached is not None:
            return cached

    data = retry_request(
        lambda: _http_get_json(url),
        max_retries=max_retries,
        base_delay=base_delay,
    )

    if cache_dir:
        save_to_cache(cache_dir, cache_key, data)

    return data


def fetch_posts_with_comments(page_size=DEFAULT_PAGE_SIZE, max_retries=DEFAULT_MAX_RETRIES,
                              base_delay=DEFAULT_BASE_DELAY, cache_dir=None):
    """
    Fetch all posts and attach their comments under a 'comments' key.
    Returns a list of post dicts, each enriched with its comments.
    """
    posts = fetch_posts(page_size=page_size, max_retries=max_retries,
                        base_delay=base_delay, cache_dir=cache_dir)

    for post in posts:
        post["comments"] = fetch_comments_for_post(
            post["id"], max_retries=max_retries,
            base_delay=base_delay, cache_dir=cache_dir,
        )

    return posts


# ── CLI entry point ──────────────────────────────────────────────────────────


def main():
    """Demonstrate the client: fetch first 5 posts with comments, cache results."""
    cache_dir = DEFAULT_CACHE_DIR
    print(f"Fetching posts (cache dir: {cache_dir})...")

    posts = fetch_posts(page_size=5, cache_dir=cache_dir)
    print(f"Fetched {len(posts)} posts.")

    for post in posts[:3]:  # Show first 3
        comments = fetch_comments_for_post(post["id"], cache_dir=cache_dir)
        print(f"\n  Post {post['id']}: {post['title'][:50]}...")
        print(f"    {len(comments)} comment(s)")
        for c in comments[:2]:
            print(f"      - {c['name'][:40]}...")


if __name__ == "__main__":
    main()
