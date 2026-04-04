# RestApiClient.Tests.ps1
# Pester 5 tests for RestApiClient module using TDD methodology.
# Each Describe block represents a TDD cycle: test written first, then implementation added.
#
# Run with: Invoke-Pester -Path ./RestApiClient.Tests.ps1 -Output Detailed
# Or use:   ./run-tests.ps1  (installs Pester if missing, then runs tests)

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    # Import the module under test. This will fail (red) until RestApiClient.psm1 exists.
    [string]$modulePath = Join-Path -Path $PSScriptRoot -ChildPath 'RestApiClient.psm1'
    Import-Module -Name $modulePath -Force

    # --- Test Fixtures ---
    # Sample posts matching JSONPlaceholder schema
    $script:FixturePosts = @(
        [PSCustomObject]@{ id = 1; userId = 1; title = 'First Post';  body = 'Content one' }
        [PSCustomObject]@{ id = 2; userId = 1; title = 'Second Post'; body = 'Content two' }
        [PSCustomObject]@{ id = 3; userId = 2; title = 'Third Post';  body = 'Content three' }
    )

    # Sample comments matching JSONPlaceholder schema
    $script:FixtureComments = @(
        [PSCustomObject]@{ id = 1; postId = 1; name = 'Alice'; email = 'alice@example.com'; body = 'Great post!' }
        [PSCustomObject]@{ id = 2; postId = 1; name = 'Bob';   email = 'bob@example.com';   body = 'I agree!'    }
    )

    # Unique temp directory per test run — avoids cross-run contamination
    $script:TestCacheDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) `
        -ChildPath "pester_cache_$([System.Guid]::NewGuid().ToString('N'))"
}

AfterAll {
    if (Test-Path -Path $script:TestCacheDir) {
        Remove-Item -Path $script:TestCacheDir -Recurse -Force
    }
    Remove-Module -Name 'RestApiClient' -Force -ErrorAction SilentlyContinue
}

# =============================================================================
# TDD Cycle 1: Invoke-ApiRequest — core HTTP + retry logic
# =============================================================================
Describe 'Invoke-ApiRequest' {

    Context 'Successful request' {

        It 'Returns data from the injected HTTP invoker' {
            # RED: function doesn't exist yet → GREEN: implement Invoke-ApiRequest
            [PSCustomObject]$expected = [PSCustomObject]@{ id = 1; title = 'Test' }
            [scriptblock]$mockHttp = { param([string]$Uri) return $expected }

            [object]$result = Invoke-ApiRequest -Uri 'https://example.com/test' -HttpInvoker $mockHttp

            $result | Should -Not -BeNullOrEmpty
            $result.id    | Should -Be 1
            $result.title | Should -Be 'Test'
        }

        It 'Passes the URI unchanged to the HTTP invoker' {
            [string]$script:capturedUri = ''
            [scriptblock]$mockHttp = { param([string]$Uri) $script:capturedUri = $Uri; return @() }

            Invoke-ApiRequest -Uri 'https://example.com/api/posts' -HttpInvoker $mockHttp

            $script:capturedUri | Should -Be 'https://example.com/api/posts'
        }
    }

    Context 'Retry on failure' {

        It 'Retries MaxRetries times then throws (1 initial + N retries = N+1 calls)' {
            # RED: no retry logic → GREEN: add while loop with catch + retry
            [int]$script:callCount = 0
            [scriptblock]$mockHttp  = { param([string]$Uri) $script:callCount++; throw 'Simulated failure' }
            [scriptblock]$mockDelay = { param([int]$ms) }   # no-op so tests run fast

            { Invoke-ApiRequest -Uri 'https://example.com/fail' -MaxRetries 2 `
                -HttpInvoker $mockHttp -DelayInvoker $mockDelay } | Should -Throw

            # MaxRetries=2 → 1 initial + 2 retries = 3 total calls
            $script:callCount | Should -Be 3
        }

        It 'Succeeds when a later retry returns data' {
            [int]$script:retryCount = 0
            [PSCustomObject]$expected = [PSCustomObject]@{ id = 42; title = 'Retry Success' }
            [scriptblock]$mockHttp = {
                param([string]$Uri)
                $script:retryCount++
                if ($script:retryCount -lt 3) { throw 'Temporary error' }
                return $expected
            }
            [scriptblock]$mockDelay = { param([int]$ms) }

            [object]$result = Invoke-ApiRequest -Uri 'https://example.com/retry' `
                -MaxRetries 3 -HttpInvoker $mockHttp -DelayInvoker $mockDelay

            $result.id    | Should -Be 42
            $script:retryCount | Should -Be 3
        }

        It 'Applies exponential backoff — delays double each retry' {
            # RED: no backoff → GREEN: multiply delay by 2 after each failure
            [System.Collections.Generic.List[int]]$script:delays = `
                [System.Collections.Generic.List[int]]::new()
            [int]$script:backoffCalls = 0
            [scriptblock]$mockHttp  = { param([string]$Uri) $script:backoffCalls++; throw 'Error' }
            [scriptblock]$mockDelay = { param([int]$ms) $script:delays.Add($ms) }

            { Invoke-ApiRequest -Uri 'https://example.com/backoff' -MaxRetries 3 `
                -InitialDelayMs 100 -HttpInvoker $mockHttp -DelayInvoker $mockDelay } | Should -Throw

            # 3 retries → 3 sleeps; delays must be 100, 200, 400
            $script:delays.Count | Should -Be 3
            $script:delays[0]    | Should -Be 100
            $script:delays[1]    | Should -Be 200
            $script:delays[2]    | Should -Be 400
        }

        It 'Throws a descriptive error message containing retry count info' {
            [scriptblock]$mockHttp  = { param([string]$Uri) throw 'Connection refused' }
            [scriptblock]$mockDelay = { param([int]$ms) }

            { Invoke-ApiRequest -Uri 'https://example.com/err' -MaxRetries 1 `
                -HttpInvoker $mockHttp -DelayInvoker $mockDelay } | Should -Throw -ExpectedMessage '*retries*'
        }
    }
}

