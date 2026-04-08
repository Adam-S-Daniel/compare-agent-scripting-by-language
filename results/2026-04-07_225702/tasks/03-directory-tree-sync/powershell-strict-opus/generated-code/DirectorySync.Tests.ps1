# Import the module under test and enable strict mode inside Pester's BeforeAll
BeforeAll {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    . "$PSScriptRoot/DirectorySync.ps1"
}

Describe 'Get-FileHashMap' {
    BeforeEach {
        # Create temporary directory structures for testing
        $script:testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "DirSyncTest_$([System.Guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $script:testRoot -Force | Out-Null
    }

    AfterEach {
        if (Test-Path $script:testRoot) {
            Remove-Item -Recurse -Force $script:testRoot
        }
    }

    It 'Should return an empty hashtable for an empty directory' {
        $result = Get-FileHashMap -Path $script:testRoot
        $result | Should -BeOfType [hashtable]
        $result.Count | Should -Be 0
    }

    It 'Should return SHA-256 hashes for files in a directory' {
        $filePath = Join-Path $script:testRoot 'test.txt'
        Set-Content -Path $filePath -Value 'hello world' -NoNewline
        $result = Get-FileHashMap -Path $script:testRoot
        $result.Count | Should -Be 1
        $result.ContainsKey('test.txt') | Should -BeTrue
        # SHA-256 of "hello world"
        $result['test.txt'] | Should -Be 'B94D27B9934D3E08A52E52D7DA7DABFAC484EFE37A5380EE9088F7ACE2EFCDE9'
    }

    It 'Should use relative paths as keys including subdirectories' {
        $subDir = Join-Path $script:testRoot 'sub'
        New-Item -ItemType Directory -Path $subDir -Force | Out-Null
        $filePath = Join-Path $subDir 'nested.txt'
        Set-Content -Path $filePath -Value 'nested content' -NoNewline

        $result = Get-FileHashMap -Path $script:testRoot
        $result.Count | Should -Be 1
        # Use forward-slash normalized path
        $key = 'sub/nested.txt'
        $result.ContainsKey($key) | Should -BeTrue
    }
}

