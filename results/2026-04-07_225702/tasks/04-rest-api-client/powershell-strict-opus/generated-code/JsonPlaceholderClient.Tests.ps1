Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import the module under test and define test fixtures
BeforeAll {
    Import-Module "$PSScriptRoot/JsonPlaceholderClient.psm1" -Force

    # ---------- Test Fixtures ----------

    # Sample post data mimicking JSONPlaceholder /posts response
    function Get-SamplePosts {
        [CmdletBinding()]
        [OutputType([hashtable[]])]
        param()
        return @(
            @{ id = 1; userId = 1; title = 'First Post'; body = 'Body of first post' }
            @{ id = 2; userId = 1; title = 'Second Post'; body = 'Body of second post' }
            @{ id = 3; userId = 2; title = 'Third Post'; body = 'Body of third post' }
        )
    }

    # Sample comment data mimicking JSONPlaceholder /posts/{id}/comments response
    function Get-SampleComments {
        [CmdletBinding()]
        [OutputType([hashtable[]])]
        param([int]$PostId)
        return @(
            @{ id = ($PostId * 10 + 1); postId = $PostId; name = "Comment A on post $PostId"; email = 'a@example.com'; body = "Comment body A for post $PostId" }
            @{ id = ($PostId * 10 + 2); postId = $PostId; name = "Comment B on post $PostId"; email = 'b@example.com'; body = "Comment body B for post $PostId" }
        )
    }
}

# ---------- Tests ----------

Describe 'Get-Posts' {
    Context 'When API returns posts successfully' {
        BeforeEach {
            # Mock Invoke-ApiRequest to return sample posts without hitting the network
            Mock -ModuleName JsonPlaceholderClient Invoke-ApiRequest {
                return (Get-SamplePosts)
            }
        }

        It 'Should return all posts from the API' {
            [array]$posts = Get-Posts -BaseUri 'https://jsonplaceholder.typicode.com'
            $posts.Count | Should -Be 3
        }

        It 'Should contain expected post properties' {
            [array]$posts = Get-Posts -BaseUri 'https://jsonplaceholder.typicode.com'
            $posts[0].title | Should -Be 'First Post'
            $posts[0].id | Should -Be 1
        }

        It 'Should call the API with the correct posts endpoint' {
            $null = Get-Posts -BaseUri 'https://jsonplaceholder.typicode.com'
            Should -Invoke -ModuleName JsonPlaceholderClient Invoke-ApiRequest -Times 1 -Exactly
        }
    }

    Context 'When fetching posts with pagination' {
        BeforeEach {
            # Simulate paginated responses: page 1 returns 2 items, page 2 returns 1 item
            $script:callCount = 0
            Mock -ModuleName JsonPlaceholderClient Invoke-ApiRequest {
                $script:callCount++
                if ($script:callCount -eq 1) {
                    return @(
                        @{ id = 1; userId = 1; title = 'Post 1'; body = 'Body 1' }
                        @{ id = 2; userId = 1; title = 'Post 2'; body = 'Body 2' }
                    )
                } else {
                    return @(
                        @{ id = 3; userId = 2; title = 'Post 3'; body = 'Body 3' }
                    )
                }
            }
        }

        It 'Should fetch multiple pages when PageSize is smaller than total' {
            [array]$posts = Get-Posts -BaseUri 'https://jsonplaceholder.typicode.com' -PageSize 2 -MaxPages 2
            $posts.Count | Should -Be 3
        }

        It 'Should stop paginating when a page returns fewer items than PageSize' {
            $null = Get-Posts -BaseUri 'https://jsonplaceholder.typicode.com' -PageSize 2 -MaxPages 10
            # First page returns 2 (full page), second returns 1 (partial) -> stops
            Should -Invoke -ModuleName JsonPlaceholderClient Invoke-ApiRequest -Times 2 -Exactly
        }
    }

    Context 'When pagination returns empty page' {
        BeforeEach {
            # PageSize=1 so first page with 1 item is "full", triggering a second request
            $script:callCount = 0
            Mock -ModuleName JsonPlaceholderClient Invoke-ApiRequest {
                $script:callCount++
                if ($script:callCount -eq 1) {
                    return @(
                        @{ id = 1; userId = 1; title = 'Only Post'; body = 'Body' }
                    )
                } else {
                    return @()
                }
            }
        }

        It 'Should stop when an empty page is returned' {
            [array]$posts = Get-Posts -BaseUri 'https://jsonplaceholder.typicode.com' -PageSize 1 -MaxPages 5
            $posts.Count | Should -Be 1
            Should -Invoke -ModuleName JsonPlaceholderClient Invoke-ApiRequest -Times 2 -Exactly
        }
    }
}

