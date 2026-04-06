Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# DirectorySync.ps1
# Implementation of directory tree comparison and synchronization.
#
# TDD approach:
#   RED   - Tests written in DirectorySync.Tests.ps1 (all fail before this file exists)
#   GREEN - Minimum code here to make each test pass
#   REFACTOR - Functions are kept clean, typed, and documented
#
# Design:
#   1. Get-FileHash256        - hash a single file via SHA-256
#   2. Get-DirectoryIndex     - build a relative-path -> hash map for a tree
#   3. Compare-DirectoryTrees - diff two indexes into Identical/Modified/OnlyInSource/OnlyInTarget
#   4. New-SyncPlan           - turn comparison result into a list of action items
#   5. Invoke-SyncPlan        - execute (or dry-run) a plan, return a result report
#   6. Invoke-DirectorySync   - top-level orchestrator combining all of the above


# ---------------------------------------------------------------------------
# Get-FileHash256
# ---------------------------------------------------------------------------
# Computes the SHA-256 hash of a single file and returns it as a lowercase
# 64-character hex string.  Throws if the file does not exist.
function Get-FileHash256 {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        throw "File not found: '$FilePath'"
    }

    $hashObj = Get-FileHash -LiteralPath $FilePath -Algorithm SHA256
    return $hashObj.Hash.ToLowerInvariant()
}


# ---------------------------------------------------------------------------
# Get-DirectoryIndex
# ---------------------------------------------------------------------------
# Recursively enumerates all files under $DirectoryPath and returns a
# hashtable mapping each file's RELATIVE path (using OS path separator) to
# its SHA-256 hash.  An empty directory returns an empty hashtable.
function Get-DirectoryIndex {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$DirectoryPath
    )

    if (-not (Test-Path -LiteralPath $DirectoryPath -PathType Container)) {
        throw "Directory not found: '$DirectoryPath'"
    }

    [hashtable]$index = @{}

    # Resolve to a canonical absolute path so relative-path calculation is stable
    [string]$resolvedBase = (Resolve-Path -LiteralPath $DirectoryPath).Path

    # Ensure the base ends with a separator for reliable string trimming
    if (-not $resolvedBase.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $resolvedBase = $resolvedBase + [System.IO.Path]::DirectorySeparatorChar
    }

    $files = Get-ChildItem -LiteralPath $resolvedBase -Recurse -File -ErrorAction Stop

    foreach ($file in $files) {
        # Derive relative path by stripping the base prefix
        [string]$relativePath = $file.FullName.Substring($resolvedBase.Length)
        $index[$relativePath] = Get-FileHash256 -FilePath $file.FullName
    }

    return $index
}


# ---------------------------------------------------------------------------
# Compare-DirectoryTrees
# ---------------------------------------------------------------------------
# Compares two directory trees and categorises every file into one of four
# buckets:
#   Identical    - same relative path, same hash in both trees
#   Modified     - same relative path, different hash
#   OnlyInSource - present in source, absent in target
#   OnlyInTarget - present in target, absent in source
#
# Returns a PSCustomObject with those four array properties.
function Compare-DirectoryTrees {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$TargetPath
    )

    [hashtable]$sourceIndex = Get-DirectoryIndex -DirectoryPath $SourcePath
    [hashtable]$targetIndex = Get-DirectoryIndex -DirectoryPath $TargetPath

    [System.Collections.Generic.List[string]]$identical     = [System.Collections.Generic.List[string]]::new()
    [System.Collections.Generic.List[string]]$modified      = [System.Collections.Generic.List[string]]::new()
    [System.Collections.Generic.List[string]]$onlyInSource  = [System.Collections.Generic.List[string]]::new()
    [System.Collections.Generic.List[string]]$onlyInTarget  = [System.Collections.Generic.List[string]]::new()

    # Walk every file in source and compare against target
    foreach ($relativePath in $sourceIndex.Keys) {
        if ($targetIndex.ContainsKey($relativePath)) {
            if ($sourceIndex[$relativePath] -eq $targetIndex[$relativePath]) {
                $identical.Add($relativePath)
            } else {
                $modified.Add($relativePath)
            }
        } else {
            $onlyInSource.Add($relativePath)
        }
    }

    # Find files that are in target but not in source
    foreach ($relativePath in $targetIndex.Keys) {
        if (-not $sourceIndex.ContainsKey($relativePath)) {
            $onlyInTarget.Add($relativePath)
        }
    }

    return [PSCustomObject]@{
        Identical   = [string[]]$identical.ToArray()
        Modified    = [string[]]$modified.ToArray()
        OnlyInSource = [string[]]$onlyInSource.ToArray()
        OnlyInTarget = [string[]]$onlyInTarget.ToArray()
    }
}