# =============================================================================
# TDD Cycle 2: Cache utilities — read/write JSON cache files
# =============================================================================
Describe 'Cache utility functions' {

    Context 'Get-CachePath' {

        It 'Returns a .json file path inside the specified cache directory' {
            [string]$result = Get-CachePath -CacheDir '/tmp/cache' -CacheKey 'my_key'
            $result | Should -Be (Join-Path -Path '/tmp/cache' -ChildPath 'my_key.json')
        }

        It 'Sanitizes special characters in the cache key to underscores' {
            [string]$result = Get-CachePath -CacheDir '/tmp/cache' -CacheKey 'key?page=1&limit=10'
            $result | Should -Be (Join-Path -Path '/tmp/cache' -ChildPath 'key_page_1_limit_10.json')
        }
    }

    Context 'Save-CachedData and Get-CachedData round-trip' {

        BeforeEach {
            if (Test-Path -Path $script:TestCacheDir) {
                Remove-Item -Path $script:TestCacheDir -Recurse -Force
            }
        }

        It 'Saves an object as JSON and retrieves it correctly' {
            # RED: functions don't exist → GREEN: implement save/load JSON
            [string]$cachePath = Join-Path -Path $script:TestCacheDir -ChildPath 'test.json'
            [PSCustomObject]$data = [PSCustomObject]@{ id = 7; name = 'Widget' }

            Save-CachedData -CachePath $cachePath -Data $data
            [object]$loaded = Get-CachedData -CachePath $cachePath

            $loaded       | Should -Not -BeNullOrEmpty
            $loaded.id    | Should -Be 7
            $loaded.name  | Should -Be 'Widget'
        }

        It 'Creates intermediate directories that do not exist' {
            [string]$nested    = Join-Path -Path $script:TestCacheDir -ChildPath 'a/b/c'
            [string]$cachePath = Join-Path -Path $nested -ChildPath 'data.json'

            Save-CachedData -CachePath $cachePath -Data ([PSCustomObject]@{ v = 1 })

            Test-Path -Path $nested    | Should -BeTrue
            Test-Path -Path $cachePath | Should -BeTrue
        }

        It 'Returns $null when no cache file exists' {
            [string]$missing = Join-Path -Path $script:TestCacheDir -ChildPath 'missing.json'

            [object]$result = Get-CachedData -CachePath $missing

            $result | Should -BeNullOrEmpty
        }
    }
}

