#Requires -Modules Pester
Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# DirectorySync.Tests.ps1
# TDD test suite for directory tree comparison and sync functionality.
# Tests are written FIRST (red), then the implementation is added to make them pass (green).

BeforeAll {
    # Import the module under test
    . "$PSScriptRoot/DirectorySync.ps1"
}

Describe 'Get-FileHash256' {
    Context 'when computing SHA-256 hash of a file' {
        It 'returns a non-empty string hash for a valid file' {
            # Arrange
            $tempFile = [System.IO.Path]::GetTempFileName()
            try {
                Set-Content -Path $tempFile -Value 'hello world' -NoNewline

                # Act
                $hash = Get-FileHash256 -FilePath $tempFile

                # Assert
                $hash | Should -Not -BeNullOrEmpty
                $hash | Should -BeOfType [string]
                $hash.Length | Should -Be 64  # SHA-256 produces 64 hex chars
            }
            finally {
                Remove-Item -Path $tempFile -Force
            }
        }

        It 'returns different hashes for files with different content' {
            $tempFile1 = [System.IO.Path]::GetTempFileName()
            $tempFile2 = [System.IO.Path]::GetTempFileName()
            try {
                Set-Content -Path $tempFile1 -Value 'content A' -NoNewline
                Set-Content -Path $tempFile2 -Value 'content B' -NoNewline

                $hash1 = Get-FileHash256 -FilePath $tempFile1
                $hash2 = Get-FileHash256 -FilePath $tempFile2

                $hash1 | Should -Not -Be $hash2
            }
            finally {
                Remove-Item -Path $tempFile1 -Force
                Remove-Item -Path $tempFile2 -Force
            }
        }

        It 'returns identical hashes for files with the same content' {
            $tempFile1 = [System.IO.Path]::GetTempFileName()
            $tempFile2 = [System.IO.Path]::GetTempFileName()
            try {
                Set-Content -Path $tempFile1 -Value 'same content' -NoNewline
                Set-Content -Path $tempFile2 -Value 'same content' -NoNewline

                $hash1 = Get-FileHash256 -FilePath $tempFile1
                $hash2 = Get-FileHash256 -FilePath $tempFile2

                $hash1 | Should -Be $hash2
            }
            finally {
                Remove-Item -Path $tempFile1 -Force
                Remove-Item -Path $tempFile2 -Force
            }
        }

        It 'throws an error for a non-existent file' {
            { Get-FileHash256 -FilePath '/nonexistent/path/file.txt' } | Should -Throw
        }
    }
}

Describe 'Get-DirectoryIndex' {
    Context 'when indexing a directory' {
        BeforeEach {
            # Create a mock directory structure
            $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "DirSyncTest_$(Get-Random)"
            New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $script:testDir 'subdir') -Force | Out-Null
            Set-Content -Path (Join-Path $script:testDir 'file1.txt') -Value 'file1' -NoNewline
            Set-Content -Path (Join-Path $script:testDir 'file2.txt') -Value 'file2' -NoNewline
            Set-Content -Path (Join-Path $script:testDir 'subdir/nested.txt') -Value 'nested' -NoNewline
        }

        AfterEach {
            Remove-Item -Path $script:testDir -Recurse -Force
        }

        It 'returns a hashtable with relative file paths as keys' {
            $index = Get-DirectoryIndex -DirectoryPath $script:testDir

            $index | Should -BeOfType [hashtable]
            $index.Keys | Should -Contain 'file1.txt'
            $index.Keys | Should -Contain 'file2.txt'
            $index.Keys | Should -Contain ([System.IO.Path]::Combine('subdir', 'nested.txt'))
        }

        It 'stores SHA-256 hashes as values' {
            $index = Get-DirectoryIndex -DirectoryPath $script:testDir

            foreach ($key in $index.Keys) {
                $index[$key] | Should -Not -BeNullOrEmpty
                $index[$key].Length | Should -Be 64
            }
        }

        It 'returns empty hashtable for empty directory' {
            $emptyDir = Join-Path ([System.IO.Path]::GetTempPath()) "EmptyDirTest_$(Get-Random)"
            New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
            try {
                $index = Get-DirectoryIndex -DirectoryPath $emptyDir
                $index | Should -BeOfType [hashtable]
                $index.Count | Should -Be 0
            }
            finally {
                Remove-Item -Path $emptyDir -Recurse -Force
            }
        }

        It 'throws for a non-existent directory' {
            { Get-DirectoryIndex -DirectoryPath '/nonexistent/path' } | Should -Throw
        }
    }
}

