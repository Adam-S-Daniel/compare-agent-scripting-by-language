Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# SearchReplace.ps1
# Recursive file search-and-replace tool with preview, backup, and reporting.
# Supports glob-based file matching and regex-based search patterns.

<#
.SYNOPSIS
    Searches files matching a glob pattern for lines matching a regex pattern.
.DESCRIPTION
    Recursively finds files under Path matching FilePattern, then returns
    every line that matches SearchPattern along with file name and line number.
#>
function Find-PatternInFiles {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[PSCustomObject]])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$FilePattern,

        [Parameter(Mandatory)]
        [string]$SearchPattern
    )

    # Validate path exists
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Path does not exist or is not a directory: $Path"
    }

    # Validate search pattern is not empty
    if ([string]::IsNullOrWhiteSpace($SearchPattern)) {
        throw "SearchPattern must not be empty."
    }

    # Validate regex compiles
    try {
        [void][regex]::new($SearchPattern)
    }
    catch {
        throw "Invalid regex pattern '$SearchPattern': $($_.Exception.Message)"
    }

    [System.Collections.Generic.List[PSCustomObject]]$results = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Recursively find files matching the glob pattern
    [System.IO.FileInfo[]]$files = @(Get-ChildItem -Path $Path -Filter $FilePattern -Recurse -File)

    # Compile the regex once for consistent case-sensitive matching
    [regex]$compiledRegex = [regex]::new($SearchPattern)

    foreach ($file in $files) {
        [string[]]$lines = @(Get-Content -LiteralPath $file.FullName)
        for ([int]$i = 0; $i -lt $lines.Count; $i++) {
            if ($compiledRegex.IsMatch($lines[$i])) {
                [PSCustomObject]$match = [PSCustomObject]@{
                    FileName   = [string]$file.FullName
                    LineNumber = [int]($i + 1)
                    LineText   = [string]$lines[$i]
                }
                $results.Add($match)
            }
        }
    }

    # Return the list (may be empty)
    if ($results.Count -eq 0) {
        return
    }
    return $results
}

<#
.SYNOPSIS
    Preview mode: shows matches with surrounding context and optional replacement preview.
.DESCRIPTION
    Returns match objects that include context lines before/after each match,
    and optionally what the replacement would look like.
#>
function Get-MatchPreview {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[PSCustomObject]])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$FilePattern,

        [Parameter(Mandatory)]
        [string]$SearchPattern,

        [string]$ReplacePattern = '',

        [int]$ContextLines = 2
    )

    # Use Find-PatternInFiles to locate matches
    [PSCustomObject[]]$matches = @(Find-PatternInFiles -Path $Path -FilePattern $FilePattern -SearchPattern $SearchPattern)

    [System.Collections.Generic.List[PSCustomObject]]$previews = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($m in $matches) {
        if ($null -eq $m) { continue }

        [string[]]$allLines = @(Get-Content -LiteralPath $m.FileName)
        [int]$lineIndex = [int]($m.LineNumber - 1)

        # Calculate context bounds
        [int]$startIndex = [Math]::Max(0, $lineIndex - $ContextLines)
        [int]$endIndex = [Math]::Min($allLines.Count - 1, $lineIndex + $ContextLines)

        # Gather context before
        [System.Collections.Generic.List[string]]$contextBefore = [System.Collections.Generic.List[string]]::new()
        for ([int]$b = $startIndex; $b -lt $lineIndex; $b++) {
            $contextBefore.Add([string]$allLines[$b])
        }

        # Gather context after
        [System.Collections.Generic.List[string]]$contextAfter = [System.Collections.Generic.List[string]]::new()
        for ([int]$a = $lineIndex + 1; $a -le $endIndex; $a++) {
            $contextAfter.Add([string]$allLines[$a])
        }

        # Build replacement preview if a replace pattern was given
        [string]$replacementLine = ''
        if (-not [string]::IsNullOrEmpty($ReplacePattern)) {
            $replacementLine = [string]([regex]::Replace($m.LineText, $SearchPattern, $ReplacePattern))
        }

        [PSCustomObject]$preview = [PSCustomObject]@{
            FileName        = [string]$m.FileName
            LineNumber      = [int]$m.LineNumber
            MatchLine       = [string]$m.LineText
            ReplacementLine = [string]$replacementLine
            ContextBefore   = [string[]]$contextBefore.ToArray()
            ContextAfter    = [string[]]$contextAfter.ToArray()
        }
        $previews.Add($preview)
    }

    if ($previews.Count -eq 0) {
        return
    }
    return $previews
}

<#
.SYNOPSIS
    Performs search-and-replace on files, with optional backup and a summary report.
.DESCRIPTION
    Recursively finds files matching FilePattern under Path, replaces occurrences of
    SearchPattern with ReplacePattern, optionally backs up originals, and returns a
    report detailing every change made.
#>
function Invoke-SearchReplace {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$FilePattern,

        [Parameter(Mandatory)]
        [string]$SearchPattern,

        [Parameter(Mandatory)]
        [string]$ReplacePattern,

        [switch]$CreateBackup
    )

    # First find all matches so we can build the report
    [PSCustomObject[]]$matchResults = @(Find-PatternInFiles -Path $Path -FilePattern $FilePattern -SearchPattern $SearchPattern)

    [System.Collections.Generic.List[PSCustomObject]]$changes = [System.Collections.Generic.List[PSCustomObject]]::new()
    [System.Collections.Generic.HashSet[string]]$modifiedFiles = [System.Collections.Generic.HashSet[string]]::new()

    # Group matches by file to process each file once
    # Build a dictionary of filename -> list of match info
    [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[PSCustomObject]]]$fileMatches =
        [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[PSCustomObject]]]::new()

    foreach ($m in $matchResults) {
        if ($null -eq $m) { continue }
        [string]$fn = [string]$m.FileName
        if (-not $fileMatches.ContainsKey($fn)) {
            $fileMatches[$fn] = [System.Collections.Generic.List[PSCustomObject]]::new()
        }
        $fileMatches[$fn].Add($m)
    }

    foreach ($fileName in $fileMatches.Keys) {
        [string[]]$lines = @(Get-Content -LiteralPath $fileName)
        [bool]$fileChanged = $false

        # Create backup before any modification
        if ($CreateBackup.IsPresent) {
            Copy-Item -LiteralPath $fileName -Destination "$fileName.bak" -Force
        }

        # Process each matching line
        foreach ($m in $fileMatches[$fileName]) {
            [int]$lineIndex = [int]($m.LineNumber - 1)
            [string]$oldLine = [string]$lines[$lineIndex]
            [string]$newLine = [string]([regex]::Replace($oldLine, $SearchPattern, $ReplacePattern))

            if ($oldLine -ne $newLine) {
                $lines[$lineIndex] = $newLine
                $fileChanged = $true

                [PSCustomObject]$change = [PSCustomObject]@{
                    FileName   = [string]$fileName
                    LineNumber = [int]$m.LineNumber
                    OldText    = [string]$oldLine
                    NewText    = [string]$newLine
                }
                $changes.Add($change)
            }
        }

        # Write modified content back to the file
        if ($fileChanged) {
            Set-Content -LiteralPath $fileName -Value $lines -NoNewline:$false
            [void]$modifiedFiles.Add($fileName)
        }
    }

    # Build summary report
    [PSCustomObject]$report = [PSCustomObject]@{
        TotalFilesModified = [int]$modifiedFiles.Count
        TotalReplacements  = [int]$changes.Count
        Changes            = [PSCustomObject[]]$changes.ToArray()
    }

    return $report
}
