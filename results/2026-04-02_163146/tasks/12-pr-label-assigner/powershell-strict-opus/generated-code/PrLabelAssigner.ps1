# PR Label Assigner Module
# Assigns labels to a PR based on changed file paths and configurable
# glob-pattern-to-label mapping rules. Supports:
#   - Glob patterns (**, *, ?)
#   - Multiple labels per file
#   - Priority-based conflict resolution

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-GlobMatch {
    <#
    .SYNOPSIS
        Tests whether a file path matches a glob pattern.
    .DESCRIPTION
        Converts glob patterns (**, *, ?) into regex and tests the path.
        Supports:
          - ** for recursive directory matching (zero or more path segments)
          - * for single-segment wildcard (no slashes)
          - ? for single-character wildcard
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Pattern
    )

    # Normalize backslashes to forward slashes for cross-platform consistency
    [string]$normalizedPath = $Path -replace '\\', '/'
    [string]$normalizedPattern = $Pattern -replace '\\', '/'

    # Convert glob pattern to regex:
    # 1. Escape regex special characters (except our glob wildcards)
    # 2. Replace glob tokens with regex equivalents
    [string]$regex = [regex]::Escape($normalizedPattern)

    # The order matters: handle ** before * since Escape turns * into \*
    # After escaping, ** becomes \*\*, and * becomes \*

    # Replace \*\* (escaped **) with a placeholder first
    $regex = $regex -replace '\\\*\\\*', '{{GLOBSTAR}}'
    # Replace remaining \* (escaped single *) with non-slash match
    $regex = $regex -replace '\\\*', '[^/]*'
    # Replace the globstar placeholder with match-anything (including slashes)
    $regex = $regex -replace '{{GLOBSTAR}}', '.*'
    # Replace \? (escaped ?) with single-character match (no slash)
    $regex = $regex -replace '\\\?', '[^/]'

    # For patterns like "*.test.*" that don't contain a slash,
    # they should match just the filename portion of the path.
    # If the pattern contains no slash, match against the filename only.
    if ($normalizedPattern -notmatch '/') {
        [string]$fileName = $normalizedPath
        if ($normalizedPath -match '/') {
            $fileName = $normalizedPath.Substring($normalizedPath.LastIndexOf('/') + 1)
        }
        return [bool]($fileName -match [string]('^' + $regex + '$'))
    }

    # Full path match for patterns containing directory separators
    return [bool]($normalizedPath -match [string]('^' + $regex + '$'))
}

function New-LabelRule {
    <#
    .SYNOPSIS
        Creates a label rule with a glob pattern, label name, and priority.
    .DESCRIPTION
        Validates inputs and returns a hashtable representing a mapping rule.
        Priority defaults to 0; higher values take precedence in conflict resolution.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Pattern,

        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter()]
        [int]$Priority = 0
    )

    if ([string]::IsNullOrWhiteSpace($Pattern)) {
        throw 'Pattern cannot be empty or whitespace.'
    }
    if ([string]::IsNullOrWhiteSpace($Label)) {
        throw 'Label cannot be empty or whitespace.'
    }

    [hashtable]$rule = @{
        Pattern  = [string]$Pattern
        Label    = [string]$Label
        Priority = [int]$Priority
    }
    return $rule
}

