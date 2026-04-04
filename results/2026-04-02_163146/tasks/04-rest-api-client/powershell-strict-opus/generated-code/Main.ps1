#!/usr/bin/env pwsh
Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# =============================================================================
# Main.ps1 — Demonstrates the REST API Client against JSONPlaceholder
# Usage: pwsh ./Main.ps1
# =============================================================================

Import-Module "$PSScriptRoot/RestApiClient.psm1" -Force

Write-Host '=== JSONPlaceholder REST API Client ===' -ForegroundColor Cyan
Write-Host ''

# --- Fetch paginated posts ---
Write-Host '1. Fetching posts with pagination (page size = 10)...' -ForegroundColor Yellow
[PSObject[]]$posts = Get-PaginatedPosts -PageSize 10 -UseCache
Write-Host "   Retrieved $($posts.Count) posts total." -ForegroundColor Green
Write-Host ''

# --- Show first 3 posts ---
Write-Host '2. First 3 posts:' -ForegroundColor Yellow
foreach ($post in $posts[0..2]) {
    Write-Host "   [$($post.id)] $($post.title)" -ForegroundColor White
}
Write-Host ''

# --- Fetch posts with comments (limited to 3 for demo) ---
Write-Host '3. Fetching first 3 posts with their comments...' -ForegroundColor Yellow
[PSObject[]]$enriched = Get-PostsWithComments -MaxPosts 3 -UseCache
foreach ($post in $enriched) {
    Write-Host "   Post $($post.id): $($post.title)" -ForegroundColor White
    [int]$commentCount = 0
    if ($null -ne $post.comments) {
        $commentCount = @($post.comments).Count
    }
    Write-Host "     -> $commentCount comments" -ForegroundColor DarkGray
}
Write-Host ''

# --- Show caching in action ---
Write-Host '4. Second fetch uses cache (no API calls):' -ForegroundColor Yellow
[PSObject[]]$cachedPosts = Get-Posts -UseCache
Write-Host "   Got $($cachedPosts.Count) cached posts." -ForegroundColor Green
Write-Host ''

Write-Host '=== Done ===' -ForegroundColor Cyan
