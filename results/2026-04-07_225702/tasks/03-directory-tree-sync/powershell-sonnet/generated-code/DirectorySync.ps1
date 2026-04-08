# DirectorySync.ps1
# Directory Tree Sync implementation
#
# Compares two directory trees, identifies files that differ (by SHA-256 content hash),
# files that exist only in one tree, and generates a sync plan.
# Supports dry-run mode (report only) and execute mode (perform the sync).

# ===========================================================================
# FEATURE 1: Compute SHA-256 hash of a file
# ===========================================================================

function Get-FileSha256 {
    <#
    .SYNOPSIS
        Computes the SHA-256 hash of a file.
    .PARAMETER Path
        Absolute path to the file.
    .OUTPUTS
        Lowercase hex string of the SHA-256 digest.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "File not found: '$Path'"
    }

    $hashObj = Get-FileHash -LiteralPath $Path -Algorithm SHA256
    return $hashObj.Hash.ToLower()
}

# ===========================================================================
# FEATURE 2: Get directory tree as relative-path -> hash map
# ===========================================================================

function Get-DirectoryTree {
    <#
    .SYNOPSIS
        Recursively walks a directory and returns a hashtable of
        relative-path -> SHA-256 hash for every file.
    .PARAMETER Path
        Root directory to walk.
    .OUTPUTS
        [hashtable] where keys are relative paths (forward-slash separated)
        and values are SHA-256 hex strings.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Directory does not exist: '$Path'"
    }

    $tree = @{}

    # Get all files recursively
    $files = Get-ChildItem -LiteralPath $Path -Recurse -File

    foreach ($file in $files) {
        # Build a relative path using forward slashes for cross-platform consistency
        $relativePath = $file.FullName.Substring($Path.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar, '/')
        $relativePath = $relativePath.Replace([System.IO.Path]::DirectorySeparatorChar, '/')

        $tree[$relativePath] = Get-FileSha256 -Path $file.FullName
    }

    return $tree
}

# ===========================================================================
# FEATURE 3: Compare two directory trees
# ===========================================================================

function Compare-DirectoryTrees {
    <#
    .SYNOPSIS
        Compares two directory trees and categorizes each file.
    .PARAMETER SourcePath
        Root of the source directory tree.
    .PARAMETER DestPath
        Root of the destination directory tree.
    .OUTPUTS
        A PSCustomObject with:
          - SourceOnly : [string[]] relative paths only in source
          - DestOnly   : [string[]] relative paths only in destination
          - Modified   : [string[]] relative paths present in both with different hashes
          - Identical  : [string[]] relative paths present in both with identical hashes
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$DestPath
    )

    $sourceTree = Get-DirectoryTree -Path $SourcePath
    $destTree   = Get-DirectoryTree -Path $DestPath

    $sourceOnly = [System.Collections.Generic.List[string]]::new()
    $destOnly   = [System.Collections.Generic.List[string]]::new()
    $modified   = [System.Collections.Generic.List[string]]::new()
    $identical  = [System.Collections.Generic.List[string]]::new()

    # Check all source files
    foreach ($relPath in $sourceTree.Keys) {
        if ($destTree.ContainsKey($relPath)) {
            if ($sourceTree[$relPath] -eq $destTree[$relPath]) {
                $identical.Add($relPath)
            } else {
                $modified.Add($relPath)
            }
        } else {
            $sourceOnly.Add($relPath)
        }
    }

    # Check dest files not in source
    foreach ($relPath in $destTree.Keys) {
        if (-not $sourceTree.ContainsKey($relPath)) {
            $destOnly.Add($relPath)
        }
    }

    return [PSCustomObject]@{
        SourceOnly = $sourceOnly.ToArray()
        DestOnly   = $destOnly.ToArray()
        Modified   = $modified.ToArray()
        Identical  = $identical.ToArray()
    }
}

# ===========================================================================
# FEATURE 4: Generate sync plan
# ===========================================================================