# ---------------------------------------------------------------------------
# New-SyncPlan
# ---------------------------------------------------------------------------
# Converts a comparison result (from Compare-DirectoryTrees) into an ordered
# list of plan items.  Each item has:
#   Action       - 'CopyToTarget' | 'UpdateInTarget' | 'DeleteFromTarget'
#   RelativePath - the relative file path the action applies to
#
# Files in the Identical bucket produce NO plan items.
function New-SyncPlan {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$ComparisonResult
    )

    [System.Collections.Generic.List[PSCustomObject]]$plan = [System.Collections.Generic.List[PSCustomObject]]::new()

    # New files: copy from source to target
    foreach ($relativePath in $ComparisonResult.OnlyInSource) {
        $plan.Add([PSCustomObject]@{
            Action       = 'CopyToTarget'
            RelativePath = $relativePath
        })
    }

    # Changed files: overwrite target with source version
    foreach ($relativePath in $ComparisonResult.Modified) {
        $plan.Add([PSCustomObject]@{
            Action       = 'UpdateInTarget'
            RelativePath = $relativePath
        })
    }

    # Orphan files in target: remove them
    foreach ($relativePath in $ComparisonResult.OnlyInTarget) {
        $plan.Add([PSCustomObject]@{
            Action       = 'DeleteFromTarget'
            RelativePath = $relativePath
        })
    }

    return [PSCustomObject[]]$plan.ToArray()
}


# ---------------------------------------------------------------------------
# Invoke-SyncPlan
# ---------------------------------------------------------------------------
# Executes (or simulates) a sync plan produced by New-SyncPlan.
#
# Parameters:
#   Plan        - array of plan items (Action + RelativePath)
#   SourcePath  - root of the source tree
#   TargetPath  - root of the target tree
#   DryRun      - switch; if set, NO files are touched and a report is returned
#
# Returns an array of result objects with:
#   Action       - the action that was taken (or would be taken)
#   RelativePath - the file the action applies to
#   Status       - 'WouldExecute' (dry-run) or 'Success' / 'Failed' (execute)
#   Error        - populated only when Status is 'Failed'
function Invoke-SyncPlan {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Plan,

        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$TargetPath,

        [switch]$DryRun
    )

    [System.Collections.Generic.List[PSCustomObject]]$report = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($item in $Plan) {
        [string]$action       = [string]$item.Action
        [string]$relativePath = [string]$item.RelativePath
        [string]$sourceFull   = Join-Path $SourcePath $relativePath
        [string]$targetFull   = Join-Path $TargetPath $relativePath

        if ($DryRun) {
            # Dry-run: just record what would happen
            $report.Add([PSCustomObject]@{
                Action       = $action
                RelativePath = $relativePath
                Status       = 'WouldExecute'
                Error        = [string]$null
            })
            continue
        }

        # Execute mode
        [string]$status = 'Success'
        [string]$errorMsg = [string]$null

        try {
            switch ($action) {
                'CopyToTarget' {
                    # Ensure the destination subdirectory exists
                    [string]$targetDir = [System.IO.Path]::GetDirectoryName($targetFull)
                    if (-not (Test-Path -LiteralPath $targetDir -PathType Container)) {
                        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                    }
                    Copy-Item -LiteralPath $sourceFull -Destination $targetFull -Force
                }
                'UpdateInTarget' {
                    [string]$targetDir = [System.IO.Path]::GetDirectoryName($targetFull)
                    if (-not (Test-Path -LiteralPath $targetDir -PathType Container)) {
                        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                    }
                    Copy-Item -LiteralPath $sourceFull -Destination $targetFull -Force
                }
                'DeleteFromTarget' {
                    Remove-Item -LiteralPath $targetFull -Force
                }
                default {
                    throw "Unknown action: '$action'"
                }
            }
        }
        catch {
            $status   = 'Failed'
            $errorMsg = [string]$_.Exception.Message
        }

        $report.Add([PSCustomObject]@{
            Action       = $action
            RelativePath = $relativePath
            Status       = $status
            Error        = $errorMsg
        })
    }

    return [PSCustomObject[]]$report.ToArray()
}


# ---------------------------------------------------------------------------
# Invoke-DirectorySync
# ---------------------------------------------------------------------------
# Top-level entry point.  Compares source and target, builds a sync plan,
# then either reports (DryRun) or executes the plan.
#
# Returns the result report from Invoke-SyncPlan.
function Invoke-DirectorySync {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$TargetPath,

        [switch]$DryRun
    )

    Write-Verbose "Comparing '$SourcePath' with '$TargetPath'..."
    [PSCustomObject]$comparison = Compare-DirectoryTrees -SourcePath $SourcePath -TargetPath $TargetPath

    Write-Verbose "Building sync plan..."
    [PSCustomObject[]]$plan = New-SyncPlan -ComparisonResult $comparison

    if ($plan.Count -eq 0) {
        Write-Verbose "Directories are already in sync — no actions needed."
        return [PSCustomObject[]]@()
    }

    if ($DryRun) {
        Write-Verbose "DRY-RUN mode: reporting $($plan.Count) planned action(s)."
    } else {
        Write-Verbose "EXECUTE mode: performing $($plan.Count) action(s)."
    }

    [PSCustomObject[]]$report = Invoke-SyncPlan -Plan $plan -SourcePath $SourcePath -TargetPath $TargetPath -DryRun:$DryRun

    return $report
}
