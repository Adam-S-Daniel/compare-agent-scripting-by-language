# FileRenamer.psm1
# Batch File Renamer module — PowerShell strict mode
# Supports: preview mode, conflict detection, undo script generation, and actual renaming

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Internal helper: build the rename map for a directory given pattern/replacement
# Returns an array of PSCustomObjects with OldName, NewName, OldPath, NewPath
# ---------------------------------------------------------------------------
function Build-RenameMap {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [string]$Directory,
        [string]$Pattern,
        [string]$Replacement
    )

    $files = Get-ChildItem -LiteralPath $Directory -File

    [PSCustomObject[]]$operations = @(
        foreach ($file in $files) {
            if ([regex]::IsMatch($file.Name, $Pattern)) {
                $newName = [regex]::Replace($file.Name, $Pattern, $Replacement)
                [PSCustomObject]@{
                    OldName = [string]$file.Name
                    NewName = [string]$newName
                    OldPath = [string]$file.FullName
                    NewPath = [string](Join-Path $Directory $newName)
                }
            }
        }
    )

    return $operations
}

# ---------------------------------------------------------------------------
# Get-RenamePreview
# Preview mode: shows what files would be renamed without performing any renames.
# Returns an array of operation objects (OldName, NewName, OldPath, NewPath).
# ---------------------------------------------------------------------------
function Get-RenamePreview {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Directory,

        [Parameter(Mandatory)]
        [string]$Pattern,

        [Parameter(Mandatory)]
        [string]$Replacement
    )

    # Validate directory exists
    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
        throw "Directory not found: '$Directory'"
    }

    return Build-RenameMap -Directory $Directory -Pattern $Pattern -Replacement $Replacement
}

# ---------------------------------------------------------------------------
# Get-ConflictDetection
# Checks whether the rename operation would cause conflicts:
#   - Multiple source files mapping to the same target name
#   - A new name colliding with an existing file that is NOT being renamed
# Returns a result object: { HasConflicts: bool, Conflicts: array }
# ---------------------------------------------------------------------------
function Get-ConflictDetection {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$Directory,

        [Parameter(Mandatory)]
        [string]$Pattern,

        [Parameter(Mandatory)]
        [string]$Replacement
    )

    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
        throw "Directory not found: '$Directory'"
    }

    [PSCustomObject[]]$ops = Build-RenameMap -Directory $Directory -Pattern $Pattern -Replacement $Replacement

    # Collect all existing file names in the directory
    [string[]]$existingNames = @(Get-ChildItem -LiteralPath $Directory -File | Select-Object -ExpandProperty Name)

    # Names that are being renamed (source side) — these are "moving out"
    [string[]]$sourceNames = @($ops | Select-Object -ExpandProperty OldName)

    # Target names that will exist after rename (source files being renamed in)
    [string[]]$targetNames = @($ops | Select-Object -ExpandProperty NewName)

    $conflicts = [System.Collections.Generic.List[PSCustomObject]]::new()

    # 1. Check for duplicate target names among the rename operations
    $grouped = $ops | Group-Object -Property NewName
    foreach ($group in $grouped) {
        if ($group.Count -gt 1) {
            $conflicts.Add([PSCustomObject]@{
                NewName     = [string]$group.Name
                Reason      = 'Multiple source files map to the same target name'
                SourceFiles = [string[]]@($group.Group | Select-Object -ExpandProperty OldName)
            })
        }
    }

    # 2. Check whether any new name collides with an existing file NOT in the rename set
    foreach ($op in $ops) {
        if ($existingNames -contains $op.NewName -and $sourceNames -notcontains $op.NewName) {
            # NewName already exists and is not itself being renamed away
            $conflicts.Add([PSCustomObject]@{
                NewName     = [string]$op.NewName
                Reason      = "Target name '$($op.NewName)' already exists and is not being renamed"
                SourceFiles = [string[]]@($op.OldName)
            })
        }
    }

    $hasConflicts = $conflicts.Count -gt 0

    return [PSCustomObject]@{
        HasConflicts = [bool]$hasConflicts
        Conflicts    = [PSCustomObject[]]$conflicts.ToArray()
    }
}

# ---------------------------------------------------------------------------
# Invoke-FileRename
# Performs the actual file renames.
# Throws if conflicts are detected so callers must handle conflict checking
# or catch the error.
# Returns an array of result objects { OldName, NewName, Success, Error }.
# ---------------------------------------------------------------------------
function Invoke-FileRename {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Directory,

        [Parameter(Mandatory)]
        [string]$Pattern,

        [Parameter(Mandatory)]
        [string]$Replacement
    )

    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
        throw "Directory not found: '$Directory'"
    }

    # Run conflict detection first — abort if any conflicts exist
    $conflictResult = Get-ConflictDetection -Directory $Directory -Pattern $Pattern -Replacement $Replacement
    if ($conflictResult.HasConflicts) {
        $conflictList = ($conflictResult.Conflicts | ForEach-Object { $_.NewName }) -join ', '
        throw "Rename aborted: conflicts detected for target name(s): $conflictList"
    }

    [PSCustomObject[]]$ops = Build-RenameMap -Directory $Directory -Pattern $Pattern -Replacement $Replacement

    if ($ops.Count -eq 0) {
        return [PSCustomObject[]]@()
    }

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($op in $ops) {
        try {
            Move-Item -LiteralPath $op.OldPath -Destination $op.NewPath
            $results.Add([PSCustomObject]@{
                OldName = [string]$op.OldName
                NewName = [string]$op.NewName
                OldPath = [string]$op.OldPath
                NewPath = [string]$op.NewPath
                Success = [bool]$true
                Error   = [string]''
            })
        }
        catch {
            $results.Add([PSCustomObject]@{
                OldName = [string]$op.OldName
                NewName = [string]$op.NewName
                OldPath = [string]$op.OldPath
                NewPath = [string]$op.NewPath
                Success = [bool]$false
                Error   = [string]$_.Exception.Message
            })
            throw
        }
    }

    return [PSCustomObject[]]$results.ToArray()
}

# ---------------------------------------------------------------------------
# New-UndoScript
# Generates a PowerShell script that reverses a set of rename operations.
# The undo script renames each file from NewPath back to OldPath.
# Throws if RenameOperations is empty.
# ---------------------------------------------------------------------------
function New-UndoScript {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$RenameOperations,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    if ($RenameOperations.Count -eq 0) {
        throw "RenameOperations must not be empty — nothing to undo."
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# Auto-generated undo script — reverses a batch rename operation')
    $lines.Add('# Run this script to restore original file names')
    $lines.Add('')
    $lines.Add('Set-StrictMode -Version Latest')
    $lines.Add('$ErrorActionPreference = ''Stop''')
    $lines.Add('')

    foreach ($op in $RenameOperations) {
        # Undo: rename NewPath -> OldPath (i.e., reverse the rename)
        $escapedNewPath = $op.NewPath -replace "'", "''"
        $escapedOldPath = $op.OldPath -replace "'", "''"
        $lines.Add("Move-Item -LiteralPath '$escapedNewPath' -Destination '$escapedOldPath'")
    }

    $lines.Add('')
    $lines.Add("Write-Host 'Undo complete: $([int]$RenameOperations.Count) file(s) restored.'")

    $content = $lines -join [System.Environment]::NewLine
    Set-Content -LiteralPath $OutputPath -Value $content -Encoding UTF8
}

# Export public functions
Export-ModuleMember -Function Get-RenamePreview, Invoke-FileRename, Get-ConflictDetection, New-UndoScript