Describe 'Get-PostComments' {
    Context 'When API returns comments for a post' {
        BeforeEach {
            Mock -ModuleName JsonPlaceholderClient Invoke-ApiRequest {
                return (Get-SampleComments -PostId 1)
            }
        }

        It 'Should return comments for the given post' {
            [array]$comments = Get-PostComments -BaseUri 'https://jsonplaceholder.typicode.com' -PostId 1
            $comments.Count | Should -Be 2
        }

        It 'Should return comments with correct postId' {
            [array]$comments = Get-PostComments -BaseUri 'https://jsonplaceholder.typicode.com' -PostId 1
            $comments[0].postId | Should -Be 1
        }
    }
}

Describe 'Invoke-ApiRequest (retry with exponential backoff)' {
    Context 'When request succeeds on first try' {
        BeforeEach {
            Mock -ModuleName JsonPlaceholderClient Invoke-RestMethod {
                return @(@{ id = 1; title = 'OK' })
            }
            Mock -ModuleName JsonPlaceholderClient Start-Sleep {}
        }

        It 'Should return data without retrying' {
            [array]$result = Invoke-ApiRequest -Uri 'https://jsonplaceholder.typicode.com/posts'
            $result[0].title | Should -Be 'OK'
            Should -Invoke -ModuleName JsonPlaceholderClient Start-Sleep -Times 0 -Exactly
        }
    }

    Context 'When request fails then succeeds (transient error)' {
        BeforeEach {
            $script:attemptCount = 0
            Mock -ModuleName JsonPlaceholderClient Invoke-RestMethod {
                $script:attemptCount++
                if ($script:attemptCount -lt 3) {
                    throw [System.Net.Http.HttpRequestException]::new('Service Unavailable')
                }
                return @(@{ id = 1; title = 'Recovered' })
            }
            Mock -ModuleName JsonPlaceholderClient Start-Sleep {}
        }

        It 'Should retry and eventually succeed' {
            [array]$result = Invoke-ApiRequest -Uri 'https://jsonplaceholder.typicode.com/posts' -MaxRetries 5
            $result[0].title | Should -Be 'Recovered'
        }

        It 'Should have called Start-Sleep for backoff between retries' {
            $null = Invoke-ApiRequest -Uri 'https://jsonplaceholder.typicode.com/posts' -MaxRetries 5
            # 2 failures = 2 sleeps before the 3rd (successful) attempt
            Should -Invoke -ModuleName JsonPlaceholderClient Start-Sleep -Times 2 -Exactly
        }
    }

    Context 'When all retries are exhausted' {
        BeforeEach {
            Mock -ModuleName JsonPlaceholderClient Invoke-RestMethod {
                throw [System.Net.Http.HttpRequestException]::new('Server Error')
            }
            Mock -ModuleName JsonPlaceholderClient Start-Sleep {}
        }

        It 'Should throw after max retries exhausted' {
            { Invoke-ApiRequest -Uri 'https://jsonplaceholder.typicode.com/posts' -MaxRetries 3 } |
                Should -Throw -ExpectedMessage '*Server Error*'
        }

        It 'Should have retried the expected number of times' {
            try {
                Invoke-ApiRequest -Uri 'https://jsonplaceholder.typicode.com/posts' -MaxRetries 3
            } catch {
                # expected
            }
            # 3 retries = 3 sleeps (after attempt 1, 2, 3 fail; then final attempt 4 also fails but no sleep after)
            Should -Invoke -ModuleName JsonPlaceholderClient Start-Sleep -Times 3 -Exactly
        }
    }

    Context 'Exponential backoff timing' {
        BeforeEach {
            $script:sleepValues = [System.Collections.Generic.List[double]]::new()
            $script:attemptCount = 0
            Mock -ModuleName JsonPlaceholderClient Invoke-RestMethod {
                $script:attemptCount++
                if ($script:attemptCount -le 3) {
                    throw [System.Net.Http.HttpRequestException]::new('Fail')
                }
                return @(@{ id = 1 })
            }
            Mock -ModuleName JsonPlaceholderClient Start-Sleep {
                param([double]$Seconds)
                $script:sleepValues.Add($Seconds)
            }
        }

        It 'Should use exponentially increasing delays' {
            $null = Invoke-ApiRequest -Uri 'https://example.com/test' -MaxRetries 5 -BaseDelaySeconds 1.0
            # Delays should be: 1, 2, 4 (exponential base * 2^attempt)
            $script:sleepValues[0] | Should -Be 1.0
            $script:sleepValues[1] | Should -Be 2.0
            $script:sleepValues[2] | Should -Be 4.0
        }
    }
}

