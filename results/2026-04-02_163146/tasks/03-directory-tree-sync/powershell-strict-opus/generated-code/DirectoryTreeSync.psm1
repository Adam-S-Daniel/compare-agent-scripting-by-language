# DirectoryTreeSync.psm1
# Module for comparing and syncing directory trees by content hash (SHA-256).
# Supports dry-run mode (report only) and execute mode (perform the sync).

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Computes SHA-256 hashes for every file in a directory tree.
.DESCRIPTION
    Recursively walks the given directory, computes a SHA-256 hash for each file,
    and returns a hashtable keyed by relative path (using forward slashes).
.PARAMETER Path
    The root directory to scan.
.OUTPUTS
    A hashtable mapping relative file paths to their SHA-256 hex strings.
#>
function Get-DirectoryHashMap {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    # Validate the path exists and is a directory
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Directory not found: '$Path'"
    }

    [hashtable]$hashMap = @{}

    # Resolve to an absolute path for consistent relative-path computation
    [string]$resolvedRoot = (Resolve-Path -LiteralPath $Path).Path

    # Get all files recursively
    [System.IO.FileInfo[]]$files = @(Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File)

    foreach ($file in $files) {
        # Compute relative path from root, normalized to forward slashes
        [string]$relativePath = $file.FullName.Substring($resolvedRoot.Length).TrimStart(
            [System.IO.Path]::DirectorySeparatorChar,
            [System.IO.Path]::AltDirectorySeparatorChar
        )
        $relativePath = $relativePath.Replace([System.IO.Path]::DirectorySeparatorChar, '/')

        # Compute SHA-256 hash
        [string]$hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        $hashMap[$relativePath] = $hash
    }

    return $hashMap
}

<#
.SYNOPSIS
    Compares two directory trees and categorizes differences by content hash.
.DESCRIPTION
    Compares source and target directories by computing SHA-256 hashes for all
    files in both trees. Returns a PSCustomObject with four arrays:
    - SourceOnly: files present only in the source
    - TargetOnly: files present only in the target
    - Modified:   files present in both but with different content
    - Unchanged:  files present in both with identical content
.PARAMETER SourcePath
    The source directory (the "truth" to sync from).
.PARAMETER TargetPath
    The target directory (to be brought in sync with source).
#>
function Compare-DirectoryTrees {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$TargetPath
    )

    [hashtable]$sourceHashes = Get-DirectoryHashMap -Path $SourcePath
    [hashtable]$targetHashes = Get-DirectoryHashMap -Path $TargetPath

    # Collect all unique relative paths from both trees
    [System.Collections.Generic.HashSet[string]]$allKeys = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::Ordinal
    )
    foreach ($k in $sourceHashes.Keys) { [void]$allKeys.Add([string]$k) }
    foreach ($k in $targetHashes.Keys) { [void]$allKeys.Add([string]$k) }

    [System.Collections.ArrayList]$sourceOnly = [System.Collections.ArrayList]::new()
    [System.Collections.ArrayList]$targetOnly = [System.Collections.ArrayList]::new()
    [System.Collections.ArrayList]$modified   = [System.Collections.ArrayList]::new()
    [System.Collections.ArrayList]$unchanged  = [System.Collections.ArrayList]::new()

    foreach ($key in $allKeys) {
        [bool]$inSource = $sourceHashes.ContainsKey($key)
        [bool]$inTarget = $targetHashes.ContainsKey($key)

        if ($inSource -and $inTarget) {
            if ([string]$sourceHashes[$key] -eq [string]$targetHashes[$key]) {
                [void]$unchanged.Add($key)
            }
            else {
                [void]$modified.Add($key)
            }
        }
        elseif ($inSource) {
            [void]$sourceOnly.Add($key)
        }
        else {
            [void]$targetOnly.Add($key)
        }
    }

    return [PSCustomObject]@{
        SourceOnly = [string[]]@($sourceOnly | Sort-Object)
        TargetOnly = [string[]]@($targetOnly | Sort-Object)
        Modified   = [string[]]@($modified   | Sort-Object)
        Unchanged  = [string[]]@($unchanged  | Sort-Object)
    }
}

<#
.SYNOPSIS
    Generates a sync plan to make a target directory match a source directory.
.DESCRIPTION
    Compares source and target trees, then produces an ordered list of actions:
    - COPY:   file exists only in source -> copy to target
    - DELETE: file exists only in target -> remove from target
    - UPDATE: file differs              -> overwrite target with source
