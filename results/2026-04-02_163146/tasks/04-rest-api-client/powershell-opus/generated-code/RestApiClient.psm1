# RestApiClient.psm1
# REST API client for JSONPlaceholder (https://jsonplaceholder.typicode.com).
#
# Features:
#   - Fetch posts and comments
#   - Pagination support (_page / _limit query parameters)
#   - Retry with exponential backoff on transient failures
#   - Local JSON file caching
#
# Design: every function that touches the network uses Invoke-RestMethod,
# which Pester can mock at the module level for deterministic testing.

$script:BaseUrl   = 'https://jsonplaceholder.typicode.com'
$script:CacheDir  = Join-Path $PSScriptRoot '.cache'

# ── TDD Cycle 1 — Get-Posts ───────────────────────────────────────────────────
# RED:   test calls Get-Posts, function doesn't exist → CommandNotFoundException
# GREEN: minimal implementation that calls the API and returns the result

function Get-Posts {
    <#
    .SYNOPSIS
        Fetches posts from JSONPlaceholder. Supports pagination via -Page and -Limit.
    #>
    [CmdletBinding()]
    param(
        [int]$Page  = 0,
        [int]$Limit = 0
    )

    $uri = "$script:BaseUrl/posts"
    $queryParts = @()
    if ($Page -gt 0)  { $queryParts += "_page=$Page" }
    if ($Limit -gt 0) { $queryParts += "_limit=$Limit" }
    if ($queryParts.Count -gt 0) {
        $uri += '?' + ($queryParts -join '&')
    }

    Invoke-RestMethodWithRetry -Uri $uri
}

# ── TDD Cycle 2 — Get-Comments ────────────────────────────────────────────────
# RED:   test calls Get-Comments -PostId 1, function doesn't exist
# GREEN: minimal implementation returning comments for a given post

function Get-Comments {
    <#
    .SYNOPSIS
        Fetches comments for a specific post (or all comments) from JSONPlaceholder.
    #>
    [CmdletBinding()]
    param(
        [int]$PostId = 0
    )

    if ($PostId -gt 0) {
        $uri = "$script:BaseUrl/posts/$PostId/comments"
    } else {
        $uri = "$script:BaseUrl/comments"
    }

    Invoke-RestMethodWithRetry -Uri $uri
}

# ── TDD Cycle 3 — Retry with exponential backoff ──────────────────────────────
# RED:   test forces Invoke-RestMethod to throw twice then succeed; expects 3 calls
# GREEN: wrapper that retries on failure with exponential delay

function Invoke-RestMethodWithRetry {
    <#
    .SYNOPSIS
        Wraps Invoke-RestMethod with retry logic and exponential backoff.
    .DESCRIPTION
        On transient errors the call is retried up to MaxRetries times.
        The delay between attempts doubles each time: BaseDelay * 2^attempt (seconds).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Uri,
        [int]$MaxRetries = 3,
        [double]$BaseDelay = 0.5
    )

    $attempt = 0
    while ($true) {
        try {
            $result = Invoke-RestMethod -Uri $Uri -ErrorAction Stop
            return $result
        }
        catch {
            $attempt++
            if ($attempt -gt $MaxRetries) {
                # All retries exhausted — surface a meaningful error
                throw "Request to '$Uri' failed after $MaxRetries retries: $_"
            }
            # Exponential backoff: 0.5s, 1s, 2s, ...
            $delay = $BaseDelay * [Math]::Pow(2, $attempt - 1)
            Write-Verbose "Attempt $attempt failed for '$Uri'. Retrying in ${delay}s..."
            Start-Sleep -Milliseconds ([int]($delay * 1000))
        }
    }
}

# ── TDD Cycle 4 — Local JSON caching ──────────────────────────────────────────
# RED:   test calls Get-PostsCached; second call should NOT hit the API
# GREEN: write-through cache that persists results to .cache/*.json

