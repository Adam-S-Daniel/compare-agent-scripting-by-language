#Requires -Modules Pester
<#
.SYNOPSIS
    TDD test suite for the JSONPlaceholder REST API client.

.DESCRIPTION
    Red/Green TDD approach:
      1. Tests are written first (red — they fail because the module doesn't exist yet).
      2. Minimum implementation is added to make each group pass (green).
      3. Refactor as needed.

    Test groups, in order of implementation:
      1. Get-ApiCache / Set-ApiCache  — local JSON cache I/O
      2. Invoke-ApiRequest            — HTTP GET with exponential-backoff retry
      3. Get-Posts                    — paginated post fetching + caching
      4. Get-PostComments             — per-post comment fetching + caching
      5. Get-PostsWithComments        — orchestration: posts + their comments
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    # Import the module under test. -Force ensures a clean load on every run.
    Import-Module (Join-Path $PSScriptRoot 'ApiClient.psm1') -Force
}

# ─────────────────────────────────────────────────────────────────────────────
# 1. CACHE FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────
Describe 'Get-ApiCache' {
    BeforeEach {
        # Use a unique temp directory per test to avoid cross-test pollution.
        $script:TempCacheDir = Join-Path ([System.IO.Path]::GetTempPath()) "PesterCache_$([guid]::NewGuid().ToString('N'))"
    }
    AfterEach {
        if (Test-Path $script:TempCacheDir) {
            Remove-Item $script:TempCacheDir -Recurse -Force
        }
    }

    # RED: no cache file → expect $null
    It 'returns $null when the cache directory does not exist' {
        $result = Get-ApiCache -CacheDir $script:TempCacheDir -CacheKey 'posts'
        $result | Should -BeNullOrEmpty
    }

    It 'returns $null when the cache file does not exist' {
        [void](New-Item -ItemType Directory -Path $script:TempCacheDir -Force)
        $result = Get-ApiCache -CacheDir $script:TempCacheDir -CacheKey 'posts'
        $result | Should -BeNullOrEmpty
    }

    # RED: cache file exists → deserialise and return it
    It 'returns deserialized data when a single-object cache file exists' {
        [void](New-Item -ItemType Directory -Path $script:TempCacheDir -Force)
        @{ id = 1; title = 'Cached Post' } | ConvertTo-Json | Set-Content (Join-Path $script:TempCacheDir 'post.json')

        $result = Get-ApiCache -CacheDir $script:TempCacheDir -CacheKey 'post'
        $result.id    | Should -Be 1
        $result.title | Should -Be 'Cached Post'
    }

    It 'returns deserialized array data when an array cache file exists' {
        [void](New-Item -ItemType Directory -Path $script:TempCacheDir -Force)
        @(
            @{ id = 1; title = 'Post 1' },
            @{ id = 2; title = 'Post 2' }
        ) | ConvertTo-Json | Set-Content (Join-Path $script:TempCacheDir 'posts.json')

        [object[]]$result = @(Get-ApiCache -CacheDir $script:TempCacheDir -CacheKey 'posts')
        $result.Count    | Should -Be 2
        $result[0].id    | Should -Be 1
        $result[1].title | Should -Be 'Post 2'
    }
}

