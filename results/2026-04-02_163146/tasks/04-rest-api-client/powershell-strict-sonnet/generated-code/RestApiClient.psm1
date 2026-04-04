# RestApiClient.psm1
# REST API client targeting JSONPlaceholder (https://jsonplaceholder.typicode.com).
#
# Features:
#   - Paginated post fetching  (/posts?_page=N&_limit=M)
#   - Per-post comment fetching (/posts/{id}/comments)
#   - Retry with exponential backoff on HTTP failure
#   - Local JSON file cache (cache-first strategy)
#   - Fully injectable HTTP and delay scriptblocks for unit-testable mocking
#
# STRICT MODE: Set-StrictMode and $ErrorActionPreference are enforced throughout.

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# =============================================================================
# Invoke-ApiRequest
# Core HTTP helper. All network calls go through here so retry + backoff are
# applied uniformly. Accepts optional $HttpInvoker and $DelayInvoker scriptblocks
# so tests can replace real HTTP and Sleep without touching global state.
# =============================================================================
function Invoke-ApiRequest {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        # The full URI to GET.
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        # Maximum number of retries after the initial attempt.
        [int]$MaxRetries = 3,

        # Delay in milliseconds before the first retry; doubles each subsequent retry.
        [int]$InitialDelayMs = 1000,

        # Injected HTTP invoker: { param([string]$Uri) ... return $data }
        # Defaults to Invoke-RestMethod when $null.
        [scriptblock]$HttpInvoker = $null,

        # Injected sleep invoker: { param([int]$ms) ... }
        # Defaults to Start-Sleep when $null.
        [scriptblock]$DelayInvoker = $null
    )

    [int]$attempt = 0
    [int]$delay   = $InitialDelayMs

    while ($attempt -le $MaxRetries) {
        try {
            # Invoke the HTTP call — real or injected mock
            if ($null -ne $HttpInvoker) {
                return (& $HttpInvoker $Uri)
            } else {
                return (Invoke-RestMethod -Uri $Uri -Method Get)
            }
        } catch {
            [string]$errorDetail = [string]$_
            $attempt++

            if ($attempt -gt $MaxRetries) {
                # All retries exhausted — surface a descriptive error
                throw "API request to '$Uri' failed after $MaxRetries retries. Last error: $errorDetail"
            }

            Write-Warning "Attempt $attempt of $MaxRetries failed for '$Uri': $errorDetail. Retrying in ${delay}ms..."

            # Sleep before next attempt — use injected invoker or real Start-Sleep
            if ($null -ne $DelayInvoker) {
                & $DelayInvoker $delay
            } else {
                Start-Sleep -Milliseconds $delay
            }

            # Exponential backoff: double the delay for the next failure
            $delay = [int]($delay * 2)
        }
    }

    # Unreachable: the loop always returns or throws. Here for strict-mode safety.
    throw "Invoke-ApiRequest: unexpected state after retry loop for '$Uri'"
}

# =============================================================================
# Get-CachePath
# Computes the filesystem path for a cache entry. Special characters in the key
# are replaced with underscores to produce a valid filename.
# =============================================================================
function Get-CachePath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CacheDir,

        [Parameter(Mandatory = $true)]
        [string]$CacheKey
    )

    # Replace anything that isn't alphanumeric, underscore, or hyphen
    [string]$safe = $CacheKey -replace '[^a-zA-Z0-9_-]', '_'
    return [string](Join-Path -Path $CacheDir -ChildPath "${safe}.json")
}

# =============================================================================
# Get-CachedData
# Reads and deserialises a JSON cache file. Returns $null if the file is absent.
# =============================================================================
function Get-CachedData {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CachePath
    )

    if (-not (Test-Path -Path $CachePath -PathType Leaf)) {
        return $null
    }

    [string]$raw = Get-Content -Path $CachePath -Raw
    return ($raw | ConvertFrom-Json)
}

# =============================================================================
# Save-CachedData
# Serialises data to JSON and writes it to the cache path, creating any missing
# parent directories automatically.
# =============================================================================
function Save-CachedData {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CachePath,

        [Parameter(Mandatory = $true)]
        [object]$Data
    )

    [string]$dir = [string](Split-Path -Parent $CachePath)
    if (-not (Test-Path -Path $dir -PathType Container)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $Data | ConvertTo-Json -Depth 10 | Set-Content -Path $CachePath -Encoding UTF8
}

