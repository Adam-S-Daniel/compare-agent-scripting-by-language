# ApiClient.ps1
# REST API Client for JSONPlaceholder (https://jsonplaceholder.typicode.com)
#
# Features:
#   - Fetch posts and their comments
#   - Automatic pagination (Get-AllPosts)
#   - Retry with exponential backoff (Invoke-ApiRequestWithRetry)
#   - Local JSON file caching (Get-CachedData / Save-CachedData)
#
# TDD NOTE: This implementation was written AFTER the tests in ApiClient.Tests.ps1
# to satisfy each failing test in order (red → green for each Describe block).

#Requires -Version 5.1

# Base URL for the JSONPlaceholder API
$script:BaseUrl = "https://jsonplaceholder.typicode.com"

# Default cache directory (relative to this script).
# Tests override this via the -CacheDirectory parameter.
$script:DefaultCacheDir = Join-Path $PSScriptRoot "cache"

# ===========================================================================
# CORE HTTP — retry with exponential backoff
# ===========================================================================

function Invoke-ApiRequestWithRetry {
    <#
    .SYNOPSIS
        Issues an HTTP GET request, retrying with exponential backoff on failure.

    .DESCRIPTION
        Each failure increments an attempt counter. Before retrying, the function
        sleeps for  BaseDelaySeconds * 2^(attempt-1)  seconds:
            attempt 1 failed → sleep BaseDelay  (2^0 = 1x)
            attempt 2 failed → sleep 2*BaseDelay (2^1 = 2x)
            attempt 3 failed → sleep 4*BaseDelay (2^2 = 4x)
            ...
        After MaxRetries failures, an error is thrown.

    .PARAMETER Uri
        The full URL to request.

    .PARAMETER MaxRetries
        Maximum number of attempts (default 3).

    .PARAMETER BaseDelaySeconds
        Initial delay in seconds before the first retry (default 1).
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Uri,

        [int]$MaxRetries = 3,

        [int]$BaseDelaySeconds = 1
    )

    $attempt = 0

    while ($true) {
        try {
            return Invoke-RestMethod -Uri $Uri -Method Get
        }
        catch {
            $attempt++

            if ($attempt -ge $MaxRetries) {
                # All retries exhausted — surface a clear error message
                throw "API request to '$Uri' failed after $MaxRetries attempt(s). Last error: $_"
            }

            # Exponential backoff: 1s → 2s → 4s → ...
            $delay = [int]($BaseDelaySeconds * [Math]::Pow(2, $attempt - 1))
            Write-Verbose "Attempt $attempt/$MaxRetries failed ($($_.Exception.Message)). Retrying in ${delay}s..."
            Start-Sleep -Seconds $delay
        }
    }
}

# ===========================================================================
# CACHING — JSON file-based local cache
# ===========================================================================

function Get-CachedData {
    <#
    .SYNOPSIS
        Reads a cached object from a JSON file.

    .PARAMETER CacheKey
        Logical name for the cache entry. The file is <CacheDirectory>/<CacheKey>.json.

    .PARAMETER CacheDirectory
        Root directory for cache files. Defaults to $script:DefaultCacheDir.

    .OUTPUTS
        Deserialized object on cache hit; $null on cache miss.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$CacheKey,

        [string]$CacheDirectory = $script:DefaultCacheDir
    )

    $cachePath = Join-Path $CacheDirectory "$CacheKey.json"

    if (Test-Path $cachePath) {
        Write-Verbose "Cache HIT: $CacheKey"
        return Get-Content $cachePath -Raw | ConvertFrom-Json
    }

    Write-Verbose "Cache MISS: $CacheKey"
    return $null
}

function Save-CachedData {
    <#
    .SYNOPSIS
        Serializes an object to a JSON cache file.

    .PARAMETER CacheKey
        Logical key for this cache entry.

    .PARAMETER Data
        The object to serialize and store.

    .PARAMETER CacheDirectory
        Root directory for cache files. Created if it doesn't exist.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$CacheKey,

        [Parameter(Mandatory)]
        $Data,

        [string]$CacheDirectory = $script:DefaultCacheDir
    )

    # Ensure the cache directory exists
    if (-not (Test-Path $CacheDirectory)) {
        New-Item -ItemType Directory -Path $CacheDirectory -Force | Out-Null
    }

    $cachePath = Join-Path $CacheDirectory "$CacheKey.json"
    $Data | ConvertTo-Json -Depth 10 | Set-Content $cachePath
    Write-Verbose "Cached $CacheKey → $cachePath"
}

# ===========================================================================
# POSTS
# ===========================================================================

