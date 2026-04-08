#!/usr/bin/env pwsh
# Demo script: shows PR Label Assigner in action with mock data.

. $PSScriptRoot/PrLabelAssigner.ps1

Write-Host "=== PR Label Assigner Demo ===" -ForegroundColor Cyan
Write-Host ""

# Configurable rules: glob pattern -> label, with optional priority
# Lower priority number = higher precedence when rules conflict on the same file
$rules = @(
    @{ Pattern = "docs/**";        Label = "documentation"; Priority = 5 },
    @{ Pattern = "src/api/**";     Label = "api";           Priority = 1 },
    @{ Pattern = "src/**";         Label = "source";        Priority = 10 },
    @{ Pattern = "*.test.*";       Label = "tests";         Priority = 3 },
    @{ Pattern = "*.md";           Label = "markdown";      Priority = 8 },
    @{ Pattern = ".github/**";     Label = "ci";            Priority = 2 },
    @{ Pattern = "*.config.*";     Label = "config";        Priority = 4 }
)

# Mock changed files simulating a PR
$changedFiles = @(
    "src/api/users.js",
    "src/api/auth.js",
    "src/utils/helpers.js",
    "docs/setup.md",
    "docs/api-reference.md",
    "tests/api.test.js",
    "tests/utils.test.ts",
    ".github/workflows/ci.yml",
    "jest.config.js"
)

Write-Host "Rules:" -ForegroundColor Yellow
foreach ($rule in $rules) {
    $pri = if ($rule.ContainsKey('Priority')) { $rule.Priority } else { 0 }
    Write-Host "  $($rule.Pattern) -> $($rule.Label) (priority: $pri)"
}

Write-Host ""
Write-Host "Changed files:" -ForegroundColor Yellow
foreach ($file in $changedFiles) {
    Write-Host "  $file"
}

Write-Host ""
$labels = Get-PrLabels -ChangedFiles $changedFiles -Rules $rules

Write-Host "Assigned labels:" -ForegroundColor Green
foreach ($label in ($labels | Sort-Object)) {
    Write-Host "  [$label]" -ForegroundColor Green
}
