# FileRenamer.ps1
# Batch file renamer with preview mode, undo capability, and conflict detection.
# Driven by TDD — each function was written to pass a failing Pester test.

# ---------------------------------------------------------------------------
# Get-RenamePreview
# ---------------------------------------------------------------------------
# Returns an array of objects describing what WOULD happen if the rename were
# performed. No files are touched.
#
# Each result object has:
#   OldName    - the current filename (leaf only)
#   NewName    - the proposed filename after substitution
#   OldPath    - full path to the existing file
#   NewPath    - full path the file would move to
#   HasConflict - $true when NewPath already exists OR two renames target the same name
function Get-RenamePreview {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Directory,
        [Parameter(Mandatory)] [string] $Pattern,
        [Parameter(Mandatory)] [string] $Replacement
    )

    if (-not (Test-Path $Directory)) {
        throw "Directory not found: $Directory"
    }

    # Collect candidate rename pairs for files whose names match $Pattern
    $candidates = Get-ChildItem -LiteralPath $Directory -File | Where-Object {
        $_.Name -match $Pattern
    } | ForEach-Object {
        $newName = $_.Name -replace $Pattern, $Replacement
        [PSCustomObject]@{
            OldName     = $_.Name
            NewName     = $newName
            OldPath     = $_.FullName
            NewPath     = Join-Path $Directory $newName
            HasConflict = $false
        }
    }

    if ($null -eq $candidates -or @($candidates).Count -eq 0) {
        return @()
    }

    $candidates = @($candidates)

    # Detect inter-rename conflicts: two source files map to the same new name
    $newNameGroups = $candidates | Group-Object NewName
    $conflictNames = $newNameGroups | Where-Object { $_.Count -gt 1 } | Select-Object -ExpandProperty Name

    # Detect collisions with existing files NOT being renamed
    $renamedOldNames = $candidates | Select-Object -ExpandProperty OldName
    foreach ($item in $candidates) {
        if ($conflictNames -contains $item.NewName) {
            $item.HasConflict = $true
            continue
        }
        # Collision with a bystander file (exists on disk and is not part of this rename set)
        if (Test-Path $item.NewPath) {
            $existingLeaf = Split-Path $item.NewPath -Leaf
            if ($renamedOldNames -notcontains $existingLeaf) {
                $item.HasConflict = $true
            }
        }
    }

    return $candidates
}

# ---------------------------------------------------------------------------
# Invoke-BatchRename
# ---------------------------------------------------------------------------
# Performs the actual renames (or previews with -WhatIf).
# Skips any pair that has a conflict.
# Optionally generates an undo script.
#
# Returns result objects with Success, OldName, NewName, Error fields.
function Invoke-BatchRename {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)] [string] $Directory,
        [Parameter(Mandatory)] [string] $Pattern,
        [Parameter(Mandatory)] [string] $Replacement,
        [switch] $GenerateUndo,
        [string] $UndoPath = (Join-Path $Directory "undo_rename.ps1")
    )

    $preview = Get-RenamePreview -Directory $Directory -Pattern $Pattern -Replacement $Replacement

    $safe     = @($preview | Where-Object { -not $_.HasConflict })
    $skipped  = @($preview | Where-Object { $_.HasConflict })

    # Report skipped items so the caller is aware of conflicts
    foreach ($skip in $skipped) {
        Write-Warning "Skipping '$($skip.OldName)' -> '$($skip.NewName)': conflict detected."
    }

    $results = @()

    foreach ($pair in $safe) {
        # ShouldProcess honours -WhatIf: when set, the body is skipped
        if ($PSCmdlet.ShouldProcess($pair.OldPath, "Rename to $($pair.NewName)")) {
            try {
                Rename-Item -LiteralPath $pair.OldPath -NewName $pair.NewName -ErrorAction Stop
                $results += [PSCustomObject]@{
                    OldName = $pair.OldName
                    NewName = $pair.NewName
                    Success = $true
                    Error   = $null
                }
            }
            catch {
                $results += [PSCustomObject]@{
                    OldName = $pair.OldName
                    NewName = $pair.NewName
                    Success = $false
                    Error   = $_.Exception.Message
                }
            }
        }
    }

    # Generate undo script from successful renames
    if ($GenerateUndo -and $results.Count -gt 0) {
        $successPairs = $results | Where-Object { $_.Success }
        if (@($successPairs).Count -gt 0) {
            New-UndoScript -RenamePairs $successPairs -Directory $Directory -OutputPath $UndoPath
        }
    }

    return $results
}

# ---------------------------------------------------------------------------
# New-UndoScript
# ---------------------------------------------------------------------------
# Generates a PowerShell script that reverses a set of renames.
# The generated script renames NewName -> OldName for every pair.
function New-UndoScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $RenamePairs,   # objects with OldName / NewName
        [Parameter(Mandatory)] [string] $Directory,
        [Parameter(Mandatory)] [string] $OutputPath
    )

    $lines = @()
    $lines += "# Auto-generated undo script — reverses a batch rename operation."
    $lines += "# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $lines += "# Directory : $Directory"
    $lines += ""
    $lines += 'param([string]$Directory = "{0}")' -f $Directory
    $lines += ""

    foreach ($pair in $RenamePairs) {
        $newPath = 'Join-Path $Directory "{0}"' -f $pair.NewName
        $oldName = $pair.OldName
        $lines += "# Reverse: $($pair.NewName) -> $oldName"
        $lines += "if (Test-Path ($newPath)) {"
        $lines += '    Rename-Item -LiteralPath ({0}) -NewName "{1}"' -f $newPath, $oldName
        $lines += "} else {"
        $lines += '    Write-Warning "Cannot undo: file not found: $($Directory)/{0}"' -f $pair.NewName
        $lines += "}"
        $lines += ""
    }

    $lines | Set-Content -LiteralPath $OutputPath -Encoding UTF8
}
