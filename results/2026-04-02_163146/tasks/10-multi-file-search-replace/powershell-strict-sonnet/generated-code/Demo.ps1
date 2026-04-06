# Demo.ps1
# Demonstrates the multi-file search and replace tool.
# Run: pwsh -File Demo.ps1

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# Import the module
[string]$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'SearchReplace.ps1')

Write-Host '=== Multi-File Search and Replace Demo ===' -ForegroundColor Cyan

# Create a temporary demo directory with sample files
[string]$demoDir = Join-Path ([System.IO.Path]::GetTempPath()) 'SearchReplaceDemo'
if (Test-Path $demoDir) { Remove-Item $demoDir -Recurse -Force }
$null = New-Item $demoDir -ItemType Directory

$null = New-Item (Join-Path $demoDir 'src') -ItemType Directory
$null = New-Item (Join-Path $demoDir 'docs') -ItemType Directory

Set-Content (Join-Path $demoDir 'src' 'app.txt') @(
    'Welcome to the foo application',
    'This is version foo-1.0',
    'Contact: admin@foo.example.com'
)
Set-Content (Join-Path $demoDir 'src' 'config.txt') @(
    'database=foo_db',
    'host=foo.local',
    'debug=false'
)
Set-Content (Join-Path $demoDir 'docs' 'readme.txt') @(
    'foo is a great tool',
    'See foo documentation for details'
)
Set-Content (Join-Path $demoDir 'build.log') @(
    'Build started for foo project',
    'foo compiled successfully'
)

Write-Host "`n1. PREVIEW MODE (no files modified):" -ForegroundColor Yellow
[PSCustomObject[]]$preview = Invoke-MultiFileSearchReplace `
    -RootPath $demoDir `
    -GlobPattern '*.txt' `
    -SearchPattern '\bfoo\b' `
    -Replacement 'bar' `
    -Preview $true `
    -CreateBackup $false

foreach ($match in $preview) {
    Write-Host "  $([System.IO.Path]::GetFileName($match.FilePath)) Line $($match.LineNumber):" -ForegroundColor Gray
    Write-Host "    OLD: $($match.OldText)" -ForegroundColor Red
    Write-Host "    NEW: $($match.NewText)" -ForegroundColor Green
}
Write-Host "  (Total matches: $($preview.Count), files not modified)"

Write-Host "`n2. REPLACE MODE with backup creation:" -ForegroundColor Yellow
[PSCustomObject[]]$changes = Invoke-MultiFileSearchReplace `
    -RootPath $demoDir `
    -GlobPattern '*.txt' `
    -SearchPattern '\bfoo\b' `
    -Replacement 'bar' `
    -Preview $false `
    -CreateBackup $true

Write-Host "`n3. SUMMARY REPORT:" -ForegroundColor Yellow
[string]$summary = Get-SearchReplaceSummary -Changes $changes
Write-Host $summary

# Verify backups were created
[object[]]$backups = @(Get-ChildItem $demoDir -Filter '*.bak' -Recurse -File)
Write-Host "4. BACKUPS CREATED: $($backups.Count) .bak files" -ForegroundColor Yellow
foreach ($bak in $backups) {
    Write-Host "   $($bak.Name)"
}

# Verify .log files were NOT touched
[string]$logContent = Get-Content (Join-Path $demoDir 'build.log') -Raw
[bool]$logUntouched = $logContent -match '\bfoo\b'
Write-Host "`n5. .log file untouched (glob was *.txt only): $logUntouched" -ForegroundColor Yellow

# Cleanup
Remove-Item $demoDir -Recurse -Force
Write-Host "`nDemo complete." -ForegroundColor Green
