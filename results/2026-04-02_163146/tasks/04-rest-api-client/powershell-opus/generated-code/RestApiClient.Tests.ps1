# RestApiClient.Tests.ps1
# Pester 5 tests for the JSONPlaceholder REST API client.
#
# TDD approach — each Describe block corresponds to a red/green/refactor cycle:
#   1. Get-Posts           — basic post retrieval
#   2. Get-Comments        — comment retrieval by post
#   3. Retry logic         — exponential backoff on transient errors
#   4. Caching             — local JSON file persistence
#   5. Pagination          — iterate through all pages
#   6. Get-PostsWithComments — composite fetch
#   7. Error handling      — graceful failure after exhausting retries
#
# All HTTP calls are mocked via Pester's Mock so tests run offline.

BeforeAll {
    Import-Module "$PSScriptRoot/RestApiClient.psm1" -Force
}

# ── Shared test fixtures ──────────────────────────────────────────────────────

$script:FakePosts = @(
    [PSCustomObject]@{ id = 1; userId = 1; title = 'Post One';   body = 'Body one' }
    [PSCustomObject]@{ id = 2; userId = 1; title = 'Post Two';   body = 'Body two' }
    [PSCustomObject]@{ id = 3; userId = 2; title = 'Post Three'; body = 'Body three' }
)

$script:FakeComments = @(
    [PSCustomObject]@{ id = 1; postId = 1; name = 'Alice'; email = 'alice@test.com'; body = 'Great post!' }
    [PSCustomObject]@{ id = 2; postId = 1; name = 'Bob';   email = 'bob@test.com';   body = 'Thanks!' }
)

# ── TDD Cycle 1: Get-Posts ────────────────────────────────────────────────────
# RED:   Get-Posts doesn't exist → test fails with CommandNotFoundException
# GREEN: implement Get-Posts calling Invoke-RestMethod → test passes
# REFACTOR: extract URI building into the function body

Describe 'Get-Posts' {
    BeforeEach {
        # Mock the underlying REST call inside the module
        Mock Invoke-RestMethod { return $script:FakePosts } -ModuleName RestApiClient
    }

    It 'returns all posts from the API' {
        $posts = Get-Posts
        $posts.Count | Should -Be 3
        $posts[0].title | Should -Be 'Post One'
    }

    It 'calls the correct base URL' {
        Get-Posts | Out-Null
        Should -Invoke Invoke-RestMethod -ModuleName RestApiClient -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://jsonplaceholder.typicode.com/posts'
        }
    }

    It 'appends pagination query parameters when specified' {
        Get-Posts -Page 2 -Limit 5 | Out-Null
        Should -Invoke Invoke-RestMethod -ModuleName RestApiClient -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://jsonplaceholder.typicode.com/posts?_page=2&_limit=5'
        }
    }
}

# ── TDD Cycle 2: Get-Comments ────────────────────────────────────────────────
# RED:   Get-Comments -PostId 1 doesn't exist
# GREEN: implement Get-Comments; mock returns fake comments

Describe 'Get-Comments' {
    BeforeEach {
        Mock Invoke-RestMethod { return $script:FakeComments } -ModuleName RestApiClient
    }

    It 'returns comments for a specific post' {
        $comments = Get-Comments -PostId 1
        $comments.Count | Should -Be 2
        $comments[0].name | Should -Be 'Alice'
    }

    It 'builds the correct URL for a specific post' {
        Get-Comments -PostId 42 | Out-Null
        Should -Invoke Invoke-RestMethod -ModuleName RestApiClient -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://jsonplaceholder.typicode.com/posts/42/comments'
        }
    }

    It 'fetches all comments when no PostId is given' {
        Get-Comments | Out-Null
        Should -Invoke Invoke-RestMethod -ModuleName RestApiClient -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://jsonplaceholder.typicode.com/comments'
        }
    }
}

# ── TDD Cycle 3: Retry with exponential backoff ──────────────────────────────
# RED:   Invoke-RestMethodWithRetry doesn't retry on failure
# GREEN: implement retry loop; mock throws twice then succeeds
# REFACTOR: make MaxRetries and BaseDelay configurable parameters

