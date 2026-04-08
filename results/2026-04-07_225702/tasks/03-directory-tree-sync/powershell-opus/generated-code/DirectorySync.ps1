# DirectorySync.ps1 — Directory tree comparison and sync tool
# Compares two directory trees by SHA-256 content hashes,
# identifies differences, and can sync them in dry-run or execute mode.

function Get-FileHashSHA256 {
    # Compute SHA-256 hash of a file's contents, returned as lowercase hex string.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "File does not exist: $Path"
    }

    $hash = Get-FileHash -LiteralPath $Path -Algorithm SHA256
    return $hash.Hash.ToLower()
}

function Get-DirectoryFileMap {
    # Build a hashtable of { relative_path -> sha256_hash } for every file
    # in the given directory tree. Paths use OS-native separators.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Directory does not exist: $Path"
    }

    $map = @{}
    $resolvedRoot = (Resolve-Path -LiteralPath $Path).Path

    $files = Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File
    foreach ($file in $files) {
        # Compute the relative path from the root
        $relativePath = $file.FullName.Substring($resolvedRoot.Length).TrimStart([IO.Path]::DirectorySeparatorChar)
        $map[$relativePath] = Get-FileHashSHA256 -Path $file.FullName
    }

    return $map
}

function Compare-DirectoryTrees {
    # Compare two directory trees by content hash and categorise every file as:
    #   Identical       — present in both with the same SHA-256
    #   Modified        — present in both but hashes differ
    #   SourceOnly      — only in the source tree
    #   DestinationOnly — only in the destination tree
    # Returns a PSCustomObject with those four array properties.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$DestinationPath
    )

    $srcMap = Get-DirectoryFileMap -Path $SourcePath
    $dstMap = Get-DirectoryFileMap -Path $DestinationPath

    $identical       = [System.Collections.Generic.List[string]]::new()
    $modified        = [System.Collections.Generic.List[string]]::new()
    $sourceOnly      = [System.Collections.Generic.List[string]]::new()
    $destinationOnly = [System.Collections.Generic.List[string]]::new()

    # Walk source files
    foreach ($key in $srcMap.Keys) {
        if ($dstMap.ContainsKey($key)) {
            if ($srcMap[$key] -eq $dstMap[$key]) {
                $identical.Add($key)
            } else {
                $modified.Add($key)
            }
        } else {
            $sourceOnly.Add($key)
        }
    }

    # Files only in destination
    foreach ($key in $dstMap.Keys) {
        if (-not $srcMap.ContainsKey($key)) {
            $destinationOnly.Add($key)
        }
    }

    return [PSCustomObject]@{
        Identical       = $identical.ToArray()
        Modified        = $modified.ToArray()
        SourceOnly      = $sourceOnly.ToArray()
        DestinationOnly = $destinationOnly.ToArray()
    }
}

function New-SyncPlan {
    # Generate an array of sync actions needed to make the destination match the source.
    # Each action is a PSCustomObject with Action (Copy|Overwrite|Delete) and RelativePath.
    # Identical files produce no action.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$DestinationPath
    )

    $comparison = Compare-DirectoryTrees -SourcePath $SourcePath -DestinationPath $DestinationPath
    $plan = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($file in $comparison.SourceOnly) {
        $plan.Add([PSCustomObject]@{ Action = 'Copy'; RelativePath = $file })
    }

    foreach ($file in $comparison.Modified) {
        $plan.Add([PSCustomObject]@{ Action = 'Overwrite'; RelativePath = $file })
    }

    foreach ($file in $comparison.DestinationOnly) {
        $plan.Add([PSCustomObject]@{ Action = 'Delete'; RelativePath = $file })
    }

    return @($plan)
}

function Invoke-SyncPlan {
    # Execute (or dry-run) a sync plan produced by New-SyncPlan.
    # -DryRun: report what would happen without touching the filesystem.
    # Returns an array of status strings describing each action taken/planned.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$Plan,

        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$DestinationPath,

        [switch]$DryRun
    )

    $report = [System.Collections.Generic.List[string]]::new()

    foreach ($entry in $Plan) {
        $relPath   = $entry.RelativePath
        $srcFile   = Join-Path $SourcePath $relPath
        $dstFile   = Join-Path $DestinationPath $relPath

        switch ($entry.Action) {
            'Copy' {
                if ($DryRun) {
                    $report.Add("[DRY-RUN] COPY $relPath -> $DestinationPath")
                } else {
                    # Ensure parent directory exists
                    $parentDir = Split-Path -Path $dstFile -Parent
                    if (-not (Test-Path -LiteralPath $parentDir)) {
                        New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
                    }
                    Copy-Item -LiteralPath $srcFile -Destination $dstFile -Force
                    $report.Add("COPIED $relPath -> $DestinationPath")
                }
            }
            'Overwrite' {
                if ($DryRun) {
                    $report.Add("[DRY-RUN] OVERWRITE $relPath in $DestinationPath")
                } else {
                    Copy-Item -LiteralPath $srcFile -Destination $dstFile -Force
                    $report.Add("OVERWRITTEN $relPath in $DestinationPath")
                }
            }
            'Delete' {
                if ($DryRun) {
                    $report.Add("[DRY-RUN] DELETE $relPath from $DestinationPath")
                } else {
                    Remove-Item -LiteralPath $dstFile -Force
                    $report.Add("DELETED $relPath from $DestinationPath")
                }
            }
            default {
                throw "Unknown sync action: $($entry.Action)"
            }
        }
    }

    return @($report)
}

function Invoke-DirectorySync {
    # Top-level entry point: compare two trees, build a sync plan,
    # and either report (dry-run) or execute the plan.
    # Returns a PSCustomObject with Plan (the action list) and Report (status strings).
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$DestinationPath,

        [switch]$DryRun
    )

    $plan = New-SyncPlan -SourcePath $SourcePath -DestinationPath $DestinationPath

    if ($DryRun) {
        $report = Invoke-SyncPlan -Plan $plan -SourcePath $SourcePath -DestinationPath $DestinationPath -DryRun
    } else {
        $report = Invoke-SyncPlan -Plan $plan -SourcePath $SourcePath -DestinationPath $DestinationPath
    }

    return [PSCustomObject]@{
        Plan   = $plan
        Report = $report
    }
}