function Get-Posts {
    <#
    .SYNOPSIS
        Fetches a single page of posts from the JSONPlaceholder API.

    .PARAMETER Page
        1-based page number. Passed as ?_page=N.

    .PARAMETER Limit
        Items per page. Passed as ?_limit=N.

    .PARAMETER UseCache
        When set, reads from cache if available and writes result to cache.

    .PARAMETER CacheDirectory
        Cache root override (mainly for testing).
    #>
    param(
        [int]$Page = 1,
        [int]$Limit = 10,
        [switch]$UseCache,
        [string]$CacheDirectory = $script:DefaultCacheDir
    )

    $cacheKey = "posts_page${Page}_limit${Limit}"

    if ($UseCache) {
        $cached = Get-CachedData -CacheKey $cacheKey -CacheDirectory $CacheDirectory
        if ($null -ne $cached) {
            return $cached
        }
    }

    $uri = "$($script:BaseUrl)/posts?_page=${Page}&_limit=${Limit}"
    $posts = Invoke-ApiRequestWithRetry -Uri $uri

    if ($UseCache) {
        Save-CachedData -CacheKey $cacheKey -Data $posts -CacheDirectory $CacheDirectory
    }

    return $posts
}

function Get-AllPosts {
    <#
    .SYNOPSIS
        Fetches ALL posts by iterating through pages until an empty page is returned.

    .DESCRIPTION
        Pagination strategy: request page 1, then page 2, etc.
        Stop when a page returns zero results.

    .PARAMETER Limit
        Posts per page (controls how many API calls are made).

    .PARAMETER UseCache
        Pass-through to Get-Posts for per-page caching.

    .PARAMETER CacheDirectory
        Cache root override.
    #>
    param(
        [int]$Limit = 10,
        [switch]$UseCache,
        [string]$CacheDirectory = $script:DefaultCacheDir
    )

    $allPosts = @()
    $currentPage = 1

    do {
        $page = Get-Posts -Page $currentPage -Limit $Limit `
                          -UseCache:$UseCache -CacheDirectory $CacheDirectory

        # PowerShell functions returning @() yield $null at the call-site, so
        # both the null check and the Count==0 check are needed for robustness.
        if ($null -eq $page) { break }

        # @() wrapper ensures we always work with an array (handles PS5 scalar-unwrap)
        $pageArray = @($page)
        if ($pageArray.Count -eq 0) { break }

        $allPosts += $pageArray
        $currentPage++

    } while ($true)

    return $allPosts
}

# ===========================================================================
# COMMENTS
# ===========================================================================

function Get-PostComments {
    <#
    .SYNOPSIS
        Fetches all comments for a specific post.

    .PARAMETER PostId
        ID of the post whose comments to retrieve.

    .PARAMETER UseCache
        When set, reads from cache if available and writes result to cache.

    .PARAMETER CacheDirectory
        Cache root override.
    #>
    param(
        [Parameter(Mandatory)]
        [int]$PostId,

        [switch]$UseCache,
        [string]$CacheDirectory = $script:DefaultCacheDir
    )

    $cacheKey = "post_${PostId}_comments"

    if ($UseCache) {
        $cached = Get-CachedData -CacheKey $cacheKey -CacheDirectory $CacheDirectory
        if ($null -ne $cached) {
            return $cached
        }
    }

    $uri = "$($script:BaseUrl)/posts/${PostId}/comments"
    $comments = Invoke-ApiRequestWithRetry -Uri $uri

    if ($UseCache) {
        Save-CachedData -CacheKey $cacheKey -Data $comments -CacheDirectory $CacheDirectory
    }

    return $comments
}

# ===========================================================================
# COMBINED — posts enriched with their comments
# ===========================================================================

function Get-PostsWithComments {
    <#
    .SYNOPSIS
        Fetches a page of posts and enriches each post with its comments.

    .OUTPUTS
        Array of [PSCustomObject]@{ Post = ...; Comments = @(...) }
    #>
    param(
        [int]$Page = 1,
        [int]$Limit = 10,
        [switch]$UseCache,
        [string]$CacheDirectory = $script:DefaultCacheDir
    )

    $posts = Get-Posts -Page $Page -Limit $Limit `
                       -UseCache:$UseCache -CacheDirectory $CacheDirectory

    # Use @() to guarantee the result is always an array even for a single post
    $result = @(foreach ($post in $posts) {
        $comments = Get-PostComments -PostId $post.id `
                                     -UseCache:$UseCache -CacheDirectory $CacheDirectory
        [PSCustomObject]@{
            Post     = $post
            Comments = $comments
        }
    })

    return $result
}
