# SearchReplace.ps1
# Multi-file search-and-replace tool with preview mode, backup, and change report.
#
# Public functions:
#   Find-Matches        – locate all regex matches across files
#   Invoke-Preview      – show what changes would be made, without writing files
#   Invoke-SearchReplace – perform replacements, optionally create backups,
#                          return a structured change report

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# Validate that $Path exists; throw with a clear message if it does not.
function Assert-PathExists {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Path '$Path' does not exist."
    }
}

# Validate that $Pattern compiles as a regex; throw with a clear message if not.
function Assert-ValidRegex {
    param([string]$Pattern)
    try {
        $null = [System.Text.RegularExpressions.Regex]::new($Pattern)
    } catch {
        throw "SearchPattern '$Pattern' is invalid as a regular expression: $_"
    }
}

# Return all files under $RootPath whose names match $GlobPattern (recursive).
function Get-MatchingFiles {
    param(
        [string]$RootPath,
        [string]$GlobPattern
    )
    Get-ChildItem -Recurse -Path $RootPath -Filter $GlobPattern -File
}

# ---------------------------------------------------------------------------
# Find-Matches
# ---------------------------------------------------------------------------
# Recursively search files matching GlobPattern under RootPath for lines that
# contain SearchPattern (a regex).  Returns an array of custom objects:
#   [PSCustomObject]@{ FilePath; LineNumber; LineContent }
function Find-Matches {
    param(
        [string]$RootPath,
        [string]$GlobPattern,
        [string]$SearchPattern
    )

    Assert-PathExists -Path $RootPath
    Assert-ValidRegex -Pattern $SearchPattern

    $results = @()

    foreach ($file in Get-MatchingFiles -RootPath $RootPath -GlobPattern $GlobPattern) {
        $lineNum = 0
        foreach ($line in Get-Content -LiteralPath $file.FullName) {
            $lineNum++
            if ($line -match $SearchPattern) {
                $results += [PSCustomObject]@{
                    FilePath    = $file.FullName
                    LineNumber  = $lineNum
                    LineContent = $line
                }
            }
        }
    }

    return $results
}

# ---------------------------------------------------------------------------
# Invoke-Preview
# ---------------------------------------------------------------------------
# Show what search-and-replace would do WITHOUT modifying any files.
# Returns an array of custom objects:
#   [PSCustomObject]@{ FilePath; LineNumber; OldText; NewText }
function Invoke-Preview {
    param(
        [string]$RootPath,
        [string]$GlobPattern,
        [string]$SearchPattern,
        [string]$ReplacePattern
    )

    Assert-PathExists -Path $RootPath
    Assert-ValidRegex -Pattern $SearchPattern

    $previews = @()

    foreach ($file in Get-MatchingFiles -RootPath $RootPath -GlobPattern $GlobPattern) {
        $lineNum = 0
        foreach ($line in Get-Content -LiteralPath $file.FullName) {
            $lineNum++
            if ($line -match $SearchPattern) {
                $newLine = $line -replace $SearchPattern, $ReplacePattern
                $previews += [PSCustomObject]@{
                    FilePath   = $file.FullName
                    LineNumber = $lineNum
                    OldText    = $line
                    NewText    = $newLine
                }
            }
        }
    }

    return $previews
}

# ---------------------------------------------------------------------------
# Invoke-SearchReplace
# ---------------------------------------------------------------------------
# Perform the actual search-and-replace across matching files.
# Parameters:
#   -RootPath       Root directory to search from
#   -GlobPattern    File name glob, e.g. *.txt
#   -SearchPattern  Regex to search for
#   -ReplacePattern Replacement string (supports regex back-references)
#   -Backup         [switch] If present, copy each modified file to <file>.bak
#                   BEFORE overwriting it.
#
# Returns an array of change-report objects:
#   [PSCustomObject]@{ FilePath; LineNumber; OldText; NewText }
function Invoke-SearchReplace {
    param(
        [string]$RootPath,
        [string]$GlobPattern,
        [string]$SearchPattern,
        [string]$ReplacePattern,
        [switch]$Backup
    )

    Assert-PathExists -Path $RootPath
    Assert-ValidRegex -Pattern $SearchPattern

    $report = @()

    foreach ($file in Get-MatchingFiles -RootPath $RootPath -GlobPattern $GlobPattern) {
        $lines      = Get-Content -LiteralPath $file.FullName
        $newLines   = @()
        $fileChanged = $false
        $fileChanges = @()

        $lineNum = 0
        foreach ($line in $lines) {
            $lineNum++
            if ($line -match $SearchPattern) {
                $newLine = $line -replace $SearchPattern, $ReplacePattern
                $fileChanged = $true
                $fileChanges += [PSCustomObject]@{
                    FilePath   = $file.FullName
                    LineNumber = $lineNum
                    OldText    = $line
                    NewText    = $newLine
                }
                $newLines += $newLine
            } else {
                $newLines += $line
            }
        }

        if ($fileChanged) {
            # Create backup BEFORE writing changes
            if ($Backup) {
                Copy-Item -LiteralPath $file.FullName -Destination "$($file.FullName).bak" -Force
            }

            # Write modified content back; preserve trailing newline behavior
            Set-Content -LiteralPath $file.FullName -Value $newLines

            $report += $fileChanges
        }
    }

    return $report
}
