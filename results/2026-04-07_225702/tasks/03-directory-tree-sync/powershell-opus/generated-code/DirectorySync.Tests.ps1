# DirectorySync.Tests.ps1 — Pester tests for directory tree sync tool
# TDD approach: each Describe block was written as a failing test first,
# then the implementation was added to make it pass.

BeforeAll {
    . "$PSScriptRoot/DirectorySync.ps1"
}

Describe 'Compare-DirectoryTrees' {
    BeforeAll {
        # Source tree: has file1.txt, sub/file2.txt, sub/file3.txt
        $src = Join-Path $TestDrive 'src'
        New-Item -Path $src -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $src 'sub') -ItemType Directory -Force | Out-Null
        Set-Content -Path (Join-Path $src 'file1.txt') -Value 'same' -NoNewline
        Set-Content -Path (Join-Path $src 'sub/file2.txt') -Value 'modified-src' -NoNewline
        Set-Content -Path (Join-Path $src 'sub/file3.txt') -Value 'only-in-src' -NoNewline

        # Destination tree: has file1.txt (same), sub/file2.txt (different), extra.txt
        $dst = Join-Path $TestDrive 'dst'
        New-Item -Path $dst -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $dst 'sub') -ItemType Directory -Force | Out-Null
        Set-Content -Path (Join-Path $dst 'file1.txt') -Value 'same' -NoNewline
        Set-Content -Path (Join-Path $dst 'sub/file2.txt') -Value 'modified-dst' -NoNewline
        Set-Content -Path (Join-Path $dst 'extra.txt') -Value 'only-in-dst' -NoNewline
    }

    It 'identifies files that are identical' {
        $result = Compare-DirectoryTrees -SourcePath $src -DestinationPath $dst
        $result.Identical | Should -Contain 'file1.txt'
    }

    It 'identifies files that differ by content hash' {
        $result = Compare-DirectoryTrees -SourcePath $src -DestinationPath $dst
        $result.Modified | Should -Contain (Join-Path 'sub' 'file2.txt')
    }

    It 'identifies files only in source' {
        $result = Compare-DirectoryTrees -SourcePath $src -DestinationPath $dst
        $result.SourceOnly | Should -Contain (Join-Path 'sub' 'file3.txt')
    }

    It 'identifies files only in destination' {
        $result = Compare-DirectoryTrees -SourcePath $src -DestinationPath $dst
        $result.DestinationOnly | Should -Contain 'extra.txt'
    }

    It 'handles two identical trees with no differences' {
        $ident1 = Join-Path $TestDrive 'ident1'
        $ident2 = Join-Path $TestDrive 'ident2'
        New-Item -Path $ident1, $ident2 -ItemType Directory -Force | Out-Null
        Set-Content -Path (Join-Path $ident1 'a.txt') -Value 'x' -NoNewline
        Set-Content -Path (Join-Path $ident2 'a.txt') -Value 'x' -NoNewline
        $result = Compare-DirectoryTrees -SourcePath $ident1 -DestinationPath $ident2
        $result.Modified.Count | Should -Be 0
        $result.SourceOnly.Count | Should -Be 0
        $result.DestinationOnly.Count | Should -Be 0
        $result.Identical | Should -Contain 'a.txt'
    }
}