Describe 'Compare-DirectoryTrees' {
    BeforeEach {
        $script:sourceRoot = Join-Path ([System.IO.Path]::GetTempPath()) "DirSyncSrc_$([System.Guid]::NewGuid().ToString('N'))"
        $script:targetRoot = Join-Path ([System.IO.Path]::GetTempPath()) "DirSyncTgt_$([System.Guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $script:sourceRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $script:targetRoot -Force | Out-Null
    }

    AfterEach {
        if (Test-Path $script:sourceRoot) { Remove-Item -Recurse -Force $script:sourceRoot }
        if (Test-Path $script:targetRoot) { Remove-Item -Recurse -Force $script:targetRoot }
    }

    It 'Should detect files only in source' {
        Set-Content -Path (Join-Path $script:sourceRoot 'only-src.txt') -Value 'src' -NoNewline

        $result = Compare-DirectoryTrees -SourcePath $script:sourceRoot -TargetPath $script:targetRoot
        $result.SourceOnly.Count | Should -Be 1
        $result.SourceOnly[0] | Should -Be 'only-src.txt'
        $result.TargetOnly.Count | Should -Be 0
        $result.Modified.Count | Should -Be 0
        $result.Identical.Count | Should -Be 0
    }

    It 'Should detect files only in target' {
        Set-Content -Path (Join-Path $script:targetRoot 'only-tgt.txt') -Value 'tgt' -NoNewline

        $result = Compare-DirectoryTrees -SourcePath $script:sourceRoot -TargetPath $script:targetRoot
        $result.SourceOnly.Count | Should -Be 0
        $result.TargetOnly.Count | Should -Be 1
        $result.TargetOnly[0] | Should -Be 'only-tgt.txt'
    }

    It 'Should detect modified files (same name, different content)' {
        Set-Content -Path (Join-Path $script:sourceRoot 'shared.txt') -Value 'version A' -NoNewline
        Set-Content -Path (Join-Path $script:targetRoot 'shared.txt') -Value 'version B' -NoNewline

        $result = Compare-DirectoryTrees -SourcePath $script:sourceRoot -TargetPath $script:targetRoot
        $result.Modified.Count | Should -Be 1
        $result.Modified[0] | Should -Be 'shared.txt'
        $result.Identical.Count | Should -Be 0
    }

    It 'Should detect identical files' {
        Set-Content -Path (Join-Path $script:sourceRoot 'same.txt') -Value 'identical' -NoNewline
        Set-Content -Path (Join-Path $script:targetRoot 'same.txt') -Value 'identical' -NoNewline

        $result = Compare-DirectoryTrees -SourcePath $script:sourceRoot -TargetPath $script:targetRoot
        $result.Identical.Count | Should -Be 1
        $result.Identical[0] | Should -Be 'same.txt'
        $result.Modified.Count | Should -Be 0
    }

    It 'Should handle a mixed scenario with nested directories' {
        # Source: a.txt, sub/b.txt, sub/c.txt
        # Target: a.txt (different content), sub/b.txt (same), sub/d.txt
        Set-Content -Path (Join-Path $script:sourceRoot 'a.txt') -Value 'hello' -NoNewline
        New-Item -ItemType Directory -Path (Join-Path $script:sourceRoot 'sub') -Force | Out-Null
        Set-Content -Path (Join-Path $script:sourceRoot 'sub/b.txt') -Value 'same' -NoNewline
        Set-Content -Path (Join-Path $script:sourceRoot 'sub/c.txt') -Value 'only in source' -NoNewline

        Set-Content -Path (Join-Path $script:targetRoot 'a.txt') -Value 'world' -NoNewline
        New-Item -ItemType Directory -Path (Join-Path $script:targetRoot 'sub') -Force | Out-Null
        Set-Content -Path (Join-Path $script:targetRoot 'sub/b.txt') -Value 'same' -NoNewline
        Set-Content -Path (Join-Path $script:targetRoot 'sub/d.txt') -Value 'only in target' -NoNewline

        $result = Compare-DirectoryTrees -SourcePath $script:sourceRoot -TargetPath $script:targetRoot
        $result.SourceOnly | Should -Contain 'sub/c.txt'
        $result.TargetOnly | Should -Contain 'sub/d.txt'
        $result.Modified | Should -Contain 'a.txt'
        $result.Identical | Should -Contain 'sub/b.txt'
    }
}

Describe 'New-SyncPlan' {
    BeforeEach {
        $script:sourceRoot = Join-Path ([System.IO.Path]::GetTempPath()) "DirSyncSrc_$([System.Guid]::NewGuid().ToString('N'))"
        $script:targetRoot = Join-Path ([System.IO.Path]::GetTempPath()) "DirSyncTgt_$([System.Guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $script:sourceRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $script:targetRoot -Force | Out-Null
    }

    AfterEach {
        if (Test-Path $script:sourceRoot) { Remove-Item -Recurse -Force $script:sourceRoot }
        if (Test-Path $script:targetRoot) { Remove-Item -Recurse -Force $script:targetRoot }
    }

    It 'Should generate Copy actions for source-only files' {
        Set-Content -Path (Join-Path $script:sourceRoot 'new.txt') -Value 'new file' -NoNewline

        $plan = New-SyncPlan -SourcePath $script:sourceRoot -TargetPath $script:targetRoot
        $plan.Actions.Count | Should -Be 1
        $plan.Actions[0].Action | Should -Be 'Copy'
        $plan.Actions[0].RelativePath | Should -Be 'new.txt'
    }

    It 'Should generate Delete actions for target-only files' {
        Set-Content -Path (Join-Path $script:targetRoot 'orphan.txt') -Value 'orphan' -NoNewline

        $plan = New-SyncPlan -SourcePath $script:sourceRoot -TargetPath $script:targetRoot
        $plan.Actions.Count | Should -Be 1
        $plan.Actions[0].Action | Should -Be 'Delete'
        $plan.Actions[0].RelativePath | Should -Be 'orphan.txt'
    }

    It 'Should generate Overwrite actions for modified files' {
        Set-Content -Path (Join-Path $script:sourceRoot 'file.txt') -Value 'v2' -NoNewline
        Set-Content -Path (Join-Path $script:targetRoot 'file.txt') -Value 'v1' -NoNewline

        $plan = New-SyncPlan -SourcePath $script:sourceRoot -TargetPath $script:targetRoot
        $plan.Actions.Count | Should -Be 1
        $plan.Actions[0].Action | Should -Be 'Overwrite'
        $plan.Actions[0].RelativePath | Should -Be 'file.txt'
    }

    It 'Should generate no actions for identical trees' {
        Set-Content -Path (Join-Path $script:sourceRoot 'same.txt') -Value 'same' -NoNewline
        Set-Content -Path (Join-Path $script:targetRoot 'same.txt') -Value 'same' -NoNewline

        $plan = New-SyncPlan -SourcePath $script:sourceRoot -TargetPath $script:targetRoot
        $plan.Actions.Count | Should -Be 0
    }

    It 'Should include SourcePath and TargetPath in the plan' {
        $plan = New-SyncPlan -SourcePath $script:sourceRoot -TargetPath $script:targetRoot
        $plan.SourcePath | Should -Be $script:sourceRoot
        $plan.TargetPath | Should -Be $script:targetRoot
    }
}