.PARAMETER SourcePath
    The source (authoritative) directory.
.PARAMETER TargetPath
    The target directory to be synced.
#>
function New-SyncPlan {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$TargetPath
    )

    # Resolve paths so plan entries contain absolute file paths
    [string]$resolvedSource = (Resolve-Path -LiteralPath $SourcePath).Path
    [string]$resolvedTarget = (Resolve-Path -LiteralPath $TargetPath).Path

    $comparison = Compare-DirectoryTrees -SourcePath $resolvedSource -TargetPath $resolvedTarget

    [System.Collections.ArrayList]$plan = [System.Collections.ArrayList]::new()

    # COPY actions for files only in source
    foreach ($relPath in $comparison.SourceOnly) {
        [void]$plan.Add([PSCustomObject]@{
            Action       = [string]'COPY'
            RelativePath = [string]$relPath
            SourceFile   = [string](Join-Path $resolvedSource $relPath)
            TargetFile   = [string](Join-Path $resolvedTarget $relPath)
        })
    }

    # DELETE actions for files only in target
    foreach ($relPath in $comparison.TargetOnly) {
        [void]$plan.Add([PSCustomObject]@{
            Action       = [string]'DELETE'
            RelativePath = [string]$relPath
            SourceFile   = [string]''
            TargetFile   = [string](Join-Path $resolvedTarget $relPath)
        })
    }

    # UPDATE actions for modified files
    foreach ($relPath in $comparison.Modified) {
        [void]$plan.Add([PSCustomObject]@{
            Action       = [string]'UPDATE'
            RelativePath = [string]$relPath
            SourceFile   = [string](Join-Path $resolvedSource $relPath)
            TargetFile   = [string](Join-Path $resolvedTarget $relPath)
        })
    }

    return [PSCustomObject[]]@($plan)
}

<#
.SYNOPSIS
    Executes (or dry-runs) a sync plan.
.DESCRIPTION
    Iterates through sync plan actions and either performs them (execute mode)
    or reports what would be done (dry-run mode). Returns a report of actions
    taken or skipped, including error details for failed operations.
.PARAMETER Plan
    An array of sync plan objects (from New-SyncPlan).
.PARAMETER DryRun
    If set, no file operations are performed; only a report is generated.
#>
function Invoke-SyncPlan {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$Plan,

        [Parameter()]
        [switch]$DryRun
    )

    [System.Collections.ArrayList]$report = [System.Collections.ArrayList]::new()

    foreach ($entry in $Plan) {
        [string]$action = $entry.Action
        [string]$relPath = $entry.RelativePath
        [string]$status = ''

        if ($DryRun) {
            $status = 'SKIPPED (dry-run)'
        }
        else {
            try {
                switch ($action) {
                    'COPY' {
                        # Ensure target parent directory exists
                        [string]$targetParent = Split-Path -Path $entry.TargetFile -Parent
                        if (-not (Test-Path -LiteralPath $targetParent)) {
                            New-Item -Path $targetParent -ItemType Directory -Force | Out-Null
                        }

                        if (-not (Test-Path -LiteralPath $entry.SourceFile)) {
                            throw "Source file not found: '$($entry.SourceFile)'"
                        }

                        Copy-Item -LiteralPath $entry.SourceFile -Destination $entry.TargetFile -Force
                        $status = 'DONE'
                    }
                    'DELETE' {
                        if (Test-Path -LiteralPath $entry.TargetFile) {
                            Remove-Item -LiteralPath $entry.TargetFile -Force
                        }
                        $status = 'DONE'
                    }
                    'UPDATE' {
                        if (-not (Test-Path -LiteralPath $entry.SourceFile)) {
                            throw "Source file not found: '$($entry.SourceFile)'"
                        }

                        Copy-Item -LiteralPath $entry.SourceFile -Destination $entry.TargetFile -Force
                        $status = 'DONE'
                    }
                    default {
                        throw "Unknown action: '$action'"
                    }
                }
            }
            catch {
                $status = "ERROR: $($_.Exception.Message)"
            }
        }

        [void]$report.Add([PSCustomObject]@{
            Action       = [string]$action
            RelativePath = [string]$relPath
            Status       = [string]$status
        })
    }

    return [PSCustomObject[]]@($report)
}

# Export all public functions
Export-ModuleMember -Function @(
    'Get-DirectoryHashMap',
    'Compare-DirectoryTrees',
    'New-SyncPlan',
    'Invoke-SyncPlan'
)
