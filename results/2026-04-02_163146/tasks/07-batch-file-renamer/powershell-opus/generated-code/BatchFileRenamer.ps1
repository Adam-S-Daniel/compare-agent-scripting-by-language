# BatchFileRenamer.ps1
# Regex-based batch file renamer with preview, undo, and conflict detection
# Implementation driven by TDD - each function added to satisfy failing tests

# ============================================================================
# TDD Cycle 1 (GREEN): Get-RenamePreview
# Tests required: compute new filenames from regex pattern/replacement
# Minimum implementation: iterate filenames, apply -replace, return changed ones
# ============================================================================

function Get-RenamePreview {
    <#
    .SYNOPSIS
        Computes rename operations from a regex pattern without touching files.
    .DESCRIPTION
        Takes a list of filenames and applies a regex pattern + replacement to
        compute what the new names would be. Returns only files that would change.
    .PARAMETER FileNames
        Array of filenames to evaluate.
    .PARAMETER Pattern
        Regex pattern to match against filenames.
    .PARAMETER Replacement
        Replacement string (supports $1, $2, etc. for capture groups).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$FileNames,

        [Parameter(Mandatory)]
        [string]$Pattern,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Replacement
    )

    # Validate the regex pattern is valid before processing
    try {
        [regex]::new($Pattern) | Out-Null
    }
    catch {
        throw "Invalid regex pattern '$Pattern': $($_.Exception.Message)"
    }

    $results = @()

    foreach ($fileName in $FileNames) {
        # Apply regex replacement
        $newName = [regex]::Replace($fileName, $Pattern, $Replacement)

        # Only include files where the name actually changes
        if ($newName -ne $fileName) {
            $results += [PSCustomObject]@{
                OldName = $fileName
                NewName = $newName
            }
        }
    }

    return $results
}

# ============================================================================
# TDD Cycle 2 (GREEN): Find-RenameConflicts
# Tests required: detect when two files would get the same name,
#                 or when a new name collides with an existing file
# ============================================================================

function Find-RenameConflicts {
    <#
    .SYNOPSIS
        Detects naming conflicts in a set of rename operations.
    .DESCRIPTION
        Checks for two types of conflicts:
        1. Duplicate targets: two or more files would be renamed to the same name
        2. Existing file conflicts: a new name matches an existing file that isn't being renamed
    .PARAMETER RenameOperations
        Array of objects with OldName and NewName properties (from Get-RenamePreview).
    .PARAMETER AllFileNames
        Complete list of filenames in the directory (for checking existing file conflicts).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$RenameOperations,

        [Parameter()]
        [string[]]$AllFileNames = @()
    )

    $conflicts = @()

    # Check for duplicate target names (multiple files -> same name)
    $targetGroups = $RenameOperations | Group-Object -Property NewName | Where-Object { $_.Count -gt 1 }
    foreach ($group in $targetGroups) {
        $sourceNames = ($group.Group | ForEach-Object { $_.OldName }) -join ", "
        $conflicts += [PSCustomObject]@{
            Type    = "DuplicateTarget"
            NewName = $group.Name
            Message = "Multiple files would be renamed to '$($group.Name)': $sourceNames"
        }
    }

    # Check for collisions with existing files not being renamed
    $oldNames = @($RenameOperations | ForEach-Object { $_.OldName })
    foreach ($op in $RenameOperations) {
        # If the new name matches an existing file that is NOT itself being renamed
        if ($AllFileNames -contains $op.NewName -and $oldNames -notcontains $op.NewName) {
            $conflicts += [PSCustomObject]@{
                Type    = "ExistingFile"
                NewName = $op.NewName
                Message = "Cannot rename '$($op.OldName)' to '$($op.NewName)': a file with that name already exists"
            }
        }
    }

    return $conflicts
}

# ============================================================================
# TDD Cycle 3 (GREEN): Invoke-BatchRename
# Tests required: actually rename files in a directory, using mock filesystem
# ============================================================================

