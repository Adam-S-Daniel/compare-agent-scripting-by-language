Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# =============================================================================
# RestApiClient Pester Tests
# Developed with RED/GREEN TDD — each Describe block represents a TDD round.
# All HTTP calls are mocked; no real network requests are made during testing.
# =============================================================================

BeforeAll {
    Import-Module "$PSScriptRoot/RestApiClient.psm1" -Force
}

# =============================================================================
# TEST FIXTURES — sample data matching JSONPlaceholder API schema
# =============================================================================

# Sample posts (mimics GET /posts response)
$script:SamplePosts = @(
    [PSCustomObject]@{ userId = 1; id = 1; title = 'Post One'; body = 'Body one' }
    [PSCustomObject]@{ userId = 1; id = 2; title = 'Post Two'; body = 'Body two' }
    [PSCustomObject]@{ userId = 2; id = 3; title = 'Post Three'; body = 'Body three' }
)

# Sample comments for post 1 (mimics GET /posts/1/comments response)
$script:SampleCommentsPost1 = @(
    [PSCustomObject]@{ postId = 1; id = 1; name = 'Comment 1'; email = 'a@b.com'; body = 'Nice post' }
    [PSCustomObject]@{ postId = 1; id = 2; name = 'Comment 2'; email = 'c@d.com'; body = 'Great work' }
)

# Sample comments for post 2
$script:SampleCommentsPost2 = @(
    [PSCustomObject]@{ postId = 2; id = 3; name = 'Comment 3'; email = 'e@f.com'; body = 'Interesting' }
)

# =============================================================================
# TDD Round 1: Invoke-RestMethodWithRetry — retry with exponential backoff
# RED:  Tests written first expecting retry behavior and error handling
# GREEN: Implemented retry loop in module
# =============================================================================
Describe 'Invoke-RestMethodWithRetry' {

    Context 'When the API call succeeds on the first attempt' {
        BeforeAll {
            # Mock the underlying Invoke-RestMethod to succeed immediately
            Mock -ModuleName RestApiClient Invoke-RestMethod {
                return @([PSCustomObject]@{ id = 1; title = 'Test' })
            }
        }

        It 'Should return the API response' {
            [PSObject[]]$result = Invoke-RestMethodWithRetry -Uri 'https://example.com/test'
            $result.Count | Should -Be 1
            $result[0].id | Should -Be 1
        }

        It 'Should call Invoke-RestMethod exactly once' {
            Invoke-RestMethodWithRetry -Uri 'https://example.com/test' | Out-Null
            Should -Invoke -ModuleName RestApiClient Invoke-RestMethod -Times 1 -Exactly -Scope It
        }
    }

    Context 'When the API call fails then succeeds (transient failure)' {
        BeforeAll {
            [int]$script:retryCallCount = 0
            Mock -ModuleName RestApiClient Invoke-RestMethod {
                $script:retryCallCount++
                if ($script:retryCallCount -le 2) {
                    throw [System.Net.Http.HttpRequestException]::new('Connection refused')
                }
                return @([PSCustomObject]@{ id = 1; title = 'Recovered' })
            }
            # Mock Start-Sleep so tests run fast
            Mock -ModuleName RestApiClient Start-Sleep {}
        }

        BeforeEach {
            $script:retryCallCount = 0
        }

        It 'Should retry and eventually return the response' {
            [PSObject[]]$result = Invoke-RestMethodWithRetry -Uri 'https://example.com/test' -MaxRetries 3 -BaseDelaySeconds 0.001
            $result[0].title | Should -Be 'Recovered'
        }

        It 'Should have called Invoke-RestMethod multiple times' {
            Invoke-RestMethodWithRetry -Uri 'https://example.com/test' -MaxRetries 3 -BaseDelaySeconds 0.001 | Out-Null
            Should -Invoke -ModuleName RestApiClient Invoke-RestMethod -Times 3 -Exactly -Scope It
        }
    }

    Context 'When all retry attempts are exhausted' {
        BeforeAll {
            Mock -ModuleName RestApiClient Invoke-RestMethod {
                throw [System.Net.Http.HttpRequestException]::new('Server error 500')
            }
            Mock -ModuleName RestApiClient Start-Sleep {}
        }

        It 'Should throw an error with a meaningful message after max retries' {
            { Invoke-RestMethodWithRetry -Uri 'https://example.com/fail' -MaxRetries 2 -BaseDelaySeconds 0.001 } |
                Should -Throw '*failed after 2 retries*'
        }

        It 'Should have attempted the call MaxRetries + 1 times (initial + retries)' {
            try {
                Invoke-RestMethodWithRetry -Uri 'https://example.com/fail' -MaxRetries 2 -BaseDelaySeconds 0.001
            }
            catch {
                # expected
            }
            # 1 initial + 2 retries = 3 total calls
            Should -Invoke -ModuleName RestApiClient Invoke-RestMethod -Times 3 -Exactly -Scope It
        }
    }

    Context 'Exponential backoff timing' {
        BeforeAll {
            Mock -ModuleName RestApiClient Invoke-RestMethod {
                throw [System.Net.Http.HttpRequestException]::new('Timeout')
            }
            Mock -ModuleName RestApiClient Start-Sleep {}
        }

        It 'Should call Start-Sleep with exponentially increasing delays' {
            try {
                Invoke-RestMethodWithRetry -Uri 'https://example.com/slow' -MaxRetries 3 -BaseDelaySeconds 1.0
            }
            catch {
                # expected after exhausting retries
            }
            # Attempt 1 fails -> sleep 1s (1 * 2^0), attempt 2 fails -> sleep 2s (1 * 2^1),
            # attempt 3 fails -> sleep 4s (1 * 2^2), attempt 4 (last) fails -> throw
            Should -Invoke -ModuleName RestApiClient Start-Sleep -Times 1 -Scope It -ParameterFilter { $Milliseconds -eq 1000 }
            Should -Invoke -ModuleName RestApiClient Start-Sleep -Times 1 -Scope It -ParameterFilter { $Milliseconds -eq 2000 }
            Should -Invoke -ModuleName RestApiClient Start-Sleep -Times 1 -Scope It -ParameterFilter { $Milliseconds -eq 4000 }
        }
    }
}

