# JSONPlaceholder REST API Client
# Fetches posts and comments with retry logic, pagination, and local caching.

$script:BaseUrl = 'https://jsonplaceholder.typicode.com'

function Get-Posts {
    <#
    .SYNOPSIS
        Fetches posts from the JSONPlaceholder API with pagination support.
    .PARAMETER Page
        Page number (1-based). Defaults to 1.
    .PARAMETER Limit
        Number of posts per page. Defaults to 10.
    #>
    param(
        [int]$Page = 1,
        [int]$Limit = 10
    )
    # JSONPlaceholder supports _page and _limit query parameters for pagination
    $uri = "$script:BaseUrl/posts?_page=$Page&_limit=$Limit"
    $response = Invoke-RestMethod -Uri $uri -Method Get
    return $response
}

function Get-AllPosts {
    <#
    .SYNOPSIS
        Fetches all posts by iterating through pages until an empty page is returned.
    #>
    param(
        [int]$Limit = 10
    )
    $allPosts = @()
    $page = 1
    do {
        $posts = Get-Posts -Page $page -Limit $Limit
        if ($null -eq $posts -or @($posts).Count -eq 0) {
            break
        }
        $allPosts += @($posts)
        $page++
    } while ($true)
    return $allPosts
}

function Get-Comments {
    <#
    .SYNOPSIS
        Fetches comments for a specific post from the JSONPlaceholder API.
    #>
    param(
        [Parameter(Mandatory)]
        [int]$PostId
    )
    $uri = "$script:BaseUrl/posts/$PostId/comments"
    $response = Invoke-RestMethod -Uri $uri -Method Get
    return $response
}

function Invoke-WithRetry {
    <#
    .SYNOPSIS
        Executes a script block with exponential backoff retry on failure.
    .PARAMETER ScriptBlock
        The action to execute.
    .PARAMETER MaxRetries
        Maximum number of retry attempts. Defaults to 3.
    .PARAMETER BaseDelayMs
        Base delay in milliseconds. Doubles on each retry (exponential backoff).
    #>
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        [int]$MaxRetries = 3,
        [int]$BaseDelayMs = 1000
    )
    $attempt = 0
    while ($true) {
        try {
            $attempt++
            return & $ScriptBlock
        } catch {
            if ($attempt -gt $MaxRetries) {
                # All retries exhausted — re-throw the last error
                throw
            }
            # Exponential backoff: base * 2^(attempt-1)
            $delaySeconds = ($BaseDelayMs * [math]::Pow(2, $attempt - 1)) / 1000
            Write-Warning "Attempt $attempt failed: $($_.Exception.Message). Retrying in $($delaySeconds)s..."
            Start-Sleep -Seconds $delaySeconds
        }
    }
}

# Default cache directory sits alongside this script
$script:DefaultCacheDir = Join-Path $PSScriptRoot '.cache'

function Save-ToCache {
    <#
    .SYNOPSIS
        Saves data to a local JSON cache file.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Key,
        [Parameter(Mandatory)]
        $Data,
        [string]$CacheDir = $script:DefaultCacheDir
    )
    if (-not (Test-Path $CacheDir)) {
        New-Item -ItemType Directory -Path $CacheDir -Force | Out-Null
    }
    $filePath = Join-Path $CacheDir "$Key.json"
    $Data | ConvertTo-Json -Depth 10 | Set-Content -Path $filePath -Encoding UTF8
}

function Get-FromCache {
    <#
    .SYNOPSIS
        Retrieves data from a local JSON cache file if it exists and is not stale.
    .PARAMETER MaxAgeMinutes
        Maximum age in minutes before the cache is considered stale.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Key,
        [int]$MaxAgeMinutes = 30,
        [string]$CacheDir = $script:DefaultCacheDir
    )
    $filePath = Join-Path $CacheDir "$Key.json"
    if (-not (Test-Path $filePath)) {
        return $null
    }
    $file = Get-Item $filePath
    $age = (Get-Date) - $file.LastWriteTime
    if ($age.TotalMinutes -gt $MaxAgeMinutes) {
        return $null
    }
    $content = Get-Content -Path $filePath -Raw | ConvertFrom-Json
    return $content
}

function Get-PostsWithComments {
    <#
    .SYNOPSIS
        Fetches a page of posts and attaches each post's comments.
        Uses retry logic for resilience and caches results locally.
    #>
    param(
        [int]$Page = 1,
        [int]$Limit = 10,
        [string]$CacheDir = $script:DefaultCacheDir,
        [int]$MaxRetries = 3,
        [int]$BaseDelayMs = 1000
    )

    $cacheKey = "posts-with-comments-page$Page"

    # Try cache first
    $cached = Get-FromCache -Key $cacheKey -CacheDir $CacheDir
    if ($null -ne $cached) {
        return $cached
    }

    # Fetch posts with retry
    $posts = Invoke-WithRetry -ScriptBlock {
        Get-Posts -Page $Page -Limit $Limit
    } -MaxRetries $MaxRetries -BaseDelayMs $BaseDelayMs

    # Fetch comments for each post with retry, then attach them
    $results = @()
    foreach ($post in @($posts)) {
        $comments = Invoke-WithRetry -ScriptBlock {
            Get-Comments -PostId $post.id
        } -MaxRetries $MaxRetries -BaseDelayMs $BaseDelayMs

        # Attach comments to the post object
        $post | Add-Member -NotePropertyName 'comments' -NotePropertyValue @($comments) -Force
        $results += $post
    }

    # Cache the combined results
    Save-ToCache -Key $cacheKey -Data $results -CacheDir $CacheDir

    return $results
}