Describe 'New-SyncPlan' {
    BeforeAll {
        # Build mock source / destination trees
        $src = Join-Path $TestDrive 'plansrc'
        $dst = Join-Path $TestDrive 'plandst'
        New-Item -Path $src, $dst -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $src 'sub') -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $dst 'sub') -ItemType Directory -Force | Out-Null

        Set-Content -Path (Join-Path $src 'same.txt') -Value 'same' -NoNewline
        Set-Content -Path (Join-Path $dst 'same.txt') -Value 'same' -NoNewline
        Set-Content -Path (Join-Path $src 'changed.txt') -Value 'v2' -NoNewline
        Set-Content -Path (Join-Path $dst 'changed.txt') -Value 'v1' -NoNewline
        Set-Content -Path (Join-Path $src 'sub/newfile.txt') -Value 'new' -NoNewline
        Set-Content -Path (Join-Path $dst 'orphan.txt') -Value 'orphan' -NoNewline
    }

    It 'produces a Copy action for source-only files' {
        $plan = New-SyncPlan -SourcePath $src -DestinationPath $dst
        $copyActions = $plan | Where-Object { $_.Action -eq 'Copy' }
        $copyActions.RelativePath | Should -Contain (Join-Path 'sub' 'newfile.txt')
    }

    It 'produces an Overwrite action for modified files' {
        $plan = New-SyncPlan -SourcePath $src -DestinationPath $dst
        $overwriteActions = $plan | Where-Object { $_.Action -eq 'Overwrite' }
        $overwriteActions.RelativePath | Should -Contain 'changed.txt'
    }

    It 'produces a Delete action for destination-only files' {
        $plan = New-SyncPlan -SourcePath $src -DestinationPath $dst
        $deleteActions = $plan | Where-Object { $_.Action -eq 'Delete' }
        $deleteActions.RelativePath | Should -Contain 'orphan.txt'
    }

    It 'does not produce actions for identical files' {
        $plan = New-SyncPlan -SourcePath $src -DestinationPath $dst
        $sameActions = $plan | Where-Object { $_.RelativePath -eq 'same.txt' }
        $sameActions | Should -BeNullOrEmpty
    }

    It 'returns an empty plan when trees are identical' {
        $id1 = Join-Path $TestDrive 'id1'
        $id2 = Join-Path $TestDrive 'id2'
        New-Item -Path $id1, $id2 -ItemType Directory -Force | Out-Null
        Set-Content -Path (Join-Path $id1 'x.txt') -Value 'x' -NoNewline
        Set-Content -Path (Join-Path $id2 'x.txt') -Value 'x' -NoNewline
        $plan = New-SyncPlan -SourcePath $id1 -DestinationPath $id2
        $plan.Count | Should -Be 0
    }
}

Describe 'Invoke-SyncPlan — dry-run mode' {
    BeforeAll {
        $src = Join-Path $TestDrive 'drysrc'
        $dst = Join-Path $TestDrive 'drydst'
        New-Item -Path $src, $dst -ItemType Directory -Force | Out-Null
        Set-Content -Path (Join-Path $src 'new.txt') -Value 'new' -NoNewline
        Set-Content -Path (Join-Path $dst 'stale.txt') -Value 'stale' -NoNewline
    }

    It 'does not modify the destination in dry-run mode' {
        $plan = New-SyncPlan -SourcePath $src -DestinationPath $dst
        Invoke-SyncPlan -Plan $plan -SourcePath $src -DestinationPath $dst -DryRun
        # new.txt should NOT have been copied
        Test-Path (Join-Path $dst 'new.txt') | Should -BeFalse
        # stale.txt should NOT have been deleted
        Test-Path (Join-Path $dst 'stale.txt') | Should -BeTrue
    }

    It 'returns a report of planned actions in dry-run mode' {
        $plan = New-SyncPlan -SourcePath $src -DestinationPath $dst
        $report = Invoke-SyncPlan -Plan $plan -SourcePath $src -DestinationPath $dst -DryRun
        $report | Should -Not -BeNullOrEmpty
        $report.Count | Should -BeGreaterOrEqual 2
    }
}

