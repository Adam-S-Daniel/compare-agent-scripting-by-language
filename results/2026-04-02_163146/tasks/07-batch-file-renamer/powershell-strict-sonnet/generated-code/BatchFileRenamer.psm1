# BatchFileRenamer.psm1
# Batch file renamer with regex patterns, preview mode, undo capability, and conflict detection.
#
# TDD implementation order:
#   1. Get-RenamePreview  - compute what would be renamed (no filesystem changes)
#   2. Find-RenameConflicts - detect when two files would collide
#   3. Invoke-BatchRename  - perform renames with -WhatIf and conflict guard
#   4. New-UndoScript      - generate a reversing PowerShell script

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Data types used throughout the module
# ---------------------------------------------------------------------------

# RenameOperation: describes a single file rename
# Properties: OldName (string), NewName (string), WillChange (bool)

# RenameResult: returned by Invoke-BatchRename
# Properties: OldName, NewName, Success (bool), Error (string|null)

# ConflictInfo: returned by Find-RenameConflicts
# Properties: ConflictingName (string), SourceFiles (string[])

# ---------------------------------------------------------------------------
# FUNCTION: Get-RenamePreview
# ---------------------------------------------------------------------------
# Computes rename operations for a list of filenames given a regex pattern
# and replacement string. Does NOT touch the filesystem.
# Returns only the operations where the name would actually change.
function Get-RenamePreview {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        # Array of bare filenames (no directory paths)
        [Parameter(Mandatory)]
        [string[]]$Files,

        # .NET regex pattern to match against each filename
        [Parameter(Mandatory)]
        [string]$Pattern,

        # Replacement string (supports $1, $2 capture group references)
        [Parameter(Mandatory)]
        [string]$Replacement
    )

    # Validate the pattern compiles
    try {
        $null = [System.Text.RegularExpressions.Regex]::new($Pattern)
    }
    catch {
        throw [System.ArgumentException]::new("Invalid regex pattern '$Pattern': $_", 'Pattern')
    }

    [System.Collections.Generic.List[object]]$results = [System.Collections.Generic.List[object]]::new()

    foreach ($file in $Files) {
        # Check if the pattern matches
        if ([System.Text.RegularExpressions.Regex]::IsMatch($file, $Pattern)) {
            [string]$newName = [System.Text.RegularExpressions.Regex]::Replace($file, $Pattern, $Replacement)

            # Only include if the name actually changes
            if ($newName -ne $file) {
                $operation = [PSCustomObject]@{
                    OldName   = $file
                    NewName   = $newName
                    WillChange = $true
                }
                $results.Add($operation)
            }
        }
    }

    return , [object[]]$results.ToArray()
}

# ---------------------------------------------------------------------------
# FUNCTION: Find-RenameConflicts
# ---------------------------------------------------------------------------
# Given a list of rename operations, finds cases where two or more source
# files would be renamed to the same target name.
function Find-RenameConflicts {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [object[]]$Operations
    )

    # Group operations by their target NewName
    [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[string]]]$groups =
        [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[string]]]::new()

    foreach ($op in $Operations) {
        [string]$newName = [string]$op.NewName
        if (-not $groups.ContainsKey($newName)) {
            $groups[$newName] = [System.Collections.Generic.List[string]]::new()
        }
        $groups[$newName].Add([string]$op.OldName)
    }

    # Collect groups with more than one source (= conflicts)
    [System.Collections.Generic.List[object]]$conflicts = [System.Collections.Generic.List[object]]::new()

    foreach ($key in $groups.Keys) {
        if ($groups[$key].Count -gt 1) {
            $conflict = [PSCustomObject]@{
                ConflictingName = $key
                SourceFiles     = [string[]]$groups[$key].ToArray()
            }
            $conflicts.Add($conflict)
        }
    }

    return , [object[]]$conflicts.ToArray()
}