Describe 'Invoke-RestMethodWithRetry' {
    It 'succeeds on first attempt without retrying' {
        Mock Invoke-RestMethod { return @{ ok = $true } } -ModuleName RestApiClient
        Mock Start-Sleep {} -ModuleName RestApiClient

        $result = Invoke-RestMethodWithRetry -Uri 'https://example.com/test'
        $result.ok | Should -Be $true
        Should -Invoke Invoke-RestMethod -ModuleName RestApiClient -Times 1 -Exactly
        Should -Invoke Start-Sleep -ModuleName RestApiClient -Times 0 -Exactly
    }

    It 'retries on transient failure and eventually succeeds' {
        # Fail twice, succeed on third attempt
        $script:retryCallCount = 0
        Mock Invoke-RestMethod {
            $script:retryCallCount++
            if ($script:retryCallCount -lt 3) {
                throw 'Simulated network error'
            }
            return @{ ok = $true }
        } -ModuleName RestApiClient

        # Stub out sleep so tests are fast
        Mock Start-Sleep {} -ModuleName RestApiClient

        $result = Invoke-RestMethodWithRetry -Uri 'https://example.com/test' -BaseDelay 0.001
        $result.ok | Should -Be $true
        Should -Invoke Invoke-RestMethod -ModuleName RestApiClient -Times 3 -Exactly
        Should -Invoke Start-Sleep -ModuleName RestApiClient -Times 2 -Exactly
    }

    It 'uses exponential backoff delays' {
        $script:backoffCallCount = 0
        $script:capturedDelays = @()

        Mock Invoke-RestMethod {
            $script:backoffCallCount++
            if ($script:backoffCallCount -lt 3) {
                throw 'Simulated error'
            }
            return @{ ok = $true }
        } -ModuleName RestApiClient

        Mock Start-Sleep {
            $script:capturedDelays += $Milliseconds
        } -ModuleName RestApiClient

        Invoke-RestMethodWithRetry -Uri 'https://example.com/test' -BaseDelay 1.0 | Out-Null

        # Attempt 1 fails → delay = 1.0 * 2^0 = 1000ms
        # Attempt 2 fails → delay = 1.0 * 2^1 = 2000ms
        $script:capturedDelays.Count | Should -Be 2
        $script:capturedDelays[0] | Should -Be 1000
        $script:capturedDelays[1] | Should -Be 2000
    }
}

# ── TDD Cycle 4: Local JSON caching ──────────────────────────────────────────
# RED:   Get-PostsCached doesn't exist
# GREEN: implement write-through cache with JSON files
# REFACTOR: extract cache path computation

Describe 'Get-PostsCached' {
    BeforeAll {
        # Use a temp directory for cache isolation
        $script:OrigCacheDir = (Get-Module RestApiClient).Invoke({ $script:CacheDir })
        $script:TestCacheDir = Join-Path ([System.IO.Path]::GetTempPath()) "pester-cache-$(Get-Random)"
        (Get-Module RestApiClient).Invoke({ param($d) $script:CacheDir = $d }, $script:TestCacheDir)
    }

    AfterAll {
        # Restore original cache dir and clean up
        (Get-Module RestApiClient).Invoke({ param($d) $script:CacheDir = $d }, $script:OrigCacheDir)
        if (Test-Path $script:TestCacheDir) {
            Remove-Item $script:TestCacheDir -Recurse -Force
        }
    }

    BeforeEach {
        # Clean cache before each test
        if (Test-Path $script:TestCacheDir) {
            Remove-Item $script:TestCacheDir -Recurse -Force
        }
        Mock Invoke-RestMethod { return $script:FakePosts } -ModuleName RestApiClient
    }

    It 'fetches from API on first call and caches the result' {
        $posts = Get-PostsCached
        $posts.Count | Should -Be 3

        # Verify a cache file was written
        $cacheFile = Join-Path $script:TestCacheDir 'posts_page0_limit0.json'
        Test-Path $cacheFile | Should -Be $true
    }

    It 'returns cached data on second call without hitting the API' {
        # First call — populates cache
        Get-PostsCached | Out-Null
        # Second call — should come from cache
        $posts = Get-PostsCached
        $posts.Count | Should -Be 3

        # Invoke-RestMethod must be called exactly once (only the first fetch)
        Should -Invoke Invoke-RestMethod -ModuleName RestApiClient -Times 1 -Exactly
    }

    It 'bypasses cache when ForceRefresh is used' {
        Get-PostsCached | Out-Null
        Get-PostsCached -ForceRefresh | Out-Null

        # Both calls should hit the API
        Should -Invoke Invoke-RestMethod -ModuleName RestApiClient -Times 2 -Exactly
    }
}

Describe 'Get-CommentsCached' {
    BeforeAll {
        $script:OrigCacheDir2 = (Get-Module RestApiClient).Invoke({ $script:CacheDir })
        $script:TestCacheDir2 = Join-Path ([System.IO.Path]::GetTempPath()) "pester-cache2-$(Get-Random)"
        (Get-Module RestApiClient).Invoke({ param($d) $script:CacheDir = $d }, $script:TestCacheDir2)
    }

    AfterAll {
        (Get-Module RestApiClient).Invoke({ param($d) $script:CacheDir = $d }, $script:OrigCacheDir2)
        if (Test-Path $script:TestCacheDir2) {
            Remove-Item $script:TestCacheDir2 -Recurse -Force
        }
    }

    BeforeEach {
        if (Test-Path $script:TestCacheDir2) {
            Remove-Item $script:TestCacheDir2 -Recurse -Force
        }
        Mock Invoke-RestMethod { return $script:FakeComments } -ModuleName RestApiClient
    }

    It 'caches comments and serves from cache on repeat calls' {
        Get-CommentsCached -PostId 1 | Out-Null
        $comments = Get-CommentsCached -PostId 1
        $comments.Count | Should -Be 2

        Should -Invoke Invoke-RestMethod -ModuleName RestApiClient -Times 1 -Exactly
    }
}