Describe 'Invoke-SyncPlan — execute mode' {
    BeforeEach {
        # Fresh trees for every test so mutations don't leak between tests
        $script:exSrc = Join-Path $TestDrive 'exsrc'
        $script:exDst = Join-Path $TestDrive 'exdst'
        # Clean up from prior test
        if (Test-Path $script:exSrc) { Remove-Item $script:exSrc -Recurse -Force }
        if (Test-Path $script:exDst) { Remove-Item $script:exDst -Recurse -Force }
        New-Item -Path $script:exSrc, $script:exDst -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $script:exSrc 'sub') -ItemType Directory -Force | Out-Null
    }

    It 'copies source-only files to the destination' {
        Set-Content -Path (Join-Path $exSrc 'sub/new.txt') -Value 'new' -NoNewline
        $plan = New-SyncPlan -SourcePath $exSrc -DestinationPath $exDst
        Invoke-SyncPlan -Plan $plan -SourcePath $exSrc -DestinationPath $exDst
        Test-Path (Join-Path $exDst 'sub/new.txt') | Should -BeTrue
        Get-Content (Join-Path $exDst 'sub/new.txt') -Raw | Should -Be 'new'
    }

    It 'overwrites modified files with source version' {
        Set-Content -Path (Join-Path $exSrc 'f.txt') -Value 'v2' -NoNewline
        Set-Content -Path (Join-Path $exDst 'f.txt') -Value 'v1' -NoNewline
        $plan = New-SyncPlan -SourcePath $exSrc -DestinationPath $exDst
        Invoke-SyncPlan -Plan $plan -SourcePath $exSrc -DestinationPath $exDst
        Get-Content (Join-Path $exDst 'f.txt') -Raw | Should -Be 'v2'
    }

    It 'deletes destination-only files' {
        Set-Content -Path (Join-Path $exDst 'orphan.txt') -Value 'bye' -NoNewline
        $plan = New-SyncPlan -SourcePath $exSrc -DestinationPath $exDst
        Invoke-SyncPlan -Plan $plan -SourcePath $exSrc -DestinationPath $exDst
        Test-Path (Join-Path $exDst 'orphan.txt') | Should -BeFalse
    }

    It 'makes destination identical to source after full sync' {
        # Source: a.txt, sub/b.txt
        Set-Content -Path (Join-Path $exSrc 'a.txt') -Value 'aaa' -NoNewline
        Set-Content -Path (Join-Path $exSrc 'sub/b.txt') -Value 'bbb' -NoNewline
        # Destination: a.txt (different), c.txt (extra)
        Set-Content -Path (Join-Path $exDst 'a.txt') -Value 'old' -NoNewline
        Set-Content -Path (Join-Path $exDst 'c.txt') -Value 'extra' -NoNewline

        $plan = New-SyncPlan -SourcePath $exSrc -DestinationPath $exDst
        Invoke-SyncPlan -Plan $plan -SourcePath $exSrc -DestinationPath $exDst

        # After sync, compare should show everything identical
        $result = Compare-DirectoryTrees -SourcePath $exSrc -DestinationPath $exDst
        $result.Modified.Count | Should -Be 0
        $result.SourceOnly.Count | Should -Be 0
        $result.DestinationOnly.Count | Should -Be 0
        $result.Identical.Count | Should -Be 2
    }

    It 'returns a report of actions taken' {
        Set-Content -Path (Join-Path $exSrc 'x.txt') -Value 'x' -NoNewline
        $plan = New-SyncPlan -SourcePath $exSrc -DestinationPath $exDst
        $report = Invoke-SyncPlan -Plan $plan -SourcePath $exSrc -DestinationPath $exDst
        $report | Should -Not -BeNullOrEmpty
        ($report -join "`n") | Should -BeLike '*COPIED*'
    }
}

Describe 'Invoke-DirectorySync — end-to-end' {
    BeforeEach {
        $script:e2eSrc = Join-Path $TestDrive 'e2esrc'
        $script:e2eDst = Join-Path $TestDrive 'e2edst'
        if (Test-Path $script:e2eSrc) { Remove-Item $script:e2eSrc -Recurse -Force }
        if (Test-Path $script:e2eDst) { Remove-Item $script:e2eDst -Recurse -Force }
        New-Item -Path $script:e2eSrc, $script:e2eDst -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $script:e2eSrc 'dir') -ItemType Directory -Force | Out-Null
        Set-Content -Path (Join-Path $script:e2eSrc 'a.txt') -Value 'aaa' -NoNewline
        Set-Content -Path (Join-Path $script:e2eSrc 'dir/b.txt') -Value 'bbb' -NoNewline
        Set-Content -Path (Join-Path $script:e2eDst 'a.txt') -Value 'old' -NoNewline
        Set-Content -Path (Join-Path $script:e2eDst 'stale.txt') -Value 'gone' -NoNewline
    }

    It 'dry-run reports without modifying destination' {
        $result = Invoke-DirectorySync -SourcePath $e2eSrc -DestinationPath $e2eDst -DryRun
        $result.Report.Count | Should -BeGreaterOrEqual 1
        # Nothing should have changed
        Get-Content (Join-Path $e2eDst 'a.txt') -Raw | Should -Be 'old'
        Test-Path (Join-Path $e2eDst 'stale.txt') | Should -BeTrue
    }

    It 'execute mode syncs destination to match source' {
        $result = Invoke-DirectorySync -SourcePath $e2eSrc -DestinationPath $e2eDst
        $result.Report.Count | Should -BeGreaterOrEqual 1
        # Verify the trees are now identical
        $cmp = Compare-DirectoryTrees -SourcePath $e2eSrc -DestinationPath $e2eDst
        $cmp.Modified.Count | Should -Be 0
        $cmp.SourceOnly.Count | Should -Be 0
        $cmp.DestinationOnly.Count | Should -Be 0
    }

    It 'returns the sync plan in the result' {
        $result = Invoke-DirectorySync -SourcePath $e2eSrc -DestinationPath $e2eDst -DryRun
        $result.Plan.Count | Should -BeGreaterOrEqual 1
        $result.Plan[0].Action | Should -BeIn @('Copy','Overwrite','Delete')
    }
}