# ---------------------------------------------------------------------------
# FUNCTION: Invoke-BatchRename
# ---------------------------------------------------------------------------
# Performs (or previews via -WhatIf) regex-based file renames in a directory.
# Throws System.InvalidOperationException if conflicts are detected (unless
# -Force is specified, which skips conflicting renames).
function Invoke-BatchRename {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([object[]])]
    param(
        # Directory containing files to rename
        [Parameter(Mandatory)]
        [string]$Directory,

        # .NET regex pattern matched against bare filenames
        [Parameter(Mandatory)]
        [string]$Pattern,

        # Replacement string (supports $1, $2 capture group references)
        [Parameter(Mandatory)]
        [string]$Replacement,

        # If set, skip conflicting renames instead of throwing
        [Parameter()]
        [switch]$Force
    )

    if (-not (Test-Path -Path $Directory -PathType Container)) {
        throw [System.IO.DirectoryNotFoundException]::new("Directory not found: '$Directory'")
    }

    # Enumerate bare filenames in the directory
    [string[]]$fileNames = Get-ChildItem -Path $Directory -File |
        Select-Object -ExpandProperty Name

    # Compute preview
    [object[]]$operations = Get-RenamePreview -Files $fileNames -Pattern $Pattern -Replacement $Replacement

    # Conflict check
    [object[]]$conflicts = Find-RenameConflicts -Operations $operations

    if ($conflicts.Count -gt 0 -and -not $Force.IsPresent) {
        [string]$conflictSummary = ($conflicts | ForEach-Object {
            "$($_.ConflictingName) <- [$($_.SourceFiles -join ', ')]"
        }) -join '; '
        throw [System.InvalidOperationException]::new(
            "Rename conflicts detected: $conflictSummary. Use -Force to skip conflicting renames."
        )
    }

    # Build a set of conflicting target names so we can skip them when -Force
    [System.Collections.Generic.HashSet[string]]$conflictNames =
        [System.Collections.Generic.HashSet[string]]::new()
    foreach ($c in $conflicts) {
        [void]$conflictNames.Add([string]$c.ConflictingName)
    }

    [System.Collections.Generic.List[object]]$results = [System.Collections.Generic.List[object]]::new()

    foreach ($op in $operations) {
        [string]$oldName = [string]$op.OldName
        [string]$newName = [string]$op.NewName

        # Skip conflicting operations when -Force
        if ($conflictNames.Contains($newName)) {
            $result = [PSCustomObject]@{
                OldName = $oldName
                NewName = $newName
                Success = $false
                Error   = 'Skipped due to naming conflict'
            }
            $results.Add($result)
            continue
        }

        [string]$oldPath = Join-Path $Directory $oldName

        if ($PSCmdlet.ShouldProcess($oldPath, "Rename to '$newName'")) {
            try {
                Rename-Item -Path $oldPath -NewName $newName -ErrorAction Stop
                $result = [PSCustomObject]@{
                    OldName = $oldName
                    NewName = $newName
                    Success = $true
                    Error   = [string]''
                }
            }
            catch {
                $result = [PSCustomObject]@{
                    OldName = $oldName
                    NewName = $newName
                    Success = $false
                    Error   = [string]$_.ToString()
                }
            }
            $results.Add($result)
        }
    }

    return , [object[]]$results.ToArray()
}

# ---------------------------------------------------------------------------
# FUNCTION: New-UndoScript
# ---------------------------------------------------------------------------
# Generates a PowerShell script that reverses a set of rename operations.
# The script renames NewName -> OldName for each operation.
# When OutputPath is provided the script is also saved to that path.
function New-UndoScript {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # The rename operations to reverse
        [Parameter(Mandatory)]
        [object[]]$Operations,

        # The directory in which the renames were performed
        [Parameter(Mandatory)]
        [string]$Directory,

        # Optional path to write the undo script to disk
        [Parameter()]
        [string]$OutputPath = ''
    )

    # Build the script lines
    [System.Collections.Generic.List[string]]$lines = [System.Collections.Generic.List[string]]::new()

    $lines.Add('# Auto-generated undo script for batch file rename')
    $lines.Add("# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $lines.Add("# Target directory: $Directory")
    $lines.Add('')
    $lines.Add('Set-StrictMode -Latest')
    $lines.Add('$ErrorActionPreference = ''Stop''')
    $lines.Add('')
    $lines.Add("# Change to the target directory")
    $lines.Add("Push-Location -Path '$Directory'")
    $lines.Add('try {')

    if ($Operations.Count -eq 0) {
        $lines.Add('    # No rename operations to undo')
    }
    else {
        foreach ($op in $Operations) {
            [string]$oldName = [string]$op.OldName
            [string]$newName = [string]$op.NewName
            # Reverse: rename NewName back to OldName
            $lines.Add("    Rename-Item -Path '$newName' -NewName '$oldName' -ErrorAction Stop")
        }
    }

    $lines.Add('}')
    $lines.Add('finally {')
    $lines.Add('    Pop-Location')
    $lines.Add('}')

    [string]$script = $lines -join [System.Environment]::NewLine

    if ($OutputPath -ne '') {
        Set-Content -Path $OutputPath -Value $script -Encoding UTF8
    }

    return $script
}

# Export public functions
Export-ModuleMember -Function Get-RenamePreview, Find-RenameConflicts, Invoke-BatchRename, New-UndoScript
