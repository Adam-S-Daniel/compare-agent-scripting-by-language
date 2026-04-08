Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# SearchReplace.ps1 — Recursive search-and-replace with preview, backup, and reporting.
# Built incrementally via red/green TDD.

function Find-MatchingFiles {
    <#
    .SYNOPSIS
        Recursively finds files matching a glob pattern under a given path.
    #>
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$GlobPattern
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Directory not found: $Path"
    }

    [System.IO.FileInfo[]]$files = @(Get-ChildItem -Path $Path -Filter $GlobPattern -Recurse -File)
    return $files
}

function Search-FileContent {
    <#
    .SYNOPSIS
        Searches a file for lines matching a regex, returning match objects with context.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject[]])]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string]$SearchPattern,

        [Parameter()]
        [int]$ContextLines = 0
    )

    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        throw "File not found: $FilePath"
    }

    [string[]]$allLines = @(Get-Content -LiteralPath $FilePath)
    [regex]$regex = [regex]::new($SearchPattern)
    [System.Collections.Generic.List[pscustomobject]]$results = [System.Collections.Generic.List[pscustomobject]]::new()

    for ([int]$i = 0; $i -lt $allLines.Count; $i++) {
        [string]$line = $allLines[$i]
        if ($regex.IsMatch($line)) {
            # Gather context before (guard against negative indices)
            [string[]]$ctxBefore = @()
            if ($ContextLines -gt 0 -and $i -gt 0) {
                [int]$beforeStart = [Math]::Max(0, $i - $ContextLines)
                [string[]]$ctxBefore = @($allLines[$beforeStart..($i - 1)])
            }

            # Gather context after (guard against past-end indices)
            [string[]]$ctxAfter = @()
            if ($ContextLines -gt 0 -and $i -lt ($allLines.Count - 1)) {
                [int]$afterEnd = [Math]::Min($allLines.Count - 1, $i + $ContextLines)
                [string[]]$ctxAfter = @($allLines[($i + 1)..$afterEnd])
            }

            [pscustomobject]$match = [pscustomobject]@{
                FilePath      = [string]$FilePath
                LineNumber    = [int]($i + 1)
                LineText      = [string]$line
                ContextBefore = [string[]]$ctxBefore
                ContextAfter  = [string[]]$ctxAfter
            }
            $results.Add($match)
        }
    }

    return [pscustomobject[]]$results.ToArray()
}

function Backup-File {
    <#
    .SYNOPSIS
        Creates a .bak copy of a file before modification.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        throw "File not found: $FilePath"
    }

    [string]$backupPath = "$FilePath.bak"
    Copy-Item -LiteralPath $FilePath -Destination $backupPath -Force
    return $backupPath
}

function Invoke-SearchReplace {
    <#
    .SYNOPSIS
        Orchestrates recursive search-and-replace across files matching a glob pattern.
        Supports preview mode (no modifications), backup creation, and detailed reporting.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$GlobPattern,

        [Parameter(Mandatory)]
        [string]$SearchPattern,

        [Parameter(Mandatory)]
        [string]$ReplaceWith,

        [Parameter()]
        [switch]$Preview,

        [Parameter()]
        [int]$ContextLines = 0
    )

    [System.IO.FileInfo[]]$files = @(Find-MatchingFiles -Path $Path -GlobPattern $GlobPattern)
    [regex]$regex = [regex]::new($SearchPattern)
    [System.Collections.Generic.List[pscustomobject]]$report = [System.Collections.Generic.List[pscustomobject]]::new()

    foreach ($file in $files) {
        [string]$filePath = $file.FullName
        [string[]]$lines = @(Get-Content -LiteralPath $filePath)
        [bool]$fileHasMatch = $false

        for ([int]$i = 0; $i -lt $lines.Count; $i++) {
            if ($regex.IsMatch($lines[$i])) {
                [string]$oldLine = $lines[$i]
                [string]$newLine = $regex.Replace($oldLine, $ReplaceWith)

                [pscustomobject]$entry = [pscustomobject]@{
                    File       = [string]$filePath
                    LineNumber = [int]($i + 1)
                    OldText    = [string]$oldLine
                    NewText    = [string]$newLine
                }
                $report.Add($entry)

                if (-not $Preview) {
                    $lines[$i] = $newLine
                    $fileHasMatch = $true
                }
            }
        }

        # Write modified content back, creating backup first
        if ($fileHasMatch -and (-not $Preview)) {
            Backup-File -FilePath $filePath | Out-Null
            Set-Content -LiteralPath $filePath -Value ($lines -join "`n") -NoNewline
        }
    }

    return [pscustomobject[]]$report.ToArray()
}

function Format-PreviewReport {
    <#
    .SYNOPSIS
        Formats an array of change report entries into a human-readable summary string.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject[]]$ReportEntries
    )

    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("=== Search & Replace Report ===")
    [void]$sb.AppendLine("Total changes: $($ReportEntries.Count)")
    [void]$sb.AppendLine("")

    # Group entries by file for readability
    [hashtable]$grouped = @{}
    foreach ($entry in $ReportEntries) {
        [string]$key = $entry.File
        if (-not $grouped.ContainsKey($key)) {
            $grouped[$key] = [System.Collections.Generic.List[pscustomobject]]::new()
        }
        ([System.Collections.Generic.List[pscustomobject]]$grouped[$key]).Add($entry)
    }

    foreach ($filePath in $grouped.Keys) {
        [void]$sb.AppendLine("File: $filePath")
        foreach ($entry in [System.Collections.Generic.List[pscustomobject]]$grouped[$filePath]) {
            [void]$sb.AppendLine("  Line $($entry.LineNumber):")
            [void]$sb.AppendLine("    - $($entry.OldText)")
            [void]$sb.AppendLine("    + $($entry.NewText)")
        }
        [void]$sb.AppendLine("")
    }

    return $sb.ToString()
}