Describe 'Error handling' {
    It 'Compare-DirectoryTrees throws when source does not exist' {
        { Compare-DirectoryTrees -SourcePath (Join-Path $TestDrive 'nope') -DestinationPath $TestDrive } |
            Should -Throw '*does not exist*'
    }

    It 'Compare-DirectoryTrees throws when destination does not exist' {
        { Compare-DirectoryTrees -SourcePath $TestDrive -DestinationPath (Join-Path $TestDrive 'nope') } |
            Should -Throw '*does not exist*'
    }

    It 'Invoke-SyncPlan handles an unknown action gracefully' {
        $badPlan = @([PSCustomObject]@{ Action = 'Warp'; RelativePath = 'x.txt' })
        { Invoke-SyncPlan -Plan $badPlan -SourcePath $TestDrive -DestinationPath $TestDrive } |
            Should -Throw '*Unknown sync action*'
    }

    It 'Invoke-SyncPlan with empty plan does nothing' {
        $emptyPlan = @()
        $report = Invoke-SyncPlan -Plan $emptyPlan -SourcePath $TestDrive -DestinationPath $TestDrive
        $report.Count | Should -Be 0
    }
}

Describe 'Get-DirectoryFileMap' {
    BeforeAll {
        # Create a mock directory tree under TestDrive
        $root = Join-Path $TestDrive 'maptest'
        New-Item -Path $root -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $root 'sub') -ItemType Directory -Force | Out-Null
        Set-Content -Path (Join-Path $root 'file1.txt') -Value 'content1' -NoNewline
        Set-Content -Path (Join-Path $root 'sub/file2.txt') -Value 'content2' -NoNewline
    }

    It 'returns a hashtable mapping relative paths to SHA-256 hashes' {
        $map = Get-DirectoryFileMap -Path $root
        $map | Should -BeOfType [hashtable]
        $map.Count | Should -Be 2
        $map.ContainsKey('file1.txt') | Should -BeTrue
        $map.ContainsKey((Join-Path 'sub' 'file2.txt')) | Should -BeTrue
    }

    It 'returns an empty hashtable for an empty directory' {
        $empty = Join-Path $TestDrive 'emptydir'
        New-Item -Path $empty -ItemType Directory -Force | Out-Null
        $map = Get-DirectoryFileMap -Path $empty
        $map.Count | Should -Be 0
    }

    It 'throws when the directory does not exist' {
        { Get-DirectoryFileMap -Path (Join-Path $TestDrive 'nope') } |
            Should -Throw '*does not exist*'
    }
}

Describe 'Get-FileHashSHA256' {
    It 'returns the SHA-256 hash of a file' {
        $tmpFile = Join-Path $TestDrive 'hashtest.txt'
        Set-Content -Path $tmpFile -Value 'hello world' -NoNewline
        $hash = Get-FileHashSHA256 -Path $tmpFile
        # Known SHA-256 of "hello world"
        $hash | Should -Be 'b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9'
    }

    It 'returns different hashes for different content' {
        $f1 = Join-Path $TestDrive 'a.txt'
        $f2 = Join-Path $TestDrive 'b.txt'
        Set-Content -Path $f1 -Value 'aaa' -NoNewline
        Set-Content -Path $f2 -Value 'bbb' -NoNewline
        $h1 = Get-FileHashSHA256 -Path $f1
        $h2 = Get-FileHashSHA256 -Path $f2
        $h1 | Should -Not -Be $h2
    }

    It 'throws a meaningful error for a nonexistent file' {
        { Get-FileHashSHA256 -Path (Join-Path $TestDrive 'noexist.txt') } |
            Should -Throw '*does not exist*'
    }
}
