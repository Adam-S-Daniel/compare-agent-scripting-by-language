# ApiClient.ps1
# JSONPlaceholder REST API client with caching and retry/exponential-backoff.
#
# TDD approach followed:
#   1. Write a failing Pester test (red)
#   2. Write the minimum code to make it pass (green)
#   3. Refactor as needed
#   Repeat for each functional area: cache → HTTP helper → posts → comments →
#   pagination → enrichment.
#
# !! PowerShell pipeline unrolling !!
# PowerShell's output pipeline unrolls single-element arrays at every function
# boundary. To preserve array identity across boundaries we prepend a comma
# to array return values:
#
#   return ,$array          # caller receives $array as-is (not unrolled)
#
# This is the standard PowerShell idiom for "return an array without flattening".
# The outer wrapper array is unwrapped once by the caller's assignment, leaving
# the real array intact.

# ---------------------------------------------------------------------------
# CYCLE 1 — Cache layer
# ---------------------------------------------------------------------------

<#
.SYNOPSIS
    Persists data as a JSON file keyed by $Key inside $CacheDir.
#>
function Save-Cache {
    param(
        [Parameter(Mandatory)] [string]  $Key,
        [Parameter(Mandatory)]           $Data,
        [Parameter(Mandatory)] [string]  $CacheDir
    )

    if (-not (Test-Path $CacheDir)) {
        New-Item -ItemType Directory -Path $CacheDir | Out-Null
    }

    $filePath = Join-Path $CacheDir "$Key.json"
    $Data | ConvertTo-Json -Depth 10 | Set-Content -Path $filePath -Encoding UTF8
}

<#
.SYNOPSIS
    Returns deserialized data for $Key from $CacheDir, or $null if absent.
#>
function Get-Cache {
    param(
        [Parameter(Mandatory)] [string] $Key,
        [Parameter(Mandatory)] [string] $CacheDir
    )

    $filePath = Join-Path $CacheDir "$Key.json"
    if (-not (Test-Path $filePath)) { return $null }

    Get-Content -Path $filePath -Raw | ConvertFrom-Json
}

# ---------------------------------------------------------------------------
# CYCLE 2 — HTTP helper with retry + exponential backoff
# ---------------------------------------------------------------------------

<#
.SYNOPSIS
    Calls $Uri via Invoke-RestMethod, retrying up to $MaxRetries times on error.
    Delay between retries doubles each time (exponential backoff) starting from
    $BaseDelayMs milliseconds. BaseDelayMs=0 makes tests fast.
#>
function Invoke-ApiRequest {
    param(
        [Parameter(Mandatory)] [string] $Uri,
        [int]    $MaxRetries  = 3,
        [int]    $BaseDelayMs = 200   # set to 0 in tests for speed
    )

    $attempt = 0
    while ($true) {
        try {
            # @() collects all pipeline output (handles both single and multi-item
            # responses). Leading comma prevents the caller's assignment from
            # unrolling the array a second time.
            return ,@(Invoke-RestMethod -Uri $Uri -Method Get)
        }
        catch {
            $attempt++
            if ($attempt -ge $MaxRetries) {
                # All retries exhausted — surface the error with context
                throw "Request to '$Uri' failed after $MaxRetries attempt(s): $_"
            }

            # Exponential backoff: 200ms, 400ms, 800ms …
            $delayMs = $BaseDelayMs * [Math]::Pow(2, $attempt - 1)
            if ($delayMs -gt 0) { Start-Sleep -Milliseconds $delayMs }
        }
    }
}

# ---------------------------------------------------------------------------
# CYCLE 3 — Fetch a single page of posts, with cache
# ---------------------------------------------------------------------------

# JSONPlaceholder base URL — override in tests via Mock
$script:BaseUrl = "https://jsonplaceholder.typicode.com"

<#
.SYNOPSIS
    Returns posts for a given $Page. Checks the local cache first; if absent,
    fetches from the API and stores the result.