Describe 'Compare-DirectoryTrees' {
    Context 'with mock directory structures' {
        BeforeEach {
            # Source tree: file1 (same), file2 (different), file3 (only in source)
            $script:sourceDir = Join-Path ([System.IO.Path]::GetTempPath()) "Source_$(Get-Random)"
            # Target tree: file1 (same), file2 (different), file4 (only in target)
            $script:targetDir = Join-Path ([System.IO.Path]::GetTempPath()) "Target_$(Get-Random)"

            New-Item -ItemType Directory -Path $script:sourceDir -Force | Out-Null
            New-Item -ItemType Directory -Path $script:targetDir -Force | Out-Null

            # file1.txt: same content in both
            Set-Content -Path (Join-Path $script:sourceDir 'file1.txt') -Value 'identical content' -NoNewline
            Set-Content -Path (Join-Path $script:targetDir 'file1.txt') -Value 'identical content' -NoNewline

            # file2.txt: different content
            Set-Content -Path (Join-Path $script:sourceDir 'file2.txt') -Value 'source version' -NoNewline
            Set-Content -Path (Join-Path $script:targetDir 'file2.txt') -Value 'target version' -NoNewline

            # file3.txt: only in source
            Set-Content -Path (Join-Path $script:sourceDir 'file3.txt') -Value 'only in source' -NoNewline

            # file4.txt: only in target
            Set-Content -Path (Join-Path $script:targetDir 'file4.txt') -Value 'only in target' -NoNewline
        }

        AfterEach {
            Remove-Item -Path $script:sourceDir -Recurse -Force
            Remove-Item -Path $script:targetDir -Recurse -Force
        }

        It 'returns a comparison result object' {
            $result = Compare-DirectoryTrees -SourcePath $script:sourceDir -TargetPath $script:targetDir

            $result | Should -Not -BeNullOrEmpty
        }

        It 'identifies files that are identical in both trees' {
            $result = Compare-DirectoryTrees -SourcePath $script:sourceDir -TargetPath $script:targetDir

            $result.Identical | Should -Contain 'file1.txt'
        }

        It 'identifies files that differ between trees' {
            $result = Compare-DirectoryTrees -SourcePath $script:sourceDir -TargetPath $script:targetDir

            $result.Modified | Should -Contain 'file2.txt'
        }

        It 'identifies files only in source' {
            $result = Compare-DirectoryTrees -SourcePath $script:sourceDir -TargetPath $script:targetDir

            $result.OnlyInSource | Should -Contain 'file3.txt'
        }

        It 'identifies files only in target' {
            $result = Compare-DirectoryTrees -SourcePath $script:sourceDir -TargetPath $script:targetDir

            $result.OnlyInTarget | Should -Contain 'file4.txt'
        }
    }

    Context 'with nested subdirectories' {
        BeforeEach {
            $script:sourceDir = Join-Path ([System.IO.Path]::GetTempPath()) "Source_$(Get-Random)"
            $script:targetDir = Join-Path ([System.IO.Path]::GetTempPath()) "Target_$(Get-Random)"

            New-Item -ItemType Directory -Path (Join-Path $script:sourceDir 'sub') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $script:targetDir 'sub') -Force | Out-Null

            Set-Content -Path (Join-Path $script:sourceDir 'sub/nested.txt') -Value 'nested source' -NoNewline
            Set-Content -Path (Join-Path $script:targetDir 'sub/nested.txt') -Value 'nested target' -NoNewline
        }

        AfterEach {
            Remove-Item -Path $script:sourceDir -Recurse -Force
            Remove-Item -Path $script:targetDir -Recurse -Force
        }

        It 'compares nested files using relative paths' {
            $result = Compare-DirectoryTrees -SourcePath $script:sourceDir -TargetPath $script:targetDir

            $expectedPath = [System.IO.Path]::Combine('sub', 'nested.txt')
            $result.Modified | Should -Contain $expectedPath
        }
    }
}

