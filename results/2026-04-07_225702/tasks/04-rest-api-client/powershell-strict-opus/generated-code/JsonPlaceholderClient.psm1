Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# =============================================================================
# JsonPlaceholderClient Module
# =============================================================================
# A REST API client for JSONPlaceholder (https://jsonplaceholder.typicode.com)
# that fetches posts and comments with pagination, retry/backoff, and caching.
#
# Design:
#   - Invoke-ApiRequest: low-level HTTP wrapper with retry + exponential backoff
#   - Get-Posts / Get-PostComments: endpoint-specific functions with pagination
#   - Save-Cache / Get-Cache: JSON file caching with TTL
#   - Get-PostsWithComments: orchestrator combining all features
# =============================================================================

function Invoke-ApiRequest {
    <#
    .SYNOPSIS
        Makes an HTTP GET request with retry and exponential backoff.
    .DESCRIPTION
        Wraps Invoke-RestMethod, retrying on transient failures with
        exponentially increasing delays: BaseDelay * 2^attempt seconds.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Uri,

        [Parameter()]
        [int]$MaxRetries = 3,

        [Parameter()]
        [double]$BaseDelaySeconds = 1.0
    )

    [int]$attempt = 0
    while ($true) {
        try {
            # Invoke-RestMethod is the actual HTTP call — mocked in tests
            [object[]]$response = @(Invoke-RestMethod -Uri $Uri -Method Get -ErrorAction Stop)
            # Use comma operator to prevent PowerShell pipeline from unrolling the array
            return , $response
        }
        catch {
            $attempt++
            if ($attempt -gt $MaxRetries) {
                # All retries exhausted — propagate the error
                Write-Error "API request to '$Uri' failed after $($MaxRetries + 1) attempts: $_" -ErrorAction Stop
                throw  # unreachable but satisfies strict analysis
            }
            # Exponential backoff: 1s, 2s, 4s, 8s, ...
            [double]$delay = $BaseDelaySeconds * [Math]::Pow(2, ($attempt - 1))
            Write-Warning "Request to '$Uri' failed (attempt $attempt/$($MaxRetries + 1)). Retrying in ${delay}s..."
            Start-Sleep -Seconds $delay
        }
    }
}

function Get-Posts {
    <#
    .SYNOPSIS
        Fetches posts from JSONPlaceholder with pagination support.
    .DESCRIPTION
        Uses _start/_limit query parameters for pagination. Stops when a page
        returns fewer items than PageSize or MaxPages is reached.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [string]$BaseUri,

        [Parameter()]
        [int]$PageSize = 100,

        [Parameter()]
        [int]$MaxPages = 10
    )

    [System.Collections.Generic.List[object]]$allPosts = [System.Collections.Generic.List[object]]::new()
    [int]$page = 0

    while ($page -lt $MaxPages) {
        [int]$start = $page * $PageSize
        [string]$uri = "${BaseUri}/posts?_start=${start}&_limit=${PageSize}"

        [object[]]$pagePosts = @(Invoke-ApiRequest -Uri $uri)

        # An empty page or null means no more data
        if ($null -eq $pagePosts -or $pagePosts.Count -eq 0) {
            break
        }

        foreach ($post in $pagePosts) {
            $allPosts.Add($post)
        }

        # Partial page means we've reached the end
        if ($pagePosts.Count -lt $PageSize) {
            break
        }

        $page++
    }

    return [object[]]$allPosts.ToArray()
}

function Get-PostComments {
    <#
    .SYNOPSIS
        Fetches comments for a specific post.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [string]$BaseUri,

        [Parameter(Mandatory)]
        [int]$PostId
    )

    [string]$uri = "${BaseUri}/posts/${PostId}/comments"
    [object[]]$comments = @(Invoke-ApiRequest -Uri $uri)
    return $comments
}