#>
function Get-Posts {
    param(
        [int]    $Page        = 1,
        [string] $CacheDir    = "./cache",
        [int]    $MaxRetries  = 3,
        [int]    $BaseDelayMs = 200
    )

    $cacheKey = "posts_page_$Page"
    $cached = Get-Cache -Key $cacheKey -CacheDir $CacheDir
    if ($null -ne $cached) {
        # Wrap cached result so it returns as an array, not a scalar
        return ,@($cached)
    }

    # JSONPlaceholder uses _page / _limit query params for pagination
    $uri  = "$script:BaseUrl/posts?_page=$Page&_limit=10"
    $data = Invoke-ApiRequest -Uri $uri -MaxRetries $MaxRetries -BaseDelayMs $BaseDelayMs

    if ($null -ne $data -and $data.Count -gt 0) {
        Save-Cache -Key $cacheKey -Data $data -CacheDir $CacheDir
    }

    return ,$data
}

# ---------------------------------------------------------------------------
# CYCLE 4 — Fetch comments for a post, with cache
# ---------------------------------------------------------------------------

<#
.SYNOPSIS
    Returns all comments for $PostId. Checks cache first; falls back to API.
#>
function Get-Comments {
    param(
        [Parameter(Mandatory)] [int]    $PostId,
        [string] $CacheDir    = "./cache",
        [int]    $MaxRetries  = 3,
        [int]    $BaseDelayMs = 200
    )

    $cacheKey = "comments_post_$PostId"
    $cached = Get-Cache -Key $cacheKey -CacheDir $CacheDir
    if ($null -ne $cached) {
        return ,@($cached)
    }

    $uri  = "$script:BaseUrl/posts/$PostId/comments"
    $data = Invoke-ApiRequest -Uri $uri -MaxRetries $MaxRetries -BaseDelayMs $BaseDelayMs

    if ($null -ne $data -and $data.Count -gt 0) {
        Save-Cache -Key $cacheKey -Data $data -CacheDir $CacheDir
    }

    return ,$data
}

# ---------------------------------------------------------------------------
# CYCLE 5 — Pagination: aggregate all pages until an empty page is returned
# ---------------------------------------------------------------------------

<#
.SYNOPSIS
    Walks pages 1, 2, 3 … calling Get-Posts until an empty page is returned,
    then returns all collected posts.
#>
function Get-AllPosts {
    param(
        [string] $CacheDir    = "./cache",
        [int]    $MaxRetries  = 3,
        [int]    $BaseDelayMs = 200
    )

    $allPosts = [System.Collections.Generic.List[object]]::new()
    $page = 1

    while ($true) {
        $posts = Get-Posts -Page $page -CacheDir $CacheDir `
                           -MaxRetries $MaxRetries -BaseDelayMs $BaseDelayMs

        # Stop when the API returns an empty page
        if ($null -eq $posts -or $posts.Count -eq 0) { break }

        foreach ($post in $posts) { $allPosts.Add($post) }
        $page++
    }

    # Comma operator: return the array without unrolling it at this boundary
    return ,$allPosts.ToArray()
}

# ---------------------------------------------------------------------------
# CYCLE 6 — Enrich posts with their comments
# ---------------------------------------------------------------------------

<#
.SYNOPSIS
    Returns every post fetched via Get-AllPosts, with a "Comments" property
    added that contains the array of comments for that post.
#>
function Get-PostsWithComments {
    param(
        [string] $CacheDir    = "./cache",
        [int]    $MaxRetries  = 3,
        [int]    $BaseDelayMs = 200
    )

    $posts = Get-AllPosts -CacheDir $CacheDir `
                          -MaxRetries $MaxRetries -BaseDelayMs $BaseDelayMs

    foreach ($post in $posts) {
        $comments = Get-Comments -PostId $post.id -CacheDir $CacheDir `
                                 -MaxRetries $MaxRetries -BaseDelayMs $BaseDelayMs

        # Add Comments as a NoteProperty so the object remains inspectable
        $post | Add-Member -NotePropertyName "Comments" `
                           -NotePropertyValue $comments -Force
    }

    return ,$posts
}