function Get-PostsCached {
    <#
    .SYNOPSIS
        Returns posts, using a local JSON cache to avoid redundant API calls.
    #>
    [CmdletBinding()]
    param(
        [int]$Page  = 0,
        [int]$Limit = 0,
        [switch]$ForceRefresh
    )

    $cacheKey  = "posts_page${Page}_limit${Limit}"
    $cacheFile = Join-Path $script:CacheDir "$cacheKey.json"

    # Return cached data if available and not forcing refresh
    if (-not $ForceRefresh -and (Test-Path $cacheFile)) {
        $json = Get-Content $cacheFile -Raw
        return ($json | ConvertFrom-Json)
    }

    # Fetch from the API
    $data = Get-Posts -Page $Page -Limit $Limit

    # Persist to cache
    if (-not (Test-Path $script:CacheDir)) {
        New-Item -ItemType Directory -Path $script:CacheDir -Force | Out-Null
    }
    $data | ConvertTo-Json -Depth 10 | Set-Content $cacheFile -Encoding UTF8

    return $data
}

function Get-CommentsCached {
    <#
    .SYNOPSIS
        Returns comments for a post, using a local JSON cache.
    #>
    [CmdletBinding()]
    param(
        [int]$PostId = 0,
        [switch]$ForceRefresh
    )

    $cacheKey  = "comments_post${PostId}"
    $cacheFile = Join-Path $script:CacheDir "$cacheKey.json"

    if (-not $ForceRefresh -and (Test-Path $cacheFile)) {
        $json = Get-Content $cacheFile -Raw
        return ($json | ConvertFrom-Json)
    }

    $data = Get-Comments -PostId $PostId

    if (-not (Test-Path $script:CacheDir)) {
        New-Item -ItemType Directory -Path $script:CacheDir -Force | Out-Null
    }
    $data | ConvertTo-Json -Depth 10 | Set-Content $cacheFile -Encoding UTF8

    return $data
}

function Clear-ApiCache {
    <#
    .SYNOPSIS
        Removes all cached JSON files.
    #>
    [CmdletBinding()]
    param()

    if (Test-Path $script:CacheDir) {
        Remove-Item -Path $script:CacheDir -Recurse -Force
    }
}

# ── TDD Cycle 5 — Pagination helper ───────────────────────────────────────────
# RED:   test calls Get-AllPosts -PageSize 2 with 5 total posts; expects all 5
# GREEN: loop that fetches pages until an empty page is returned

function Get-AllPosts {
    <#
    .SYNOPSIS
        Fetches all posts by iterating through pages until no more data is returned.
    #>
    [CmdletBinding()]
    param(
        [int]$PageSize = 10
    )

    $allPosts = @()
    $page = 1

    while ($true) {
        $batch = Get-Posts -Page $page -Limit $PageSize

        # JSONPlaceholder returns an empty array when past the last page
        if (-not $batch -or $batch.Count -eq 0) {
            break
        }

        $allPosts += $batch
        $page++
    }

    return $allPosts
}

# ── TDD Cycle 6 — Get-PostsWithComments ───────────────────────────────────────
# RED:   test calls Get-PostsWithComments; expects each post to have a Comments property
# GREEN: fetch posts then attach their comments

function Get-PostsWithComments {
    <#
    .SYNOPSIS
        Fetches posts and attaches each post's comments as a nested property.
    #>
    [CmdletBinding()]
    param(
        [int]$Page  = 0,
        [int]$Limit = 0
    )

    $posts = Get-Posts -Page $Page -Limit $Limit

    foreach ($post in $posts) {
        $comments = Get-Comments -PostId $post.id
        $post | Add-Member -NotePropertyName 'comments' -NotePropertyValue $comments -Force
    }

    return $posts
}

# Export public functions
Export-ModuleMember -Function @(
    'Get-Posts'
    'Get-Comments'
    'Invoke-RestMethodWithRetry'
    'Get-PostsCached'
    'Get-CommentsCached'
    'Clear-ApiCache'
    'Get-AllPosts'
    'Get-PostsWithComments'
)