function Invoke-BatchRename {
    <#
    .SYNOPSIS
        Executes batch rename operations on files in a directory.
    .DESCRIPTION
        Renames files based on regex pattern matching. Supports preview mode
        and conflict detection. Returns results of the rename operations.
    .PARAMETER Path
        Directory containing files to rename.
    .PARAMETER Pattern
        Regex pattern to match against filenames.
    .PARAMETER Replacement
        Replacement string for matched filenames.
    .PARAMETER Preview
        If set, only shows what would be renamed without making changes.
    .PARAMETER Force
        If set, skips conflict checking (use with caution).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Pattern,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Replacement,

        [switch]$Preview,

        [switch]$Force
    )

    # Validate directory exists
    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw "Directory not found: '$Path'"
    }

    # Get all files in the directory (names only)
    $files = Get-ChildItem -Path $Path -File | Select-Object -ExpandProperty Name

    if ($files.Count -eq 0) {
        Write-Warning "No files found in '$Path'"
        return @()
    }

    # Compute rename preview
    $operations = Get-RenamePreview -FileNames $files -Pattern $Pattern -Replacement $Replacement

    if ($operations.Count -eq 0) {
        Write-Warning "No files match pattern '$Pattern'"
        return @()
    }

    # In preview mode, just return the operations
    if ($Preview) {
        return $operations
    }

    # Check for conflicts unless Force is specified
    if (-not $Force) {
        $conflicts = Find-RenameConflicts -RenameOperations $operations -AllFileNames $files
        if ($conflicts.Count -gt 0) {
            $conflictMessages = ($conflicts | ForEach-Object { $_.Message }) -join "; "
            throw "Rename conflicts detected: $conflictMessages"
        }
    }

    # Execute the renames
    $results = @()
    foreach ($op in $operations) {
        $sourcePath = Join-Path -Path $Path -ChildPath $op.OldName
        $destPath = Join-Path -Path $Path -ChildPath $op.NewName

        try {
            Rename-Item -Path $sourcePath -NewName $op.NewName -ErrorAction Stop
            $results += [PSCustomObject]@{
                OldName = $op.OldName
                NewName = $op.NewName
                Status  = "Success"
            }
        }
        catch {
            $results += [PSCustomObject]@{
                OldName = $op.OldName
                NewName = $op.NewName
                Status  = "Failed"
                Error   = $_.Exception.Message
            }
        }
    }

    return $results
}

# ============================================================================
# TDD Cycle 4 (GREEN): New-UndoScript
# Tests required: generate a PowerShell script that reverses rename operations
# ============================================================================

function New-UndoScript {
    <#
    .SYNOPSIS
        Generates a PowerShell undo script to reverse rename operations.
    .DESCRIPTION
        Takes rename operations and produces a script that will rename each
        file back to its original name. Can output to file or return as string.
    .PARAMETER RenameOperations
        Array of objects with OldName and NewName properties.
    .PARAMETER Directory
        The directory where files were renamed.
    .PARAMETER OutputPath
        Optional path to write the undo script. If omitted, returns as string.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$RenameOperations,

        [Parameter(Mandatory)]
        [string]$Directory,

        [Parameter()]
        [string]$OutputPath
    )

    # Build the undo script content with reverse operations
    $scriptLines = @()
    $scriptLines += "# Undo script generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $scriptLines += "# Reverses rename operations in: $Directory"
    $scriptLines += '# Usage: Run this script to undo the batch rename'
    $scriptLines += ''
    $scriptLines += '$errorCount = 0'

    # Reverse each operation: NewName -> OldName
    foreach ($op in $RenameOperations) {
        $escapedNew = $op.NewName -replace "'", "''"
        $escapedOld = $op.OldName -replace "'", "''"
        $scriptLines += ""
        $scriptLines += "# Undo: '$($op.NewName)' -> '$($op.OldName)'"
        $scriptLines += "try {"
        $scriptLines += "    Rename-Item -Path (Join-Path '$Directory' '$escapedNew') -NewName '$escapedOld' -ErrorAction Stop"
        $scriptLines += "    Write-Host `"Restored: '$($op.NewName)' -> '$($op.OldName)'`" -ForegroundColor Green"
        $scriptLines += "}"
        $scriptLines += "catch {"
        $scriptLines += "    Write-Host `"Failed to restore: '$($op.NewName)' -> '$($op.OldName)': `$(`$_.Exception.Message)`" -ForegroundColor Red"
        $scriptLines += '    $errorCount++'
        $scriptLines += "}"
    }

    $scriptLines += ""
    $scriptLines += 'if ($errorCount -eq 0) {'
    $scriptLines += '    Write-Host "`nAll files restored successfully." -ForegroundColor Green'
    $scriptLines += "}"
    $scriptLines += "else {"
    $scriptLines += '    Write-Host "`n$errorCount file(s) failed to restore." -ForegroundColor Red'
    $scriptLines += "}"

    $scriptContent = $scriptLines -join "`n"

    # Write to file if OutputPath specified, otherwise return as string
    if ($OutputPath) {
        $scriptContent | Out-File -FilePath $OutputPath -Encoding utf8 -Force
        return $OutputPath
    }

    return $scriptContent
}

# ============================================================================
# TDD Cycle 5 (GREEN): Format-RenamePreview
# Tests required: format preview output as a readable table
# ============================================================================

function Format-RenamePreview {
    <#
    .SYNOPSIS
        Formats rename preview operations for display.
    .DESCRIPTION
        Takes rename operations and returns formatted strings showing
        old name -> new name for each operation.
    .PARAMETER RenameOperations
        Array of objects with OldName and NewName properties.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$RenameOperations
    )

    $output = @()
    $output += "Preview of rename operations ($($RenameOperations.Count) file(s)):"
    $output += ("-" * 60)

    foreach ($op in $RenameOperations) {
        $output += "  $($op.OldName) -> $($op.NewName)"
    }

    $output += ("-" * 60)

    return ($output -join "`n")
}
