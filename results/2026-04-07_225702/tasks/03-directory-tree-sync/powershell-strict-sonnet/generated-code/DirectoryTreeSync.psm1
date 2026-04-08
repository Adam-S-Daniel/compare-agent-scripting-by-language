#Requires -Version 7.0
# DirectoryTreeSync.psm1
# Compares two directory trees by SHA-256 hash, builds a sync plan, and can
# execute or dry-run that plan.  All code runs under PowerShell strict mode.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ─── Get-DirectoryIndex ───────────────────────────────────────────────────────
# Returns a hashtable of { relativeForwardSlashPath -> sha256hex } for every
# file found recursively under $Path.
function Get-DirectoryIndex {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Directory not found: '$Path'"
    }

    [hashtable]$index = @{}

    # Enumerate all files recursively
    $files = Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction Stop

    foreach ($file in $files) {
        # Build a platform-independent relative key with forward slashes
        [string]$relative = $file.FullName.Substring($Path.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar, '/')
        [string]$relKey   = $relative.Replace([System.IO.Path]::DirectorySeparatorChar, '/')

        # Compute SHA-256 — Get-FileHash returns uppercase hex; lower-case for consistency
        [string]$hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()

        $index[$relKey] = $hash
    }

    return $index
}

# ─── Compare-DirectoryTrees ───────────────────────────────────────────────────
# Compares src and dst by their directory indexes and returns a PSCustomObject
# with four string-array properties:
#   Identical       — relative paths with the same hash in both trees
#   Modified        — relative paths present in both but with different hashes
#   SourceOnly      — relative paths present only in source
#   DestinationOnly — relative paths present only in destination
function Compare-DirectoryTrees {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][string]$DestinationPath
    )

    [hashtable]$srcIndex = Get-DirectoryIndex -Path $SourcePath
    [hashtable]$dstIndex = Get-DirectoryIndex -Path $DestinationPath

    [System.Collections.Generic.List[string]]$identical       = [System.Collections.Generic.List[string]]::new()
    [System.Collections.Generic.List[string]]$modified        = [System.Collections.Generic.List[string]]::new()
    [System.Collections.Generic.List[string]]$sourceOnly      = [System.Collections.Generic.List[string]]::new()
    [System.Collections.Generic.List[string]]$destinationOnly = [System.Collections.Generic.List[string]]::new()

    # Walk source keys
    foreach ($key in $srcIndex.Keys) {
        if ($dstIndex.ContainsKey($key)) {
            if ($srcIndex[$key] -eq $dstIndex[$key]) {
                $identical.Add($key)
            } else {
                $modified.Add($key)
            }
        } else {
            $sourceOnly.Add($key)
        }
    }

    # Walk destination keys to find destination-only files
    foreach ($key in $dstIndex.Keys) {
        if (-not $srcIndex.ContainsKey($key)) {
            $destinationOnly.Add($key)
        }
    }

    return [PSCustomObject]@{
        SourcePath      = $SourcePath
        DestinationPath = $DestinationPath
        Identical       = [string[]]$identical
        Modified        = [string[]]$modified
        SourceOnly      = [string[]]$sourceOnly
        DestinationOnly = [string[]]$destinationOnly
    }
}

