# PR Label Assigner - Assigns labels to PRs based on changed file paths
# Supports glob patterns, multiple labels per file, and priority ordering

function ConvertTo-GlobRegex {
    param([string] $GlobPattern)

    # Escape special regex characters except * and ?
    $regex = [regex]::Escape($GlobPattern)

    # Convert glob patterns to regex (order matters: ** before *)
    $regex = $regex -replace '\\\*\\\*', '.*' -replace '\\\*', '[^/]*' -replace '\\\?', '.'

    return $regex
}

function Test-FileMatch {
    param(
        [string] $FilePath,
        [string] $GlobPattern
    )

    $regex = ConvertTo-GlobRegex -GlobPattern $GlobPattern
    $regex = "^$regex$"

    # Case-insensitive matching
    return $FilePath -match $regex
}

function Get-AssignedLabels {
    param(
        [string[]] $ChangedFiles,
        [object[]] $LabelRules,
        [switch] $UsePriority
    )

    $assignedLabels = @{}

    foreach ($file in $ChangedFiles) {
        # Sort rules by priority if specified
        $rulesToProcess = $LabelRules
        if ($UsePriority) {
            $rulesToProcess = $LabelRules | Sort-Object -Property @{Expression={$_.priority}; Ascending=$false}
        }

        foreach ($rule in $rulesToProcess) {
            if (Test-FileMatch -FilePath $file -GlobPattern $rule.pattern) {
                # Add labels from this rule
                foreach ($label in $rule.labels) {
                    $assignedLabels[$label] = $true
                }
            }
        }
    }

    return @($assignedLabels.Keys | Sort-Object)
}