Describe 'Set-ApiCache' {
    BeforeEach {
        $script:TempCacheDir = Join-Path ([System.IO.Path]::GetTempPath()) "PesterCache_$([guid]::NewGuid().ToString('N'))"
    }
    AfterEach {
        if (Test-Path $script:TempCacheDir) {
            Remove-Item $script:TempCacheDir -Recurse -Force
        }
    }

    # RED: directory creation
    It 'creates the cache directory when it does not exist' {
        $data = [PSCustomObject]@{ id = 1 }
        Set-ApiCache -CacheDir $script:TempCacheDir -CacheKey 'post' -Data $data
        Test-Path $script:TempCacheDir | Should -BeTrue
    }

    # RED: file written as valid JSON
    It 'writes data as a JSON file with the correct cache key name' {
        $data = [PSCustomObject]@{ id = 42; title = 'Hello' }
        Set-ApiCache -CacheDir $script:TempCacheDir -CacheKey 'mykey' -Data $data

        [string]$expectedFile = Join-Path $script:TempCacheDir 'mykey.json'
        Test-Path $expectedFile | Should -BeTrue

        $saved = Get-Content $expectedFile -Raw | ConvertFrom-Json
        $saved.id    | Should -Be 42
        $saved.title | Should -Be 'Hello'
    }

    It 'overwrites an existing cache file' {
        [void](New-Item -ItemType Directory -Path $script:TempCacheDir -Force)
        $first  = [PSCustomObject]@{ value = 'old' }
        $second = [PSCustomObject]@{ value = 'new' }

        Set-ApiCache -CacheDir $script:TempCacheDir -CacheKey 'k' -Data $first
        Set-ApiCache -CacheDir $script:TempCacheDir -CacheKey 'k' -Data $second

        $saved = Get-Content (Join-Path $script:TempCacheDir 'k.json') -Raw | ConvertFrom-Json
        $saved.value | Should -Be 'new'
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# 2. INVOKE-APIREQUEST — retry with exponential backoff
# ─────────────────────────────────────────────────────────────────────────────
Describe 'Invoke-ApiRequest' {
    # Mock Invoke-RestMethod and Start-Sleep *inside* the ApiClient module so
    # that calls originating from our functions are intercepted.

    It 'returns the response body on a first-attempt success' {
        [PSCustomObject]$expected = [PSCustomObject]@{ id = 1; title = 'Success' }
        Mock -ModuleName ApiClient Invoke-RestMethod { return $expected }
        Mock -ModuleName ApiClient Start-Sleep { }

        $result = Invoke-ApiRequest -Uri 'https://example.com/posts' -MaxRetries 3 -BaseDelayMs 10
        $result.id    | Should -Be 1
        $result.title | Should -Be 'Success'
        Should -Invoke -ModuleName ApiClient Invoke-RestMethod -Times 1 -Exactly
    }

    It 'retries on transient failure and returns success on a later attempt' {
        $script:CallCount = 0
        Mock -ModuleName ApiClient Invoke-RestMethod {
            $script:CallCount++
            if ($script:CallCount -lt 2) { throw 'Transient network error' }
            return [PSCustomObject]@{ id = 99 }
        }
        Mock -ModuleName ApiClient Start-Sleep { }

        $result = Invoke-ApiRequest -Uri 'https://example.com/posts' -MaxRetries 3 -BaseDelayMs 10
        $result.id | Should -Be 99
        Should -Invoke -ModuleName ApiClient Invoke-RestMethod -Times 2 -Exactly
    }

    It 'applies exponential backoff delays between retries' {
        $script:SleepCalls = [System.Collections.Generic.List[int]]::new()
        Mock -ModuleName ApiClient Invoke-RestMethod { throw 'Always fails' }
        Mock -ModuleName ApiClient Start-Sleep {
            # $Milliseconds is the bound parameter value from Start-Sleep's signature
            $script:SleepCalls.Add([int]$Milliseconds)
        }

        # MaxRetries=3 → 3 attempts → 2 sleeps before the final throw
        { Invoke-ApiRequest -Uri 'https://example.com' -MaxRetries 3 -BaseDelayMs 100 } | Should -Throw

        # First delay: 100 * 2^0 = 100, Second delay: 100 * 2^1 = 200
        $script:SleepCalls.Count | Should -Be 2
        $script:SleepCalls[0]   | Should -Be 100
        $script:SleepCalls[1]   | Should -Be 200
    }

    It 'throws a descriptive error after exhausting all retries' {
        Mock -ModuleName ApiClient Invoke-RestMethod { throw 'Persistent failure' }
        Mock -ModuleName ApiClient Start-Sleep { }

        { Invoke-ApiRequest -Uri 'https://example.com' -MaxRetries 3 -BaseDelayMs 10 } |
            Should -Throw -ExpectedMessage '*3 attempts*'

        Should -Invoke -ModuleName ApiClient Invoke-RestMethod -Times 3 -Exactly
    }

    It 'honours the MaxRetries parameter — single attempt when MaxRetries is 1' {
        Mock -ModuleName ApiClient Invoke-RestMethod { throw 'Fail' }
        Mock -ModuleName ApiClient Start-Sleep { }

        { Invoke-ApiRequest -Uri 'https://example.com' -MaxRetries 1 -BaseDelayMs 10 } | Should -Throw

        Should -Invoke -ModuleName ApiClient Invoke-RestMethod -Times 1 -Exactly
        Should -Invoke -ModuleName ApiClient Start-Sleep -Times 0
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# 3. GET-POSTS — paginated fetching + caching
# ─────────────────────────────────────────────────────────────────────────────
Describe 'Get-Posts' {
    BeforeEach {
        $script:TempCacheDir = Join-Path ([System.IO.Path]::GetTempPath()) "PesterCache_$([guid]::NewGuid().ToString('N'))"
        # Canonical mock response for two posts
        $script:MockPosts = @(
            [PSCustomObject]@{ id = 1; title = 'Post One'; userId = 1 },
            [PSCustomObject]@{ id = 2; title = 'Post Two'; userId = 1 }
        )
    }
    AfterEach {
        if (Test-Path $script:TempCacheDir) {
            Remove-Item $script:TempCacheDir -Recurse -Force
        }
    }

    It 'calls the API and returns posts when there is no cache' {
        Mock -ModuleName ApiClient Invoke-ApiRequest { return $script:MockPosts }

        [object[]]$result = @(Get-Posts -BaseUrl 'https://api.example.com' -CacheDir $script:TempCacheDir -Page 1 -PageSize 10)
        $result.Count    | Should -Be 2
        $result[0].title | Should -Be 'Post One'
        Should -Invoke -ModuleName ApiClient Invoke-ApiRequest -Times 1 -Exactly
    }

    It 'passes the correct paginated URI to Invoke-ApiRequest' {
        $script:CapturedUri = ''
        Mock -ModuleName ApiClient Invoke-ApiRequest {
            $script:CapturedUri = [string]$Uri
            return $script:MockPosts
        }

        Get-Posts -BaseUrl 'https://api.example.com' -CacheDir $script:TempCacheDir -Page 2 -PageSize 5 | Out-Null
        $script:CapturedUri | Should -Be 'https://api.example.com/posts?_page=2&_limit=5'
    }

    It 'saves fetched posts to the cache' {
        Mock -ModuleName ApiClient Invoke-ApiRequest { return $script:MockPosts }

        Get-Posts -BaseUrl 'https://api.example.com' -CacheDir $script:TempCacheDir -Page 1 -PageSize 10 | Out-Null

        [string]$expectedFile = Join-Path $script:TempCacheDir 'posts_page1_size10.json'
        Test-Path $expectedFile | Should -BeTrue
    }

    It 'returns cached data without calling the API on a second call' {
        Mock -ModuleName ApiClient Invoke-ApiRequest { return $script:MockPosts }

        # First call — populates cache
        Get-Posts -BaseUrl 'https://api.example.com' -CacheDir $script:TempCacheDir -Page 1 -PageSize 10 | Out-Null
        # Second call — should hit cache
        [object[]]$result = @(Get-Posts -BaseUrl 'https://api.example.com' -CacheDir $script:TempCacheDir -Page 1 -PageSize 10)

        $result.Count | Should -Be 2
        # API called only once despite two Get-Posts calls
        Should -Invoke -ModuleName ApiClient Invoke-ApiRequest -Times 1 -Exactly
    }

    It 'uses separate cache keys for different pages' {
        Mock -ModuleName ApiClient Invoke-ApiRequest { return $script:MockPosts }

        Get-Posts -BaseUrl 'https://api.example.com' -CacheDir $script:TempCacheDir -Page 1 -PageSize 10 | Out-Null
        Get-Posts -BaseUrl 'https://api.example.com' -CacheDir $script:TempCacheDir -Page 2 -PageSize 10 | Out-Null

        Test-Path (Join-Path $script:TempCacheDir 'posts_page1_size10.json') | Should -BeTrue
        Test-Path (Join-Path $script:TempCacheDir 'posts_page2_size10.json') | Should -BeTrue
        Should -Invoke -ModuleName ApiClient Invoke-ApiRequest -Times 2 -Exactly
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# 4. GET-POSTCOMMENTS — per-post comment fetching + caching
# ─────────────────────────────────────────────────────────────────────────────
Describe 'Get-PostComments' {
    BeforeEach {
        $script:TempCacheDir = Join-Path ([System.IO.Path]::GetTempPath()) "PesterCache_$([guid]::NewGuid().ToString('N'))"
        $script:MockComments = @(
            [PSCustomObject]@{ id = 10; postId = 1; name = 'Commenter A'; body = 'Great post' },
            [PSCustomObject]@{ id = 11; postId = 1; name = 'Commenter B'; body = 'Thanks!'     }
        )
    }
    AfterEach {
        if (Test-Path $script:TempCacheDir) {
            Remove-Item $script:TempCacheDir -Recurse -Force
        }
    }

    It 'fetches comments for the specified post ID' {
        Mock -ModuleName ApiClient Invoke-ApiRequest { return $script:MockComments }

        [object[]]$result = @(Get-PostComments -PostId 1 -BaseUrl 'https://api.example.com' -CacheDir $script:TempCacheDir)
        $result.Count   | Should -Be 2
        $result[0].name | Should -Be 'Commenter A'
        Should -Invoke -ModuleName ApiClient Invoke-ApiRequest -Times 1 -Exactly
    }

    It 'builds the correct comments URI' {
        $script:CapturedUri = ''
        Mock -ModuleName ApiClient Invoke-ApiRequest {
            $script:CapturedUri = [string]$Uri
            return $script:MockComments
        }

        Get-PostComments -PostId 7 -BaseUrl 'https://api.example.com' -CacheDir $script:TempCacheDir | Out-Null
        $script:CapturedUri | Should -Be 'https://api.example.com/posts/7/comments'
    }

    It 'saves fetched comments to the cache' {
        Mock -ModuleName ApiClient Invoke-ApiRequest { return $script:MockComments }

        Get-PostComments -PostId 3 -BaseUrl 'https://api.example.com' -CacheDir $script:TempCacheDir | Out-Null
        Test-Path (Join-Path $script:TempCacheDir 'comments_post_3.json') | Should -BeTrue
    }

    It 'returns cached comments without calling the API on a second call' {
        Mock -ModuleName ApiClient Invoke-ApiRequest { return $script:MockComments }

        Get-PostComments -PostId 1 -BaseUrl 'https://api.example.com' -CacheDir $script:TempCacheDir | Out-Null
        [object[]]$result = @(Get-PostComments -PostId 1 -BaseUrl 'https://api.example.com' -CacheDir $script:TempCacheDir)

        $result.Count | Should -Be 2
        Should -Invoke -ModuleName ApiClient Invoke-ApiRequest -Times 1 -Exactly
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# 5. GET-POSTSWITHCOMMENTS — orchestration
# ─────────────────────────────────────────────────────────────────────────────
Describe 'Get-PostsWithComments' {
    BeforeEach {
        $script:TempCacheDir = Join-Path ([System.IO.Path]::GetTempPath()) "PesterCache_$([guid]::NewGuid().ToString('N'))"

        $script:MockPosts = @(
            [PSCustomObject]@{ id = 1; title = 'Post One' },
            [PSCustomObject]@{ id = 2; title = 'Post Two' }
        )
        $script:MockCommentsForPost1 = @(
            [PSCustomObject]@{ id = 10; postId = 1; body = 'Comment A' }
        )
        $script:MockCommentsForPost2 = @(
            [PSCustomObject]@{ id = 20; postId = 2; body = 'Comment B' },
            [PSCustomObject]@{ id = 21; postId = 2; body = 'Comment C' }
        )
    }
    AfterEach {
        if (Test-Path $script:TempCacheDir) {
            Remove-Item $script:TempCacheDir -Recurse -Force
        }
    }

    It 'returns each post paired with its comments' {
        # Mock Invoke-ApiRequest to return posts or comments based on the URI
        Mock -ModuleName ApiClient Invoke-ApiRequest {
            if ($Uri -match '/posts\?') { return $script:MockPosts }
            if ($Uri -match '/posts/1/comments') { return $script:MockCommentsForPost1 }
            if ($Uri -match '/posts/2/comments') { return $script:MockCommentsForPost2 }
            throw "Unexpected URI: $Uri"
        }

        [object[]]$result = @(Get-PostsWithComments -BaseUrl 'https://api.example.com' -CacheDir $script:TempCacheDir -Page 1 -PageSize 10)

        $result.Count | Should -Be 2

        # First result: Post One with 1 comment
        $result[0].Post.title      | Should -Be 'Post One'
        @($result[0].Comments).Count | Should -Be 1
        $result[0].Comments[0].body  | Should -Be 'Comment A'

        # Second result: Post Two with 2 comments
        $result[1].Post.title      | Should -Be 'Post Two'
        @($result[1].Comments).Count | Should -Be 2
    }

    It 'fetches comments for each post individually' {
        Mock -ModuleName ApiClient Invoke-ApiRequest {
            if ($Uri -match '/posts\?') { return $script:MockPosts }
            return @([PSCustomObject]@{ id = 99; postId = 1; body = 'x' })
        }

        Get-PostsWithComments -BaseUrl 'https://api.example.com' -CacheDir $script:TempCacheDir -Page 1 -PageSize 10 | Out-Null

        # One API call for posts + one per post for comments (2 posts = 3 total)
        Should -Invoke -ModuleName ApiClient Invoke-ApiRequest -Times 3 -Exactly
    }

    It 'passes Page and PageSize through to Get-Posts' {
        $script:CapturedUri = ''
        Mock -ModuleName ApiClient Invoke-ApiRequest {
            if ($Uri -match '/posts\?') {
                $script:CapturedUri = [string]$Uri
                return @([PSCustomObject]@{ id = 5; title = 'P' })
            }
            return @([PSCustomObject]@{ id = 1; postId = 5; body = 'c' })
        }

        Get-PostsWithComments -BaseUrl 'https://api.example.com' -CacheDir $script:TempCacheDir -Page 3 -PageSize 5 | Out-Null
        $script:CapturedUri | Should -Be 'https://api.example.com/posts?_page=3&_limit=5'
    }
}