Describe 'Invoke-SyncPlan - DryRun mode' {
    BeforeEach {
        $script:sourceRoot = Join-Path ([System.IO.Path]::GetTempPath()) "DirSyncSrc_$([System.Guid]::NewGuid().ToString('N'))"
        $script:targetRoot = Join-Path ([System.IO.Path]::GetTempPath()) "DirSyncTgt_$([System.Guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $script:sourceRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $script:targetRoot -Force | Out-Null
    }

    AfterEach {
        if (Test-Path $script:sourceRoot) { Remove-Item -Recurse -Force $script:sourceRoot }
        if (Test-Path $script:targetRoot) { Remove-Item -Recurse -Force $script:targetRoot }
    }

    It 'Should not modify files in dry-run mode' {
        Set-Content -Path (Join-Path $script:sourceRoot 'new.txt') -Value 'new' -NoNewline
        Set-Content -Path (Join-Path $script:targetRoot 'orphan.txt') -Value 'orphan' -NoNewline

        $plan = New-SyncPlan -SourcePath $script:sourceRoot -TargetPath $script:targetRoot
        $result = Invoke-SyncPlan -Plan $plan -DryRun

        # Target should be unchanged
        Test-Path (Join-Path $script:targetRoot 'new.txt') | Should -BeFalse
        Test-Path (Join-Path $script:targetRoot 'orphan.txt') | Should -BeTrue
    }

    It 'Should return a report of planned actions in dry-run mode' {
        Set-Content -Path (Join-Path $script:sourceRoot 'new.txt') -Value 'new' -NoNewline

        $plan = New-SyncPlan -SourcePath $script:sourceRoot -TargetPath $script:targetRoot
        $result = Invoke-SyncPlan -Plan $plan -DryRun

        $result.ActionsPerformed.Count | Should -Be 1
        $result.ActionsPerformed[0].Action | Should -Be 'Copy'
        $result.ActionsPerformed[0].Status | Should -Be 'DryRun'
        $result.DryRun | Should -BeTrue
    }
}

