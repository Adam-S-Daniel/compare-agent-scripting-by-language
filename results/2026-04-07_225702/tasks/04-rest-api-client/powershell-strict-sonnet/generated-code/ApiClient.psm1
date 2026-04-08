<#
.SYNOPSIS
    REST API client for JSONPlaceholder with caching and retry logic.

.DESCRIPTION
    Provides functions to fetch posts and comments from JSONPlaceholder
    (https://jsonplaceholder.typicode.com) with:
      - Local JSON file caching (per-page, per-post)
      - Exponential-backoff retry on HTTP failure
      - Strict-mode compliance throughout

    TDD implementation order (each block corresponds to a test group):
      1. Get-ApiCache / Set-ApiCache  — cache I/O
      2. Invoke-ApiRequest            — HTTP + retry
      3. Get-Posts                    — paginated posts + caching
      4. Get-PostComments             — per-post comments + caching
      5. Get-PostsWithComments        — orchestration

.NOTES
    Strict-mode requirements met:
      - Set-StrictMode -Latest at top of file
      - $ErrorActionPreference = 'Stop'
      - Every parameter is explicitly typed
      - Every function declares [OutputType()]
      - [CmdletBinding()] on every function
      - Explicit casts wherever type coercion could occur
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ─────────────────────────────────────────────────────────────────────────────
# BLOCK 1 — CACHE FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────

<#
.SYNOPSIS
    Reads a cached API response from a local JSON file.

.OUTPUTS
    PSObject — the deserialised cache content, or $null on a cache miss.
#>
function Get-ApiCache {
    [CmdletBinding()]
    [OutputType([PSObject])]
    param(
        [Parameter(Mandatory)]
        [string]$CacheDir,

        [Parameter(Mandatory)]
        [string]$CacheKey
    )

    [string]$cacheFile = Join-Path $CacheDir "$CacheKey.json"

    if (-not (Test-Path -Path $cacheFile)) {
        return $null
    }

    [string]$raw = Get-Content -Path $cacheFile -Raw
    return ($raw | ConvertFrom-Json)
}

<#
.SYNOPSIS
    Persists an API response to a local JSON cache file.

.DESCRIPTION
    Creates the cache directory if it doesn't exist, then writes $Data
    serialised as JSON (depth 10) to <CacheDir>/<CacheKey>.json.
#>
function Set-ApiCache {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string]$CacheDir,

        [Parameter(Mandatory)]
        [string]$CacheKey,

        [Parameter(Mandatory)]
        [PSObject]$Data
    )

    if (-not (Test-Path -Path $CacheDir)) {
        [void](New-Item -ItemType Directory -Path $CacheDir -Force)
    }

    [string]$cacheFile   = Join-Path $CacheDir "$CacheKey.json"
    [string]$jsonContent = $Data | ConvertTo-Json -Depth 10
    Set-Content -Path $cacheFile -Value $jsonContent
}

# ─────────────────────────────────────────────────────────────────────────────
# BLOCK 2 — HTTP REQUEST WITH EXPONENTIAL-BACKOFF RETRY
# ─────────────────────────────────────────────────────────────────────────────

<#
.SYNOPSIS
    Makes an HTTP GET request and retries with exponential backoff on failure.

.DESCRIPTION
    Retry behaviour:
      - Attempt 1..MaxRetries
      - After the k-th failure (k < MaxRetries): sleep BaseDelayMs * 2^(k-1)
      - After the MaxRetries-th failure: throw a descriptive error
    Delays (BaseDelayMs=1000, MaxRetries=3): 1 s, 2 s → then throw.

.OUTPUTS
    PSObject — the response body returned by Invoke-RestMethod.
#>
function Invoke-ApiRequest {
    [CmdletBinding()]
    [OutputType([PSObject])]
    param(
        [Parameter(Mandatory)]
        [string]$Uri,

        [int]$MaxRetries   = 3,
        [int]$BaseDelayMs  = 1000
    )

    [int]$attempt         = 0
    [string]$lastErrorMsg = ''

    do {
        $attempt++
        try {
            # Invoke-RestMethod is mocked in tests via Mock -ModuleName ApiClient
            return Invoke-RestMethod -Uri $Uri -Method Get
        }
        catch {
            $lastErrorMsg = $_.Exception.Message

            if ($attempt -ge $MaxRetries) {
                # All retries exhausted — surface a clear error
                throw "API request failed after $MaxRetries attempts for URI '$Uri'. Last error: $lastErrorMsg"
            }

            # Exponential backoff: 1×, 2×, 4×, … of BaseDelayMs
            [int]$delayMs = [int]($BaseDelayMs * [Math]::Pow(2.0, [double]($attempt - 1)))
            Start-Sleep -Milliseconds $delayMs
        }
    } while ($attempt -lt $MaxRetries)

    # Defensive throw — should be unreachable but satisfies strict analysis
    throw "Unexpected end of retry loop for '$Uri'"
}

# ─────────────────────────────────────────────────────────────────────────────
# BLOCK 3 — PAGINATED POST FETCHING
# ─────────────────────────────────────────────────────────────────────────────