Describe 'New-SyncPlan' {
    It 'generates a plan with CopyToTarget actions for source-only files' {
        $comparisonResult = [PSCustomObject]@{
            Identical    = @('same.txt')
            Modified     = @()
            OnlyInSource = @('new-file.txt')
            OnlyInTarget = @()
        }

        $plan = New-SyncPlan -ComparisonResult $comparisonResult

        $copyActions = $plan | Where-Object { $_.Action -eq 'CopyToTarget' }
        $copyActions | Should -Not -BeNullOrEmpty
        ($copyActions | Where-Object { $_.RelativePath -eq 'new-file.txt' }) | Should -Not -BeNullOrEmpty
    }

    It 'generates a plan with UpdateInTarget actions for modified files' {
        $comparisonResult = [PSCustomObject]@{
            Identical    = @()
            Modified     = @('changed.txt')
            OnlyInSource = @()
            OnlyInTarget = @()
        }

        $plan = New-SyncPlan -ComparisonResult $comparisonResult

        $updateActions = $plan | Where-Object { $_.Action -eq 'UpdateInTarget' }
        $updateActions | Should -Not -BeNullOrEmpty
        ($updateActions | Where-Object { $_.RelativePath -eq 'changed.txt' }) | Should -Not -BeNullOrEmpty
    }

    It 'generates a plan with DeleteFromTarget actions for target-only files' {
        $comparisonResult = [PSCustomObject]@{
            Identical    = @()
            Modified     = @()
            OnlyInSource = @()
            OnlyInTarget = @('orphan.txt')
        }

        $plan = New-SyncPlan -ComparisonResult $comparisonResult

        $deleteActions = $plan | Where-Object { $_.Action -eq 'DeleteFromTarget' }
        $deleteActions | Should -Not -BeNullOrEmpty
        ($deleteActions | Where-Object { $_.RelativePath -eq 'orphan.txt' }) | Should -Not -BeNullOrEmpty
    }

    It 'generates no actions for identical files' {
        $comparisonResult = [PSCustomObject]@{
            Identical    = @('same.txt')
            Modified     = @()
            OnlyInSource = @()
            OnlyInTarget = @()
        }

        $plan = New-SyncPlan -ComparisonResult $comparisonResult

        $plan.Count | Should -Be 0
    }

    It 'returns an array of plan items with Action and RelativePath properties' {
        $comparisonResult = [PSCustomObject]@{
            Identical    = @()
            Modified     = @('mod.txt')
            OnlyInSource = @('new.txt')
            OnlyInTarget = @('old.txt')
        }

        $plan = New-SyncPlan -ComparisonResult $comparisonResult

        $plan | ForEach-Object {
            $_ | Should -HaveProperty 'Action'
            $_ | Should -HaveProperty 'RelativePath'
        }
    }
}