Describe 'Clear-ApiCache' {
    BeforeAll {
        $script:OrigCacheDir3 = (Get-Module RestApiClient).Invoke({ $script:CacheDir })
        $script:TestCacheDir3 = Join-Path ([System.IO.Path]::GetTempPath()) "pester-cache3-$(Get-Random)"
        (Get-Module RestApiClient).Invoke({ param($d) $script:CacheDir = $d }, $script:TestCacheDir3)
    }

    AfterAll {
        (Get-Module RestApiClient).Invoke({ param($d) $script:CacheDir = $d }, $script:OrigCacheDir3)
        if (Test-Path $script:TestCacheDir3) {
            Remove-Item $script:TestCacheDir3 -Recurse -Force
        }
    }

    It 'removes the cache directory' {
        Mock Invoke-RestMethod { return $script:FakePosts } -ModuleName RestApiClient

        Get-PostsCached | Out-Null
        Test-Path $script:TestCacheDir3 | Should -Be $true

        Clear-ApiCache
        Test-Path $script:TestCacheDir3 | Should -Be $false
    }
}

# ── TDD Cycle 5: Pagination ──────────────────────────────────────────────────
# RED:   Get-AllPosts doesn't exist
# GREEN: implement page loop; mock returns data for pages 1-3, empty for page 4

Describe 'Get-AllPosts' {
    BeforeEach {
        # Simulate 3 pages of data, then an empty page to signal end of pagination.
        # Parse _page from the URI with a simple regex (avoids System.Web dependency).
        Mock Invoke-RestMethod {
            $page = 0
            if ($Uri -match '_page=(\d+)') {
                $page = [int]$Matches[1]
            }

            switch ($page) {
                1 { return @(
                        [PSCustomObject]@{ id = 1; title = 'P1' }
                        [PSCustomObject]@{ id = 2; title = 'P2' }
                    )
                }
                2 { return @(
                        [PSCustomObject]@{ id = 3; title = 'P3' }
                        [PSCustomObject]@{ id = 4; title = 'P4' }
                    )
                }
                3 { return @(
                        [PSCustomObject]@{ id = 5; title = 'P5' }
                    )
                }
                default { return @() }
            }
        } -ModuleName RestApiClient
    }

    It 'fetches all pages until an empty response is returned' {
        $all = Get-AllPosts -PageSize 2
        $all.Count | Should -Be 5
        $all[-1].title | Should -Be 'P5'
    }

    It 'makes the right number of API calls (pages + 1 empty sentinel)' {
        Get-AllPosts -PageSize 2 | Out-Null
        # Pages 1, 2, 3 (data), 4 (empty → stop) = 4 calls
        Should -Invoke Invoke-RestMethod -ModuleName RestApiClient -Times 4 -Exactly
    }
}

# ── TDD Cycle 6: Get-PostsWithComments ────────────────────────────────────────
# RED:   Get-PostsWithComments doesn't exist
# GREEN: fetch posts, then fetch comments for each and attach them

Describe 'Get-PostsWithComments' {
    BeforeEach {
        Mock Invoke-RestMethod {
            if ($Uri -match '/comments') {
                return $script:FakeComments
            }
            return $script:FakePosts
        } -ModuleName RestApiClient
    }

    It 'returns posts with a comments property attached' {
        $posts = Get-PostsWithComments
        $posts.Count | Should -Be 3
        $posts[0].comments | Should -Not -BeNullOrEmpty
        $posts[0].comments[0].name | Should -Be 'Alice'
    }

    It 'makes one posts call plus one comments call per post' {
        Get-PostsWithComments | Out-Null
        # 1 call for posts + 3 calls for comments (one per post)
        Should -Invoke Invoke-RestMethod -ModuleName RestApiClient -Times 4 -Exactly
    }
}

# ── TDD Cycle 7: Error handling ───────────────────────────────────────────────
# RED:   all retries fail → should throw a meaningful error
# GREEN: Invoke-RestMethodWithRetry throws after MaxRetries

Describe 'Error handling' {
    It 'throws a meaningful error after all retries are exhausted' {
        Mock Invoke-RestMethod { throw 'Server error 500' } -ModuleName RestApiClient
        Mock Start-Sleep {} -ModuleName RestApiClient

        {
            Invoke-RestMethodWithRetry -Uri 'https://example.com/fail' -MaxRetries 2 -BaseDelay 0.001
        } | Should -Throw "*failed after 2 retries*"
    }

    It 'includes the original error message in the thrown exception' {
        Mock Invoke-RestMethod { throw 'Connection refused' } -ModuleName RestApiClient
        Mock Start-Sleep {} -ModuleName RestApiClient

        {
            Invoke-RestMethodWithRetry -Uri 'https://example.com/fail' -MaxRetries 1 -BaseDelay 0.001
        } | Should -Throw "*Connection refused*"
    }

    It 'Get-Posts surfaces the retry error to the caller' {
        Mock Invoke-RestMethod { throw 'Timeout' } -ModuleName RestApiClient
        Mock Start-Sleep {} -ModuleName RestApiClient

        { Get-Posts } | Should -Throw "*failed after*retries*"
    }
}
