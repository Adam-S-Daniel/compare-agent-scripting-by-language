# SearchReplace.psm1
# Multi-file search and replace module with:
#   - Recursive glob pattern file search (Find-MatchingFiles)
#   - Regex pattern matching in files (Search-InFiles)
#   - Preview mode showing matches with context (Get-SearchPreview)
#   - Backup creation before modifying files (New-FileBackup)
#   - Full search-and-replace with summary report (Invoke-SearchReplace)
#
# Built using TDD methodology with Pester tests.

# ============================================================
# Round 1: Find files matching a glob pattern recursively
# ============================================================
function Find-MatchingFiles {
    <#
    .SYNOPSIS
        Recursively finds files matching a glob pattern under a given path.
    .PARAMETER Path
        The root directory to search in.
    .PARAMETER GlobPattern
        The file name glob pattern (e.g., "*.txt", "*.log").
    .OUTPUTS
        System.IO.FileInfo[] - Array of matching file objects.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$GlobPattern
    )

    # Validate the search path exists
    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw "Path '$Path' does not exist or is not a directory."
    }

    # Recursively find files matching the glob pattern
    $results = Get-ChildItem -Path $Path -Filter $GlobPattern -Recurse -File -ErrorAction Stop
    # Always return an array (even if empty or single result)
    return @($results)
}

# ============================================================
# Round 2: Search for a regex pattern within files
# ============================================================
function Search-InFiles {
    <#
    .SYNOPSIS
        Searches files for lines matching a regex pattern.
    .PARAMETER Files
        Array of FileInfo objects to search.
    .PARAMETER Pattern
        The regex pattern to search for.
    .PARAMETER IgnoreCase
        If set, performs case-insensitive matching. Default is case-sensitive.
    .OUTPUTS
        Array of match objects with FilePath, LineNumber, LineText properties.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.IO.FileInfo[]]$Files,

        [Parameter(Mandatory)]
        [string]$Pattern,

        [switch]$IgnoreCase
    )

    # Validate regex pattern upfront to give a clear error
    try {
        $null = [regex]::new($Pattern)
    }
    catch {
        throw "Invalid regex pattern '$Pattern': $($_.Exception.Message)"
    }

    # Return empty if no files provided
    if ($Files.Count -eq 0) {
        return @()
    }

    # Build regex options: default is case-sensitive, -IgnoreCase enables insensitive
    $regexOptions = if ($IgnoreCase) {
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    } else {
        [System.Text.RegularExpressions.RegexOptions]::None
    }
    $regex = [regex]::new($Pattern, $regexOptions)

    $results = [System.Collections.ArrayList]::new()

    foreach ($file in $Files) {
        $lines = Get-Content -Path $file.FullName -ErrorAction Stop
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($regex.IsMatch($lines[$i])) {
                $null = $results.Add([PSCustomObject]@{
                    FilePath   = $file.FullName
                    LineNumber = $i + 1  # 1-based line numbers
                    LineText   = $lines[$i]
                })
            }
        }
    }

    return @($results)
}

# ============================================================
# Round 3: Preview mode - show matches with surrounding context
# ============================================================
function Get-SearchPreview {
    <#
    .SYNOPSIS
        Shows regex matches with surrounding context lines, without modifying files.
    .PARAMETER Files
        Array of FileInfo objects to search.
    .PARAMETER Pattern
        The regex pattern to search for.
    .PARAMETER ContextLines
        Number of lines to show before and after each match. Default is 2.
    .OUTPUTS
        Array of preview objects with FilePath, LineNumber, ContextBefore, MatchLine, ContextAfter.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo[]]$Files,

        [Parameter(Mandatory)]
        [string]$Pattern,

        [int]$ContextLines = 2
    )

    $results = [System.Collections.ArrayList]::new()

    foreach ($file in $Files) {
        $lines = Get-Content -Path $file.FullName -ErrorAction Stop
        $totalLines = $lines.Count

        for ($i = 0; $i -lt $totalLines; $i++) {
            if ($lines[$i] -match $Pattern) {
                # Calculate context boundaries, clamping to file boundaries
                $beforeStart = [Math]::Max(0, $i - $ContextLines)
                $afterEnd = [Math]::Min($totalLines - 1, $i + $ContextLines)

                # Gather context before the match
                $contextBefore = @()
                if ($i -gt 0 -and $beforeStart -lt $i) {
                    $contextBefore = @($lines[$beforeStart..($i - 1)])
                }

                # Gather context after the match
                $contextAfter = @()
                if ($i -lt ($totalLines - 1) -and ($i + 1) -le $afterEnd) {
                    $contextAfter = @($lines[($i + 1)..$afterEnd])
                }

                $null = $results.Add([PSCustomObject]@{
                    FilePath      = $file.FullName
                    LineNumber    = $i + 1  # 1-based
                    ContextBefore = $contextBefore
                    MatchLine     = $lines[$i]
                    ContextAfter  = $contextAfter
                })
            }
        }
    }

    return @($results)
}

