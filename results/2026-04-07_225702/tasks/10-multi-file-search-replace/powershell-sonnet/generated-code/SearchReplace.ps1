# SearchReplace.ps1
# Multi-file recursive search-and-replace with preview mode, backup creation,
# and change-summary reporting.
#
# Public API:
#   Find-FileMatches    - locate matching lines across files
#   Invoke-SearchReplace - perform (or preview) substitutions

# ---------------------------------------------------------------------------
# Find-FileMatches
# ---------------------------------------------------------------------------
# Recursively finds files under -Path whose names match -GlobPattern, then
# returns one match-object per line that contains -SearchPattern (regex).
#
# Returns: [PSCustomObject]{ File; LineNumber; LineText }[]
# ---------------------------------------------------------------------------
function Find-FileMatches {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $GlobPattern,
        [Parameter(Mandatory)] [string] $SearchPattern
    )

    # --- validate path ---
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Path '$Path' does not exist or is not a directory."
    }

    # --- validate regex early so callers get a clear error ---
    try {
        $null = [regex]::new($SearchPattern)
    }
    catch {
        throw "SearchPattern '$SearchPattern' is invalid: $($_.Exception.Message)"
    }

    # Collect matching files recursively using the glob pattern
    $files = Get-ChildItem -Path $Path -Filter $GlobPattern -Recurse -File

    $matches_ = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($file in $files) {
        $lineNum = 0
        foreach ($line in [System.IO.File]::ReadLines($file.FullName)) {
            $lineNum++
            if ($line -match $SearchPattern) {
                $matches_.Add([PSCustomObject]@{
                    File       = $file.FullName
                    LineNumber = $lineNum
                    LineText   = $line
                })
            }
        }
    }

    return $matches_
}

# ---------------------------------------------------------------------------
# Invoke-SearchReplace
# ---------------------------------------------------------------------------
# Performs regex search-and-replace across files matching the glob.
#
# -Preview   : report planned changes without modifying any file
# (no flag)  : create a .bak backup of each changed file, apply changes,
#              and return a summary report
#
# Returns: [PSCustomObject]{ File; LineNumber; OldText; NewText }[]
# ---------------------------------------------------------------------------
function Invoke-SearchReplace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $GlobPattern,
        [Parameter(Mandatory)] [string] $SearchPattern,
        [Parameter(Mandatory)] [string] $Replacement,
        [switch] $Preview
    )

    # Reuse Find-FileMatches for validation; we re-scan per file below for full
    # line replacement, but this also validates path + regex early.
    $null = Find-FileMatches -Path $Path -GlobPattern $GlobPattern -SearchPattern $SearchPattern

    $files  = Get-ChildItem -Path $Path -Filter $GlobPattern -Recurse -File
    $report = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($file in $files) {
        $lines      = [System.IO.File]::ReadAllLines($file.FullName)
        $newLines   = [string[]]::new($lines.Length)
        $fileChanged = $false

        for ($i = 0; $i -lt $lines.Length; $i++) {
            $oldLine = $lines[$i]
            if ($oldLine -match $SearchPattern) {
                $newLine = $oldLine -replace $SearchPattern, $Replacement
                $newLines[$i] = $newLine
                $fileChanged  = $true

                $report.Add([PSCustomObject]@{
                    File       = $file.FullName
                    LineNumber = $i + 1
                    OldText    = $oldLine
                    NewText    = $newLine
                })
            }
            else {
                $newLines[$i] = $oldLine
            }
        }

        # Write changes only in live mode
        if ($fileChanged -and -not $Preview) {
            # Backup original
            $backupPath = [System.IO.Path]::ChangeExtension($file.FullName, ".bak")
            Copy-Item -LiteralPath $file.FullName -Destination $backupPath -Force

            # Write modified content (preserve original encoding as UTF-8 NoBOM)
            [System.IO.File]::WriteAllLines($file.FullName, $newLines,
                [System.Text.UTF8Encoding]::new($false))
        }
    }

    return $report
}
