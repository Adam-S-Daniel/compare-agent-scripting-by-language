# ApiClient.Tests.ps1
# TDD tests for the REST API Client using JSONPlaceholder.
#
# TDD APPROACH:
#   Each Describe block corresponds to one TDD cycle:
#     RED   - test written first, fails because the function doesn't exist yet
#     GREEN - minimal implementation added to make the test pass
#     REFACTOR - code cleaned up without breaking tests
#
# Run all tests with:  Invoke-Pester
# Run verbosely with:  Invoke-Pester -Output Detailed

# ---------------------------------------------------------------------------
# Bootstrap: install Pester 5.x if not present
# ---------------------------------------------------------------------------
$pesterModule = Get-Module -ListAvailable -Name Pester |
    Where-Object { $_.Version.Major -ge 5 } |
    Sort-Object Version -Descending |
    Select-Object -First 1

if (-not $pesterModule) {
    Write-Host "Pester 5 not found. Installing..." -ForegroundColor Yellow
    Install-Module -Name Pester -Force -Scope CurrentUser -MinimumVersion 5.0 -SkipPublisherCheck
}

Import-Module Pester -MinimumVersion 5.0 -Force

# ---------------------------------------------------------------------------
# Dot-source the implementation so Pester can mock cmdlets called within it.
# BeforeAll runs once before any test in the file.
# ---------------------------------------------------------------------------
BeforeAll {
    . "$PSScriptRoot/ApiClient.ps1"
}

# ===========================================================================
# TDD CYCLE 1 — Get-Posts
#   RED:   no ApiClient.ps1 exists → "Get-Posts is not recognized"
#   GREEN: implement Get-Posts that calls Invoke-RestMethod
# ===========================================================================
Describe "Get-Posts" {
    Context "successful API call" {
        BeforeEach {
            # Mock Invoke-RestMethod so tests never hit the real network.
            # ParameterFilter ensures only posts-endpoint calls are matched.
            Mock Invoke-RestMethod {
                return @(
                    [PSCustomObject]@{ id = 1; userId = 1; title = "Test Post 1"; body = "Body 1" },
                    [PSCustomObject]@{ id = 2; userId = 1; title = "Test Post 2"; body = "Body 2" }
                )
            } -ParameterFilter { $Uri -like "*posts*" }
        }

        It "returns a list of posts" {
            $posts = Get-Posts
            $posts | Should -Not -BeNullOrEmpty
            $posts.Count | Should -Be 2
        }

        It "returns posts with expected fields" {
            $posts = Get-Posts
            $posts[0].id    | Should -Be 1
            $posts[0].title | Should -Be "Test Post 1"
        }

        It "calls the JSONPlaceholder posts endpoint" {
            Get-Posts
            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Uri -like "*jsonplaceholder.typicode.com/posts*"
            }
        }

        It "passes page number as _page query parameter" {
            Get-Posts -Page 2
            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Uri -like "*_page=2*"
            }
        }

        It "passes limit as _limit query parameter" {
            Get-Posts -Limit 5
            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Uri -like "*_limit=5*"
            }
        }
    }
}

# ===========================================================================
# TDD CYCLE 2 — Get-PostComments
#   RED:   Get-PostComments not defined → error
#   GREEN: implement Get-PostComments that calls /<postId>/comments
# ===========================================================================
Describe "Get-PostComments" {
    Context "successful API call" {
        BeforeEach {
            Mock Invoke-RestMethod {
                return @(
                    [PSCustomObject]@{ id = 1; postId = 1; name = "Alice"; email = "a@test.com"; body = "Great!" },
                    [PSCustomObject]@{ id = 2; postId = 1; name = "Bob";   email = "b@test.com"; body = "Nice!"  }
                )
            } -ParameterFilter { $Uri -like "*comments*" }
        }

        It "returns comments for a post" {
            $comments = Get-PostComments -PostId 1
            $comments | Should -Not -BeNullOrEmpty
            $comments.Count | Should -Be 2
        }

        It "returns comments with expected fields" {
            $comments = Get-PostComments -PostId 1
            $comments[0].postId | Should -Be 1
            $comments[0].name   | Should -Be "Alice"
        }

        It "calls the correct comments endpoint for the given post id" {
            Get-PostComments -PostId 42
            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Uri -like "*posts/42/comments*"
            }
        }
    }
}