Describe 'Invoke-SyncPlan (dry-run mode)' {
    BeforeEach {
        $script:sourceDir = Join-Path ([System.IO.Path]::GetTempPath()) "Source_$(Get-Random)"
        $script:targetDir = Join-Path ([System.IO.Path]::GetTempPath()) "Target_$(Get-Random)"

        New-Item -ItemType Directory -Path $script:sourceDir -Force | Out-Null
        New-Item -ItemType Directory -Path $script:targetDir -Force | Out-Null

        Set-Content -Path (Join-Path $script:sourceDir 'new-file.txt') -Value 'new content' -NoNewline
        Set-Content -Path (Join-Path $script:targetDir 'old-file.txt') -Value 'old content' -NoNewline
    }

    AfterEach {
        Remove-Item -Path $script:sourceDir -Recurse -Force
        Remove-Item -Path $script:targetDir -Recurse -Force
    }

    It 'does NOT modify files in dry-run mode' {
        $plan = @(
            [PSCustomObject]@{ Action = 'CopyToTarget'; RelativePath = 'new-file.txt' }
            [PSCustomObject]@{ Action = 'DeleteFromTarget'; RelativePath = 'old-file.txt' }
        )

        Invoke-SyncPlan -Plan $plan -SourcePath $script:sourceDir -TargetPath $script:targetDir -DryRun

        # In dry-run: new-file.txt should NOT exist in target
        (Join-Path $script:targetDir 'new-file.txt') | Should -Not -Exist
        # In dry-run: old-file.txt should STILL exist in target
        (Join-Path $script:targetDir 'old-file.txt') | Should -Exist
    }

    It 'returns a report of planned actions in dry-run mode' {
        $plan = @(
            [PSCustomObject]@{ Action = 'CopyToTarget'; RelativePath = 'new-file.txt' }
        )

        $report = Invoke-SyncPlan -Plan $plan -SourcePath $script:sourceDir -TargetPath $script:targetDir -DryRun

        $report | Should -Not -BeNullOrEmpty
        ($report | Where-Object { $_.Action -eq 'CopyToTarget' -and $_.RelativePath -eq 'new-file.txt' }) | Should -Not -BeNullOrEmpty
    }
}

Describe 'Invoke-SyncPlan (execute mode)' {
    BeforeEach {
        $script:sourceDir = Join-Path ([System.IO.Path]::GetTempPath()) "Source_$(Get-Random)"
        $script:targetDir = Join-Path ([System.IO.Path]::GetTempPath()) "Target_$(Get-Random)"

        New-Item -ItemType Directory -Path $script:sourceDir -Force | Out-Null
        New-Item -ItemType Directory -Path $script:targetDir -Force | Out-Null

        Set-Content -Path (Join-Path $script:sourceDir 'new-file.txt') -Value 'new content' -NoNewline
        Set-Content -Path (Join-Path $script:sourceDir 'updated-file.txt') -Value 'source version' -NoNewline
        Set-Content -Path (Join-Path $script:targetDir 'updated-file.txt') -Value 'old version' -NoNewline
        Set-Content -Path (Join-Path $script:targetDir 'delete-me.txt') -Value 'to be deleted' -NoNewline
    }

    AfterEach {
        Remove-Item -Path $script:sourceDir -Recurse -Force
        Remove-Item -Path $script:targetDir -Recurse -Force
    }

    It 'copies source-only files to target' {
        $plan = @(
            [PSCustomObject]@{ Action = 'CopyToTarget'; RelativePath = 'new-file.txt' }
        )

        Invoke-SyncPlan -Plan $plan -SourcePath $script:sourceDir -TargetPath $script:targetDir

        (Join-Path $script:targetDir 'new-file.txt') | Should -Exist
    }

    It 'updates modified files in target' {
        $plan = @(
            [PSCustomObject]@{ Action = 'UpdateInTarget'; RelativePath = 'updated-file.txt' }
        )

        Invoke-SyncPlan -Plan $plan -SourcePath $script:sourceDir -TargetPath $script:targetDir

        $content = Get-Content -Path (Join-Path $script:targetDir 'updated-file.txt') -Raw
        $content | Should -Be 'source version'
    }

    It 'deletes target-only files' {
        $plan = @(
            [PSCustomObject]@{ Action = 'DeleteFromTarget'; RelativePath = 'delete-me.txt' }
        )

        Invoke-SyncPlan -Plan $plan -SourcePath $script:sourceDir -TargetPath $script:targetDir

        (Join-Path $script:targetDir 'delete-me.txt') | Should -Not -Exist
    }

    It 'creates subdirectories when copying nested files' {
        New-Item -ItemType Directory -Path (Join-Path $script:sourceDir 'subdir') -Force | Out-Null
        Set-Content -Path (Join-Path $script:sourceDir 'subdir/nested.txt') -Value 'nested content' -NoNewline

        $plan = @(
            [PSCustomObject]@{ Action = 'CopyToTarget'; RelativePath = ([System.IO.Path]::Combine('subdir', 'nested.txt')) }
        )

        Invoke-SyncPlan -Plan $plan -SourcePath $script:sourceDir -TargetPath $script:targetDir

        (Join-Path $script:targetDir 'subdir/nested.txt') | Should -Exist
    }

    It 'returns a report of executed actions' {
        $plan = @(
            [PSCustomObject]@{ Action = 'CopyToTarget'; RelativePath = 'new-file.txt' }
        )

        $report = Invoke-SyncPlan -Plan $plan -SourcePath $script:sourceDir -TargetPath $script:targetDir

        $report | Should -Not -BeNullOrEmpty
        ($report | Where-Object { $_.Action -eq 'CopyToTarget' -and $_.Status -eq 'Success' }) | Should -Not -BeNullOrEmpty
    }
}