function Save-Cache {
    <#
    .SYNOPSIS
        Saves data to a local JSON cache file.
    .DESCRIPTION
        Creates the cache directory if it doesn't exist, then serializes
        the data as JSON. File modification time is used for TTL checks.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string]$CacheDir,

        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter(Mandatory)]
        [object]$Data
    )

    if (-not (Test-Path $CacheDir)) {
        $null = New-Item -ItemType Directory -Path $CacheDir -Force
    }

    [string]$filePath = Join-Path $CacheDir "${Key}.json"
    # Depth 10 ensures nested objects (posts with comments) are fully serialized
    $Data | ConvertTo-Json -Depth 10 | Set-Content -Path $filePath -Encoding UTF8
}

function Get-Cache {
    <#
    .SYNOPSIS
        Loads data from a local JSON cache file if it exists and is fresh.
    .DESCRIPTION
        Returns $null if the file doesn't exist or has exceeded MaxAgeMinutes.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [string]$CacheDir,

        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter()]
        [int]$MaxAgeMinutes = 60
    )

    [string]$filePath = Join-Path $CacheDir "${Key}.json"

    if (-not (Test-Path $filePath)) {
        return $null
    }

    # Check TTL based on file modification time
    [datetime]$lastWrite = (Get-Item $filePath).LastWriteTime
    [timespan]$age = (Get-Date) - $lastWrite
    if ($age.TotalMinutes -gt [double]$MaxAgeMinutes) {
        return $null
    }

    [string]$json = Get-Content -Path $filePath -Raw -Encoding UTF8
    [object]$data = $json | ConvertFrom-Json
    return $data
}

function Get-PostsWithComments {
    <#
    .SYNOPSIS
        Orchestrator: fetches all posts with their comments, using cache.
    .DESCRIPTION
        First checks the local cache. If fresh data is available, returns it.
        Otherwise fetches posts (with pagination), fetches comments for each
        post, attaches comments to posts, caches the result, and returns it.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [string]$BaseUri,

        [Parameter()]
        [string]$CacheDir = (Join-Path $PSScriptRoot '.cache'),

        [Parameter()]
        [int]$CacheMaxAgeMinutes = 60,

        [Parameter()]
        [int]$PageSize = 100,

        [Parameter()]
        [int]$MaxPages = 10
    )

    [string]$cacheKey = 'posts_with_comments'

    # Try cache first
    [object]$cached = Get-Cache -CacheDir $CacheDir -Key $cacheKey -MaxAgeMinutes $CacheMaxAgeMinutes
    if ($null -ne $cached) {
        Write-Verbose 'Returning cached posts with comments.'
        return @($cached)
    }

    # Fetch posts with pagination
    Write-Verbose 'Fetching posts from API...'
    [object[]]$posts = Get-Posts -BaseUri $BaseUri -PageSize $PageSize -MaxPages $MaxPages

    # Fetch comments for each post and attach them
    [System.Collections.Generic.List[object]]$results = [System.Collections.Generic.List[object]]::new()
    foreach ($post in $posts) {
        [int]$postId = [int]$post.id
        Write-Verbose "Fetching comments for post $postId..."
        [object[]]$comments = Get-PostComments -BaseUri $BaseUri -PostId $postId

        # Build a combined object with comments attached
        [hashtable]$enriched = @{
            id       = $post.id
            userId   = $post.userId
            title    = $post.title
            body     = $post.body
            comments = $comments
        }
        $results.Add([pscustomobject]$enriched)
    }

    [object[]]$output = $results.ToArray()

    # Cache the combined results
    Save-Cache -CacheDir $CacheDir -Key $cacheKey -Data $output
    Write-Verbose "Cached $($output.Count) posts with comments to '$CacheDir'."

    return $output
}

# Export all public functions
Export-ModuleMember -Function @(
    'Invoke-ApiRequest'
    'Get-Posts'
    'Get-PostComments'
    'Save-Cache'
    'Get-Cache'
    'Get-PostsWithComments'
)