# =============================================================================
# Get-Posts
# Fetches a page of posts from the API using JSONPlaceholder pagination params
# (_page, _limit). Results are cached to disk; subsequent calls return the
# cached copy without making a network request.
# =============================================================================
function Get-Posts {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [string]$BaseUrl     = 'https://jsonplaceholder.typicode.com',
        [int]$Page           = 1,
        [int]$Limit          = 10,
        [int]$MaxRetries     = 3,
        [string]$CacheDir    = './cache',
        [scriptblock]$HttpInvoker  = $null,
        [scriptblock]$DelayInvoker = $null
    )

    # Cache key encodes the pagination parameters so each page is stored separately
    [string]$cacheKey  = "posts_page${Page}_limit${Limit}"
    [string]$cachePath = Get-CachePath -CacheDir $CacheDir -CacheKey $cacheKey

    [object]$cached = Get-CachedData -CachePath $cachePath
    if ($null -ne $cached) {
        Write-Verbose "Cache hit: posts page=$Page limit=$Limit"
        return [PSCustomObject[]]@($cached)
    }

    # Construct paginated URI per JSONPlaceholder convention
    [string]$uri = "${BaseUrl}/posts?_page=${Page}&_limit=${Limit}"
    [object]$posts = Invoke-ApiRequest -Uri $uri -MaxRetries $MaxRetries `
        -HttpInvoker $HttpInvoker -DelayInvoker $DelayInvoker

    # Guard: Invoke-ApiRequest returns $null when the HTTP response is an empty array
    # (PowerShell unrolls @() to nothing on the pipeline). Normalise to empty array.
    if ($null -eq $posts) {
        Save-CachedData -CachePath $cachePath -Data ([PSCustomObject[]]@())
        return [PSCustomObject[]]@()
    }
    Save-CachedData -CachePath $cachePath -Data $posts
    return [PSCustomObject[]]@($posts)
}

# =============================================================================
# Get-PostComments
# Fetches all comments for a single post. Cached by post ID.
# =============================================================================
function Get-PostComments {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true)]
        [int]$PostId,

        [string]$BaseUrl     = 'https://jsonplaceholder.typicode.com',
        [int]$MaxRetries     = 3,
        [string]$CacheDir    = './cache',
        [scriptblock]$HttpInvoker  = $null,
        [scriptblock]$DelayInvoker = $null
    )

    [string]$cacheKey  = "comments_post${PostId}"
    [string]$cachePath = Get-CachePath -CacheDir $CacheDir -CacheKey $cacheKey

    [object]$cached = Get-CachedData -CachePath $cachePath
    if ($null -ne $cached) {
        Write-Verbose "Cache hit: comments for post $PostId"
        return [PSCustomObject[]]@($cached)
    }

    [string]$uri = "${BaseUrl}/posts/${PostId}/comments"
    [object]$comments = Invoke-ApiRequest -Uri $uri -MaxRetries $MaxRetries `
        -HttpInvoker $HttpInvoker -DelayInvoker $DelayInvoker

    if ($null -eq $comments) {
        Save-CachedData -CachePath $cachePath -Data ([PSCustomObject[]]@())
        return [PSCustomObject[]]@()
    }
    Save-CachedData -CachePath $cachePath -Data $comments
    return [PSCustomObject[]]@($comments)
}

# =============================================================================
# Get-PostsWithComments
# Fetches a page of posts then enriches each with its comments, returning a
# combined object array. Both posts and comments are individually cached.
# =============================================================================
function Get-PostsWithComments {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [string]$BaseUrl     = 'https://jsonplaceholder.typicode.com',
        [int]$Page           = 1,
        [int]$Limit          = 10,
        [int]$MaxRetries     = 3,
        [string]$CacheDir    = './cache',
        [scriptblock]$HttpInvoker  = $null,
        [scriptblock]$DelayInvoker = $null
    )

    [PSCustomObject[]]$posts = Get-Posts `
        -BaseUrl $BaseUrl -Page $Page -Limit $Limit `
        -MaxRetries $MaxRetries -CacheDir $CacheDir `
        -HttpInvoker $HttpInvoker -DelayInvoker $DelayInvoker

    [System.Collections.Generic.List[PSCustomObject]]$enriched = `
        [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($post in $posts) {
        [PSCustomObject[]]$comments = Get-PostComments `
            -PostId ([int]$post.id) `
            -BaseUrl $BaseUrl -MaxRetries $MaxRetries -CacheDir $CacheDir `
            -HttpInvoker $HttpInvoker -DelayInvoker $DelayInvoker

        $enriched.Add([PSCustomObject]@{
            id       = [int]$post.id
            userId   = [int]$post.userId
            title    = [string]$post.title
            body     = [string]$post.body
            comments = $comments
        })
    }

    return [PSCustomObject[]]$enriched.ToArray()
}
