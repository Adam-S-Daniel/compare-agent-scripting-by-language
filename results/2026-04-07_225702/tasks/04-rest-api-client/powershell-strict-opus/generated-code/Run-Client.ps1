#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Demonstrates the JSONPlaceholder REST API client.
.DESCRIPTION
    Fetches posts with their comments from https://jsonplaceholder.typicode.com,
    using pagination, retry with exponential backoff, and local JSON caching.
#>

Import-Module "$PSScriptRoot/JsonPlaceholderClient.psm1" -Force

[string]$baseUri = 'https://jsonplaceholder.typicode.com'
[string]$cacheDir = Join-Path $PSScriptRoot '.cache'

Write-Host 'Fetching posts with comments from JSONPlaceholder...' -ForegroundColor Cyan
Write-Host "Cache directory: $cacheDir"

[array]$postsWithComments = Get-PostsWithComments `
    -BaseUri $baseUri `
    -CacheDir $cacheDir `
    -PageSize 10 `
    -MaxPages 3 `
    -CacheMaxAgeMinutes 60 `
    -Verbose

Write-Host "`nFetched $($postsWithComments.Count) posts." -ForegroundColor Green

# Display a summary of the first 5 posts
[int]$displayCount = [Math]::Min(5, $postsWithComments.Count)
for ([int]$i = 0; $i -lt $displayCount; $i++) {
    $post = $postsWithComments[$i]
    [int]$commentCount = 0
    if ($null -ne $post.comments) {
        $commentCount = @($post.comments).Count
    }
    Write-Host "`n  [$($post.id)] $($post.title)" -ForegroundColor Yellow
    Write-Host "      $commentCount comment(s)" -ForegroundColor DarkGray
}

if ($postsWithComments.Count -gt $displayCount) {
    Write-Host "`n  ... and $($postsWithComments.Count - $displayCount) more posts." -ForegroundColor DarkGray
}
