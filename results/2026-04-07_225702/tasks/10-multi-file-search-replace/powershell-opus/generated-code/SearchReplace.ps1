# SearchReplace.ps1
# Recursively searches files for a regex pattern and performs search-and-replace
# with preview mode, backup creation, and a summary report.

function Invoke-SearchReplace {
    <#
    .SYNOPSIS
        Recursively search and replace text in files matching a glob pattern.
    .PARAMETER Path
        Root directory to search recursively.
    .PARAMETER FilePattern
        Glob pattern for files to include (e.g. "*.txt").
    .PARAMETER SearchPattern
        Regex pattern to search for.
    .PARAMETER ReplaceWith
        Replacement string (supports regex backreferences like $1).
    .PARAMETER Preview
        If set, show matches without modifying files.
    .PARAMETER Backup
        If set, create .bak copies of files before modifying.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$FilePattern,

        [Parameter(Mandatory)]
        [string]$SearchPattern,

        [Parameter(Mandatory)]
        [string]$ReplaceWith,

        [switch]$Preview,

        [switch]$Backup
    )

    # Validate the root path exists
    if (-not (Test-Path $Path -PathType Container)) {
        throw "Directory not found: $Path"
    }

    # Find all files matching the glob pattern recursively
    $files = Get-ChildItem -Path $Path -Filter $FilePattern -Recurse -File

    $allMatches = @()

    foreach ($file in $files) {
        # Force array so single-line files don't collapse to a scalar string
        $lines = @(Get-Content -Path $file.FullName)
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ($line -match $SearchPattern) {
                $newLine = $line -replace $SearchPattern, $ReplaceWith
                $allMatches += [PSCustomObject]@{
                    FilePath   = $file.FullName
                    LineNumber = $i + 1
                    OldText    = $line
                    NewText    = $newLine
                }
            }
        }
    }

    # Build result object
    $result = [PSCustomObject]@{
        Matches      = $allMatches
        FilesChanged = @()
        BackupFiles  = @()
    }

    # In preview mode, return without modifying files
    if ($Preview) {
        return $result
    }

    # Group matches by file to perform replacements
    $filesChanged = @()
    $backupFiles = @()
    $groupedByFile = $allMatches | Group-Object -Property FilePath

    foreach ($group in $groupedByFile) {
        $filePath = $group.Name

        # Create backup if requested
        if ($Backup) {
            $bakPath = "$filePath.bak"
            Copy-Item -Path $filePath -Destination $bakPath
            $backupFiles += $bakPath
        }

        # Read the file, apply all replacements, write back
        $content = Get-Content -Path $filePath
        $newContent = $content | ForEach-Object {
            $_ -replace $SearchPattern, $ReplaceWith
        }
        Set-Content -Path $filePath -Value $newContent

        $filesChanged += $filePath
    }

    $result.FilesChanged = $filesChanged
    $result.BackupFiles = $backupFiles

    return $result
}

function Format-SearchReplaceSummary {
    <#
    .SYNOPSIS
        Formats a human-readable summary report from Invoke-SearchReplace results.
    .PARAMETER Result
        The result object returned by Invoke-SearchReplace.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Result
    )

    $matches = $Result.Matches
    $matchCount = $matches.Count
    $fileCount = ($matches | Select-Object -ExpandProperty FilePath -Unique).Count

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("=== Search & Replace Summary ===")
    [void]$sb.AppendLine("$matchCount match(es) across $fileCount file(s)")
    [void]$sb.AppendLine("")

    if ($Result.FilesChanged.Count -gt 0) {
        [void]$sb.AppendLine("Files modified: $($Result.FilesChanged.Count)")
    }
    if ($Result.BackupFiles.Count -gt 0) {
        [void]$sb.AppendLine("Backups created: $($Result.BackupFiles.Count)")
    }

    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("--- Details ---")

    foreach ($m in $matches) {
        $relPath = $m.FilePath
        [void]$sb.AppendLine("  $($relPath):$($m.LineNumber)")
        [void]$sb.AppendLine("    - $($m.OldText)")
        [void]$sb.AppendLine("    + $($m.NewText)")
    }

    return $sb.ToString()
}
