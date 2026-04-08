# Tests for JSONPlaceholder REST API client
# Using TDD: each test is written before the implementation code.

BeforeAll {
    . "$PSScriptRoot/JsonPlaceholderClient.ps1"
}

Describe 'Get-Posts' {
    Context 'when API returns posts successfully' {
        BeforeAll {
            # Mock Invoke-RestMethod to return fake posts
            Mock Invoke-RestMethod {
                return @(
                    [PSCustomObject]@{ id = 1; userId = 1; title = 'Post 1'; body = 'Body 1' },
                    [PSCustomObject]@{ id = 2; userId = 1; title = 'Post 2'; body = 'Body 2' }
                )
            }
        }

        It 'returns an array of posts' {
            $posts = Get-Posts
            $posts.Count | Should -Be 2
        }

        It 'returns posts with expected properties' {
            $posts = Get-Posts
            $posts[0].id | Should -Be 1
            $posts[0].title | Should -Be 'Post 1'
        }

        It 'calls the correct API endpoint' {
            Get-Posts | Out-Null
            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $Uri -like '*/posts*'
            }
        }
    }
}

Describe 'Get-Comments' {
    Context 'when API returns comments for a post' {
        BeforeAll {
            # Mock returns comments for post 1
            Mock Invoke-RestMethod {
                return @(
                    [PSCustomObject]@{ id = 1; postId = 1; name = 'Comment 1'; email = 'a@b.com'; body = 'Nice post' },
                    [PSCustomObject]@{ id = 2; postId = 1; name = 'Comment 2'; email = 'c@d.com'; body = 'Great' }
                )
            }
        }

        It 'returns comments for a given post ID' {
            $comments = Get-Comments -PostId 1
            $comments.Count | Should -Be 2
        }

        It 'returns comments with expected properties' {
            $comments = Get-Comments -PostId 1
            $comments[0].postId | Should -Be 1
            $comments[0].name | Should -Be 'Comment 1'
        }

        It 'calls the correct API endpoint with post ID' {
            Get-Comments -PostId 1 | Out-Null
            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $Uri -like '*/posts/1/comments*'
            }
        }
    }
}

Describe 'Get-Posts pagination' {
    Context 'when requesting a specific page' {
        BeforeAll {
            Mock Invoke-RestMethod {
                # Return different posts depending on which page is requested
                return @(
                    [PSCustomObject]@{ id = 11; userId = 2; title = 'Page 2 Post 1'; body = 'Body' },
                    [PSCustomObject]@{ id = 12; userId = 2; title = 'Page 2 Post 2'; body = 'Body' }
                )
            }
        }

        It 'passes page and limit query parameters to the API' {
            Get-Posts -Page 2 -Limit 10 | Out-Null
            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $Uri -match '_page=2' -and $Uri -match '_limit=10'
            }
        }

        It 'defaults to page 1 with limit 10' {
            Get-Posts | Out-Null
            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $Uri -match '_page=1' -and $Uri -match '_limit=10'
            }
        }

        It 'returns results from the requested page' {
            $posts = Get-Posts -Page 2 -Limit 10
            $posts[0].id | Should -Be 11
        }
    }

    Context 'when fetching all pages' {
        BeforeAll {
            # Simulate 2 pages of results: first call returns 2 items, second returns 1, third returns empty
            $script:callCount = 0
            Mock Invoke-RestMethod {
                $script:callCount++
                if ($script:callCount -eq 1) {
                    return @(
                        [PSCustomObject]@{ id = 1; userId = 1; title = 'P1'; body = 'B' },
                        [PSCustomObject]@{ id = 2; userId = 1; title = 'P2'; body = 'B' }
                    )
                } elseif ($script:callCount -eq 2) {
                    return @(
                        [PSCustomObject]@{ id = 3; userId = 1; title = 'P3'; body = 'B' }
                    )
                } else {
                    return @()
                }
            }
        }

        It 'fetches all pages and combines results' {
            $script:callCount = 0
            $allPosts = Get-AllPosts -Limit 2
            $allPosts.Count | Should -Be 3
            $allPosts[2].id | Should -Be 3
        }

        It 'stops when an empty page is returned' {
            $script:callCount = 0
            Get-AllPosts -Limit 2 | Out-Null
            # Should have made 3 calls: page 1 (2 items), page 2 (1 item), page 3 (empty)
            Should -Invoke Invoke-RestMethod -Times 3 -Exactly
        }
    }
}