Describe 'Invoke-DirectorySync (end-to-end)' {
    BeforeEach {
        $script:sourceDir = Join-Path ([System.IO.Path]::GetTempPath()) "Source_$(Get-Random)"
        $script:targetDir = Join-Path ([System.IO.Path]::GetTempPath()) "Target_$(Get-Random)"

        New-Item -ItemType Directory -Path $script:sourceDir -Force | Out-Null
        New-Item -ItemType Directory -Path $script:targetDir -Force | Out-Null

        # Setup: source has file1 (new), file2 (modified), no file3
        Set-Content -Path (Join-Path $script:sourceDir 'file1.txt') -Value 'brand new file' -NoNewline
        Set-Content -Path (Join-Path $script:sourceDir 'file2.txt') -Value 'updated content' -NoNewline
        # Target has file2 (old version) and file3 (orphan)
        Set-Content -Path (Join-Path $script:targetDir 'file2.txt') -Value 'old content' -NoNewline
        Set-Content -Path (Join-Path $script:targetDir 'file3.txt') -Value 'orphan file' -NoNewline
    }

    AfterEach {
        Remove-Item -Path $script:sourceDir -Recurse -Force
        Remove-Item -Path $script:targetDir -Recurse -Force
    }

    It 'in dry-run mode: returns a sync report without modifying files' {
        $report = Invoke-DirectorySync -SourcePath $script:sourceDir -TargetPath $script:targetDir -DryRun

        # Files should NOT be changed in dry-run
        (Join-Path $script:targetDir 'file1.txt') | Should -Not -Exist
        (Join-Path $script:targetDir 'file3.txt') | Should -Exist
        $oldContent = Get-Content -Path (Join-Path $script:targetDir 'file2.txt') -Raw
        $oldContent | Should -Be 'old content'

        # But report should list the planned actions
        $report | Should -Not -BeNullOrEmpty
    }

    It 'in execute mode: synchronizes the target directory to match source' {
        Invoke-DirectorySync -SourcePath $script:sourceDir -TargetPath $script:targetDir

        # file1.txt should now exist in target
        (Join-Path $script:targetDir 'file1.txt') | Should -Exist
        # file2.txt should have updated content
        $newContent = Get-Content -Path (Join-Path $script:targetDir 'file2.txt') -Raw
        $newContent | Should -Be 'updated content'
        # file3.txt (orphan) should be removed
        (Join-Path $script:targetDir 'file3.txt') | Should -Not -Exist
    }
}