# =============================================================================
# TDD Cycle 3: Get-Posts — pagination + caching
# =============================================================================
Describe 'Get-Posts' {

    BeforeEach {
        if (Test-Path -Path $script:TestCacheDir) {
            Remove-Item -Path $script:TestCacheDir -Recurse -Force
        }
    }

    It 'Returns posts returned by the HTTP invoker' {
        # RED → GREEN: implement Get-Posts calling Invoke-ApiRequest
        [scriptblock]$mockHttp = { param([string]$Uri) return $script:FixturePosts }

        [object[]]$result = Get-Posts -BaseUrl 'https://api.test' -Page 1 -Limit 3 `
            -CacheDir $script:TestCacheDir -HttpInvoker $mockHttp

        $result          | Should -Not -BeNullOrEmpty
        $result.Count    | Should -Be 3
        $result[0].title | Should -Be 'First Post'
    }

    It 'Constructs the correct paginated URI (_page and _limit query params)' {
        [string]$script:postsUri = ''
        [scriptblock]$mockHttp = { param([string]$Uri) $script:postsUri = $Uri; return @() }

        Get-Posts -BaseUrl 'https://api.test' -Page 2 -Limit 5 `
            -CacheDir $script:TestCacheDir -HttpInvoker $mockHttp

        $script:postsUri | Should -Be 'https://api.test/posts?_page=2&_limit=5'
    }

    It 'Writes a JSON cache file after fetching' {
        # RED → GREEN: call Save-CachedData after Invoke-ApiRequest
        [scriptblock]$mockHttp = { param([string]$Uri) return $script:FixturePosts }

        Get-Posts -BaseUrl 'https://api.test' -Page 1 -Limit 3 `
            -CacheDir $script:TestCacheDir -HttpInvoker $mockHttp

        [string]$expected = Join-Path -Path $script:TestCacheDir -ChildPath 'posts_page1_limit3.json'
        Test-Path -Path $expected | Should -BeTrue
    }

    It 'Returns cached data on subsequent calls without making HTTP requests' {
        # RED → GREEN: check cache before calling HTTP
        [scriptblock]$firstHttp = { param([string]$Uri) return $script:FixturePosts }
        Get-Posts -BaseUrl 'https://api.test' -Page 1 -Limit 3 `
            -CacheDir $script:TestCacheDir -HttpInvoker $firstHttp

        [int]$script:secondCallCount = 0
        [scriptblock]$secondHttp = { param([string]$Uri) $script:secondCallCount++; return @() }

        [object[]]$result = Get-Posts -BaseUrl 'https://api.test' -Page 1 -Limit 3 `
            -CacheDir $script:TestCacheDir -HttpInvoker $secondHttp

        $script:secondCallCount | Should -Be 0
        $result.Count           | Should -Be 3
    }
}

# =============================================================================
# TDD Cycle 4: Get-PostComments — per-post comments + caching
# =============================================================================
Describe 'Get-PostComments' {

    BeforeEach {
        if (Test-Path -Path $script:TestCacheDir) {
            Remove-Item -Path $script:TestCacheDir -Recurse -Force
        }
    }

    It 'Returns comments for the specified post ID' {
        [scriptblock]$mockHttp = { param([string]$Uri) return $script:FixtureComments }

        [object[]]$result = Get-PostComments -PostId 1 -BaseUrl 'https://api.test' `
            -CacheDir $script:TestCacheDir -HttpInvoker $mockHttp

        $result        | Should -Not -BeNullOrEmpty
        $result.Count  | Should -Be 2
        $result[0].name | Should -Be 'Alice'
    }

    It 'Constructs the correct URI with the post ID path segment' {
        [string]$script:commentsUri = ''
        [scriptblock]$mockHttp = { param([string]$Uri) $script:commentsUri = $Uri; return @() }

        Get-PostComments -PostId 42 -BaseUrl 'https://api.test' `
            -CacheDir $script:TestCacheDir -HttpInvoker $mockHttp

        $script:commentsUri | Should -Be 'https://api.test/posts/42/comments'
    }

    It 'Writes a JSON cache file keyed by post ID' {
        [scriptblock]$mockHttp = { param([string]$Uri) return $script:FixtureComments }

        Get-PostComments -PostId 1 -BaseUrl 'https://api.test' `
            -CacheDir $script:TestCacheDir -HttpInvoker $mockHttp

        [string]$expected = Join-Path -Path $script:TestCacheDir -ChildPath 'comments_post1.json'
        Test-Path -Path $expected | Should -BeTrue
    }

    It 'Uses cache on second call and skips HTTP' {
        [scriptblock]$firstHttp = { param([string]$Uri) return $script:FixtureComments }
        Get-PostComments -PostId 1 -BaseUrl 'https://api.test' `
            -CacheDir $script:TestCacheDir -HttpInvoker $firstHttp

        [int]$script:commentSecondCount = 0
        [scriptblock]$secondHttp = { param([string]$Uri) $script:commentSecondCount++; return @() }

        [object[]]$result = Get-PostComments -PostId 1 -BaseUrl 'https://api.test' `
            -CacheDir $script:TestCacheDir -HttpInvoker $secondHttp

        $script:commentSecondCount | Should -Be 0
        $result.Count              | Should -Be 2
    }
}

