# DirectorySync.ps1
# Directory Tree Sync — compares two directory trees by SHA-256 content hash,
# identifies differences, and can either report (dry-run) or execute a sync.
#
# Public API:
#   Get-FileSHA256         -Path <string>
#   Get-DirectoryIndex     -RootPath <string>
#   Compare-DirectoryTrees -SourcePath <string> -DestPath <string>
#   New-SyncPlan           -Diff <PSCustomObject>
#   Invoke-SyncPlan        -Plan <array> -SourcePath <string> -DestPath <string> [-DryRun]
#   Sync-Directories       -SourcePath <string> -DestPath <string> [-DryRun]  (end-to-end)

# ============================================================
# 1. Get-FileSHA256
#    Computes the SHA-256 hash of a single file and returns
#    the hex digest string (lowercase, 64 chars).
# ============================================================
function Get-FileSHA256 {
    param(
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "File not found: '$Path'"
    }

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        try {
            $hashBytes = $sha.ComputeHash($stream)
        }
        finally {
            $stream.Dispose()
        }
    }
    finally {
        $sha.Dispose()
    }

    # Convert byte array to lowercase hex string
    return [System.BitConverter]::ToString($hashBytes).Replace('-','').ToLower()
}

# ============================================================
# 2. Get-DirectoryIndex
#    Recursively enumerates every file under RootPath and
#    returns a hashtable:  relative/forward/slash/path => sha256hex
# ============================================================
function Get-DirectoryIndex {
    param(
        [string]$RootPath
    )

    if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) {
        throw "Directory not found: '$RootPath'"
    }

    $index = @{}
    $root  = (Resolve-Path -LiteralPath $RootPath).Path.TrimEnd([IO.Path]::DirectorySeparatorChar)

    Get-ChildItem -LiteralPath $root -Recurse -File | ForEach-Object {
        # Build a relative path, always using forward slashes for portability
        $rel = $_.FullName.Substring($root.Length + 1).Replace('\', '/')
        $index[$rel] = Get-FileSHA256 -Path $_.FullName
    }

    return $index
}

# ============================================================
# 3. Compare-DirectoryTrees
#    Diffs two directory indexes and returns a PSCustomObject
#    with three lists of relative paths:
#      SourceOnly — exist in source, missing in dest
#      DestOnly   — exist in dest, missing in source
#      Modified   — exist in both but hashes differ
# ============================================================
function Compare-DirectoryTrees {
    param(
        [string]$SourcePath,
        [string]$DestPath
    )

    $srcIndex  = Get-DirectoryIndex -RootPath $SourcePath
    $dstIndex  = Get-DirectoryIndex -RootPath $DestPath

    $sourceOnly = [System.Collections.Generic.List[string]]::new()
    $destOnly   = [System.Collections.Generic.List[string]]::new()
    $modified   = [System.Collections.Generic.List[string]]::new()

    # Files in source
    foreach ($rel in $srcIndex.Keys) {
        if (-not $dstIndex.ContainsKey($rel)) {
            $sourceOnly.Add($rel)
        }
        elseif ($srcIndex[$rel] -ne $dstIndex[$rel]) {
            $modified.Add($rel)
        }
        # identical files are intentionally ignored
    }

    # Files only in dest
    foreach ($rel in $dstIndex.Keys) {
        if (-not $srcIndex.ContainsKey($rel)) {
            $destOnly.Add($rel)
        }
    }

    return [PSCustomObject]@{
        SourceOnly = $sourceOnly.ToArray()
        DestOnly   = $destOnly.ToArray()
        Modified   = $modified.ToArray()
    }
}

# ============================================================
# 4. New-SyncPlan
#    Converts a diff result into an ordered list of action
#    objects. Each has:
#      Action       — "Copy" | "Update" | "Delete"
#      RelativePath — forward-slash relative path
# ============================================================
function New-SyncPlan {
    param(
        [PSCustomObject]$Diff
    )

    $plan = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($rel in $Diff.SourceOnly) {
        $plan.Add([PSCustomObject]@{ Action = "Copy";   RelativePath = $rel })
    }

    foreach ($rel in $Diff.Modified) {
        $plan.Add([PSCustomObject]@{ Action = "Update"; RelativePath = $rel })
    }

    foreach ($rel in $Diff.DestOnly) {
        $plan.Add([PSCustomObject]@{ Action = "Delete"; RelativePath = $rel })
    }

    return ,$plan.ToArray()   # comma operator preserves the array type through the pipeline
}

