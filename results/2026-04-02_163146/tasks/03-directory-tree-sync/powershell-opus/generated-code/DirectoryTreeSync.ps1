# DirectoryTreeSync.ps1
# Compares two directory trees by SHA-256 content hashes and generates a sync plan.
# Supports dry-run (report only) and execute (perform sync) modes.
#
# Approach:
#   1. Get-FileHashMap   — walk a directory, compute SHA-256 for each file, return a
#                          hashtable keyed by relative path (using '/' as separator).
#   2. Compare-DirectoryTrees — diff two hash maps to find source-only, target-only,
#                          and modified (different hash) files.
#   3. New-SyncPlan      — turn a diff into a list of action objects (Copy/Overwrite/Delete).
#   4. Invoke-SyncPlan   — execute the plan in dry-run or live mode, returning a report.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-FileHashMap {
    <#
    .SYNOPSIS
        Computes SHA-256 hashes for every file under the given directory.
    .OUTPUTS
        [hashtable] mapping normalised relative paths (forward-slash separated)
        to uppercase hex SHA-256 hash strings.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Directory does not exist: $Path"
    }

    $map = @{}
    $resolved = (Resolve-Path -LiteralPath $Path).Path

    # Enumerate all files recursively
    $files = Get-ChildItem -LiteralPath $resolved -Recurse -File -ErrorAction Stop

    foreach ($file in $files) {
        # Build a normalised relative path using forward slashes
        $relativePath = $file.FullName.Substring($resolved.Length).TrimStart(
            [IO.Path]::DirectorySeparatorChar,
            [IO.Path]::AltDirectorySeparatorChar
        ) -replace '\\', '/'

        $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        $map[$relativePath] = $hash
    }

    return $map
}

function Compare-DirectoryTrees {
    <#
    .SYNOPSIS
        Compares two directory trees by content hash and returns differences.
    .OUTPUTS
        [PSCustomObject] with properties:
          - SourceOnly : [string[]] files only in source
          - TargetOnly : [string[]] files only in target
          - Modified   : [string[]] files in both but with different hashes
          - Unchanged  : [string[]] files in both with the same hash
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$TargetPath
    )

    # Validate both paths exist
    if (-not (Test-Path -LiteralPath $SourcePath -PathType Container)) {
        throw "Source directory does not exist: $SourcePath"
    }
    if (-not (Test-Path -LiteralPath $TargetPath -PathType Container)) {
        throw "Target directory does not exist: $TargetPath"
    }

    $sourceMap = Get-FileHashMap -Path $SourcePath
    $targetMap = Get-FileHashMap -Path $TargetPath

    # Collect all unique relative paths
    $allKeys = @($sourceMap.Keys) + @($targetMap.Keys) | Sort-Object -Unique

    $sourceOnly = [System.Collections.Generic.List[string]]::new()
    $targetOnly = [System.Collections.Generic.List[string]]::new()
    $modified   = [System.Collections.Generic.List[string]]::new()
    $unchanged  = [System.Collections.Generic.List[string]]::new()

    foreach ($key in $allKeys) {
        $inSource = $sourceMap.ContainsKey($key)
        $inTarget = $targetMap.ContainsKey($key)

        if ($inSource -and -not $inTarget) {
            $sourceOnly.Add($key)
        }
        elseif (-not $inSource -and $inTarget) {
            $targetOnly.Add($key)
        }
        elseif ($sourceMap[$key] -ne $targetMap[$key]) {
            $modified.Add($key)
        }
        else {
            $unchanged.Add($key)
        }
    }

    return [PSCustomObject]@{
        SourceOnly = [string[]]$sourceOnly
        TargetOnly = [string[]]$targetOnly
        Modified   = [string[]]$modified
        Unchanged  = [string[]]$unchanged
    }
}

function New-SyncPlan {
    <#
    .SYNOPSIS
        Generates a sync plan to make the target match the source.
    .DESCRIPTION
        Compares source and target directories, then produces an ordered list
        of actions: Copy (source-only → target), Overwrite (modified),
        Delete (target-only).
    .OUTPUTS
        [PSCustomObject[]] each with Action, RelativePath.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$TargetPath
    )

    $diff = Compare-DirectoryTrees -SourcePath $SourcePath -TargetPath $TargetPath
    $plan = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Copy new files from source to target
    foreach ($rel in $diff.SourceOnly) {
        $plan.Add([PSCustomObject]@{
            Action       = 'Copy'
            RelativePath = $rel
        })
    }

    # Overwrite files that differ
    foreach ($rel in $diff.Modified) {
        $plan.Add([PSCustomObject]@{
            Action       = 'Overwrite'
            RelativePath = $rel
        })
    }

    # Delete files that exist only in target
    foreach ($rel in $diff.TargetOnly) {
        $plan.Add([PSCustomObject]@{
            Action       = 'Delete'
            RelativePath = $rel
        })
    }

    # Use comma operator to prevent PowerShell from unrolling empty arrays to $null
    return , ([PSCustomObject[]]$plan)
}

function Invoke-SyncPlan {
    <#
    .SYNOPSIS
        Executes a sync plan in either dry-run (report) or execute (live) mode.
    .PARAMETER DryRun
        Report planned actions without modifying anything.
    .PARAMETER Execute
        Actually perform the file operations.
    .OUTPUTS
        [PSCustomObject[]] report entries with Action, RelativePath, Status,
        and optionally ErrorMessage.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$Plan,

        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$TargetPath,

        [switch]$DryRun,

        [switch]$Execute
    )

    # Exactly one mode must be specified
    if ($DryRun -and $Execute) {
        throw 'Specify either -DryRun or -Execute, not both.'
    }
    if (-not $DryRun -and -not $Execute) {
        throw 'You must specify either -DryRun or -Execute.'
    }

    $report = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($entry in $Plan) {
        $action = $entry.Action
        $rel    = $entry.RelativePath

        # In dry-run mode, just report what would happen
        if ($DryRun) {
            $report.Add([PSCustomObject]@{
                Action       = $action
                RelativePath = $rel
                Status       = 'Planned'
                ErrorMessage = $null
            })
            continue
        }

        # Execute mode — actually perform file operations
        try {
            switch ($action) {
                'Copy' {
                    $src  = Join-Path $SourcePath $rel
                    $dest = Join-Path $TargetPath $rel
                    $destDir = Split-Path $dest -Parent
                    if (-not (Test-Path -LiteralPath $destDir)) {
                        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                    }
                    Copy-Item -LiteralPath $src -Destination $dest -Force
                }
                'Overwrite' {
                    $src  = Join-Path $SourcePath $rel
                    $dest = Join-Path $TargetPath $rel
                    Copy-Item -LiteralPath $src -Destination $dest -Force
                }
                'Delete' {
                    $dest = Join-Path $TargetPath $rel
                    if (Test-Path -LiteralPath $dest) {
                        Remove-Item -LiteralPath $dest -Force
                    }
                }
                default {
                    throw "Unknown action: $action"
                }
            }

            $report.Add([PSCustomObject]@{
                Action       = $action
                RelativePath = $rel
                Status       = 'Completed'
                ErrorMessage = $null
            })
        }
        catch {
            # Graceful error handling — capture the failure and continue
            $report.Add([PSCustomObject]@{
                Action       = $action
                RelativePath = $rel
                Status       = 'Error'
                ErrorMessage = $_.Exception.Message
            })
        }
    }

    # Use comma operator to prevent PowerShell from unrolling empty arrays to $null
    return , ([PSCustomObject[]]$report)
}