# ===========================================================================
# TDD CYCLE 3 — Get-PostsWithComments
#   RED:   Get-PostsWithComments not defined → error
#   GREEN: implement to call Get-Posts then Get-PostComments for each post
# ===========================================================================
Describe "Get-PostsWithComments" {
    BeforeEach {
        # Single mock that routes based on URL: comments vs posts
        Mock Invoke-RestMethod {
            if ($Uri -like "*comments*") {
                return @(
                    [PSCustomObject]@{ id = 1; postId = 1; name = "Commenter"; body = "Nice post!" }
                )
            } else {
                return @(
                    [PSCustomObject]@{ id = 1; userId = 1; title = "Post 1"; body = "Body 1" }
                )
            }
        }
    }

    It "returns objects that have both Post and Comments properties" {
        $result = @(Get-PostsWithComments -Page 1 -Limit 1)
        $result            | Should -Not -BeNullOrEmpty
        $result[0].Post    | Should -Not -BeNullOrEmpty
        $result[0].Comments | Should -Not -BeNullOrEmpty
    }

    It "fetches comments for every post (one API call per post for comments)" {
        Get-PostsWithComments -Page 1 -Limit 1
        # 1 call for posts + 1 call for comments on post 1 = 2 total
        Should -Invoke Invoke-RestMethod -Times 2
    }
}

# ===========================================================================
# TDD CYCLE 4 — Invoke-ApiRequestWithRetry (retry + exponential backoff)
#   RED:   function not defined → error
#   GREEN: implement with try/catch loop, exponential delay, max-retry limit
# ===========================================================================
Describe "Invoke-ApiRequestWithRetry" {
    Context "on success" {
        BeforeEach {
            Mock Invoke-RestMethod { return @{ id = 1; title = "OK" } }
        }

        It "returns response data when the first attempt succeeds" {
            $result = Invoke-ApiRequestWithRetry -Uri "https://test.example/api"
            $result.id | Should -Be 1
        }

        It "calls Invoke-RestMethod exactly once on immediate success" {
            Invoke-ApiRequestWithRetry -Uri "https://test.example/api"
            Should -Invoke Invoke-RestMethod -Times 1
        }
    }

    Context "on transient failure then success" {
        It "retries until success and returns the successful response" {
            # Fail twice, succeed on attempt 3
            $script:retryCallCount = 0
            Mock Invoke-RestMethod {
                $script:retryCallCount++
                if ($script:retryCallCount -lt 3) { throw "Transient error" }
                return @{ id = 1 }
            }
            Mock Start-Sleep {}   # suppress real delays during tests

            $result = Invoke-ApiRequestWithRetry -Uri "https://test.example/api" -MaxRetries 3
            $result.id | Should -Be 1
            Should -Invoke Invoke-RestMethod -Times 3
        }
    }

    Context "on persistent failure" {
        BeforeEach {
            Mock Invoke-RestMethod { throw "Permanent error" }
            Mock Start-Sleep {}
        }

        It "throws an error after all retries are exhausted" {
            { Invoke-ApiRequestWithRetry -Uri "https://test.example/api" -MaxRetries 3 } |
                Should -Throw
        }

        It "calls the API exactly MaxRetries times before giving up" {
            try { Invoke-ApiRequestWithRetry -Uri "https://test.example/api" -MaxRetries 3 } catch {}
            Should -Invoke Invoke-RestMethod -Times 3
        }

        It "sleeps between retries (MaxRetries-1 sleeps for MaxRetries attempts)" {
            try { Invoke-ApiRequestWithRetry -Uri "https://test.example/api" -MaxRetries 3 } catch {}
            # 3 max retries → fail 3 times → sleep after attempt 1 and 2 (not after the last throw)
            Should -Invoke Start-Sleep -Times 2
        }

        It "uses exponential backoff: first delay=BaseDelay, second delay=2*BaseDelay" {
            try {
                Invoke-ApiRequestWithRetry -Uri "https://test.example/api" -MaxRetries 3 -BaseDelaySeconds 1
            } catch {}
            Should -Invoke Start-Sleep -Times 1 -ParameterFilter { $Seconds -eq 1 }
            Should -Invoke Start-Sleep -Times 1 -ParameterFilter { $Seconds -eq 2 }
        }
    }
}