<#
.SYNOPSIS
    Fetches one page of posts from the JSONPlaceholder API with local caching.

.DESCRIPTION
    Cache key pattern: posts_page<Page>_size<PageSize>
    API endpoint:      /posts?_page=<Page>&_limit=<PageSize>

.OUTPUTS
    PSObject[] — array of post objects (id, userId, title, body).
#>
function Get-Posts {
    [CmdletBinding()]
    [OutputType([PSObject[]])]
    param(
        [string]$BaseUrl     = 'https://jsonplaceholder.typicode.com',
        [string]$CacheDir    = './cache',
        [int]$MaxRetries     = 3,
        [int]$BaseDelayMs    = 1000,
        [int]$Page           = 1,
        [int]$PageSize       = 10
    )

    [string]$cacheKey = "posts_page${Page}_size${PageSize}"

    # Cache hit → return without touching the network
    [PSObject]$cached = Get-ApiCache -CacheDir $CacheDir -CacheKey $cacheKey
    if ($null -ne $cached) {
        return [PSObject[]]@($cached)
    }

    # Cache miss → fetch from API
    [string]$uri       = "${BaseUrl}/posts?_page=${Page}&_limit=${PageSize}"
    [PSObject[]]$posts = @(Invoke-ApiRequest -Uri $uri -MaxRetries $MaxRetries -BaseDelayMs $BaseDelayMs)

    Set-ApiCache -CacheDir $CacheDir -CacheKey $cacheKey -Data $posts
    return $posts
}

# ─────────────────────────────────────────────────────────────────────────────
# BLOCK 4 — PER-POST COMMENT FETCHING
# ─────────────────────────────────────────────────────────────────────────────

<#
.SYNOPSIS
    Fetches all comments for a given post ID from JSONPlaceholder with caching.

.DESCRIPTION
    Cache key pattern: comments_post_<PostId>
    API endpoint:      /posts/<PostId>/comments

.OUTPUTS
    PSObject[] — array of comment objects (id, postId, name, email, body).
#>
function Get-PostComments {
    [CmdletBinding()]
    [OutputType([PSObject[]])]
    param(
        [Parameter(Mandatory)]
        [int]$PostId,

        [string]$BaseUrl     = 'https://jsonplaceholder.typicode.com',
        [string]$CacheDir    = './cache',
        [int]$MaxRetries     = 3,
        [int]$BaseDelayMs    = 1000
    )

    [string]$cacheKey = "comments_post_${PostId}"

    [PSObject]$cached = Get-ApiCache -CacheDir $CacheDir -CacheKey $cacheKey
    if ($null -ne $cached) {
        return [PSObject[]]@($cached)
    }

    [string]$uri          = "${BaseUrl}/posts/${PostId}/comments"
    [PSObject[]]$comments = @(Invoke-ApiRequest -Uri $uri -MaxRetries $MaxRetries -BaseDelayMs $BaseDelayMs)

    Set-ApiCache -CacheDir $CacheDir -CacheKey $cacheKey -Data $comments
    return $comments
}

# ─────────────────────────────────────────────────────────────────────────────
# BLOCK 5 — ORCHESTRATION: POSTS + THEIR COMMENTS
# ─────────────────────────────────────────────────────────────────────────────

<#
.SYNOPSIS
    Returns a page of posts, each paired with its associated comments.

.DESCRIPTION
    Composes Get-Posts and Get-PostComments.  Both layers benefit from caching,
    so repeated calls are cheap after the first fetch.

    Result shape per element:
      [PSCustomObject] @{
          Post     = <post PSObject>
          Comments = <PSObject[]>
      }

.OUTPUTS
    PSObject[] — array of {Post, Comments} wrapper objects.
#>
function Get-PostsWithComments {
    [CmdletBinding()]
    [OutputType([PSObject[]])]
    param(
        [string]$BaseUrl     = 'https://jsonplaceholder.typicode.com',
        [string]$CacheDir    = './cache',
        [int]$MaxRetries     = 3,
        [int]$BaseDelayMs    = 1000,
        [int]$Page           = 1,
        [int]$PageSize       = 10
    )

    [PSObject[]]$posts = @(Get-Posts `
        -BaseUrl   $BaseUrl  `
        -CacheDir  $CacheDir `
        -MaxRetries $MaxRetries `
        -BaseDelayMs $BaseDelayMs `
        -Page      $Page     `
        -PageSize  $PageSize)

    [System.Collections.Generic.List[PSObject]]$results =
        [System.Collections.Generic.List[PSObject]]::new()

    foreach ($post in $posts) {
        [PSObject[]]$comments = @(Get-PostComments `
            -PostId      ([int]$post.id) `
            -BaseUrl     $BaseUrl        `
            -CacheDir    $CacheDir       `
            -MaxRetries  $MaxRetries     `
            -BaseDelayMs $BaseDelayMs)

        $results.Add([PSCustomObject]@{
            Post     = $post
            Comments = $comments
        })
    }

    return [PSObject[]]$results.ToArray()
}