Describe 'Invoke-SyncPlan - Execute mode' {
    BeforeEach {
        $script:sourceRoot = Join-Path ([System.IO.Path]::GetTempPath()) "DirSyncSrc_$([System.Guid]::NewGuid().ToString('N'))"
        $script:targetRoot = Join-Path ([System.IO.Path]::GetTempPath()) "DirSyncTgt_$([System.Guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $script:sourceRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $script:targetRoot -Force | Out-Null
    }

    AfterEach {
        if (Test-Path $script:sourceRoot) { Remove-Item -Recurse -Force $script:sourceRoot }
        if (Test-Path $script:targetRoot) { Remove-Item -Recurse -Force $script:targetRoot }
    }

    It 'Should copy source-only files to target' {
        Set-Content -Path (Join-Path $script:sourceRoot 'new.txt') -Value 'new content' -NoNewline

        $plan = New-SyncPlan -SourcePath $script:sourceRoot -TargetPath $script:targetRoot
        Invoke-SyncPlan -Plan $plan

        [string]$copiedPath = Join-Path $script:targetRoot 'new.txt'
        Test-Path $copiedPath | Should -BeTrue
        Get-Content -LiteralPath $copiedPath -Raw | Should -Be 'new content'
    }

    It 'Should delete target-only files' {
        Set-Content -Path (Join-Path $script:targetRoot 'orphan.txt') -Value 'orphan' -NoNewline

        $plan = New-SyncPlan -SourcePath $script:sourceRoot -TargetPath $script:targetRoot
        Invoke-SyncPlan -Plan $plan

        Test-Path (Join-Path $script:targetRoot 'orphan.txt') | Should -BeFalse
    }

    It 'Should overwrite modified files in target with source content' {
        Set-Content -Path (Join-Path $script:sourceRoot 'file.txt') -Value 'updated' -NoNewline
        Set-Content -Path (Join-Path $script:targetRoot 'file.txt') -Value 'old' -NoNewline

        $plan = New-SyncPlan -SourcePath $script:sourceRoot -TargetPath $script:targetRoot
        Invoke-SyncPlan -Plan $plan

        Get-Content -LiteralPath (Join-Path $script:targetRoot 'file.txt') -Raw | Should -Be 'updated'
    }

    It 'Should create subdirectories when copying nested files' {
        New-Item -ItemType Directory -Path (Join-Path $script:sourceRoot 'deep/nested') -Force | Out-Null
        Set-Content -Path (Join-Path $script:sourceRoot 'deep/nested/file.txt') -Value 'deep' -NoNewline

        $plan = New-SyncPlan -SourcePath $script:sourceRoot -TargetPath $script:targetRoot
        Invoke-SyncPlan -Plan $plan

        [string]$copiedPath = Join-Path $script:targetRoot 'deep/nested/file.txt'
        Test-Path $copiedPath | Should -BeTrue
        Get-Content -LiteralPath $copiedPath -Raw | Should -Be 'deep'
    }

    It 'Should make target identical to source after a full sync' {
        # Set up a complex scenario
        Set-Content -Path (Join-Path $script:sourceRoot 'a.txt') -Value 'aaa' -NoNewline
        New-Item -ItemType Directory -Path (Join-Path $script:sourceRoot 'sub') -Force | Out-Null
        Set-Content -Path (Join-Path $script:sourceRoot 'sub/b.txt') -Value 'bbb' -NoNewline

        Set-Content -Path (Join-Path $script:targetRoot 'a.txt') -Value 'old-a' -NoNewline
        Set-Content -Path (Join-Path $script:targetRoot 'c.txt') -Value 'to-delete' -NoNewline

        $plan = New-SyncPlan -SourcePath $script:sourceRoot -TargetPath $script:targetRoot
        Invoke-SyncPlan -Plan $plan

        # Verify trees are now identical by re-comparing
        $postCompare = Compare-DirectoryTrees -SourcePath $script:sourceRoot -TargetPath $script:targetRoot
        $postCompare.SourceOnly.Count | Should -Be 0
        $postCompare.TargetOnly.Count | Should -Be 0
        $postCompare.Modified.Count | Should -Be 0
        $postCompare.Identical.Count | Should -BeGreaterThan 0
    }

    It 'Should return a report with Executed status' {
        Set-Content -Path (Join-Path $script:sourceRoot 'x.txt') -Value 'x' -NoNewline

        $plan = New-SyncPlan -SourcePath $script:sourceRoot -TargetPath $script:targetRoot
        $result = Invoke-SyncPlan -Plan $plan

        $result.DryRun | Should -BeFalse
        $result.ActionsPerformed.Count | Should -Be 1
        $result.ActionsPerformed[0].Status | Should -Be 'Executed'
    }
}