Describe 'Invoke-WithRetry' {
    Context 'when the action succeeds on first try' {
        It 'returns the result without retrying' {
            $result = Invoke-WithRetry -ScriptBlock { 'success' } -MaxRetries 3
            $result | Should -Be 'success'
        }
    }

    Context 'when the action fails then succeeds' {
        It 'retries and returns the result on eventual success' {
            $script:retryAttempt = 0
            $result = Invoke-WithRetry -ScriptBlock {
                $script:retryAttempt++
                if ($script:retryAttempt -lt 3) {
                    throw "Transient error attempt $($script:retryAttempt)"
                }
                'recovered'
            } -MaxRetries 5 -BaseDelayMs 1  # tiny delay for fast tests
            $result | Should -Be 'recovered'
            $script:retryAttempt | Should -Be 3
        }
    }

    Context 'when all retries are exhausted' {
        It 'throws the last error after max retries' {
            {
                Invoke-WithRetry -ScriptBlock {
                    throw 'persistent failure'
                } -MaxRetries 3 -BaseDelayMs 1
            } | Should -Throw '*persistent failure*'
        }
    }

    Context 'exponential backoff timing' {
        It 'calls Start-Sleep with increasing delays' {
            Mock Start-Sleep {}
            $script:retryAttempt2 = 0
            try {
                Invoke-WithRetry -ScriptBlock {
                    $script:retryAttempt2++
                    throw 'fail'
                } -MaxRetries 3 -BaseDelayMs 100
            } catch {}
            # Backoff: 100ms, 200ms, 400ms (doubling each time)
            Should -Invoke Start-Sleep -Times 3 -Exactly
            # Verify increasing delays: 0.1s, 0.2s, 0.4s
            Should -Invoke Start-Sleep -ParameterFilter { $Seconds -eq 0.1 } -Times 1
            Should -Invoke Start-Sleep -ParameterFilter { $Seconds -eq 0.2 } -Times 1
            Should -Invoke Start-Sleep -ParameterFilter { $Seconds -eq 0.4 } -Times 1
        }
    }
}

Describe 'Cache functions' {
    BeforeAll {
        # Use a temp directory for cache tests so we don't pollute the workspace
        $script:testCacheDir = Join-Path ([System.IO.Path]::GetTempPath()) "pester-cache-$(Get-Random)"
    }

    AfterAll {
        # Clean up test cache directory
        if (Test-Path $script:testCacheDir) {
            Remove-Item -Recurse -Force $script:testCacheDir
        }
    }

    Context 'Save-ToCache' {
        It 'creates the cache directory if it does not exist' {
            $data = @([PSCustomObject]@{ id = 1; title = 'Cached Post' })
            Save-ToCache -Key 'posts' -Data $data -CacheDir $script:testCacheDir
            Test-Path $script:testCacheDir | Should -BeTrue
        }

        It 'writes data as a JSON file' {
            $data = @([PSCustomObject]@{ id = 1; title = 'Cached Post' })
            Save-ToCache -Key 'posts' -Data $data -CacheDir $script:testCacheDir
            $filePath = Join-Path $script:testCacheDir 'posts.json'
            Test-Path $filePath | Should -BeTrue
        }

        It 'stores valid JSON content' {
            $data = @([PSCustomObject]@{ id = 1; title = 'Cached Post' })
            Save-ToCache -Key 'test-json' -Data $data -CacheDir $script:testCacheDir
            $filePath = Join-Path $script:testCacheDir 'test-json.json'
            $content = Get-Content -Path $filePath -Raw
            $parsed = $content | ConvertFrom-Json
            $parsed[0].id | Should -Be 1
            $parsed[0].title | Should -Be 'Cached Post'
        }
    }

    Context 'Get-FromCache' {
        It 'returns cached data when cache file exists and is fresh' {
            $data = @([PSCustomObject]@{ id = 99; title = 'Fresh' })
            Save-ToCache -Key 'fresh-data' -Data $data -CacheDir $script:testCacheDir
            $result = Get-FromCache -Key 'fresh-data' -MaxAgeMinutes 60 -CacheDir $script:testCacheDir
            $result | Should -Not -BeNullOrEmpty
            $result[0].id | Should -Be 99
        }

        It 'returns null when cache file does not exist' {
            $result = Get-FromCache -Key 'nonexistent' -MaxAgeMinutes 60 -CacheDir $script:testCacheDir
            $result | Should -BeNullOrEmpty
        }

        It 'returns null when cache file is stale' {
            $data = @([PSCustomObject]@{ id = 1; title = 'Old' })
            Save-ToCache -Key 'stale-data' -Data $data -CacheDir $script:testCacheDir
            # Artificially set file write time to 2 hours ago
            $filePath = Join-Path $script:testCacheDir 'stale-data.json'
            (Get-Item $filePath).LastWriteTime = (Get-Date).AddHours(-2)
            $result = Get-FromCache -Key 'stale-data' -MaxAgeMinutes 60 -CacheDir $script:testCacheDir
            $result | Should -BeNullOrEmpty
        }
    }
}