function Get-SyncPlan {
    <#
    .SYNOPSIS
        Generates a list of actions needed to sync the destination to the source.
    .PARAMETER Comparison
        Output from Compare-DirectoryTrees.
    .PARAMETER SourcePath
        Root of the source directory.
    .PARAMETER DestPath
        Root of the destination directory.
    .OUTPUTS
        Array of PSCustomObjects, each with:
          - Action       : "Copy" | "Overwrite" | "Delete"
          - RelativePath : relative path of the file
          - SourcePath   : full path in source (null for Delete)
          - DestPath     : full path in destination
    #>
    param(
        [Parameter(Mandatory)]
        $Comparison,

        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$DestPath
    )

    $plan = [System.Collections.Generic.List[object]]::new()

    # Files to copy from source to dest (new)
    foreach ($relPath in $Comparison.SourceOnly) {
        $plan.Add([PSCustomObject]@{
            Action       = "Copy"
            RelativePath = $relPath
            SourcePath   = Join-Path $SourcePath $relPath
            DestPath     = Join-Path $DestPath $relPath
        })
    }

    # Files to overwrite in dest (modified)
    foreach ($relPath in $Comparison.Modified) {
        $plan.Add([PSCustomObject]@{
            Action       = "Overwrite"
            RelativePath = $relPath
            SourcePath   = Join-Path $SourcePath $relPath
            DestPath     = Join-Path $DestPath $relPath
        })
    }

    # Files to delete from dest (dest-only)
    foreach ($relPath in $Comparison.DestOnly) {
        $plan.Add([PSCustomObject]@{
            Action       = "Delete"
            RelativePath = $relPath
            SourcePath   = $null
            DestPath     = Join-Path $DestPath $relPath
        })
    }

    return $plan.ToArray()
}

# ===========================================================================
# FEATURE 5: Dry-run mode
# ===========================================================================

function Invoke-SyncDryRun {
    <#
    .SYNOPSIS
        Performs a dry run of the sync: compares trees, builds the plan,
        but does NOT modify any files.
    .PARAMETER SourcePath
        Root of the source directory.
    .PARAMETER DestPath
        Root of the destination directory.
    .OUTPUTS
        A PSCustomObject with:
          - Plan    : the array of planned actions
          - Summary : counts of each action type and identical files
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$DestPath
    )

    $comparison = Compare-DirectoryTrees -SourcePath $SourcePath -DestPath $DestPath
    $plan       = Get-SyncPlan -Comparison $comparison -SourcePath $SourcePath -DestPath $DestPath

    $summary = [PSCustomObject]@{
        CopyCount      = ($plan | Where-Object { $_.Action -eq "Copy" } | Measure-Object).Count
        OverwriteCount = ($plan | Where-Object { $_.Action -eq "Overwrite" } | Measure-Object).Count
        DeleteCount    = ($plan | Where-Object { $_.Action -eq "Delete" } | Measure-Object).Count
        IdenticalCount = $comparison.Identical.Count
    }

    return [PSCustomObject]@{
        Plan    = $plan
        Summary = $summary
    }
}

# ===========================================================================
# FEATURE 6: Execute mode
# ===========================================================================

function Invoke-SyncExecute {
    <#
    .SYNOPSIS
        Executes the sync: copies new files, overwrites changed files,
        and deletes files that no longer exist in source.
    .PARAMETER SourcePath
        Root of the source directory.
    .PARAMETER DestPath
        Root of the destination directory.
    .OUTPUTS
        A PSCustomObject with:
          - ActionsPerformed : list of actions that were actually performed
          - ErrorCount       : number of errors encountered
          - Errors           : list of error messages
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$DestPath
    )

    $comparison = Compare-DirectoryTrees -SourcePath $SourcePath -DestPath $DestPath
    $plan       = Get-SyncPlan -Comparison $comparison -SourcePath $SourcePath -DestPath $DestPath

    $actionsPerformed = [System.Collections.Generic.List[object]]::new()
    $errors           = [System.Collections.Generic.List[string]]::new()

    foreach ($action in $plan) {
        try {
            switch ($action.Action) {
                "Copy" {
                    # Ensure parent directory exists
                    $destParent = Split-Path -Parent $action.DestPath
                    if (-not (Test-Path -LiteralPath $destParent)) {
                        New-Item -ItemType Directory -Path $destParent -Force | Out-Null
                    }
                    Copy-Item -LiteralPath $action.SourcePath -Destination $action.DestPath -Force
                    $actionsPerformed.Add($action)
                }
                "Overwrite" {
                    Copy-Item -LiteralPath $action.SourcePath -Destination $action.DestPath -Force
                    $actionsPerformed.Add($action)
                }
                "Delete" {
                    Remove-Item -LiteralPath $action.DestPath -Force
                    $actionsPerformed.Add($action)
                }
            }
        } catch {
            $errors.Add("Failed to $($action.Action) '$($action.RelativePath)': $_")
        }
    }

    return [PSCustomObject]@{
        ActionsPerformed = $actionsPerformed.ToArray()
        ErrorCount       = $errors.Count
        Errors           = $errors.ToArray()
    }
}