# =============================================================================
# TDD Cycle 5: Get-PostsWithComments — combine posts + per-post comments
# =============================================================================
Describe 'Get-PostsWithComments' {

    BeforeEach {
        if (Test-Path -Path $script:TestCacheDir) {
            Remove-Item -Path $script:TestCacheDir -Recurse -Force
        }
    }

    It 'Returns posts enriched with a comments property' {
        # Single mock dispatches on URI pattern
        [scriptblock]$mockHttp = {
            param([string]$Uri)
            if ($Uri -match '/posts\?') {
                return @(
                    [PSCustomObject]@{ id = 1; userId = 1; title = 'Post One'; body = 'Body One' }
                    [PSCustomObject]@{ id = 2; userId = 1; title = 'Post Two'; body = 'Body Two' }
                )
            } elseif ($Uri -match '/posts/1/comments') {
                return @(
                    [PSCustomObject]@{ id = 10; postId = 1; name = 'Commenter A'; email = 'a@test.com'; body = 'Nice!' }
                )
            } elseif ($Uri -match '/posts/2/comments') {
                return @(
                    [PSCustomObject]@{ id = 20; postId = 2; name = 'Commenter B'; email = 'b@test.com'; body = 'Great!' }
                )
            }
            throw "Unexpected URI: $Uri"
        }

        [object[]]$result = Get-PostsWithComments -BaseUrl 'https://api.test' -Page 1 -Limit 2 `
            -CacheDir $script:TestCacheDir -HttpInvoker $mockHttp

        $result                        | Should -Not -BeNullOrEmpty
        $result.Count                  | Should -Be 2
        $result[0].title               | Should -Be 'Post One'
        $result[0].comments            | Should -Not -BeNullOrEmpty
        $result[0].comments.Count      | Should -Be 1
        $result[0].comments[0].name    | Should -Be 'Commenter A'
        $result[1].title               | Should -Be 'Post Two'
        $result[1].comments[0].name    | Should -Be 'Commenter B'
    }

    It 'Fetches comments individually for each post' {
        # Track which comment URIs are requested
        [System.Collections.Generic.List[string]]$script:seenCommentUris = `
            [System.Collections.Generic.List[string]]::new()

        [scriptblock]$mockHttp = {
            param([string]$Uri)
            if ($Uri -match '/posts\?') {
                return @(
                    [PSCustomObject]@{ id = 10; userId = 1; title = 'P1'; body = 'B1' }
                    [PSCustomObject]@{ id = 20; userId = 1; title = 'P2'; body = 'B2' }
                )
            } elseif ($Uri -match '/posts/\d+/comments') {
                $script:seenCommentUris.Add($Uri)
                return @()
            }
            throw "Unexpected URI: $Uri"
        }

        Get-PostsWithComments -BaseUrl 'https://api.test' -Page 1 -Limit 2 `
            -CacheDir $script:TestCacheDir -HttpInvoker $mockHttp

        $script:seenCommentUris.Count | Should -Be 2
        $script:seenCommentUris       | Should -Contain 'https://api.test/posts/10/comments'
        $script:seenCommentUris       | Should -Contain 'https://api.test/posts/20/comments'
    }
}
