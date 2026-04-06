# DirectoryTreeSync.Tests.ps1
# Pester tests for the Directory Tree Sync module.
# Following red/green TDD: each Describe block was written as a failing test first,
# then the implementation was added to make it pass.

BeforeAll {
    . $PSScriptRoot/DirectoryTreeSync.ps1
}

# ── Helper: create mock directory trees for testing ──────────────────────────
function New-MockDirectoryTree {
    <#
    .SYNOPSIS
        Creates a temporary directory tree from a hashtable specification.
        Keys are relative file paths, values are file content strings.
    #>
    param(
        [hashtable]$Files
    )
    $root = Join-Path ([System.IO.Path]::GetTempPath()) "dts-test-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    foreach ($relPath in $Files.Keys) {
        $fullPath = Join-Path $root $relPath
        $dir = Split-Path $fullPath -Parent
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        Set-Content -Path $fullPath -Value $Files[$relPath] -NoNewline
    }
    return $root
}

# ══════════════════════════════════════════════════════════════════════════════
# TDD Cycle 1: Get-FileHashMap — compute SHA-256 hashes for every file in a tree
# ══════════════════════════════════════════════════════════════════════════════
Describe 'Get-FileHashMap' {

    It 'returns a hashtable mapping relative paths to SHA-256 hashes' {
        $root = New-MockDirectoryTree @{
            'a.txt' = 'hello'
            'sub/b.txt' = 'world'
        }
        try {
            $map = Get-FileHashMap -Path $root
            $map | Should -BeOfType [hashtable]
            $map.Keys.Count | Should -Be 2
            $map.ContainsKey('a.txt') | Should -BeTrue
            $map.ContainsKey('sub/b.txt') -or $map.ContainsKey("sub$([IO.Path]::DirectorySeparatorChar)b.txt") | Should -BeTrue
        } finally {
            Remove-Item $root -Recurse -Force
        }
    }

    It 'produces consistent SHA-256 hashes for identical content' {
        $root = New-MockDirectoryTree @{
            'x.txt' = 'same content'
        }
        try {
            $map = Get-FileHashMap -Path $root
            # Known SHA-256 for "same content" (no trailing newline)
            $expected = (Get-FileHash -InputStream ([IO.MemoryStream]::new(
                [Text.Encoding]::UTF8.GetBytes('same content')
            )) -Algorithm SHA256).Hash
            $normalizedKey = ($map.Keys | Where-Object { $_ -match 'x\.txt$' }) | Select-Object -First 1
            $map[$normalizedKey] | Should -Be $expected
        } finally {
            Remove-Item $root -Recurse -Force
        }
    }

    It 'returns an empty hashtable for an empty directory' {
        $root = Join-Path ([System.IO.Path]::GetTempPath()) "dts-empty-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        try {
            $map = Get-FileHashMap -Path $root
            $map.Keys.Count | Should -Be 0
        } finally {
            Remove-Item $root -Recurse -Force
        }
    }

    It 'throws when the path does not exist' {
        { Get-FileHashMap -Path '/nonexistent/path/abc123' } | Should -Throw
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# TDD Cycle 2: Compare-DirectoryTrees — diff two trees by hash
# ══════════════════════════════════════════════════════════════════════════════
Describe 'Compare-DirectoryTrees' {

    It 'detects identical trees as having no differences' {
        $source = New-MockDirectoryTree @{ 'a.txt' = 'hello' }
        $target = New-MockDirectoryTree @{ 'a.txt' = 'hello' }
        try {
            $diff = Compare-DirectoryTrees -SourcePath $source -TargetPath $target
            $diff.Modified.Count | Should -Be 0
            $diff.SourceOnly.Count | Should -Be 0
            $diff.TargetOnly.Count | Should -Be 0
        } finally {
            Remove-Item $source -Recurse -Force
            Remove-Item $target -Recurse -Force
        }
    }

    It 'detects files that exist only in source' {
        $source = New-MockDirectoryTree @{
            'a.txt' = 'hello'
            'extra.txt' = 'only in source'
        }
        $target = New-MockDirectoryTree @{ 'a.txt' = 'hello' }
        try {
            $diff = Compare-DirectoryTrees -SourcePath $source -TargetPath $target
            $diff.SourceOnly | Should -Contain 'extra.txt'
            $diff.TargetOnly.Count | Should -Be 0
        } finally {
            Remove-Item $source -Recurse -Force
            Remove-Item $target -Recurse -Force
        }
    }

    It 'detects files that exist only in target' {
        $source = New-MockDirectoryTree @{ 'a.txt' = 'hello' }
        $target = New-MockDirectoryTree @{
            'a.txt' = 'hello'
            'orphan.txt' = 'only in target'
        }
        try {
            $diff = Compare-DirectoryTrees -SourcePath $source -TargetPath $target
            $diff.TargetOnly | Should -Contain 'orphan.txt'
            $diff.SourceOnly.Count | Should -Be 0
        } finally {
            Remove-Item $source -Recurse -Force
            Remove-Item $target -Recurse -Force
        }
    }

    It 'detects files with different content (modified)' {
        $source = New-MockDirectoryTree @{ 'a.txt' = 'version 2' }
        $target = New-MockDirectoryTree @{ 'a.txt' = 'version 1' }
        try {
            $diff = Compare-DirectoryTrees -SourcePath $source -TargetPath $target
            $diff.Modified | Should -Contain 'a.txt'
        } finally {
            Remove-Item $source -Recurse -Force
            Remove-Item $target -Recurse -Force
        }
    }

    It 'handles subdirectories correctly' {
        $source = New-MockDirectoryTree @{
            'dir/sub/file.txt' = 'deep content'
        }
        $target = New-MockDirectoryTree @{}
        try {
            $diff = Compare-DirectoryTrees -SourcePath $source -TargetPath $target
            # The file should appear in SourceOnly with its relative path
            ($diff.SourceOnly | Where-Object { $_ -match 'file\.txt' }).Count | Should -Be 1
        } finally {
            Remove-Item $source -Recurse -Force
            Remove-Item $target -Recurse -Force
        }
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# TDD Cycle 3: New-SyncPlan — build an actionable sync plan from a diff
# ══════════════════════════════════════════════════════════════════════════════
Describe 'New-SyncPlan' {

    It 'creates copy actions for source-only files' {
        $source = New-MockDirectoryTree @{
            'new.txt' = 'new file'
        }
        $target = New-MockDirectoryTree @{}
        try {
            $plan = New-SyncPlan -SourcePath $source -TargetPath $target
            $copyActions = @($plan | Where-Object { $_.Action -eq 'Copy' })
            $copyActions.Count | Should -Be 1
            $copyActions[0].RelativePath | Should -Be 'new.txt'
        } finally {
            Remove-Item $source -Recurse -Force
            Remove-Item $target -Recurse -Force
        }
    }

    It 'creates delete actions for target-only files' {
        $source = New-MockDirectoryTree @{}
        $target = New-MockDirectoryTree @{
            'stale.txt' = 'to be removed'
        }
        try {
            $plan = New-SyncPlan -SourcePath $source -TargetPath $target
            $deleteActions = @($plan | Where-Object { $_.Action -eq 'Delete' })
            $deleteActions.Count | Should -Be 1
            $deleteActions[0].RelativePath | Should -Be 'stale.txt'
        } finally {
            Remove-Item $source -Recurse -Force
            Remove-Item $target -Recurse -Force
        }
    }

    It 'creates overwrite actions for modified files' {
        $source = New-MockDirectoryTree @{ 'changed.txt' = 'new content' }
        $target = New-MockDirectoryTree @{ 'changed.txt' = 'old content' }
        try {
            $plan = New-SyncPlan -SourcePath $source -TargetPath $target
            $overwriteActions = @($plan | Where-Object { $_.Action -eq 'Overwrite' })
            $overwriteActions.Count | Should -Be 1
            $overwriteActions[0].RelativePath | Should -Be 'changed.txt'
        } finally {
            Remove-Item $source -Recurse -Force
            Remove-Item $target -Recurse -Force
        }
    }

    It 'returns an empty plan for identical trees' {
        $source = New-MockDirectoryTree @{ 'same.txt' = 'identical' }
        $target = New-MockDirectoryTree @{ 'same.txt' = 'identical' }
        try {
            $plan = New-SyncPlan -SourcePath $source -TargetPath $target
            $plan.Count | Should -Be 0
        } finally {
            Remove-Item $source -Recurse -Force
            Remove-Item $target -Recurse -Force
        }
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# TDD Cycle 4: Invoke-SyncPlan -DryRun — report-only mode
# ══════════════════════════════════════════════════════════════════════════════
Describe 'Invoke-SyncPlan -DryRun' {

    It 'does NOT modify the target directory in dry-run mode' {
        $source = New-MockDirectoryTree @{
            'new.txt' = 'hello'
            'changed.txt' = 'updated'
        }
        $target = New-MockDirectoryTree @{
            'changed.txt' = 'original'
            'extra.txt'   = 'will be kept in dry run'
        }
        try {
            $plan = New-SyncPlan -SourcePath $source -TargetPath $target
            $report = Invoke-SyncPlan -Plan $plan -SourcePath $source -TargetPath $target -DryRun

            # Target should remain unchanged
            (Get-Content (Join-Path $target 'changed.txt') -Raw) | Should -Be 'original'
            Test-Path (Join-Path $target 'new.txt') | Should -BeFalse
            Test-Path (Join-Path $target 'extra.txt') | Should -BeTrue
        } finally {
            Remove-Item $source -Recurse -Force
            Remove-Item $target -Recurse -Force
        }
    }

    It 'returns a report of planned actions in dry-run mode' {
        $source = New-MockDirectoryTree @{ 'a.txt' = 'src' }
        $target = New-MockDirectoryTree @{}
        try {
            $plan = New-SyncPlan -SourcePath $source -TargetPath $target
            $report = Invoke-SyncPlan -Plan $plan -SourcePath $source -TargetPath $target -DryRun
            $report.Count | Should -BeGreaterThan 0
            $report[0].Status | Should -Be 'Planned'
        } finally {
            Remove-Item $source -Recurse -Force
            Remove-Item $target -Recurse -Force
        }
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# TDD Cycle 5: Invoke-SyncPlan -Execute — actually perform the sync
# ══════════════════════════════════════════════════════════════════════════════
Describe 'Invoke-SyncPlan -Execute' {

    It 'copies source-only files to the target' {
        $source = New-MockDirectoryTree @{ 'newfile.txt' = 'brand new' }
        $target = New-MockDirectoryTree @{}
        try {
            $plan = New-SyncPlan -SourcePath $source -TargetPath $target
            Invoke-SyncPlan -Plan $plan -SourcePath $source -TargetPath $target -Execute

            Test-Path (Join-Path $target 'newfile.txt') | Should -BeTrue
            (Get-Content (Join-Path $target 'newfile.txt') -Raw) | Should -Be 'brand new'
        } finally {
            Remove-Item $source -Recurse -Force
            Remove-Item $target -Recurse -Force
        }
    }

    It 'overwrites modified files in the target' {
        $source = New-MockDirectoryTree @{ 'doc.txt' = 'v2' }
        $target = New-MockDirectoryTree @{ 'doc.txt' = 'v1' }
        try {
            $plan = New-SyncPlan -SourcePath $source -TargetPath $target
            Invoke-SyncPlan -Plan $plan -SourcePath $source -TargetPath $target -Execute

            (Get-Content (Join-Path $target 'doc.txt') -Raw) | Should -Be 'v2'
        } finally {
            Remove-Item $source -Recurse -Force
            Remove-Item $target -Recurse -Force
        }
    }

    It 'deletes target-only files' {
        $source = New-MockDirectoryTree @{}
        $target = New-MockDirectoryTree @{ 'gone.txt' = 'delete me' }
        try {
            $plan = New-SyncPlan -SourcePath $source -TargetPath $target
            Invoke-SyncPlan -Plan $plan -SourcePath $source -TargetPath $target -Execute

            Test-Path (Join-Path $target 'gone.txt') | Should -BeFalse
        } finally {
            Remove-Item $source -Recurse -Force
            Remove-Item $target -Recurse -Force
        }
    }

    It 'creates necessary subdirectories when copying files' {
        $source = New-MockDirectoryTree @{ 'a/b/c.txt' = 'deep' }
        $target = New-MockDirectoryTree @{}
        try {
            $plan = New-SyncPlan -SourcePath $source -TargetPath $target
            Invoke-SyncPlan -Plan $plan -SourcePath $source -TargetPath $target -Execute

            $destFile = Join-Path $target 'a' 'b' 'c.txt'
            Test-Path $destFile | Should -BeTrue
            (Get-Content $destFile -Raw) | Should -Be 'deep'
        } finally {
            Remove-Item $source -Recurse -Force
            Remove-Item $target -Recurse -Force
        }
    }

    It 'returns a report with Completed status for each action' {
        $source = New-MockDirectoryTree @{ 'f.txt' = 'data' }
        $target = New-MockDirectoryTree @{}
        try {
            $plan = New-SyncPlan -SourcePath $source -TargetPath $target
            $report = Invoke-SyncPlan -Plan $plan -SourcePath $source -TargetPath $target -Execute
            $report.Count | Should -BeGreaterThan 0
            $report[0].Status | Should -Be 'Completed'
        } finally {
            Remove-Item $source -Recurse -Force
            Remove-Item $target -Recurse -Force
        }
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# TDD Cycle 6: Full end-to-end sync scenario
# ══════════════════════════════════════════════════════════════════════════════
Describe 'End-to-end sync' {

    It 'makes the target tree identical to the source tree' {
        $source = New-MockDirectoryTree @{
            'readme.md'       = '# Project'
            'src/main.ps1'    = 'Write-Host "Hello"'
            'src/lib/util.ps1'= 'function foo {}'
        }
        $target = New-MockDirectoryTree @{
            'readme.md'       = '# Old Readme'
            'obsolete.txt'    = 'should be removed'
        }
        try {
            # Generate and execute the sync plan
            $plan = New-SyncPlan -SourcePath $source -TargetPath $target
            Invoke-SyncPlan -Plan $plan -SourcePath $source -TargetPath $target -Execute

            # After sync, the target should match the source
            $sourceMap = Get-FileHashMap -Path $source
            $targetMap = Get-FileHashMap -Path $target

            $sourceMap.Keys.Count | Should -Be $targetMap.Keys.Count

            foreach ($key in $sourceMap.Keys) {
                $targetMap.ContainsKey($key) | Should -BeTrue -Because "target should contain $key"
                $targetMap[$key] | Should -Be $sourceMap[$key] -Because "hash of $key should match"
            }

            # Obsolete file should be gone
            Test-Path (Join-Path $target 'obsolete.txt') | Should -BeFalse
        } finally {
            Remove-Item $source -Recurse -Force
            Remove-Item $target -Recurse -Force
        }
    }

    It 'dry-run followed by execute produces expected results' {
        $source = New-MockDirectoryTree @{
            'a.txt' = 'alpha'
            'b.txt' = 'beta'
        }
        $target = New-MockDirectoryTree @{
            'a.txt' = 'alpha-old'
            'c.txt' = 'charlie'
        }
        try {
            $plan = New-SyncPlan -SourcePath $source -TargetPath $target

            # Dry run first - should report 3 actions (overwrite a.txt, copy b.txt, delete c.txt)
            $dryReport = Invoke-SyncPlan -Plan $plan -SourcePath $source -TargetPath $target -DryRun
            @($dryReport).Count | Should -Be 3

            # Target unchanged after dry run
            (Get-Content (Join-Path $target 'a.txt') -Raw) | Should -Be 'alpha-old'
            Test-Path (Join-Path $target 'c.txt') | Should -BeTrue

            # Now execute
            # Need a fresh plan since the state hasn't changed
            Invoke-SyncPlan -Plan $plan -SourcePath $source -TargetPath $target -Execute

            # Target now matches source
            (Get-Content (Join-Path $target 'a.txt') -Raw) | Should -Be 'alpha'
            (Get-Content (Join-Path $target 'b.txt') -Raw) | Should -Be 'beta'
            Test-Path (Join-Path $target 'c.txt') | Should -BeFalse
        } finally {
            Remove-Item $source -Recurse -Force
            Remove-Item $target -Recurse -Force
        }
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# TDD Cycle 7: Error handling
# ══════════════════════════════════════════════════════════════════════════════
Describe 'Error handling' {

    It 'throws when source path does not exist' {
        $target = New-MockDirectoryTree @{}
        try {
            { Compare-DirectoryTrees -SourcePath '/no/such/dir' -TargetPath $target } | Should -Throw
        } finally {
            Remove-Item $target -Recurse -Force
        }
    }

    It 'throws when target path does not exist' {
        $source = New-MockDirectoryTree @{}
        try {
            { Compare-DirectoryTrees -SourcePath $source -TargetPath '/no/such/dir' } | Should -Throw
        } finally {
            Remove-Item $source -Recurse -Force
        }
    }

    It 'Invoke-SyncPlan requires exactly one of -DryRun or -Execute' {
        $source = New-MockDirectoryTree @{ 'a.txt' = 'x' }
        $target = New-MockDirectoryTree @{}
        try {
            $plan = New-SyncPlan -SourcePath $source -TargetPath $target
            # Neither flag → error
            { Invoke-SyncPlan -Plan $plan -SourcePath $source -TargetPath $target } | Should -Throw
        } finally {
            Remove-Item $source -Recurse -Force
            Remove-Item $target -Recurse -Force
        }
    }

    It 'reports errors gracefully when a file cannot be copied' {
        $source = New-MockDirectoryTree @{ 'a.txt' = 'data' }
        $target = New-MockDirectoryTree @{}
        try {
            # Create a plan manually with a bogus source path to simulate failure
            $badPlan = @([PSCustomObject]@{
                Action       = 'Copy'
                RelativePath = 'a.txt'
            })
            # Use a nonexistent source so the copy fails
            $report = Invoke-SyncPlan -Plan $badPlan -SourcePath '/nonexistent/source' -TargetPath $target -Execute
            $report[0].Status | Should -Be 'Error'
            $report[0].ErrorMessage | Should -Not -BeNullOrEmpty
        } finally {
            Remove-Item $source -Recurse -Force
            Remove-Item $target -Recurse -Force
        }
    }
}
