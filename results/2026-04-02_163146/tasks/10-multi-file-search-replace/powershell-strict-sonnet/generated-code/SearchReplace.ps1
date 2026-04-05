# SearchReplace.ps1
# Multi-file search and replace with preview mode, backup creation, and summary reporting.
# All functions use strict mode, typed parameters, and OutputType declarations.

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# ============================================================
# Function: Get-FilesMatchingGlob
# Returns all files under RootPath whose names match GlobPattern.
# Uses Get-ChildItem -Recurse with -Filter for efficient glob matching.
# ============================================================
function Get-FilesMatchingGlob {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string]$RootPath,

        [Parameter(Mandatory)]
        [string]$GlobPattern
    )

    if (-not (Test-Path -Path $RootPath -PathType Container)) {
        throw "Root path does not exist or is not a directory: '$RootPath'"
    }

    # Use -Filter for glob matching; -Recurse searches all subdirectories.
    # Wrap in @() to always get an array even when zero or one file matches.
    [object[]]$files = @(Get-ChildItem -Path $RootPath -Filter $GlobPattern -Recurse -File -ErrorAction Stop)

    # Build result using a generic list for type safety
    [System.Collections.Generic.List[string]]$resultList = [System.Collections.Generic.List[string]]::new()
    foreach ($file in $files) {
        $resultList.Add([string]$file.FullName)
    }

    return [string[]]$resultList.ToArray()
}

# ============================================================
# Function: Search-FileForPattern
# Searches a single file for a regex pattern.
# Returns an array of match result objects with FilePath, LineNumber, LineText.
# ============================================================
function Search-FileForPattern {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string]$SearchPattern
    )

    if (-not (Test-Path -Path $FilePath -PathType Leaf)) {
        throw "File does not exist: '$FilePath'"
    }

    [System.Collections.Generic.List[PSCustomObject]]$results = [System.Collections.Generic.List[PSCustomObject]]::new()
    [int]$lineNumber = 0

    # Read file line by line for accurate line number tracking.
    # Use @() to ensure we always have an array (handles empty files gracefully).
    [object[]]$lines = @(Get-Content -Path $FilePath -ErrorAction Stop)

    foreach ($line in $lines) {
        $lineNumber++
        # Use -match for regex testing; result is stored in automatic $Matches variable
        if ([string]$line -match $SearchPattern) {
            $results.Add([PSCustomObject]@{
                FilePath   = [string]$FilePath
                LineNumber = [int]$lineNumber
                LineText   = [string]$line
            })
        }
    }

    return [PSCustomObject[]]$results.ToArray()
}

# ============================================================
# Function: Invoke-FileReplace
# Performs search-and-replace on a single file.
# Optionally creates a .bak backup before modifying.
# Returns an array of change records: FilePath, LineNumber, OldText, NewText.
# ============================================================
function Invoke-FileReplace {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string]$SearchPattern,

        [Parameter(Mandatory)]
        [string]$Replacement,

        [Parameter(Mandatory)]
        [bool]$CreateBackup
    )

    if (-not (Test-Path -Path $FilePath -PathType Leaf)) {
        throw "File does not exist: '$FilePath'"
    }

    # Read all lines; @() ensures array even for single-line or empty files
    [object[]]$originalLines = @(Get-Content -Path $FilePath -ErrorAction Stop)
    [System.Collections.Generic.List[PSCustomObject]]$changes = [System.Collections.Generic.List[PSCustomObject]]::new()

    [bool]$hasChanges = $false
    [System.Collections.Generic.List[string]]$newLines = [System.Collections.Generic.List[string]]::new()

    [int]$lineNumber = 0
    foreach ($line in $originalLines) {
        $lineNumber++
        [string]$lineStr = [string]$line
        if ($lineStr -match $SearchPattern) {
            # Apply regex replacement; -replace uses .NET regex engine
            [string]$newLine = $lineStr -replace $SearchPattern, $Replacement
            $newLines.Add($newLine)
            $changes.Add([PSCustomObject]@{
                FilePath   = [string]$FilePath
                LineNumber = [int]$lineNumber
                OldText    = $lineStr
                NewText    = $newLine
            })
            $hasChanges = $true
        } else {
            $newLines.Add($lineStr)
        }
    }

    # Only write if changes were made to avoid unnecessary file modification timestamps
    if ($hasChanges) {
        # Create backup before modifying if requested
        if ($CreateBackup) {
            [string]$backupPath = [string]"$FilePath.bak"
            Copy-Item -Path $FilePath -Destination $backupPath -Force -ErrorAction Stop
        }

        # Write modified content back to file
        Set-Content -Path $FilePath -Value $newLines.ToArray() -ErrorAction Stop
    }

    return [PSCustomObject[]]$changes.ToArray()
}