# =============================================================================
# TDD Round 2: Write-Cache / Read-Cache — local JSON file caching
# RED:  Tests written first for cache read/write/clear
# GREEN: Implemented file-based caching
# =============================================================================
Describe 'Cache Functions' {
    BeforeAll {
        # Use a temp directory for test caching to avoid polluting the project
        [string]$script:TestCacheDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "pester-cache-$(New-Guid)"
    }

    AfterAll {
        # Clean up temp cache
        if (Test-Path -Path $script:TestCacheDir) {
            Remove-Item -Path $script:TestCacheDir -Recurse -Force
        }
    }

    Context 'Write-Cache' {
        It 'Should create a JSON file in the cache directory' {
            [PSObject[]]$data = @([PSCustomObject]@{ id = 1; name = 'test' })
            Write-Cache -Key 'test-data' -Data $data -CacheDir $script:TestCacheDir

            [string]$expectedPath = Join-Path -Path $script:TestCacheDir -ChildPath 'test-data.json'
            Test-Path -Path $expectedPath | Should -BeTrue
        }

        It 'Should write valid JSON content' {
            [PSObject[]]$data = @([PSCustomObject]@{ id = 42; value = 'hello' })
            Write-Cache -Key 'json-check' -Data $data -CacheDir $script:TestCacheDir

            [string]$filePath = Join-Path -Path $script:TestCacheDir -ChildPath 'json-check.json'
            [string]$content = Get-Content -Path $filePath -Raw -Encoding UTF8
            [PSObject[]]$parsed = $content | ConvertFrom-Json
            $parsed[0].id | Should -Be 42
            $parsed[0].value | Should -Be 'hello'
        }
    }

    Context 'Read-Cache' {
        It 'Should return cached data when the file exists' {
            [PSObject[]]$original = @(
                [PSCustomObject]@{ id = 10; title = 'cached item' }
            )
            Write-Cache -Key 'read-test' -Data $original -CacheDir $script:TestCacheDir
            [PSObject[]]$result = Read-Cache -Key 'read-test' -CacheDir $script:TestCacheDir

            $result | Should -Not -BeNullOrEmpty
            $result[0].id | Should -Be 10
            $result[0].title | Should -Be 'cached item'
        }

        It 'Should return $null when the cache file does not exist' {
            [PSObject[]]$result = Read-Cache -Key 'nonexistent-key' -CacheDir $script:TestCacheDir
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Clear-Cache' {
        It 'Should remove the entire cache directory' {
            # Ensure cache has files
            Write-Cache -Key 'to-delete' -Data @([PSCustomObject]@{ x = 1 }) -CacheDir $script:TestCacheDir
            Test-Path -Path $script:TestCacheDir | Should -BeTrue

            Clear-Cache -CacheDir $script:TestCacheDir
            Test-Path -Path $script:TestCacheDir | Should -BeFalse
        }
    }

    Context 'Round-trip with multiple items' {
        It 'Should preserve array structure through write/read cycle' {
            [PSObject[]]$data = @(
                [PSCustomObject]@{ id = 1; name = 'first' }
                [PSCustomObject]@{ id = 2; name = 'second' }
                [PSCustomObject]@{ id = 3; name = 'third' }
            )
            Write-Cache -Key 'roundtrip' -Data $data -CacheDir $script:TestCacheDir
            [PSObject[]]$result = Read-Cache -Key 'roundtrip' -CacheDir $script:TestCacheDir

            $result.Count | Should -Be 3
            $result[1].name | Should -Be 'second'
        }
    }
}

# =============================================================================
# TDD Round 3: Get-Posts — fetch posts from API
# RED:  Tests written first expecting posts to be fetched via mocked API
# GREEN: Implemented Get-Posts calling Invoke-RestMethodWithRetry
# =============================================================================
Describe 'Get-Posts' {

    Context 'When API returns posts successfully' {
        BeforeAll {
            Mock -ModuleName RestApiClient Invoke-RestMethodWithRetry {
                return $script:SamplePosts
            }
        }

        It 'Should return an array of post objects' {
            [PSObject[]]$result = Get-Posts
            $result.Count | Should -Be 3
        }

        It 'Should return posts with expected properties' {
            [PSObject[]]$result = Get-Posts
            $result[0].id | Should -Be 1
            $result[0].title | Should -Be 'Post One'
            $result[0].userId | Should -Be 1
        }

        It 'Should call the API with the correct URL' {
            Get-Posts | Out-Null
            Should -Invoke -ModuleName RestApiClient Invoke-RestMethodWithRetry -ParameterFilter {
                $Uri -like '*jsonplaceholder.typicode.com/posts'
            }
        }
    }

    Context 'When API returns empty result' {
        BeforeAll {
            Mock -ModuleName RestApiClient Invoke-RestMethodWithRetry {
                return @()
            }
        }

        It 'Should return an empty array' {
            [PSObject[]]$result = Get-Posts
            $result.Count | Should -Be 0
        }
    }

    Context 'With caching enabled' {
        BeforeAll {
            [string]$script:PostsCacheDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "pester-posts-cache-$(New-Guid)"
            [int]$script:postsApiCallCount = 0
            Mock -ModuleName RestApiClient Invoke-RestMethodWithRetry {
                $script:postsApiCallCount++
                return $script:SamplePosts
            }
        }

        AfterAll {
            if (Test-Path -Path $script:PostsCacheDir) {
                Remove-Item -Path $script:PostsCacheDir -Recurse -Force
            }
        }

        BeforeEach {
            $script:postsApiCallCount = 0
            # Clear cache before each test
            if (Test-Path -Path $script:PostsCacheDir) {
                Remove-Item -Path $script:PostsCacheDir -Recurse -Force
            }
        }

        It 'Should cache results after first call' {
            Get-Posts -UseCache -CacheDir $script:PostsCacheDir | Out-Null
            [string]$cacheFile = Join-Path -Path $script:PostsCacheDir -ChildPath 'posts.json'
            Test-Path -Path $cacheFile | Should -BeTrue
        }

        It 'Should return cached data on second call without hitting API again' {
            # First call populates cache
            Get-Posts -UseCache -CacheDir $script:PostsCacheDir | Out-Null
            [int]$callsAfterFirst = $script:postsApiCallCount

            # Second call should use cache
            [PSObject[]]$result = Get-Posts -UseCache -CacheDir $script:PostsCacheDir
            $result.Count | Should -Be 3
            $script:postsApiCallCount | Should -Be $callsAfterFirst
        }
    }
}

# =============================================================================
# TDD Round 4: Get-Comments — fetch comments for a post
# RED:  Tests written first expecting comments to be fetched by post ID
# GREEN: Implemented Get-Comments calling Invoke-RestMethodWithRetry
# =============================================================================
Describe 'Get-Comments' {

    Context 'When fetching comments for a specific post' {
        BeforeAll {
            Mock -ModuleName RestApiClient Invoke-RestMethodWithRetry {
                param([string]$Uri)
                if ($Uri -like '*/posts/1/comments') {
                    return $script:SampleCommentsPost1
                }
                if ($Uri -like '*/posts/2/comments') {
                    return $script:SampleCommentsPost2
                }
                return @()
            }
        }

        It 'Should return comments for post 1' {
            [PSObject[]]$result = Get-Comments -PostId 1
            $result.Count | Should -Be 2
            $result[0].postId | Should -Be 1
            $result[0].name | Should -Be 'Comment 1'
        }

        It 'Should return comments for post 2' {
            [PSObject[]]$result = Get-Comments -PostId 2
            $result.Count | Should -Be 1
            $result[0].body | Should -Be 'Interesting'
        }

        It 'Should call the API with the correct post-specific URL' {
            Get-Comments -PostId 1 | Out-Null
            Should -Invoke -ModuleName RestApiClient Invoke-RestMethodWithRetry -ParameterFilter {
                $Uri -like '*jsonplaceholder.typicode.com/posts/1/comments'
            }
        }
    }

    Context 'When post has no comments' {
        BeforeAll {
            Mock -ModuleName RestApiClient Invoke-RestMethodWithRetry {
                return @()
            }
        }

        It 'Should return an empty array' {
            [PSObject[]]$result = Get-Comments -PostId 999
            $result.Count | Should -Be 0
        }
    }

    Context 'With caching enabled' {
        BeforeAll {
            [string]$script:CommentsCacheDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "pester-comments-cache-$(New-Guid)"
            [int]$script:commentsApiCallCount = 0
            Mock -ModuleName RestApiClient Invoke-RestMethodWithRetry {
                $script:commentsApiCallCount++
                return $script:SampleCommentsPost1
            }
        }

        AfterAll {
            if (Test-Path -Path $script:CommentsCacheDir) {
                Remove-Item -Path $script:CommentsCacheDir -Recurse -Force
            }
        }

        BeforeEach {
            $script:commentsApiCallCount = 0
            if (Test-Path -Path $script:CommentsCacheDir) {
                Remove-Item -Path $script:CommentsCacheDir -Recurse -Force
            }
        }

        It 'Should cache comments per post ID' {
            Get-Comments -PostId 1 -UseCache -CacheDir $script:CommentsCacheDir | Out-Null
            [string]$cacheFile = Join-Path -Path $script:CommentsCacheDir -ChildPath 'comments_post_1.json'
            Test-Path -Path $cacheFile | Should -BeTrue
        }

        It 'Should serve cached comments on subsequent calls' {
            Get-Comments -PostId 1 -UseCache -CacheDir $script:CommentsCacheDir | Out-Null
            [int]$callsAfterFirst = $script:commentsApiCallCount

            [PSObject[]]$result = Get-Comments -PostId 1 -UseCache -CacheDir $script:CommentsCacheDir
            $result.Count | Should -Be 2
            $script:commentsApiCallCount | Should -Be $callsAfterFirst
        }
    }
}

# =============================================================================
# TDD Round 5: Get-PaginatedPosts — pagination with _start/_limit
# RED:  Tests written first expecting multiple pages to be fetched
# GREEN: Implemented pagination loop
# =============================================================================
Describe 'Get-PaginatedPosts' {

    Context 'When fetching posts across multiple pages' {
        BeforeAll {
            # Simulate 3 pages: 2 items each, then empty page signals end
            Mock -ModuleName RestApiClient Invoke-RestMethodWithRetry {
                param([string]$Uri)
                if ($Uri -like '*_start=0*') {
                    return @(
                        [PSCustomObject]@{ id = 1; userId = 1; title = 'P1'; body = 'B1' }
                        [PSCustomObject]@{ id = 2; userId = 1; title = 'P2'; body = 'B2' }
                    )
                }
                elseif ($Uri -like '*_start=2*') {
                    return @(
                        [PSCustomObject]@{ id = 3; userId = 2; title = 'P3'; body = 'B3' }
                        [PSCustomObject]@{ id = 4; userId = 2; title = 'P4'; body = 'B4' }
                    )
                }
                elseif ($Uri -like '*_start=4*') {
                    # Last page: fewer items than page size (1 < 2)
                    return @(
                        [PSCustomObject]@{ id = 5; userId = 3; title = 'P5'; body = 'B5' }
                    )
                }
                else {
                    return @()
                }
            }
        }

        It 'Should aggregate all pages into a single result' {
            [PSObject[]]$result = Get-PaginatedPosts -PageSize 2
            $result.Count | Should -Be 5
        }

        It 'Should preserve the order of posts across pages' {
            [PSObject[]]$result = Get-PaginatedPosts -PageSize 2
            $result[0].id | Should -Be 1
            $result[2].id | Should -Be 3
            $result[4].id | Should -Be 5
        }

        It 'Should use correct _start and _limit query parameters' {
            Get-PaginatedPosts -PageSize 2 | Out-Null
            Should -Invoke -ModuleName RestApiClient Invoke-RestMethodWithRetry -ParameterFilter {
                $Uri -like '*_start=0&_limit=2*'
            }
            Should -Invoke -ModuleName RestApiClient Invoke-RestMethodWithRetry -ParameterFilter {
                $Uri -like '*_start=2&_limit=2*'
            }
        }

        It 'Should stop paginating when a page has fewer items than PageSize' {
            [PSObject[]]$result = Get-PaginatedPosts -PageSize 2
            # Should have called 3 pages: start=0, start=2, start=4 (partial page stops)
            Should -Invoke -ModuleName RestApiClient Invoke-RestMethodWithRetry -Times 3 -Exactly -Scope It
        }
    }

    Context 'When first page is empty' {
        BeforeAll {
            Mock -ModuleName RestApiClient Invoke-RestMethodWithRetry {
                return @()
            }
        }

        It 'Should return an empty array' {
            [PSObject[]]$result = Get-PaginatedPosts -PageSize 10
            $result.Count | Should -Be 0
        }
    }

    Context 'With caching' {
        BeforeAll {
            [string]$script:PagCacheDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "pester-pag-cache-$(New-Guid)"
            Mock -ModuleName RestApiClient Invoke-RestMethodWithRetry {
                param([string]$Uri)
                if ($Uri -like '*_start=0*') {
                    return @(
                        [PSCustomObject]@{ id = 1; userId = 1; title = 'Cached'; body = 'B' }
                    )
                }
                return @()
            }
        }

        AfterAll {
            if (Test-Path -Path $script:PagCacheDir) {
                Remove-Item -Path $script:PagCacheDir -Recurse -Force
            }
        }

        It 'Should cache paginated results' {
            Get-PaginatedPosts -PageSize 5 -UseCache -CacheDir $script:PagCacheDir | Out-Null
            [string]$cacheFile = Join-Path -Path $script:PagCacheDir -ChildPath 'posts_paginated_5.json'
            Test-Path -Path $cacheFile | Should -BeTrue
        }
    }
}

# =============================================================================
# TDD Round 6: Get-PostsWithComments — orchestration
# RED:  Tests written first expecting posts enriched with comments
# GREEN: Implemented orchestrator combining Get-Posts + Get-Comments
# =============================================================================
Describe 'Get-PostsWithComments' {

    Context 'When fetching posts with their comments' {
        BeforeAll {
            # Mock Get-Posts to return 2 sample posts
            Mock -ModuleName RestApiClient Get-Posts {
                return @(
                    [PSCustomObject]@{ userId = 1; id = 1; title = 'Post 1'; body = 'Body 1' }
                    [PSCustomObject]@{ userId = 2; id = 2; title = 'Post 2'; body = 'Body 2' }
                )
            }

            # Mock Get-Comments to return different comments per post
            Mock -ModuleName RestApiClient Get-Comments {
                param([int]$PostId)
                if ($PostId -eq 1) {
                    return @(
                        [PSCustomObject]@{ postId = 1; id = 1; name = 'C1'; email = 'a@b.com'; body = 'Comment for post 1' }
                    )
                }
                if ($PostId -eq 2) {
                    return @(
                        [PSCustomObject]@{ postId = 2; id = 2; name = 'C2'; email = 'c@d.com'; body = 'Comment for post 2' }
                        [PSCustomObject]@{ postId = 2; id = 3; name = 'C3'; email = 'e@f.com'; body = 'Another comment' }
                    )
                }
                return @()
            }
        }

        It 'Should return posts with comments attached' {
            [PSObject[]]$result = Get-PostsWithComments
            $result.Count | Should -Be 2
            $result[0].comments.Count | Should -Be 1
            $result[1].comments.Count | Should -Be 2
        }

        It 'Should preserve post properties in the enriched result' {
            [PSObject[]]$result = Get-PostsWithComments
            $result[0].id | Should -Be 1
            $result[0].title | Should -Be 'Post 1'
            $result[0].userId | Should -Be 1
        }

        It 'Should attach the correct comments to each post' {
            [PSObject[]]$result = Get-PostsWithComments
            $result[0].comments[0].body | Should -Be 'Comment for post 1'
            $result[1].comments[1].body | Should -Be 'Another comment'
        }

        It 'Should call Get-Comments once per post' {
            Get-PostsWithComments | Out-Null
            Should -Invoke -ModuleName RestApiClient Get-Comments -Times 2 -Exactly -Scope It
        }
    }

    Context 'When limiting the number of posts' {
        BeforeAll {
            Mock -ModuleName RestApiClient Get-Posts {
                return @(
                    [PSCustomObject]@{ userId = 1; id = 1; title = 'P1'; body = 'B1' }
                    [PSCustomObject]@{ userId = 1; id = 2; title = 'P2'; body = 'B2' }
                    [PSCustomObject]@{ userId = 1; id = 3; title = 'P3'; body = 'B3' }
                )
            }
            Mock -ModuleName RestApiClient Get-Comments {
                return @([PSCustomObject]@{ postId = 1; id = 1; name = 'C'; email = 'x@y.com'; body = 'Comment' })
            }
        }

        It 'Should only enrich up to MaxPosts posts' {
            [PSObject[]]$result = Get-PostsWithComments -MaxPosts 2
            $result.Count | Should -Be 2
        }

        It 'Should only call Get-Comments for the limited number of posts' {
            Get-PostsWithComments -MaxPosts 1 | Out-Null
            Should -Invoke -ModuleName RestApiClient Get-Comments -Times 1 -Exactly -Scope It
        }
    }
}

# =============================================================================
# TDD Round 7: Error handling — graceful failures with meaningful messages
# =============================================================================
Describe 'Error Handling' {

    Context 'When API consistently fails' {
        BeforeAll {
            Mock -ModuleName RestApiClient Invoke-RestMethod {
                throw [System.Net.Http.HttpRequestException]::new('503 Service Unavailable')
            }
            Mock -ModuleName RestApiClient Start-Sleep {}
        }

        It 'Should produce an error message that includes the URL' {
            { Invoke-RestMethodWithRetry -Uri 'https://example.com/broken' -MaxRetries 1 -BaseDelaySeconds 0.001 } |
                Should -Throw '*https://example.com/broken*'
        }

        It 'Should produce an error message that includes the original error' {
            { Invoke-RestMethodWithRetry -Uri 'https://example.com/broken' -MaxRetries 1 -BaseDelaySeconds 0.001 } |
                Should -Throw '*503 Service Unavailable*'
        }

        It 'Should throw InvalidOperationException' {
            $thrown = $false
            try {
                Invoke-RestMethodWithRetry -Uri 'https://example.com/broken' -MaxRetries 1 -BaseDelaySeconds 0.001
            }
            catch [System.InvalidOperationException] {
                $thrown = $true
            }
            $thrown | Should -BeTrue
        }
    }
}
