# PR Label Assigner - Assigns labels to changed files based on configurable rules
# Uses glob pattern matching with priority ordering and multiple label support

function ConvertGlobToRegex {
    <#
    .SYNOPSIS
    Converts a glob pattern to a regex pattern for matching file paths.
    Handles patterns like "docs/**", "src/api/**", and "*.test.*"
    #>
    param([string]$Pattern)

    # Escape special regex chars except * and ?
    $escaped = [regex]::Escape($Pattern)

    # Convert glob wildcards back to regex equivalents
    # ** matches any sequence including path separators
    $converted = $escaped -replace '\\\*\\\*', '.*'
    # * matches within a single path segment (not crossing /)
    $converted = $converted -replace '\\\*', '[^/]*'
    # ? matches single character
    $converted = $converted -replace '\\\?', '.'

    # Return anchored regex pattern
    return "^$converted`$"
}

function Test-GlobMatch {
    <#
    .SYNOPSIS
    Tests if a file path matches a glob pattern.
    Patterns without "/" are matched against the filename only.
    #>
    param(
        [string]$FilePath,
        [string]$Pattern
    )

    try {
        # If pattern has no path separators, match just the filename
        if ($Pattern -notmatch '/') {
            $fileName = Split-Path -Leaf $FilePath
            $testPath = $fileName
        }
        else {
            $testPath = $FilePath
        }

        $regex = ConvertGlobToRegex -Pattern $Pattern
        return $testPath -match $regex
    }
    catch {
        # Invalid pattern - don't match
        return $false
    }
}

function Invoke-LabelAssignment {
    <#
    .SYNOPSIS
    Assigns labels to changed files based on configurable path-to-label rules.

    .PARAMETER Files
    Array of file paths to process

    .PARAMETER Rules
    Hashtable mapping glob patterns to label arrays.
    Keys can be strings (pattern) or objects with pattern and priority properties.
    Priority: lower number = higher priority. When rules conflict, only highest
    priority rule's labels apply.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Files,

        [Parameter(Mandatory)]
        [hashtable]$Rules
    )

    # Validation
    if ($null -eq $Files) {
        throw "Files parameter cannot be null"
    }
    if ($null -eq $Rules) {
        throw "Rules parameter cannot be null"
    }

    # Collect all assigned labels
    $allLabels = @{}
    $assignmentOrder = @()

    # Process each file
    foreach ($file in $Files) {
        # Find all matching rules for this file
        $matches = @()

        foreach ($ruleKey in $Rules.Keys) {
            $pattern = $ruleKey
            $priority = 999  # Default priority
            $labels = $Rules[$ruleKey]

            # Handle both string patterns and objects with pattern/priority
            if ($ruleKey -is [hashtable] -or $ruleKey -is [pscustomobject]) {
                $pattern = $ruleKey.pattern
                if ($ruleKey.PSObject.Properties.Name -contains 'priority') {
                    $priority = $ruleKey.priority
                }
            }

            if (Test-GlobMatch -FilePath $file -Pattern $pattern) {
                # Use PSCustomObject for better property handling with Sort-Object
                $matches += [PSCustomObject]@{
                    pattern = $pattern
                    labels = $labels
                    priority = $priority
                }
            }
        }

        # Sort by priority (ascending - lower number = higher priority)
        if ($matches) {
            $matches = @($matches | Sort-Object -Property priority)

            # Apply highest priority matches, deduplicating labels
            $highestPriority = $matches[0].priority
            $priorityMatches = $matches | Where-Object { $_.priority -eq $highestPriority }

            foreach ($match in $priorityMatches) {
                foreach ($label in $match.labels) {
                    if (-not $allLabels.ContainsKey($label)) {
                        $allLabels[$label] = $true
                        $assignmentOrder += $label
                    }
                }
            }
        }
    }

    # Return unique labels in assignment order
    return $assignmentOrder
}
