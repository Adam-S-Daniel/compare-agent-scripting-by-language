# Rename-Files.ps1
# Batch File Renamer - renames files using regex-based patterns.
#
# Features:
#   - Preview mode: show what would change without doing it
#   - Undo capability: generate a PowerShell undo script that reverses the renames
#   - Conflict detection: detect when two files would get the same name
#
# TDD approach: each function was driven by a failing Pester test.

# ---------------------------------------------------------------------------
# Get-RenamePreview
# ---------------------------------------------------------------------------
# Returns an array of rename operation objects without touching the file system.
# Each object has: OldName, NewName, OldPath, NewPath
function Get-RenamePreview {
    param(
        [string]$Directory,
        [string]$Pattern,
        [string]$Replacement,
        [switch]$CaseInsensitive
    )

    if (-not (Test-Path $Directory)) {
        Write-Error "Directory not found: $Directory"
        return @()
    }

    $regexOptions = if ($CaseInsensitive) { [System.Text.RegularExpressions.RegexOptions]::IgnoreCase } else { [System.Text.RegularExpressions.RegexOptions]::None }

    $files = Get-ChildItem -Path $Directory -File

    # Use explicit array to avoid $null-vs-empty-array ambiguity
    $operations = @()
    foreach ($file in $files) {
        if ([System.Text.RegularExpressions.Regex]::IsMatch($file.Name, $Pattern, $regexOptions)) {
            $newName = [System.Text.RegularExpressions.Regex]::Replace($file.Name, $Pattern, $Replacement, $regexOptions)
            $operations += [PSCustomObject]@{
                OldName = $file.Name
                NewName = $newName
                OldPath = $file.FullName
                NewPath = Join-Path $Directory $newName
            }
        }
    }

    return $operations
}

# ---------------------------------------------------------------------------
# Test-RenameConflicts
# ---------------------------------------------------------------------------
# Checks a list of rename operations for conflicts:
#   1. Two source files mapping to the same target name ("Duplicate" conflict)
#   2. A target name already exists as a file NOT being renamed ("ExistingFile" conflict)
#
# Returns an array of conflict objects: TargetName, ConflictType, ConflictingFiles
function Test-RenameConflicts {
    param(
        [object[]]$RenameOperations,
        [string]$Directory = ""
    )

    $conflicts = @()

    # Check type 1: multiple source files map to the same target name
    $grouped = $RenameOperations | Group-Object -Property NewName
    foreach ($group in $grouped) {
        if ($group.Count -gt 1) {
            $conflicts += [PSCustomObject]@{
                TargetName       = $group.Name
                ConflictType     = "Duplicate"
                ConflictingFiles = $group.Group | ForEach-Object { $_.OldName }
            }
        }
    }

    # Check type 2: target name collides with an existing file not in the rename set
    if ($Directory -ne "" -and (Test-Path $Directory)) {
        $sourceNames = $RenameOperations | ForEach-Object { $_.OldName }

        foreach ($op in $RenameOperations) {
            # Skip no-op renames (file keeps same name)
            if ($op.OldName -eq $op.NewName) { continue }

            $targetPath = Join-Path $Directory $op.NewName
            if ((Test-Path $targetPath) -and ($sourceNames -notcontains $op.NewName)) {
                $conflicts += [PSCustomObject]@{
                    TargetName       = $op.NewName
                    ConflictType     = "ExistingFile"
                    ConflictingFiles = @($op.OldName)
                }
            }
        }
    }

    return @($conflicts)
}

# ---------------------------------------------------------------------------
# New-UndoScript
# ---------------------------------------------------------------------------
# Generates a PowerShell script that reverses a set of rename operations.
# Operations are written in reverse order so dependent renames unwind correctly.
function New-UndoScript {
    param(
        [object[]]$RenameOperations,
        [string]$OutputPath
    )

    $lines = @()
    $lines += "# Undo script - reverses the batch rename operation"
    $lines += "# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $lines += ""

    # Process in reverse order so chained renames unwind properly
    # Use index-based reversal (idiomatic PowerShell, avoids generic method resolution issues)
    $reversed = if ($RenameOperations.Count -gt 0) {
        $RenameOperations[($RenameOperations.Count - 1)..0]
    } else {
        @()
    }
    foreach ($op in $reversed) {
        $escapedNewPath = $op.NewPath -replace "'", "''"
        $escapedOldName = $op.OldName -replace "'", "''"
        $lines += "Rename-Item -Path '$escapedNewPath' -NewName '$escapedOldName'"
    }

    Set-Content -Path $OutputPath -Value $lines -Encoding UTF8
}

# ---------------------------------------------------------------------------
# Invoke-FileRename
# ---------------------------------------------------------------------------
# Main entry point. Combines preview, conflict detection, actual rename, and
# optional undo script generation.
#
# Parameters:
#   -Directory      : Path to the directory containing files to rename
#   -Pattern        : Regex pattern to match file names
#   -Replacement    : Replacement string (supports $1, $2 capture group references)
#   -Preview        : If $true, show changes but do NOT rename any files (default: $true)
#   -StopOnConflict : If set, throw an error when conflicts are detected
#   -UndoScriptPath : If specified, write an undo script to this path after renaming
#   -CaseInsensitive: If set, pattern matching is case-insensitive
function Invoke-FileRename {
    param(
        [string]$Directory,
        [string]$Pattern,
        [string]$Replacement,
        [bool]$Preview = $true,
        [switch]$StopOnConflict,
        [string]$UndoScriptPath = "",
        [switch]$CaseInsensitive
    )

    # Step 1: compute what renames would happen
    $previewParams = @{
        Directory   = $Directory
        Pattern     = $Pattern
        Replacement = $Replacement
    }
    if ($CaseInsensitive) { $previewParams['CaseInsensitive'] = $true }

    $operations = Get-RenamePreview @previewParams

    if ($operations.Count -eq 0) {
        Write-Verbose "No files matched pattern '$Pattern' in '$Directory'."
        return @()
    }

    # Step 2: conflict detection
    $conflictParams = @{ RenameOperations = $operations; Directory = $Directory }
    $conflicts = Test-RenameConflicts @conflictParams

    if ($conflicts.Count -gt 0) {
        $msg = "Rename conflicts detected:`n"
        foreach ($c in $conflicts) {
            $msg += "  [$($c.ConflictType)] Target '$($c.TargetName)' conflicts: $($c.ConflictingFiles -join ', ')`n"
        }
        if ($StopOnConflict) {
            throw $msg
        } else {
            Write-Warning $msg
        }
    }

    # Step 3: display preview
    foreach ($op in $operations) {
        Write-Verbose "  $($op.OldName)  ->  $($op.NewName)"
    }

    # Step 4: perform renames if not in preview mode
    if (-not $Preview) {
        foreach ($op in $operations) {
            if ($op.OldName -ne $op.NewName) {
                Rename-Item -Path $op.OldPath -NewName $op.NewName
            }
        }

        # Step 5: generate undo script if path was provided
        if ($UndoScriptPath -ne "") {
            New-UndoScript -RenameOperations $operations -OutputPath $UndoScriptPath
        }
    }

    return $operations
}
