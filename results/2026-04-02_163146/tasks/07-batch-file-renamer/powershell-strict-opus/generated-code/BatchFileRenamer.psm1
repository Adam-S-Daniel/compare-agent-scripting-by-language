# BatchFileRenamer.psm1 — Regex-based batch file renaming module
#
# Features:
#   - Rename files using .NET regex patterns with capture group support
#   - Preview mode: see what would change without touching disk
#   - Conflict detection: abort if two files would collide
#   - Undo script: generate a .ps1 that reverses all renames
#
# Strict mode: all functions use CmdletBinding, OutputType, explicit types,
# Set-StrictMode -Latest, and $ErrorActionPreference = 'Stop'.

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Data class: represents one rename operation result
# ---------------------------------------------------------------------------
class RenameResult {
    [string]$OldName
    [string]$NewName
    [string]$OldPath
    [string]$NewPath
    [string]$Status   # 'Renamed', 'Preview', 'Conflict', 'Skipped'

    RenameResult([string]$oldName, [string]$newName, [string]$oldPath, [string]$newPath, [string]$status) {
        $this.OldName = $oldName
        $this.NewName = $newName
        $this.OldPath = $oldPath
        $this.NewPath = $newPath
        $this.Status  = $status
    }
}

# ---------------------------------------------------------------------------
# Invoke-BatchRename — main entry point
# ---------------------------------------------------------------------------
function Invoke-BatchRename {
    <#
    .SYNOPSIS
        Rename files in a directory using a regex pattern and replacement string.

    .DESCRIPTION
        Applies a .NET regular expression to every file name in the target directory.
        Supports preview mode (-Preview), conflict detection, and undo script generation.

    .PARAMETER Path
        The directory containing files to rename.

    .PARAMETER Pattern
        A .NET regular expression matched against each file name (not the full path).

    .PARAMETER Replacement
        The replacement string. Supports $1, $2, … capture-group back-references.

    .PARAMETER Preview
        When set, shows planned renames without executing them.

    .PARAMETER UndoScriptPath
        If provided, writes a PowerShell script to this path that reverses the renames.
    #>
    [CmdletBinding()]
    [OutputType([RenameResult[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Pattern,

        [Parameter(Mandatory = $true)]
        [string]$Replacement,

        [Parameter(Mandatory = $false)]
        [switch]$Preview,

        [Parameter(Mandatory = $false)]
        [string]$UndoScriptPath = ''
    )

    # --- Validate directory exists ---
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Directory does not exist: $Path"
    }

    # --- Validate regex ---
    try {
        [void][regex]::new($Pattern)
    } catch {
        throw "The pattern is an invalid regex: $Pattern — $_"
    }

    # --- Compile the regex once for performance ---
    [regex]$regex = [regex]::new($Pattern)

    # --- Gather files (not directories) ---
    [System.IO.FileInfo[]]$files = @(Get-ChildItem -LiteralPath $Path -File)

    # --- Build rename plan: list of [OldName, NewName, OldPath, NewPath] ---
    [System.Collections.Generic.List[hashtable]]$plan = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($file in $files) {
        [string]$oldName = $file.Name
        [string]$newName = $regex.Replace($oldName, $Replacement)

        # Skip if the name did not change
        if ($newName -ceq $oldName) {
            continue
        }

        [string]$newPath = Join-Path $Path $newName

        $plan.Add(@{
            OldName = $oldName
            NewName = $newName
            OldPath = $file.FullName
            NewPath = $newPath
        })
    }

    # --- Conflict detection ---
    # Check 1: two planned renames produce the same target name
    # Check 2: a target name collides with an existing file that is NOT being renamed
    [hashtable]$targetCounts = @{}
    foreach ($entry in $plan) {
        [string]$target = [string]$entry['NewName']
        if ($targetCounts.ContainsKey($target)) {
            [int]$current = [int]$targetCounts[$target]
            $targetCounts[$target] = $current + 1
        } else {
            $targetCounts[$target] = [int]1
        }
    }

    # Collect names that are being renamed away (so they free up their slot)
    [System.Collections.Generic.HashSet[string]]$sourcesBeingRenamed = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::Ordinal
    )
    foreach ($entry in $plan) {
        [void]$sourcesBeingRenamed.Add([string]$entry['OldName'])
    }

    # Detect collisions with existing files that are NOT being renamed
    foreach ($entry in $plan) {
        [string]$target = [string]$entry['NewName']
        if (-not $targetCounts.ContainsKey($target)) { continue }
        if ([int]$targetCounts[$target] -gt 1) { continue }  # already caught below

        # Does a file with this name already exist AND is it NOT in our rename set?
        [string]$existingPath = Join-Path $Path $target
        if ((Test-Path -LiteralPath $existingPath) -and (-not $sourcesBeingRenamed.Contains($target))) {
            if ($targetCounts.ContainsKey($target)) {
                [int]$current2 = [int]$targetCounts[$target]
                $targetCounts[$target] = $current2 + 1
            } else {
                $targetCounts[$target] = [int]2
            }
        }
    }

    # Find all conflicting target names
    [string[]]$conflicts = @($targetCounts.GetEnumerator() |
        Where-Object { [int]$_.Value -gt 1 } |
        ForEach-Object { [string]$_.Key })

    # --- Handle conflicts ---
    if ($conflicts.Count -gt 0) {
        if ($Preview.IsPresent) {
            # In preview mode, return results with Conflict status instead of throwing
            [System.Collections.Generic.List[RenameResult]]$results = [System.Collections.Generic.List[RenameResult]]::new()
            foreach ($entry in $plan) {
                [string]$targetName = [string]$entry['NewName']
                [string]$status = if ($conflicts -contains $targetName) { 'Conflict' } else { 'Preview' }
                $results.Add([RenameResult]::new(
                    [string]$entry['OldName'],
                    $targetName,
                    [string]$entry['OldPath'],
                    [string]$entry['NewPath'],
                    $status
                ))
            }
            return [RenameResult[]]$results.ToArray()
        }

        # Not preview: throw with details about the conflict
        [string]$conflictList = ($conflicts -join ', ')
        throw "Rename conflict detected — multiple files would be renamed to the same target: $conflictList"
    }

    # --- Preview mode: return plan without renaming ---
    if ($Preview.IsPresent) {
        [System.Collections.Generic.List[RenameResult]]$previewResults = [System.Collections.Generic.List[RenameResult]]::new()
        foreach ($entry in $plan) {
            $previewResults.Add([RenameResult]::new(
                [string]$entry['OldName'],
                [string]$entry['NewName'],
                [string]$entry['OldPath'],
                [string]$entry['NewPath'],
                'Preview'
            ))
        }
        return [RenameResult[]]$previewResults.ToArray()
    }

    # --- Execute renames ---
    [System.Collections.Generic.List[RenameResult]]$renameResults = [System.Collections.Generic.List[RenameResult]]::new()

    foreach ($entry in $plan) {
        Rename-Item -LiteralPath ([string]$entry['OldPath']) -NewName ([string]$entry['NewName']) -Force
        $renameResults.Add([RenameResult]::new(
            [string]$entry['OldName'],
            [string]$entry['NewName'],
            [string]$entry['OldPath'],
            [string]$entry['NewPath'],
            'Renamed'
        ))
    }

    # --- Generate undo script if requested ---
    if ($UndoScriptPath -ne '') {
        Write-UndoScript -Results $renameResults.ToArray() -OutputPath $UndoScriptPath
    }

    return [RenameResult[]]$renameResults.ToArray()
}

# ---------------------------------------------------------------------------
# Write-UndoScript — generates a PowerShell script to reverse renames
# ---------------------------------------------------------------------------
function Write-UndoScript {
    <#
    .SYNOPSIS
        Generates a PowerShell undo script that reverses a set of rename operations.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [RenameResult[]]$Results,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# Undo script — reverses batch rename operations')
    [void]$sb.AppendLine('# Generated by BatchFileRenamer')
    [void]$sb.AppendLine('Set-StrictMode -Latest')
    [void]$sb.AppendLine('$ErrorActionPreference = ''Stop''')
    [void]$sb.AppendLine('')

    # Reverse in opposite order to handle any ordering dependencies
    for ([int]$i = $Results.Count - 1; $i -ge 0; $i--) {
        [RenameResult]$r = $Results[$i]
        # Escape single quotes in paths by doubling them
        [string]$escapedNewPath = $r.NewPath -replace "'", "''"
        [string]$escapedOldName = $r.OldName -replace "'", "''"
        [void]$sb.AppendLine("Rename-Item -LiteralPath '$escapedNewPath' -NewName '$escapedOldName' -Force")
    }

    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("Write-Host 'Undo complete: $($Results.Count) file(s) reverted.'")

    Set-Content -LiteralPath $OutputPath -Value $sb.ToString() -Encoding UTF8
}

# ---------------------------------------------------------------------------
# Export public functions
# ---------------------------------------------------------------------------
Export-ModuleMember -Function 'Invoke-BatchRename'