function Get-MatchingLabels {
    <#
    .SYNOPSIS
        Given changed files and rules, returns the set of labels that apply.
    .DESCRIPTION
        Iterates over each rule and each file. When a file matches a rule's
        glob pattern, that rule's label is added to the result set.
        Optionally resolves conflicts using priority within conflict groups.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$ChangedFiles,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [hashtable[]]$Rules,

        [Parameter()]
        [hashtable[]]$ConflictGroups = @()
    )

    # Track which labels matched and their highest matching priority
    [hashtable]$labelPriority = @{}

    foreach ($rule in $Rules) {
        foreach ($file in $ChangedFiles) {
            if (Test-GlobMatch -Path $file -Pattern ([string]$rule.Pattern)) {
                [string]$label = [string]$rule.Label
                [int]$priority = [int]$rule.Priority

                if (-not $labelPriority.ContainsKey($label)) {
                    $labelPriority[$label] = [int]$priority
                }
                elseif ($priority -gt [int]$labelPriority[$label]) {
                    $labelPriority[$label] = [int]$priority
                }
            }
        }
    }

    # Resolve conflicts: within each conflict group, keep only the
    # label(s) with the highest priority
    foreach ($group in $ConflictGroups) {
        [string]$prefix = [string]$group.Prefix
        [string[]]$groupLabels = @($group.Labels)

        # Find which labels in this conflict group are present
        [hashtable]$presentLabels = @{}
        foreach ($gl in $groupLabels) {
            if ($labelPriority.ContainsKey([string]$gl)) {
                $presentLabels[[string]$gl] = [int]$labelPriority[[string]$gl]
            }
        }

        if ($presentLabels.Count -le 1) {
            continue
        }

        # Find the maximum priority among the present conflict-group labels
        [int]$maxPriority = 0
        [bool]$first = $true
        foreach ($key in $presentLabels.Keys) {
            [int]$val = [int]$presentLabels[$key]
            if ($first) {
                $maxPriority = $val
                $first = $false
            }
            elseif ($val -gt $maxPriority) {
                $maxPriority = $val
            }
        }

        # Remove labels that are below the max priority in this group
        foreach ($key in @($presentLabels.Keys)) {
            if ([int]$presentLabels[$key] -lt $maxPriority) {
                $labelPriority.Remove([string]$key)
            }
        }
    }

    # Return unique sorted labels
    [string[]]$result = @($labelPriority.Keys | Sort-Object)
    return $result
}

function Import-LabelConfig {
    <#
    .SYNOPSIS
        Creates an array of label rules from a configuration hashtable.
    .DESCRIPTION
        Expects a hashtable with a 'Rules' key containing an array of rule
        definitions. Each rule must have Pattern and Label keys.
    #>
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    if (-not $Config.ContainsKey('Rules')) {
        throw 'Configuration must contain a Rules key.'
    }

    [System.Collections.ArrayList]$rules = [System.Collections.ArrayList]::new()

    foreach ($entry in $Config.Rules) {
        if (-not ($entry -is [hashtable])) {
            throw "Each rule entry must be a hashtable, got: $($entry.GetType().Name)"
        }
        if (-not $entry.ContainsKey('Pattern')) {
            throw "Rule entry is missing required key 'Pattern'. Entry: $($entry | ConvertTo-Json -Compress)"
        }
        if (-not $entry.ContainsKey('Label')) {
            throw "Rule entry is missing required key 'Label'. Entry: $($entry | ConvertTo-Json -Compress)"
        }

        [int]$priority = 0
        if ($entry.ContainsKey('Priority')) {
            $priority = [int]$entry.Priority
        }

        [hashtable]$rule = New-LabelRule -Pattern ([string]$entry.Pattern) -Label ([string]$entry.Label) -Priority $priority
        [void]$rules.Add($rule)
    }

    return [hashtable[]]$rules.ToArray()
}

function Invoke-PrLabelAssigner {
    <#
    .SYNOPSIS
        Main entry point: assigns PR labels given a config and changed file list.
    .DESCRIPTION
        Loads rules from config, applies them against changed files, resolves
        conflicts if conflict groups are provided, and returns sorted labels.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$ChangedFiles,

        [Parameter()]
        [hashtable[]]$ConflictGroups = @()
    )

    [hashtable[]]$rules = Import-LabelConfig -Config $Config

    [hashtable]$matchParams = @{
        ChangedFiles = $ChangedFiles
        Rules        = $rules
    }

    if ($ConflictGroups.Count -gt 0) {
        $matchParams['ConflictGroups'] = $ConflictGroups
    }

    [string[]]$labels = Get-MatchingLabels @matchParams

    return $labels
}
