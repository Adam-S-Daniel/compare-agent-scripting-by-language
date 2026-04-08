# Rename-FilesByPattern.ps1
# Batch file renamer using regex patterns.
# Supports: preview mode, undo script generation, and conflict detection.

function Rename-FilesByPattern {
    <#
    .SYNOPSIS
        Renames files in a directory using regex-based pattern substitution.
    .PARAMETER Path
        Directory containing the files to rename.
    .PARAMETER Pattern
        Regex pattern to match against file names.
    .PARAMETER Replacement
        Replacement string (supports regex capture group references like $1).
    .PARAMETER Preview
        If set, show what would change without actually renaming.
    .PARAMETER UndoScriptPath
        If provided, write an undo script to this path that reverses the renames.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Pattern,

        [Parameter(Mandatory)]
        [string]$Replacement,

        [switch]$Preview,

        [string]$UndoScriptPath
    )

    # Validate the directory exists
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Directory not found: $Path"
    }

    # Get all files in the directory (not subdirectories)
    $files = Get-ChildItem -LiteralPath $Path -File | Sort-Object Name

    # Build the list of proposed renames by applying the regex
    $renames = @()
    foreach ($file in $files) {
        $newName = $file.Name -replace $Pattern, $Replacement
        if ($newName -ne $file.Name) {
            $renames += [PSCustomObject]@{
                OldName  = $file.Name
                NewName  = $newName
                FullPath = $file.FullName
            }
        }
    }

    # In preview mode, just return the proposed renames
    if ($Preview) {
        return $renames
    }

    # Detect conflicts: two or more files would end up with the same new name
    $grouped = $renames | Group-Object NewName | Where-Object { $_.Count -gt 1 }
    if ($grouped) {
        $conflicts = $grouped | ForEach-Object {
            $target = $_.Name
            $sources = ($_.Group | ForEach-Object { $_.OldName }) -join ", "
            "  '$sources' would all become '$target'"
        }
        throw "Conflict detected — multiple files would get the same name:`n$($conflicts -join "`n")"
    }

    # Also detect collision with existing files that are NOT being renamed
    $renameOldNames = $renames | ForEach-Object { $_.OldName }
    foreach ($r in $renames) {
        $targetPath = Join-Path $Path $r.NewName
        if ((Test-Path -LiteralPath $targetPath) -and ($r.NewName -notin $renameOldNames)) {
            throw "Conflict: '$($r.OldName)' would overwrite existing file '$($r.NewName)' which is not part of this rename batch."
        }
    }

    # Generate undo script if requested
    if ($UndoScriptPath) {
        $undoLines = @('# Undo script — reverses the renames performed by Rename-FilesByPattern')
        foreach ($r in $renames) {
            $from = Join-Path $Path $r.NewName
            $to   = Join-Path $Path $r.OldName
            $undoLines += "Rename-Item -LiteralPath '$from' -NewName '$($r.OldName)'"
        }
        $undoLines -join "`n" | Set-Content -LiteralPath $UndoScriptPath -Encoding UTF8
    }

    # Perform the actual renames
    foreach ($r in $renames) {
        Rename-Item -LiteralPath $r.FullPath -NewName $r.NewName
    }

    return $renames
}