# ===========================================================================
# TDD CYCLE 5 — Local JSON caching (Get-CachedData / Save-CachedData)
#   RED:   cache functions not defined → error
#   GREEN: implement file-based JSON cache
# ===========================================================================
Describe "Caching" {
    BeforeAll {
        # Isolated temp directory for all cache tests
        $script:TestCacheDir = Join-Path ([System.IO.Path]::GetTempPath()) `
            "pester_api_cache_$(Get-Random)"
    }

    AfterAll {
        if (Test-Path $script:TestCacheDir) {
            Remove-Item -Recurse -Force $script:TestCacheDir
        }
    }

    Context "Get-CachedData" {
        It "returns null when cache file does not exist" {
            $result = Get-CachedData -CacheKey "nonexistent_key" -CacheDirectory $script:TestCacheDir
            $result | Should -BeNullOrEmpty
        }

        It "returns deserialized data when cache file exists" {
            # Manually create a cache entry
            New-Item -ItemType Directory -Path $script:TestCacheDir -Force | Out-Null
            @{ id = 99; title = "Cached Post" } |
                ConvertTo-Json |
                Set-Content (Join-Path $script:TestCacheDir "test_key.json")

            $result = Get-CachedData -CacheKey "test_key" -CacheDirectory $script:TestCacheDir
            $result.id    | Should -Be 99
            $result.title | Should -Be "Cached Post"
        }
    }

    Context "Save-CachedData" {
        It "creates the cache directory if it does not exist" {
            $newDir = Join-Path $script:TestCacheDir "new_subdir_$(Get-Random)"
            Save-CachedData -CacheKey "dir_test" -Data @{ x = 1 } -CacheDirectory $newDir
            Test-Path $newDir | Should -BeTrue
        }

        It "writes data as a JSON file under the cache directory" {
            $testData = @{ id = 42; name = "Test Item" }
            Save-CachedData -CacheKey "save_test" -Data $testData -CacheDirectory $script:TestCacheDir

            $filePath = Join-Path $script:TestCacheDir "save_test.json"
            Test-Path $filePath | Should -BeTrue

            $saved = Get-Content $filePath -Raw | ConvertFrom-Json
            $saved.id   | Should -Be 42
            $saved.name | Should -Be "Test Item"
        }
    }

    Context "Get-Posts with UseCache switch" {
        BeforeEach {
            $script:PostCacheDir = Join-Path $script:TestCacheDir "posts_$(Get-Random)"
            Mock Invoke-RestMethod {
                return @([PSCustomObject]@{ id = 1; title = "Fresh from API" })
            } -ParameterFilter { $Uri -like "*posts*" }
        }

        It "writes a cache file after fetching from the API" {
            Get-Posts -Page 1 -Limit 10 -UseCache -CacheDirectory $script:PostCacheDir
            $cacheFile = Join-Path $script:PostCacheDir "posts_page1_limit10.json"
            Test-Path $cacheFile | Should -BeTrue
        }

        It "returns cached data and skips the API call when cache is warm" {
            # Pre-populate cache with stale-but-identifiable data
            New-Item -ItemType Directory -Path $script:PostCacheDir -Force | Out-Null
            @([PSCustomObject]@{ id = 999; title = "Stale Cache Hit" }) |
                ConvertTo-Json |
                Set-Content (Join-Path $script:PostCacheDir "posts_page1_limit10.json")

            $result = Get-Posts -Page 1 -Limit 10 -UseCache -CacheDirectory $script:PostCacheDir
            # @() wrapper normalises both PS5 (may unwrap single-element array) and PS7
            @($result)[0].id | Should -Be 999
            Should -Not -Invoke Invoke-RestMethod
        }
    }
}

# ===========================================================================
# TDD CYCLE 6 — Get-AllPosts (pagination)
#   RED:   Get-AllPosts not defined → error
#   GREEN: implement page-by-page fetch until empty page returned
# ===========================================================================
Describe "Get-AllPosts (automatic pagination)" {
    It "stops fetching when an empty page is returned and returns all posts" {
        # Counter tracked in script scope — visible inside Mock scriptblocks in Pester 5
        $script:paginationCallCount = 0
        Mock Invoke-RestMethod {
            $script:paginationCallCount++
            switch ($script:paginationCallCount) {
                1 { return @(
                        [PSCustomObject]@{ id = 1; title = "Page 1 - Post A" },
                        [PSCustomObject]@{ id = 2; title = "Page 1 - Post B" }
                    ) }
                2 { return @(
                        [PSCustomObject]@{ id = 3; title = "Page 2 - Post C" }
                    ) }
                default { return @() }   # empty page signals end of results
            }
        }

        # @() wrapper handles PS5 scalar-unwrapping of multi-element arrays
        $allPosts = @(Get-AllPosts -Limit 2)
        $allPosts.Count | Should -Be 3
        # 3 calls: page 1 (2 items), page 2 (1 item), page 3 (0 items = stop)
        Should -Invoke Invoke-RestMethod -Times 3
    }

    It "returns all post objects from every page in order" {
        $script:singlePageCallCount = 0
        Mock Invoke-RestMethod {
            $script:singlePageCallCount++
            if ($script:singlePageCallCount -eq 1) {
                return @([PSCustomObject]@{ id = 10; title = "Only Post" })
            }
            return @()
        }

        # @() wrapper ensures single-element result stays an array in PS5
        $allPosts = @(Get-AllPosts -Limit 10)
        $allPosts.Count    | Should -Be 1
        $allPosts[0].id    | Should -Be 10
        $allPosts[0].title | Should -Be "Only Post"
    }

    It "returns null/empty when the first page has no results" {
        # PowerShell functions returning @() yield $null at the call-site,
        # so we use Should -BeNullOrEmpty rather than .Count -eq 0
        Mock Invoke-RestMethod { return @() }

        $result = Get-AllPosts -Limit 10
        $result | Should -BeNullOrEmpty
    }
}