# ─── New-SyncPlan ─────────────────────────────────────────────────────────────
# Converts a comparison result into an ordered list of actions:
#   Copy      — file exists in source only → copy to destination
#   Overwrite — file exists in both but differs → overwrite destination
#   Delete    — file exists in destination only → delete from destination
# Identical files produce no action.
function New-SyncPlan {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)][PSCustomObject]$Comparison
    )

    [string]$srcPath = [string]$Comparison.SourcePath
    [string]$dstPath = [string]$Comparison.DestinationPath

    [System.Collections.Generic.List[PSCustomObject]]$actions = `
        [System.Collections.Generic.List[PSCustomObject]]::new()

    # Copy: source-only files need to be copied to destination
    foreach ($rel in $Comparison.SourceOnly) {
        $actions.Add([PSCustomObject]@{
            Action          = 'Copy'
            RelativePath    = $rel
            SourcePath      = Join-Path $srcPath $rel
            DestinationPath = Join-Path $dstPath $rel
        })
    }

    # Overwrite: files that differ between source and destination
    foreach ($rel in $Comparison.Modified) {
        $actions.Add([PSCustomObject]@{
            Action          = 'Overwrite'
            RelativePath    = $rel
            SourcePath      = Join-Path $srcPath $rel
            DestinationPath = Join-Path $dstPath $rel
        })
    }

    # Delete: destination-only files are stale — remove them
    foreach ($rel in $Comparison.DestinationOnly) {
        $actions.Add([PSCustomObject]@{
            Action          = 'Delete'
            RelativePath    = $rel
            SourcePath      = $null          # no source for delete actions
            DestinationPath = Join-Path $dstPath $rel
        })
    }

    return [PSCustomObject]@{
        SourcePath      = $srcPath
        DestinationPath = $dstPath
        Actions         = [PSCustomObject[]]$actions
    }
}

# ─── Invoke-SyncPlan ─────────────────────────────────────────────────────────
# Executes (or dry-runs) a sync plan.
#   -DryRun : report what would happen without touching the filesystem
#   (default): perform Copy / Overwrite / Delete operations
#
# Returns a PSCustomObject report:
#   WasDryRun       — [bool]
#   ActionsPlanned  — [int] total actions in the plan
#   ActionsExecuted — [int] actions actually performed (0 in dry-run)
#   Details         — [PSCustomObject[]] per-action outcome records
function Invoke-SyncPlan {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)][PSCustomObject]$Plan,
        [switch]$DryRun
    )

    [int]$executed = 0
    [System.Collections.Generic.List[PSCustomObject]]$details = `
        [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($action in $Plan.Actions) {
        [string]$actionType = [string]$action.Action
        [string]$rel        = [string]$action.RelativePath
        [string]$dst        = [string]$action.DestinationPath

        if ($DryRun) {
            $details.Add([PSCustomObject]@{
                Action       = $actionType
                RelativePath = $rel
                Status       = 'Planned'
            })
            continue
        }

        # ── Execute the action ──────────────────────────────────────────────
        switch ($actionType) {
            'Copy' {
                [string]$src = [string]$action.SourcePath
                # Ensure the destination parent directory exists
                [string]$dstDir = [System.IO.Path]::GetDirectoryName($dst)
                if (-not (Test-Path -LiteralPath $dstDir -PathType Container)) {
                    [void](New-Item -ItemType Directory -Path $dstDir -Force -ErrorAction Stop)
                }
                Copy-Item -LiteralPath $src -Destination $dst -Force -ErrorAction Stop
            }
            'Overwrite' {
                [string]$src = [string]$action.SourcePath
                [string]$dstDir = [System.IO.Path]::GetDirectoryName($dst)
                if (-not (Test-Path -LiteralPath $dstDir -PathType Container)) {
                    [void](New-Item -ItemType Directory -Path $dstDir -Force -ErrorAction Stop)
                }
                Copy-Item -LiteralPath $src -Destination $dst -Force -ErrorAction Stop
            }
            'Delete' {
                Remove-Item -LiteralPath $dst -Force -ErrorAction Stop
            }
            default {
                throw "Unknown sync action: '$actionType'"
            }
        }

        $executed++
        $details.Add([PSCustomObject]@{
            Action       = $actionType
            RelativePath = $rel
            Status       = 'Executed'
        })
    }

    return [PSCustomObject]@{
        WasDryRun       = [bool]$DryRun
        ActionsPlanned  = [int]$Plan.Actions.Count
        ActionsExecuted = $executed
        Details         = [PSCustomObject[]]$details
    }
}

Export-ModuleMember -Function Get-DirectoryIndex, Compare-DirectoryTrees, New-SyncPlan, Invoke-SyncPlan