# ============================================================
# Function: Invoke-MultiFileSearchReplace
# Main entry point: searches all files matching GlobPattern under RootPath.
# In preview mode ($Preview = $true): shows matches without modifying files.
# In replace mode ($Preview = $false): performs replacements and creates backups if requested.
# Returns array of change/match records for use in summary report.
# ============================================================
function Invoke-MultiFileSearchReplace {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [string]$RootPath,

        [Parameter(Mandatory)]
        [string]$GlobPattern,

        [Parameter(Mandatory)]
        [string]$SearchPattern,

        [Parameter(Mandatory)]
        [string]$Replacement,

        [Parameter(Mandatory)]
        [bool]$Preview,

        [Parameter(Mandatory)]
        [bool]$CreateBackup
    )

    # Step 1: Find all files matching the glob pattern.
    # @() wraps the result to guarantee a non-null array even when there are no matches.
    [string[]]$matchingFiles = @(Get-FilesMatchingGlob -RootPath $RootPath -GlobPattern $GlobPattern)

    if ($matchingFiles.Count -eq 0) {
        Write-Verbose "No files matched pattern '$GlobPattern' under '$RootPath'"
        return [PSCustomObject[]]@()
    }

    [System.Collections.Generic.List[PSCustomObject]]$allResults = [System.Collections.Generic.List[PSCustomObject]]::new()

    if ($Preview) {
        # Preview mode: search only — do NOT modify files, do NOT create backups
        foreach ($file in $matchingFiles) {
            # @() ensures foreach never receives $null when there are no matches
            foreach ($matchItem in @(Search-FileForPattern -FilePath $file -SearchPattern $SearchPattern)) {
                # Compute what the replacement would look like (for preview context)
                [string]$previewNewText = [string]$matchItem.LineText -replace $SearchPattern, $Replacement
                $allResults.Add([PSCustomObject]@{
                    FilePath   = [string]$matchItem.FilePath
                    LineNumber = [int]$matchItem.LineNumber
                    OldText    = [string]$matchItem.LineText
                    NewText    = $previewNewText
                })
            }
        }
    } else {
        # Replace mode: perform actual replacements, optionally creating backups
        foreach ($file in $matchingFiles) {
            # @() ensures foreach never receives $null when the file has no matches
            foreach ($change in @(Invoke-FileReplace `
                -FilePath $file `
                -SearchPattern $SearchPattern `
                -Replacement $Replacement `
                -CreateBackup $CreateBackup)) {
                $allResults.Add($change)
            }
        }
    }

    return [PSCustomObject[]]$allResults.ToArray()
}

# ============================================================
# Function: Get-SearchReplaceSummary
# Formats a human-readable summary report from change records.
# Report includes: total files modified, total changes, and per-change details
# grouped by file.
# ============================================================
function Get-SearchReplaceSummary {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$Changes
    )

    if ($Changes.Count -eq 0) {
        return [string]'No changes were made.'
    }

    # Aggregate statistics
    [int]$totalChanges = [int]$Changes.Count
    [string[]]$distinctFiles = [string[]]@($Changes | ForEach-Object { [string]$_.FilePath } | Select-Object -Unique)
    [int]$totalFiles = [int]$distinctFiles.Count

    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine('========================================')
    $null = $sb.AppendLine('  Search and Replace Summary Report')
    $null = $sb.AppendLine('========================================')
    $null = $sb.AppendLine("Total files modified : $totalFiles")
    $null = $sb.AppendLine("Total changes made   : $totalChanges")
    $null = $sb.AppendLine('')

    # Group changes by file path for a cleaner, organized report
    [object[]]$grouped = @($Changes | Group-Object -Property FilePath)
    foreach ($fileGroup in $grouped) {
        $null = $sb.AppendLine("File: $($fileGroup.Name)")
        $null = $sb.AppendLine(('-' * 60))
        foreach ($change in $fileGroup.Group) {
            $null = $sb.AppendLine("  Line $($change.LineNumber):")
            $null = $sb.AppendLine("    OLD: $($change.OldText)")
            $null = $sb.AppendLine("    NEW: $($change.NewText)")
        }
        $null = $sb.AppendLine('')
    }

    return [string]$sb.ToString()
}
