Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Directory Tree Sync — compares two directory trees by SHA-256 content hash,
    identifies differences, and generates/executes a sync plan.

.DESCRIPTION
    Provides functions to:
    - Hash all files in a directory tree (Get-FileHashMap)
    - Compare two directory trees (Compare-DirectoryTrees)
    - Generate a sync plan (New-SyncPlan)
    - Execute a sync plan in dry-run or execute mode (Invoke-SyncPlan)
#>

function Get-FileHashMap {
    <#
    .SYNOPSIS
        Builds a hashtable mapping relative file paths to their SHA-256 hashes.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Directory not found: $Path"
    }

    [hashtable]$hashMap = @{}
    [string]$resolvedRoot = (Resolve-Path -LiteralPath $Path).Path

    # Get all files recursively
    [System.IO.FileInfo[]]$files = @(Get-ChildItem -LiteralPath $resolvedRoot -File -Recurse)

    foreach ($file in $files) {
        # Compute relative path and normalize to forward slashes
        [string]$relativePath = $file.FullName.Substring($resolvedRoot.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar, '/')
        [string]$normalizedPath = $relativePath.Replace([System.IO.Path]::DirectorySeparatorChar, '/')

        # Compute SHA-256 hash
        [string]$hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        $hashMap[$normalizedPath] = $hash
    }

    return $hashMap
}

function Compare-DirectoryTrees {
    <#
    .SYNOPSIS
        Compares two directory trees by SHA-256 hash and categorizes files.
    .OUTPUTS
        A hashtable with keys: SourceOnly, TargetOnly, Modified, Identical
        Each value is a string array of relative file paths.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$TargetPath
    )

    [hashtable]$sourceMap = Get-FileHashMap -Path $SourcePath
    [hashtable]$targetMap = Get-FileHashMap -Path $TargetPath

    # Collect all unique relative paths from both trees
    [System.Collections.Generic.HashSet[string]]$allKeys = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($key in $sourceMap.Keys) { [void]$allKeys.Add([string]$key) }
    foreach ($key in $targetMap.Keys) { [void]$allKeys.Add([string]$key) }

    [System.Collections.Generic.List[string]]$sourceOnly = [System.Collections.Generic.List[string]]::new()
    [System.Collections.Generic.List[string]]$targetOnly = [System.Collections.Generic.List[string]]::new()
    [System.Collections.Generic.List[string]]$modified   = [System.Collections.Generic.List[string]]::new()
    [System.Collections.Generic.List[string]]$identical   = [System.Collections.Generic.List[string]]::new()

    foreach ($key in $allKeys) {
        [bool]$inSource = $sourceMap.ContainsKey($key)
        [bool]$inTarget = $targetMap.ContainsKey($key)

        if ($inSource -and -not $inTarget) {
            $sourceOnly.Add($key)
        }
        elseif (-not $inSource -and $inTarget) {
            $targetOnly.Add($key)
        }
        elseif ([string]$sourceMap[$key] -eq [string]$targetMap[$key]) {
            $identical.Add($key)
        }
        else {
            $modified.Add($key)
        }
    }

    return @{
        SourceOnly = [string[]]@($sourceOnly)
        TargetOnly = [string[]]@($targetOnly)
        Modified   = [string[]]@($modified)
        Identical  = [string[]]@($identical)
    }
}

function New-SyncPlan {
    <#
    .SYNOPSIS
        Generates a sync plan to make TargetPath match SourcePath.
    .DESCRIPTION
        Compares two directory trees and produces a list of actions:
        - Copy:      file exists only in source → copy to target
        - Overwrite:  file differs between source and target → overwrite in target
        - Delete:    file exists only in target → delete from target
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$TargetPath
    )

    [hashtable]$comparison = Compare-DirectoryTrees -SourcePath $SourcePath -TargetPath $TargetPath

    [System.Collections.Generic.List[hashtable]]$actions = [System.Collections.Generic.List[hashtable]]::new()

    # Files only in source need to be copied to target
    foreach ($file in $comparison.SourceOnly) {
        $actions.Add(@{
            Action       = [string]'Copy'
            RelativePath = [string]$file
        })
    }

    # Files that differ need to be overwritten in target from source
    foreach ($file in $comparison.Modified) {
        $actions.Add(@{
            Action       = [string]'Overwrite'
            RelativePath = [string]$file
        })
    }

    # Files only in target need to be deleted
    foreach ($file in $comparison.TargetOnly) {
        $actions.Add(@{
            Action       = [string]'Delete'
            RelativePath = [string]$file
        })
    }

    return @{
        SourcePath = [string]$SourcePath
        TargetPath = [string]$TargetPath
        Actions    = [hashtable[]]@($actions)
    }
}

function Invoke-SyncPlan {
    <#
    .SYNOPSIS
        Executes a sync plan in either dry-run (report only) or execute mode.
    .DESCRIPTION
        In DryRun mode: reports what would happen without changing any files.
        In Execute mode: performs Copy, Overwrite, and Delete operations to
        make the target directory match the source.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Plan,

        [Parameter()]
        [switch]$DryRun
    )

    [string]$sourcePath = [string]$Plan.SourcePath
    [string]$targetPath = [string]$Plan.TargetPath
    [System.Collections.Generic.List[hashtable]]$performed = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($action in $Plan.Actions) {
        [string]$actionType = [string]$action.Action
        [string]$relativePath = [string]$action.RelativePath
        [string]$sourceFile = Join-Path $sourcePath $relativePath
        [string]$targetFile = Join-Path $targetPath $relativePath

        if ($DryRun) {
            $performed.Add(@{
                Action       = $actionType
                RelativePath = $relativePath
                Status       = [string]'DryRun'
            })
            continue
        }

        try {
            switch ($actionType) {
                'Copy' {
                    # Ensure parent directory exists
                    [string]$parentDir = Split-Path -Path $targetFile -Parent
                    if (-not (Test-Path -LiteralPath $parentDir)) {
                        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
                    }
                    Copy-Item -LiteralPath $sourceFile -Destination $targetFile -Force
                }
                'Overwrite' {
                    Copy-Item -LiteralPath $sourceFile -Destination $targetFile -Force
                }
                'Delete' {
                    Remove-Item -LiteralPath $targetFile -Force
                }
                default {
                    throw "Unknown action type: $actionType"
                }
            }

            $performed.Add(@{
                Action       = $actionType
                RelativePath = $relativePath
                Status       = [string]'Executed'
            })
        }
        catch {
            $performed.Add(@{
                Action       = $actionType
                RelativePath = $relativePath
                Status       = [string]'Failed'
                Error        = [string]$_.Exception.Message
            })
            Write-Error "Failed to $actionType '$relativePath': $($_.Exception.Message)"
        }
    }

    return @{
        DryRun           = [bool]$DryRun
        ActionsPerformed = [hashtable[]]@($performed)
    }
}