# ============================================================
# Round 4: Create backup copies of files before modification
# ============================================================
function New-FileBackup {
    <#
    .SYNOPSIS
        Creates a timestamped backup copy of a file.
    .PARAMETER FilePath
        Path to the file to back up.
    .PARAMETER BackupDirectory
        Optional directory to store backups. Defaults to same directory as original.
    .OUTPUTS
        String - The full path to the backup file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [string]$BackupDirectory
    )

    # Validate source file exists
    if (-not (Test-Path -Path $FilePath -PathType Leaf)) {
        throw "File '$FilePath' does not exist."
    }

    # Determine backup directory
    if ($BackupDirectory) {
        if (-not (Test-Path -Path $BackupDirectory -PathType Container)) {
            New-Item -Path $BackupDirectory -ItemType Directory -Force | Out-Null
        }
        $targetDir = $BackupDirectory
    } else {
        $targetDir = Split-Path -Path $FilePath -Parent
    }

    # Build timestamped backup filename to avoid collisions
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
    $extension = [System.IO.Path]::GetExtension($FilePath)
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss_fff"
    $backupName = "${baseName}${extension}.${timestamp}.bak"
    $backupPath = Join-Path $targetDir $backupName

    # Copy the file
    Copy-Item -Path $FilePath -Destination $backupPath -Force
    return $backupPath
}

# ============================================================
# Round 5: Full search-and-replace with summary report
# ============================================================
function Invoke-SearchReplace {
    <#
    .SYNOPSIS
        Performs search-and-replace across files matching a glob pattern.
        Supports preview mode, backup creation, and returns a detailed summary.
    .PARAMETER Path
        Root directory to search.
    .PARAMETER GlobPattern
        Glob pattern for file matching (e.g., "*.txt").
    .PARAMETER SearchPattern
        Regex pattern to search for.
    .PARAMETER ReplaceWith
        Replacement string (supports regex capture group references like $1).
    .PARAMETER Preview
        If set, shows what would change without modifying files.
    .PARAMETER CreateBackup
        If set, creates backup copies of files before modifying them.
    .OUTPUTS
        PSCustomObject with Changes, Backups, TotalFilesModified, TotalReplacements, PreviewOnly.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$GlobPattern,

        [Parameter(Mandatory)]
        [string]$SearchPattern,

        [Parameter(Mandatory)]
        [string]$ReplaceWith,

        [switch]$Preview,

        [switch]$CreateBackup
    )

    # Validate path
    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw "Path '$Path' does not exist or is not a directory."
    }

    # Find matching files
    $files = Find-MatchingFiles -Path $Path -GlobPattern $GlobPattern

    $changes = [System.Collections.ArrayList]::new()
    $backups = [System.Collections.ArrayList]::new()
    $modifiedFiles = [System.Collections.Generic.HashSet[string]]::new()

    $regex = [regex]::new($SearchPattern)

    foreach ($file in $files) {
        $lines = Get-Content -Path $file.FullName -ErrorAction Stop
        $fileChanged = $false
        $newLines = [System.Collections.ArrayList]::new()

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            $newLine = $regex.Replace($line, $ReplaceWith)

            if ($newLine -ne $line) {
                # Record the change
                $null = $changes.Add([PSCustomObject]@{
                    FilePath   = $file.FullName
                    LineNumber = [int]($i + 1)
                    OldText    = $line
                    NewText    = $newLine
                })
                $fileChanged = $true
            }

            $null = $newLines.Add($newLine)
        }

        # Apply changes (unless preview mode)
        if ($fileChanged -and -not $Preview) {
            # Create backup if requested
            if ($CreateBackup) {
                $backupPath = New-FileBackup -FilePath $file.FullName
                $null = $backups.Add($backupPath)
            }

            # Write the modified content back
            Set-Content -Path $file.FullName -Value $newLines.ToArray()
            $null = $modifiedFiles.Add($file.FullName)
        }
        elseif ($fileChanged -and $Preview) {
            $null = $modifiedFiles.Add($file.FullName)
        }
    }

    # Build and return the summary report
    return [PSCustomObject]@{
        Changes            = @($changes)
        Backups            = @($backups)
        TotalFilesModified = $modifiedFiles.Count
        TotalReplacements  = $changes.Count
        PreviewOnly        = [bool]$Preview
    }
}

# Export all public functions
Export-ModuleMember -Function @(
    'Find-MatchingFiles'
    'Search-InFiles'
    'Get-SearchPreview'
    'New-FileBackup'
    'Invoke-SearchReplace'
)