Describe 'Get-PostsWithComments' {
    BeforeAll {
        $script:integrationCacheDir = Join-Path ([System.IO.Path]::GetTempPath()) "pester-integration-$(Get-Random)"
    }

    AfterAll {
        if (Test-Path $script:integrationCacheDir) {
            Remove-Item -Recurse -Force $script:integrationCacheDir
        }
    }

    Context 'when fetching posts with their comments' {
        BeforeAll {
            # Mock Invoke-RestMethod to return different data based on the URI.
            # Check comments URLs first — the -like '?' wildcard in '*/posts?*' would
            # also match '/posts/1/comments', so more specific patterns go first.
            Mock Invoke-RestMethod {
                if ($Uri -like '*/posts/1/comments*') {
                    return @(
                        [PSCustomObject]@{ id = 10; postId = 1; name = 'C1'; email = 'a@b.com'; body = 'Comment on post 1' }
                    )
                } elseif ($Uri -like '*/posts/2/comments*') {
                    return @(
                        [PSCustomObject]@{ id = 20; postId = 2; name = 'C2'; email = 'c@d.com'; body = 'Comment on post 2' },
                        [PSCustomObject]@{ id = 21; postId = 2; name = 'C3'; email = 'e@f.com'; body = 'Another comment' }
                    )
                } elseif ($Uri -match '/posts\?') {
                    return @(
                        [PSCustomObject]@{ id = 1; userId = 1; title = 'Post 1'; body = 'Body 1' },
                        [PSCustomObject]@{ id = 2; userId = 1; title = 'Post 2'; body = 'Body 2' }
                    )
                }
            }
}

        It 'returns posts with a comments property attached' {
            $result = Get-PostsWithComments -Page 1 -Limit 10 -CacheDir $script:integrationCacheDir
            $result.Count | Should -Be 2
            $result[0].PSObject.Properties.Name | Should -Contain 'comments'
        }

        It 'attaches the correct comments to each post' {
            $result = Get-PostsWithComments -Page 1 -Limit 10 -CacheDir $script:integrationCacheDir
            @($result[0].comments).Count | Should -Be 1
            $result[0].comments[0].name | Should -Be 'C1'
            @($result[1].comments).Count | Should -Be 2
        }

        It 'caches results to a JSON file' {
            Get-PostsWithComments -Page 1 -Limit 10 -CacheDir $script:integrationCacheDir | Out-Null
            $cacheFile = Join-Path $script:integrationCacheDir 'posts-with-comments-page1.json'
            Test-Path $cacheFile | Should -BeTrue
        }

        It 'uses cache on second call instead of hitting the API again' {
            # First call populates cache
            Get-PostsWithComments -Page 1 -Limit 10 -CacheDir $script:integrationCacheDir | Out-Null
            # Reset the mock call count by checking before/after
            $beforeCount = (Get-Command Invoke-RestMethod).Version  # dummy to reset scope
            # Second call should use cache — no new Invoke-RestMethod calls
            Mock Invoke-RestMethod { throw 'Should not be called — cache should be used' }
            $result = Get-PostsWithComments -Page 1 -Limit 10 -CacheDir $script:integrationCacheDir
            $result.Count | Should -Be 2
        }
    }
}

Describe 'Error handling' {
    Context 'when the API returns an error' {
        BeforeAll {
            Mock Invoke-RestMethod { throw 'HTTP 500 Internal Server Error' }
            Mock Start-Sleep {}
        }

        It 'Get-Posts throws a meaningful error after retries' {
            $errorCacheDir = Join-Path ([System.IO.Path]::GetTempPath()) "pester-err-$(Get-Random)"
            {
                Get-PostsWithComments -Page 1 -Limit 10 -CacheDir $errorCacheDir -MaxRetries 2 -BaseDelayMs 1
            } | Should -Throw '*HTTP 500*'
            if (Test-Path $errorCacheDir) { Remove-Item -Recurse -Force $errorCacheDir }
        }
    }

    Context 'when PostId is invalid' {
        BeforeAll {
            Mock Invoke-RestMethod { return @() }
        }

        It 'Get-Comments returns empty for non-existent post' {
            $result = Get-Comments -PostId 99999
            @($result).Count | Should -Be 0
        }
    }
}
