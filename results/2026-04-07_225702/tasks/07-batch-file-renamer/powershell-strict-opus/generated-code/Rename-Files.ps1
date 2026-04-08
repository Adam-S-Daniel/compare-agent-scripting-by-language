Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Batch File Renamer — regex-based file renaming with preview, undo, and conflict detection.

function Get-RenamePreview {
    <#
    .SYNOPSIS
        Previews regex-based file renames without modifying files on disk.
    .DESCRIPTION
        Scans files in the given directory, applies the regex pattern to each filename,
        and returns objects describing what would be renamed.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Pattern,

        [Parameter(Mandatory)]
        [string]$Replacement
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Directory not found: $Path"
    }

    [System.Collections.Generic.List[PSCustomObject]]$results = [System.Collections.Generic.List[PSCustomObject]]::new()

    [System.IO.FileInfo[]]$files = Get-ChildItem -LiteralPath $Path -File

    foreach ($file in $files) {
        [string]$oldName = $file.Name
        if ($oldName -match $Pattern) {
            [string]$newName = [regex]::Replace($oldName, $Pattern, $Replacement)
            if ($newName -ne $oldName) {
                $results.Add([PSCustomObject]@{
                    OldName = [string]$oldName
                    NewName = [string]$newName
                    FullOldPath = [string]$file.FullName
                    FullNewPath = [string](Join-Path $Path $newName)
                })
            }
        }
    }

    return [PSCustomObject[]]$results.ToArray()
}

function Find-RenameConflicts {
    <#
    .SYNOPSIS
        Detects naming conflicts in a rename plan.
    .DESCRIPTION
        Checks for two types of conflicts:
        1. Two source files would both rename to the same target name.
        2. A target name already exists on disk and that file is not being renamed away.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$RenamePlan
    )

    [System.Collections.Generic.List[PSCustomObject]]$conflicts = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Build a set of old names (files that will be renamed away from their current name)
    [System.Collections.Generic.HashSet[string]]$oldNames = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    foreach ($entry in $RenamePlan) {
        [void]$oldNames.Add([string]$entry.OldName)
    }

    # Group by new name to find duplicates
    [hashtable]$targetCounts = @{}
    foreach ($entry in $RenamePlan) {
        [string]$key = [string]$entry.NewName
        if ($targetCounts.ContainsKey($key)) {
            [System.Collections.Generic.List[string]]$list = [System.Collections.Generic.List[string]]$targetCounts[$key]
            $list.Add([string]$entry.OldName)
        } else {
            [System.Collections.Generic.List[string]]$list = [System.Collections.Generic.List[string]]::new()
            $list.Add([string]$entry.OldName)
            $targetCounts[$key] = $list
        }
    }

    foreach ($kvp in $targetCounts.GetEnumerator()) {
        [System.Collections.Generic.List[string]]$sources = [System.Collections.Generic.List[string]]$kvp.Value
        if ($sources.Count -gt 1) {
            $conflicts.Add([PSCustomObject]@{
                ConflictingNewName = [string]$kvp.Key
                Sources            = [string[]]$sources.ToArray()
                Reason             = [string]"Multiple files would rename to the same name"
            })
        }
    }

    # Check if any target name collides with an existing file not being renamed
    foreach ($entry in $RenamePlan) {
        [string]$targetPath = [string]$entry.FullNewPath
        if ((Test-Path -LiteralPath $targetPath) -and (-not $oldNames.Contains([string]$entry.NewName))) {
            $conflicts.Add([PSCustomObject]@{
                ConflictingNewName = [string]$entry.NewName
                Sources            = [string[]]@([string]$entry.OldName)
                Reason             = [string]"Target file already exists and is not being renamed"
            })
        }
    }

    return [PSCustomObject[]]$conflicts.ToArray()
}

function Invoke-FileRename {
    <#
    .SYNOPSIS
        Executes a rename plan, renaming files on disk.
    .DESCRIPTION
        Takes a plan from Get-RenamePreview and performs the actual renames.
        Checks for conflicts first and aborts if any are found.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$RenamePlan
    )

    # Validate all source files exist before starting
    foreach ($entry in $RenamePlan) {
        if (-not (Test-Path -LiteralPath ([string]$entry.FullOldPath))) {
            throw "Source file not found: $([string]$entry.FullOldPath)"
        }
    }

    # Check for conflicts before performing any renames
    [PSCustomObject[]]$conflicts = @(Find-RenameConflicts -RenamePlan $RenamePlan)
    if ($conflicts.Count -gt 0) {
        [string]$msg = "Rename aborted due to conflict: $([string]$conflicts[0].ConflictingNewName) — $([string]$conflicts[0].Reason)"
        throw $msg
    }

    # Perform the renames
    foreach ($entry in $RenamePlan) {
        Rename-Item -LiteralPath ([string]$entry.FullOldPath) -NewName ([string]$entry.NewName)
    }
}

function New-UndoScript {
    <#
    .SYNOPSIS
        Generates a PowerShell script that reverses a set of file renames.
    .DESCRIPTION
        Takes a rename plan and writes a .ps1 file that, when executed,
        renames each file back to its original name.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$RenamePlan,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# Auto-generated undo script — reverses file renames')
    [void]$sb.AppendLine('Set-StrictMode -Version Latest')
    [void]$sb.AppendLine('$ErrorActionPreference = ''Stop''')
    [void]$sb.AppendLine('')

    foreach ($entry in $RenamePlan) {
        # Undo: rename from NewName back to OldName
        [string]$escapedNewPath = ([string]$entry.FullNewPath).Replace("'", "''")
        [string]$escapedOldName = ([string]$entry.OldName).Replace("'", "''")
        [void]$sb.AppendLine("Rename-Item -LiteralPath '$escapedNewPath' -NewName '$escapedOldName'")
    }

    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("Write-Host 'Undo complete: $($RenamePlan.Count) file(s) restored.'")

    Set-Content -LiteralPath $OutputPath -Value ([string]$sb.ToString()) -Encoding UTF8
}
