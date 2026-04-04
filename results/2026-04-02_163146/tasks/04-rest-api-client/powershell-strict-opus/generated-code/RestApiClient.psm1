Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# =============================================================================
# RestApiClient Module
# Fetches posts and comments from JSONPlaceholder with retry, pagination, caching.
# Developed with TDD — each function was test-driven (see RestApiClient.Tests.ps1).
# =============================================================================

# Module-level configuration
[string]$script:BaseUrl = 'https://jsonplaceholder.typicode.com'
[string]$script:CacheDirectory = (Join-Path -Path $PSScriptRoot -ChildPath '.cache')

# ---------------------------------------------------------------------------
# TDD Round 1: Invoke-RestMethodWithRetry
# RED:  Test expected retry behavior with exponential backoff on failure
# GREEN: Implement retry loop with configurable max retries and delay
# ---------------------------------------------------------------------------

function Invoke-RestMethodWithRetry {
    <#
    .SYNOPSIS
        Invokes a REST method with exponential backoff retry on transient failures.
    .DESCRIPTION
        Wraps Invoke-RestMethod with retry logic. On failure, waits an exponentially
        increasing delay before retrying up to MaxRetries times.
    #>
    [CmdletBinding()]
    [OutputType([PSObject[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Uri,

        [Parameter()]
        [int]$MaxRetries = 3,

        [Parameter()]
        [double]$BaseDelaySeconds = 1.0,

        [Parameter()]
        [string]$Method = 'Get'
    )

    [int]$attempt = 0

    while ($true) {
        $attempt++
        try {
            # Call the actual REST API — this is what tests mock
            [PSObject[]]$response = Invoke-RestMethod -Uri $Uri -Method $Method
            return $response
        }
        catch {
            if ($attempt -gt $MaxRetries) {
                # All retries exhausted — throw a meaningful error
                [string]$errorMsg = "REST call to '$Uri' failed after $MaxRetries retries. Last error: $($_.Exception.Message)"
                throw [System.InvalidOperationException]::new($errorMsg)
            }

            # Exponential backoff: BaseDelay * 2^(attempt-1)
            [double]$delay = $BaseDelaySeconds * [Math]::Pow(2, ($attempt - 1))
            Write-Warning "Attempt $attempt/$MaxRetries failed for '$Uri'. Retrying in $delay seconds... Error: $($_.Exception.Message)"
            Start-Sleep -Milliseconds ([int]($delay * 1000))
        }
    }
}

# ---------------------------------------------------------------------------
# TDD Round 2: Write-Cache / Read-Cache
# RED:  Test that data is written to and read from JSON files
# GREEN: Implement file-based JSON caching with key-based filenames
# ---------------------------------------------------------------------------

function Write-Cache {
    <#
    .SYNOPSIS
        Writes data to a local JSON cache file.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter(Mandatory)]
        [PSObject[]]$Data,

        [Parameter()]
        [string]$CacheDir = $script:CacheDirectory
    )

    # Ensure the cache directory exists
    if (-not (Test-Path -Path $CacheDir)) {
        New-Item -Path $CacheDir -ItemType Directory -Force | Out-Null
    }

    [string]$filePath = Join-Path -Path $CacheDir -ChildPath "$Key.json"
    # Use -InputObject with @() wrapper to preserve array structure for single items
    [string]$json = ConvertTo-Json -InputObject @($Data) -Depth 10
    Set-Content -Path $filePath -Value $json -Encoding UTF8
}

function Read-Cache {
    <#
    .SYNOPSIS
        Reads data from a local JSON cache file if it exists.
    .DESCRIPTION
        Returns cached data as PSObject array, or $null if the cache file does not exist.
    #>
    [CmdletBinding()]
    [OutputType([PSObject[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter()]
        [string]$CacheDir = $script:CacheDirectory
    )

    [string]$filePath = Join-Path -Path $CacheDir -ChildPath "$Key.json"

    if (-not (Test-Path -Path $filePath)) {
        return $null
    }

    [string]$json = Get-Content -Path $filePath -Raw -Encoding UTF8
    [PSObject[]]$data = $json | ConvertFrom-Json
    return $data
}

function Clear-Cache {
    <#
    .SYNOPSIS
        Removes all cached JSON files from the cache directory.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter()]
        [string]$CacheDir = $script:CacheDirectory
    )

    if (Test-Path -Path $CacheDir) {
        Remove-Item -Path $CacheDir -Recurse -Force
    }
}

# ---------------------------------------------------------------------------
# TDD Round 3: Get-Posts
# RED:  Test that Get-Posts returns posts from the API
# GREEN: Implement Get-Posts with caching support
# ---------------------------------------------------------------------------

function Get-Posts {
    <#
    .SYNOPSIS
        Fetches all posts from JSONPlaceholder, with optional caching.
    .DESCRIPTION
        Retrieves posts using pagination (_start/_limit params). Results are
        cached locally if UseCache is specified. Mocked in tests via
        Invoke-RestMethodWithRetry.
    #>
    [CmdletBinding()]
    [OutputType([PSObject[]])]
    param(
        [Parameter()]
        [switch]$UseCache,

        [Parameter()]
        [string]$CacheDir = $script:CacheDirectory
    )

    [string]$cacheKey = 'posts'

    # Check cache first if requested
    if ($UseCache) {
        [PSObject[]]$cached = Read-Cache -Key $cacheKey -CacheDir $CacheDir
        if ($null -ne $cached) {
            Write-Verbose 'Returning cached posts'
            return $cached
        }
    }

    # Fetch all posts (JSONPlaceholder returns all 100 by default at /posts)
    [string]$uri = "$script:BaseUrl/posts"
    [PSObject[]]$posts = Invoke-RestMethodWithRetry -Uri $uri

    # Cache the result if requested
    if ($UseCache) {
        Write-Cache -Key $cacheKey -Data $posts -CacheDir $CacheDir
    }

    return $posts
}

# ---------------------------------------------------------------------------
# TDD Round 4: Get-Comments
# RED:  Test that Get-Comments returns comments for a given post ID
# GREEN: Implement Get-Comments with caching
# ---------------------------------------------------------------------------

function Get-Comments {
    <#
    .SYNOPSIS
        Fetches comments for a specific post from JSONPlaceholder.
    #>
    [CmdletBinding()]
    [OutputType([PSObject[]])]
    param(
        [Parameter(Mandatory)]
        [int]$PostId,

        [Parameter()]
        [switch]$UseCache,

        [Parameter()]
        [string]$CacheDir = $script:CacheDirectory
    )

    [string]$cacheKey = "comments_post_$PostId"

    if ($UseCache) {
        [PSObject[]]$cached = Read-Cache -Key $cacheKey -CacheDir $CacheDir
        if ($null -ne $cached) {
            Write-Verbose "Returning cached comments for post $PostId"
            return $cached
        }
    }

    [string]$uri = "$script:BaseUrl/posts/$PostId/comments"
    [PSObject[]]$comments = Invoke-RestMethodWithRetry -Uri $uri

    if ($UseCache) {
        Write-Cache -Key $cacheKey -Data $comments -CacheDir $CacheDir
    }

    return $comments
}

# ---------------------------------------------------------------------------
# TDD Round 5: Get-PaginatedPosts
# RED:  Test that pagination parameters are correctly applied
# GREEN: Implement paginated fetching with _start/_limit
# ---------------------------------------------------------------------------

function Get-PaginatedPosts {
    <#
    .SYNOPSIS
        Fetches posts with pagination support using _start and _limit parameters.
    .DESCRIPTION
        Uses JSONPlaceholder's _start/_limit query params to fetch posts in pages.
        Iterates until an empty page is returned or all posts are collected.
    #>
    [CmdletBinding()]
    [OutputType([PSObject[]])]
    param(
        [Parameter()]
        [int]$PageSize = 10,

        [Parameter()]
        [switch]$UseCache,

        [Parameter()]
        [string]$CacheDir = $script:CacheDirectory
    )

    [string]$cacheKey = "posts_paginated_$PageSize"

    if ($UseCache) {
        [PSObject[]]$cached = Read-Cache -Key $cacheKey -CacheDir $CacheDir
        if ($null -ne $cached) {
            Write-Verbose 'Returning cached paginated posts'
            return $cached
        }
    }

    [System.Collections.Generic.List[PSObject]]$allPosts = [System.Collections.Generic.List[PSObject]]::new()
    [int]$start = 0

    while ($true) {
        [string]$uri = "$script:BaseUrl/posts?_start=$start&_limit=$PageSize"
        [PSObject[]]$page = Invoke-RestMethodWithRetry -Uri $uri

        if ($null -eq $page -or $page.Count -eq 0) {
            # No more results — exit pagination loop
            break
        }

        foreach ($post in $page) {
            $allPosts.Add($post)
        }

        # If we got fewer items than PageSize, we've reached the last page
        if ($page.Count -lt $PageSize) {
            break
        }

        $start += $PageSize
    }

    [PSObject[]]$result = $allPosts.ToArray()

    if ($UseCache) {
        Write-Cache -Key $cacheKey -Data $result -CacheDir $CacheDir
    }

    return $result
}

# ---------------------------------------------------------------------------
# TDD Round 6: Get-PostsWithComments (orchestration)
# RED:  Test that posts are fetched and each is enriched with its comments
# GREEN: Implement the orchestrator that combines posts + comments
# ---------------------------------------------------------------------------

function Get-PostsWithComments {
    <#
    .SYNOPSIS
        Fetches posts and enriches each with its comments.
    .DESCRIPTION
        For each post fetched from the API, retrieves the associated comments
        and attaches them as a 'comments' property. Supports caching.
    #>
    [CmdletBinding()]
    [OutputType([PSObject[]])]
    param(
        [Parameter()]
        [int]$MaxPosts = 0,

        [Parameter()]
        [switch]$UseCache,

        [Parameter()]
        [string]$CacheDir = $script:CacheDirectory
    )

    [hashtable]$cacheArgs = @{}
    if ($UseCache) {
        $cacheArgs['UseCache'] = $true
        $cacheArgs['CacheDir'] = $CacheDir
    }

    [PSObject[]]$posts = Get-Posts @cacheArgs

    # Optionally limit how many posts to enrich (0 = all)
    if ($MaxPosts -gt 0 -and $posts.Count -gt $MaxPosts) {
        $posts = $posts[0..($MaxPosts - 1)]
    }

    [System.Collections.Generic.List[PSObject]]$enriched = [System.Collections.Generic.List[PSObject]]::new()

    foreach ($post in $posts) {
        [PSObject[]]$comments = Get-Comments -PostId ([int]$post.id) @cacheArgs

        # Create an enriched copy with comments attached
        [PSCustomObject]$enrichedPost = [PSCustomObject]@{
            userId   = $post.userId
            id       = $post.id
            title    = $post.title
            body     = $post.body
            comments = $comments
        }
        $enriched.Add($enrichedPost)
    }

    return [PSObject[]]$enriched.ToArray()
}

# Export all public functions
Export-ModuleMember -Function @(
    'Invoke-RestMethodWithRetry'
    'Write-Cache'
    'Read-Cache'
    'Clear-Cache'
    'Get-Posts'
    'Get-Comments'
    'Get-PaginatedPosts'
    'Get-PostsWithComments'
)
