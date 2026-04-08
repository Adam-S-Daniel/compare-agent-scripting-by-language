# ApiClient.Tests.ps1
# TDD test suite for the JSONPlaceholder REST API client.
# Run with: Invoke-Pester ./ApiClient.Tests.ps1

BeforeAll {
    . "$PSScriptRoot/ApiClient.ps1"
}

# ---------------------------------------------------------------------------
# CYCLE 1 — Cache layer
# ---------------------------------------------------------------------------
Describe "Cache" {
    BeforeEach {
        # Use a temp directory so tests don't pollute real cache
        $script:TestCacheDir = Join-Path $TestDrive "cache"
    }

    It "saves data to a JSON file under the cache directory" {
        $data = @{ id = 1; title = "test" }
        Save-Cache -Key "posts_1" -Data $data -CacheDir $script:TestCacheDir

        $file = Join-Path $script:TestCacheDir "posts_1.json"
        $file | Should -Exist
    }

    It "returns cached data when the file exists" {
        $data = @{ id = 2; title = "cached" }
        Save-Cache -Key "posts_2" -Data $data -CacheDir $script:TestCacheDir

        $result = Get-Cache -Key "posts_2" -CacheDir $script:TestCacheDir
        $result.id | Should -Be 2
        $result.title | Should -Be "cached"
    }

    It "returns null when no cache entry exists" {
        $result = Get-Cache -Key "missing_key" -CacheDir $script:TestCacheDir
        $result | Should -BeNullOrEmpty
    }
}

# ---------------------------------------------------------------------------
# CYCLE 2 — HTTP helpers (mocked Invoke-RestMethod)
# ---------------------------------------------------------------------------
Describe "Invoke-ApiRequest" {
    It "calls the given URL and returns the response" {
        Mock Invoke-RestMethod { return @(@{ id = 1; title = "Post 1" }) }

        $result = Invoke-ApiRequest -Uri "https://jsonplaceholder.typicode.com/posts"
        $result.Count | Should -Be 1
        $result[0].id | Should -Be 1
    }

    It "retries on failure and succeeds on the second attempt" {
        $script:CallCount = 0
        Mock Invoke-RestMethod {
            $script:CallCount++
            if ($script:CallCount -lt 2) { throw "transient error" }
            return @(@{ id = 99 })
        }

        # MaxRetries=2, BaseDelayMs=0 so tests are fast
        $result = Invoke-ApiRequest -Uri "https://example.com" -MaxRetries 2 -BaseDelayMs 0
        $result[0].id | Should -Be 99
        $script:CallCount | Should -Be 2
    }

    It "throws after exhausting all retries" {
        Mock Invoke-RestMethod { throw "always fails" }

        { Invoke-ApiRequest -Uri "https://example.com" -MaxRetries 2 -BaseDelayMs 0 } |
            Should -Throw
    }
}

# ---------------------------------------------------------------------------
# CYCLE 3 — Fetch posts with caching
# ---------------------------------------------------------------------------
Describe "Get-Posts" {
    BeforeEach {
        $script:TestCacheDir = Join-Path $TestDrive "cache_posts"
    }

    It "returns posts from the API and caches them" {
        Mock Invoke-RestMethod {
            return @(
                @{ id = 1; title = "Post 1"; body = "body 1"; userId = 1 },
                @{ id = 2; title = "Post 2"; body = "body 2"; userId = 1 }
            )
        }

        $posts = Get-Posts -Page 1 -CacheDir $script:TestCacheDir
        $posts.Count | Should -Be 2

        # Cache file should now exist
        $cacheFile = Join-Path $script:TestCacheDir "posts_page_1.json"
        $cacheFile | Should -Exist
    }

    It "returns cached posts without calling the API again" {
        # Seed the cache directly
        $cached = @(@{ id = 5; title = "Cached post" })
        Save-Cache -Key "posts_page_2" -Data $cached -CacheDir $script:TestCacheDir

        Mock Invoke-RestMethod { throw "should not be called" }

        $posts = Get-Posts -Page 2 -CacheDir $script:TestCacheDir
        $posts[0].id | Should -Be 5
    }
}

# ---------------------------------------------------------------------------
# CYCLE 4 — Fetch comments for a post with caching
# ---------------------------------------------------------------------------
Describe "Get-Comments" {
    BeforeEach {
        $script:TestCacheDir = Join-Path $TestDrive "cache_comments"
    }

    It "returns comments for a given post ID" {
        Mock Invoke-RestMethod {
            return @(
                @{ id = 1; postId = 7; name = "Commenter"; body = "Great!" }
            )
        }

        $comments = Get-Comments -PostId 7 -CacheDir $script:TestCacheDir
        $comments[0].postId | Should -Be 7
    }

    It "caches comments so the API is not called again" {
        $cached = @(@{ id = 10; postId = 3; name = "A"; body = "B" })
        Save-Cache -Key "comments_post_3" -Data $cached -CacheDir $script:TestCacheDir

        Mock Invoke-RestMethod { throw "should not be called" }

        $comments = Get-Comments -PostId 3 -CacheDir $script:TestCacheDir
        $comments[0].id | Should -Be 10
    }
}

# ---------------------------------------------------------------------------
# CYCLE 5 — Pagination: fetch multiple pages until empty
# ---------------------------------------------------------------------------
Describe "Get-AllPosts" {
    BeforeEach {
        $script:TestCacheDir = Join-Path $TestDrive "cache_all"
        $script:PageCallCount = 0
    }

    It "aggregates posts across multiple pages and stops when a page is empty" {
        Mock Invoke-RestMethod {
            $script:PageCallCount++
            # Return data for first two pages, empty on third
            switch ($script:PageCallCount) {
                1 { return @(@{ id = 1 }, @{ id = 2 }) }
                2 { return @(@{ id = 3 }) }
                default { return @() }
            }
        }

        $all = Get-AllPosts -CacheDir $script:TestCacheDir -BaseDelayMs 0
        $all.Count | Should -Be 3
    }
}

# ---------------------------------------------------------------------------
# CYCLE 6 — Combined: posts enriched with their comments
# ---------------------------------------------------------------------------
Describe "Get-PostsWithComments" {
    BeforeEach {
        $script:TestCacheDir = Join-Path $TestDrive "cache_enriched"
    }

    It "returns each post with a Comments property containing its comments" {
        Mock Invoke-RestMethod {
            param($Uri)
            # Paginated posts URLs look like /posts?_page=1&_limit=10, not /posts$
        if ($Uri -match "/posts" -and $Uri -notmatch "/comments") {
                # Page 1 returns one post; page 2 is empty
                if ($Uri -match "_page=2") { return @() }
                return @(@{ id = 1; title = "Hello"; body = "World"; userId = 1 })
            }
            if ($Uri -match "/comments") {
                return @(@{ id = 1; postId = 1; name = "N"; body = "C" })
            }
        }

        $enriched = Get-PostsWithComments -CacheDir $script:TestCacheDir -BaseDelayMs 0
        $enriched.Count | Should -Be 1
        $enriched[0].title | Should -Be "Hello"
        $enriched[0].Comments.Count | Should -Be 1
        $enriched[0].Comments[0].postId | Should -Be 1
    }
}