Describe 'Error handling' {
    It 'Get-FileHashMap should throw for a nonexistent directory' {
        { Get-FileHashMap -Path '/nonexistent/path/abc123' } | Should -Throw '*Directory not found*'
    }

    It 'Compare-DirectoryTrees should throw if source does not exist' {
        [string]$tmpTarget = Join-Path ([System.IO.Path]::GetTempPath()) "DirSyncTgt_$([System.Guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $tmpTarget -Force | Out-Null
        try {
            { Compare-DirectoryTrees -SourcePath '/nonexistent/abc' -TargetPath $tmpTarget } | Should -Throw '*Directory not found*'
        }
        finally {
            Remove-Item -Recurse -Force $tmpTarget -ErrorAction SilentlyContinue
        }
    }

    It 'Compare-DirectoryTrees should throw if target does not exist' {
        [string]$tmpSource = Join-Path ([System.IO.Path]::GetTempPath()) "DirSyncSrc_$([System.Guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $tmpSource -Force | Out-Null
        try {
            { Compare-DirectoryTrees -SourcePath $tmpSource -TargetPath '/nonexistent/abc' } | Should -Throw '*Directory not found*'
        }
        finally {
            Remove-Item -Recurse -Force $tmpSource -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Edge cases' {
    BeforeEach {
        $script:sourceRoot = Join-Path ([System.IO.Path]::GetTempPath()) "DirSyncSrc_$([System.Guid]::NewGuid().ToString('N'))"
        $script:targetRoot = Join-Path ([System.IO.Path]::GetTempPath()) "DirSyncTgt_$([System.Guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $script:sourceRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $script:targetRoot -Force | Out-Null
    }

    AfterEach {
        if (Test-Path $script:sourceRoot) { Remove-Item -Recurse -Force $script:sourceRoot }
        if (Test-Path $script:targetRoot) { Remove-Item -Recurse -Force $script:targetRoot }
    }

    It 'Should handle empty files correctly' {
        # Create empty file in source
        New-Item -ItemType File -Path (Join-Path $script:sourceRoot 'empty.txt') | Out-Null

        $plan = New-SyncPlan -SourcePath $script:sourceRoot -TargetPath $script:targetRoot
        $plan.Actions.Count | Should -Be 1
        Invoke-SyncPlan -Plan $plan

        Test-Path (Join-Path $script:targetRoot 'empty.txt') | Should -BeTrue
    }

    It 'Should handle binary content' {
        # Write raw bytes to a file
        [byte[]]$bytes = @(0, 1, 2, 255, 128, 64)
        [System.IO.File]::WriteAllBytes((Join-Path $script:sourceRoot 'binary.bin'), $bytes)

        $plan = New-SyncPlan -SourcePath $script:sourceRoot -TargetPath $script:targetRoot
        Invoke-SyncPlan -Plan $plan

        [byte[]]$copied = [System.IO.File]::ReadAllBytes((Join-Path $script:targetRoot 'binary.bin'))
        $copied | Should -Be $bytes
    }

    It 'Should handle files with spaces in names' {
        Set-Content -Path (Join-Path $script:sourceRoot 'my file.txt') -Value 'spaces' -NoNewline

        $plan = New-SyncPlan -SourcePath $script:sourceRoot -TargetPath $script:targetRoot
        Invoke-SyncPlan -Plan $plan

        Test-Path (Join-Path $script:targetRoot 'my file.txt') | Should -BeTrue
        Get-Content -LiteralPath (Join-Path $script:targetRoot 'my file.txt') -Raw | Should -Be 'spaces'
    }

    It 'Should sync both empty directories to produce no actions' {
        $plan = New-SyncPlan -SourcePath $script:sourceRoot -TargetPath $script:targetRoot
        $plan.Actions.Count | Should -Be 0
    }
}