# ============================================================
# 5. Invoke-SyncPlan
#    Executes (or dry-runs) a sync plan produced by New-SyncPlan.
#
#    DryRun switch: report what would happen, touch nothing.
#    Default      : perform Copy / Update / Delete operations.
#
#    Returns a PSCustomObject:
#      PlannedActions  — always set
#      ActionsPerformed — 0 in dry-run, real count otherwise
#      Actions          — list of result objects with Status
# ============================================================
function Invoke-SyncPlan {
    param(
        [PSCustomObject[]]$Plan,
        [string]$SourcePath,
        [string]$DestPath,
        [switch]$DryRun
    )

    $results    = [System.Collections.Generic.List[PSCustomObject]]::new()
    $performed  = 0

    foreach ($item in $Plan) {
        $srcFile = Join-Path $SourcePath ($item.RelativePath.Replace('/', [IO.Path]::DirectorySeparatorChar))
        $dstFile = Join-Path $DestPath   ($item.RelativePath.Replace('/', [IO.Path]::DirectorySeparatorChar))

        if ($DryRun) {
            # Dry-run: just record the planned action without touching the file system
            $results.Add([PSCustomObject]@{
                Action       = $item.Action
                RelativePath = $item.RelativePath
                Status       = "Planned"
            })
        }
        else {
            try {
                switch ($item.Action) {
                    "Copy" {
                        # Ensure the parent directory exists in dest
                        $parent = Split-Path $dstFile -Parent
                        if (-not (Test-Path -LiteralPath $parent)) {
                            New-Item -ItemType Directory -Path $parent -Force | Out-Null
                        }
                        Copy-Item -LiteralPath $srcFile -Destination $dstFile -Force
                        $performed++
                        $results.Add([PSCustomObject]@{
                            Action       = "Copy"
                            RelativePath = $item.RelativePath
                            Status       = "OK"
                        })
                    }
                    "Update" {
                        $parent = Split-Path $dstFile -Parent
                        if (-not (Test-Path -LiteralPath $parent)) {
                            New-Item -ItemType Directory -Path $parent -Force | Out-Null
                        }
                        Copy-Item -LiteralPath $srcFile -Destination $dstFile -Force
                        $performed++
                        $results.Add([PSCustomObject]@{
                            Action       = "Update"
                            RelativePath = $item.RelativePath
                            Status       = "OK"
                        })
                    }
                    "Delete" {
                        if (Test-Path -LiteralPath $dstFile) {
                            Remove-Item -LiteralPath $dstFile -Force
                        }
                        $performed++
                        $results.Add([PSCustomObject]@{
                            Action       = "Delete"
                            RelativePath = $item.RelativePath
                            Status       = "OK"
                        })
                    }
                    default {
                        Write-Warning "Unknown action '$($item.Action)' for '$($item.RelativePath)' — skipped."
                    }
                }
            }
            catch {
                $results.Add([PSCustomObject]@{
                    Action       = $item.Action
                    RelativePath = $item.RelativePath
                    Status       = "Error: $_"
                })
            }
        }
    }

    return [PSCustomObject]@{
        PlannedActions   = $Plan.Count
        ActionsPerformed = $performed
        DryRun           = [bool]$DryRun
        Actions          = $results.ToArray()
    }
}

# ============================================================
# 6. Sync-Directories  (high-level entry point)
#    Combines Compare-DirectoryTrees -> New-SyncPlan ->
#    Invoke-SyncPlan into a single convenient call.
# ============================================================
function Sync-Directories {
    param(
        [string]$SourcePath,
        [string]$DestPath,
        [switch]$DryRun
    )

    if (-not (Test-Path -LiteralPath $SourcePath -PathType Container)) {
        throw "Source directory not found: '$SourcePath'"
    }
    if (-not (Test-Path -LiteralPath $DestPath -PathType Container)) {
        throw "Destination directory not found: '$DestPath'"
    }

    $diff   = Compare-DirectoryTrees -SourcePath $SourcePath -DestPath $DestPath
    $plan   = New-SyncPlan -Diff $diff
    $report = Invoke-SyncPlan -Plan $plan -SourcePath $SourcePath -DestPath $DestPath -DryRun:$DryRun

    return $report
}