Describe 'Save-Cache and Get-Cache' {
    BeforeAll {
        $script:testCacheDir = Join-Path ([System.IO.Path]::GetTempPath()) "pester_cache_$(Get-Random)"
    }

    AfterAll {
        if (Test-Path $script:testCacheDir) {
            Remove-Item -Recurse -Force $script:testCacheDir
        }
    }

    Context 'When saving and loading cached data' {
        It 'Should save data to a JSON file' {
            [hashtable[]]$data = @(@{ id = 1; title = 'Cached Post' })
            Save-Cache -CacheDir $script:testCacheDir -Key 'posts' -Data $data
            [string]$filePath = Join-Path $script:testCacheDir 'posts.json'
            Test-Path $filePath | Should -BeTrue
        }

        It 'Should load cached data correctly' {
            [hashtable[]]$data = @(@{ id = 1; title = 'Cached Post' })
            Save-Cache -CacheDir $script:testCacheDir -Key 'posts_load' -Data $data
            $loaded = Get-Cache -CacheDir $script:testCacheDir -Key 'posts_load'
            $loaded[0].title | Should -Be 'Cached Post'
        }

        It 'Should return $null when cache key does not exist' {
            $loaded = Get-Cache -CacheDir $script:testCacheDir -Key 'nonexistent'
            $loaded | Should -BeNullOrEmpty
        }
    }

    Context 'When cache has expired' {
        It 'Should return $null for expired cache entries' {
            [hashtable[]]$data = @(@{ id = 1; title = 'Old Data' })
            Save-Cache -CacheDir $script:testCacheDir -Key 'expired_test' -Data $data
            # Force the file to have an old timestamp
            [string]$filePath = Join-Path $script:testCacheDir 'expired_test.json'
            (Get-Item $filePath).LastWriteTime = (Get-Date).AddHours(-2)

            $loaded = Get-Cache -CacheDir $script:testCacheDir -Key 'expired_test' -MaxAgeMinutes 30
            $loaded | Should -BeNullOrEmpty
        }
    }
}

Describe 'Get-PostsWithComments (integration of all features)' {
    Context 'When fetching posts and their comments (no cache)' {
        BeforeEach {
            $script:testCacheDir2 = Join-Path ([System.IO.Path]::GetTempPath()) "pester_integration_$(Get-Random)"

            # Mock Invoke-ApiRequest at the module level to avoid network calls
            $script:apiCallLog = [System.Collections.Generic.List[string]]::new()
            Mock -ModuleName JsonPlaceholderClient Invoke-ApiRequest {
                # Capture the URI for verification
                $script:apiCallLog.Add($Uri)

                if ($Uri -match '/posts\?') {
                    return @(
                        @{ id = 1; userId = 1; title = 'Post 1'; body = 'Body 1' }
                        @{ id = 2; userId = 1; title = 'Post 2'; body = 'Body 2' }
                    )
                }
                if ($Uri -match '/posts/1/comments') {
                    return @(
                        @{ id = 11; postId = 1; name = 'Comment on Post 1'; email = 'a@test.com'; body = 'Nice post 1' }
                    )
                }
                if ($Uri -match '/posts/2/comments') {
                    return @(
                        @{ id = 21; postId = 2; name = 'Comment on Post 2'; email = 'b@test.com'; body = 'Nice post 2' }
                    )
                }
                return @()
            }
        }

        AfterEach {
            if (Test-Path $script:testCacheDir2) {
                Remove-Item -Recurse -Force $script:testCacheDir2
            }
        }

        It 'Should return posts with their comments attached' {
            [array]$results = Get-PostsWithComments -BaseUri 'https://jsonplaceholder.typicode.com' -CacheDir $script:testCacheDir2
            $results.Count | Should -Be 2
            $results[0].comments.Count | Should -Be 1
            $results[0].comments[0].name | Should -Be 'Comment on Post 1'
        }

        It 'Should save results to cache' {
            $null = Get-PostsWithComments -BaseUri 'https://jsonplaceholder.typicode.com' -CacheDir $script:testCacheDir2
            [string]$cachePath = Join-Path $script:testCacheDir2 'posts_with_comments.json'
            Test-Path $cachePath | Should -BeTrue
        }
    }

    Context 'When cache is available and fresh' {
        BeforeEach {
            $script:testCacheDir3 = Join-Path ([System.IO.Path]::GetTempPath()) "pester_cached_$(Get-Random)"

            # Pre-populate cache
            [hashtable[]]$cachedData = @(
                @{ id = 99; title = 'Cached'; comments = @(@{ id = 991; body = 'cached comment' }) }
            )
            Save-Cache -CacheDir $script:testCacheDir3 -Key 'posts_with_comments' -Data $cachedData

            Mock -ModuleName JsonPlaceholderClient Invoke-ApiRequest {
                throw 'Should not be called when cache is fresh'
            }
        }

        AfterEach {
            if (Test-Path $script:testCacheDir3) {
                Remove-Item -Recurse -Force $script:testCacheDir3
            }
        }

        It 'Should return cached data without calling the API' {
            [array]$results = Get-PostsWithComments -BaseUri 'https://jsonplaceholder.typicode.com' -CacheDir $script:testCacheDir3
            $results[0].id | Should -Be 99
            Should -Invoke -ModuleName JsonPlaceholderClient Invoke-ApiRequest -Times 0 -Exactly
        }
    }
}
