# DirectorySync.Tests.ps1
# TDD-driven tests for Directory Tree Sync functionality
# Run with: Invoke-Pester ./DirectorySync.Tests.ps1 -Output Detailed

BeforeAll {
    # Import the module under test
    . "$PSScriptRoot/DirectorySync.ps1"
}

# ============================================================
# SECTION 1: File Hashing (RED -> GREEN -> REFACTOR)
# ============================================================

Describe "Get-FileSHA256" {
    BeforeAll {
        # Create a temp directory for test fixtures
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "DirSyncTests_$(Get-Random)"
        New-Item -ItemType Directory -Path $script:TempDir | Out-Null
    }

    AfterAll {
        Remove-Item -Recurse -Force $script:TempDir -ErrorAction SilentlyContinue
    }

    It "returns a SHA-256 hash string for a file" {
        $testFile = Join-Path $script:TempDir "test.txt"
        Set-Content -Path $testFile -Value "hello world" -NoNewline
        $hash = Get-FileSHA256 -Path $testFile
        $hash | Should -Match '^[0-9a-f]{64}$'
    }

    It "returns the same hash for identical content" {
        $file1 = Join-Path $script:TempDir "file1.txt"
        $file2 = Join-Path $script:TempDir "file2.txt"
        Set-Content -Path $file1 -Value "same content" -NoNewline
        Set-Content -Path $file2 -Value "same content" -NoNewline
        $hash1 = Get-FileSHA256 -Path $file1
        $hash2 = Get-FileSHA256 -Path $file2
        $hash1 | Should -Be $hash2
    }

    It "returns different hashes for different content" {
        $file1 = Join-Path $script:TempDir "diff1.txt"
        $file2 = Join-Path $script:TempDir "diff2.txt"
        Set-Content -Path $file1 -Value "content A" -NoNewline
        Set-Content -Path $file2 -Value "content B" -NoNewline
        $hash1 = Get-FileSHA256 -Path $file1
        $hash2 = Get-FileSHA256 -Path $file2
        $hash1 | Should -Not -Be $hash2
    }

    It "throws a meaningful error for a missing file" {
        { Get-FileSHA256 -Path "$script:TempDir/nonexistent.txt" } | Should -Throw "*not found*"
    }
}

# ============================================================
# SECTION 2: Building File Index (RED -> GREEN -> REFACTOR)
# ============================================================

Describe "Get-DirectoryIndex" {
    BeforeAll {
        $script:TempDir2 = Join-Path ([System.IO.Path]::GetTempPath()) "DirSyncTests2_$(Get-Random)"
        New-Item -ItemType Directory -Path $script:TempDir2 | Out-Null

        # Create a small tree:
        # root/
        #   a.txt
        #   sub/
        #     b.txt
        #     c.txt
        New-Item -ItemType Directory -Path (Join-Path $script:TempDir2 "sub") | Out-Null
        Set-Content -Path (Join-Path $script:TempDir2 "a.txt") -Value "file a" -NoNewline
        Set-Content -Path (Join-Path $script:TempDir2 "sub/b.txt") -Value "file b" -NoNewline
        Set-Content -Path (Join-Path $script:TempDir2 "sub/c.txt") -Value "file c" -NoNewline
    }

    AfterAll {
        Remove-Item -Recurse -Force $script:TempDir2 -ErrorAction SilentlyContinue
    }

    It "returns a hashtable of relative paths to SHA-256 hashes" {
        $index = Get-DirectoryIndex -RootPath $script:TempDir2
        $index | Should -BeOfType [hashtable]
        $index.Keys | Should -Contain "a.txt"
        $index.Keys | Should -Contain "sub/b.txt"
        $index.Keys | Should -Contain "sub/c.txt"
        $index.Count | Should -Be 3
    }

    It "uses forward-slash normalized relative paths as keys" {
        $index = Get-DirectoryIndex -RootPath $script:TempDir2
        # Keys must be relative and forward-slash separated
        $index.Keys | ForEach-Object { $_ | Should -Not -Match '^[A-Za-z]:' }
        $index.Keys | ForEach-Object { $_ | Should -Not -Match '\\' }
    }

    It "each value is a 64-char hex SHA-256 hash" {
        $index = Get-DirectoryIndex -RootPath $script:TempDir2
        $index.Values | ForEach-Object { $_ | Should -Match '^[0-9a-f]{64}$' }
    }

    It "throws a meaningful error when directory does not exist" {
        { Get-DirectoryIndex -RootPath "/nonexistent/path/xyz" } | Should -Throw "*not found*"
    }
}

# ============================================================
# SECTION 3: Comparing Two Trees (RED -> GREEN -> REFACTOR)
# ============================================================

Describe "Compare-DirectoryTrees" {
    BeforeAll {
        $script:SourceDir = Join-Path ([System.IO.Path]::GetTempPath()) "DirSyncSrc_$(Get-Random)"
        $script:DestDir   = Join-Path ([System.IO.Path]::GetTempPath()) "DirSyncDst_$(Get-Random)"

        New-Item -ItemType Directory -Path $script:SourceDir | Out-Null
        New-Item -ItemType Directory -Path $script:DestDir   | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:SourceDir "sub") | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:DestDir   "sub") | Out-Null

        # same.txt  — identical in both trees
        Set-Content -Path (Join-Path $script:SourceDir "same.txt") -Value "same" -NoNewline
        Set-Content -Path (Join-Path $script:DestDir   "same.txt") -Value "same" -NoNewline

        # changed.txt — different content
        Set-Content -Path (Join-Path $script:SourceDir "changed.txt") -Value "source version" -NoNewline
        Set-Content -Path (Join-Path $script:DestDir   "changed.txt") -Value "dest version"   -NoNewline

        # only-in-source.txt — exists only in source
        Set-Content -Path (Join-Path $script:SourceDir "only-in-source.txt") -Value "source only" -NoNewline

        # sub/only-in-dest.txt — exists only in dest
        Set-Content -Path (Join-Path $script:DestDir "sub/only-in-dest.txt") -Value "dest only" -NoNewline
    }

    AfterAll {
        Remove-Item -Recurse -Force $script:SourceDir -ErrorAction SilentlyContinue
        Remove-Item -Recurse -Force $script:DestDir   -ErrorAction SilentlyContinue
    }

    It "returns an object with SourceOnly, DestOnly, and Modified lists" {
        $result = Compare-DirectoryTrees -SourcePath $script:SourceDir -DestPath $script:DestDir
        $result | Should -Not -BeNullOrEmpty
        $result.SourceOnly | Should -Not -BeNullOrEmpty
        $result.DestOnly   | Should -Not -BeNullOrEmpty
        $result.Modified   | Should -Not -BeNullOrEmpty
    }

    It "correctly identifies files only in source" {
        $result = Compare-DirectoryTrees -SourcePath $script:SourceDir -DestPath $script:DestDir
        $result.SourceOnly | Should -Contain "only-in-source.txt"
    }

    It "correctly identifies files only in dest" {
        $result = Compare-DirectoryTrees -SourcePath $script:SourceDir -DestPath $script:DestDir
        $result.DestOnly | Should -Contain "sub/only-in-dest.txt"
    }

    It "correctly identifies modified files" {
        $result = Compare-DirectoryTrees -SourcePath $script:SourceDir -DestPath $script:DestDir
        $result.Modified | Should -Contain "changed.txt"
    }

    It "does NOT include identical files in any list" {
        $result = Compare-DirectoryTrees -SourcePath $script:SourceDir -DestPath $script:DestDir
        $result.SourceOnly | Should -Not -Contain "same.txt"
        $result.DestOnly   | Should -Not -Contain "same.txt"
        $result.Modified   | Should -Not -Contain "same.txt"
    }
}

# ============================================================
# SECTION 4: Sync Plan Generation (RED -> GREEN -> REFACTOR)
# ============================================================

Describe "New-SyncPlan" {
    It "generates Copy actions for source-only files" {
        $diff = [PSCustomObject]@{
            SourceOnly = @("new-file.txt")
            DestOnly   = @()
            Modified   = @()
        }
        $plan = New-SyncPlan -Diff $diff
        $plan | Where-Object { $_.Action -eq "Copy" -and $_.RelativePath -eq "new-file.txt" } | Should -Not -BeNullOrEmpty
    }

    It "generates Delete actions for dest-only files" {
        $diff = [PSCustomObject]@{
            SourceOnly = @()
            DestOnly   = @("old-file.txt")
            Modified   = @()
        }
        $plan = New-SyncPlan -Diff $diff
        $plan | Where-Object { $_.Action -eq "Delete" -and $_.RelativePath -eq "old-file.txt" } | Should -Not -BeNullOrEmpty
    }

    It "generates Update actions for modified files" {
        $diff = [PSCustomObject]@{
            SourceOnly = @()
            DestOnly   = @()
            Modified   = @("changed.txt")
        }
        $plan = New-SyncPlan -Diff $diff
        $plan | Where-Object { $_.Action -eq "Update" -and $_.RelativePath -eq "changed.txt" } | Should -Not -BeNullOrEmpty
    }

    It "returns an empty array when trees are identical" {
        $diff = [PSCustomObject]@{
            SourceOnly = @()
            DestOnly   = @()
            Modified   = @()
        }
        $plan = New-SyncPlan -Diff $diff
        $plan.Count | Should -Be 0
    }
}

# ============================================================
# SECTION 5: Dry-Run Mode (RED -> GREEN -> REFACTOR)
# ============================================================

Describe "Invoke-SyncPlan -DryRun" {
    BeforeAll {
        $script:DryRunSrc = Join-Path ([System.IO.Path]::GetTempPath()) "DirSyncDrySrc_$(Get-Random)"
        $script:DryRunDst = Join-Path ([System.IO.Path]::GetTempPath()) "DirSyncDryDst_$(Get-Random)"
        New-Item -ItemType Directory -Path $script:DryRunSrc | Out-Null
        New-Item -ItemType Directory -Path $script:DryRunDst | Out-Null

        Set-Content -Path (Join-Path $script:DryRunSrc "newfile.txt")  -Value "new" -NoNewline
        Set-Content -Path (Join-Path $script:DryRunDst "oldfile.txt")  -Value "old" -NoNewline
    }

    AfterAll {
        Remove-Item -Recurse -Force $script:DryRunSrc -ErrorAction SilentlyContinue
        Remove-Item -Recurse -Force $script:DryRunDst -ErrorAction SilentlyContinue
    }

    It "does NOT modify the destination directory" {
        $plan = @(
            [PSCustomObject]@{ Action = "Copy";   RelativePath = "newfile.txt" }
            [PSCustomObject]@{ Action = "Delete"; RelativePath = "oldfile.txt" }
        )
        Invoke-SyncPlan -Plan $plan -SourcePath $script:DryRunSrc -DestPath $script:DryRunDst -DryRun

        # oldfile.txt must still exist in dest
        (Test-Path (Join-Path $script:DryRunDst "oldfile.txt")) | Should -BeTrue
        # newfile.txt must NOT have been copied to dest
        (Test-Path (Join-Path $script:DryRunDst "newfile.txt")) | Should -BeFalse
    }

    It "returns a report object with planned actions" {
        $plan = @(
            [PSCustomObject]@{ Action = "Copy"; RelativePath = "newfile.txt" }
        )
        $report = Invoke-SyncPlan -Plan $plan -SourcePath $script:DryRunSrc -DestPath $script:DryRunDst -DryRun
        $report | Should -Not -BeNullOrEmpty
        $report.PlannedActions | Should -BeGreaterThan 0
    }
}

# ============================================================
# SECTION 6: Execute Mode (RED -> GREEN -> REFACTOR)
# ============================================================

Describe "Invoke-SyncPlan -Execute" {
    BeforeAll {
        $script:ExecSrc = Join-Path ([System.IO.Path]::GetTempPath()) "DirSyncExecSrc_$(Get-Random)"
        $script:ExecDst = Join-Path ([System.IO.Path]::GetTempPath()) "DirSyncExecDst_$(Get-Random)"
        New-Item -ItemType Directory -Path $script:ExecSrc | Out-Null
        New-Item -ItemType Directory -Path $script:ExecDst | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:ExecSrc "sub") | Out-Null
    }

    AfterAll {
        Remove-Item -Recurse -Force $script:ExecSrc -ErrorAction SilentlyContinue
        Remove-Item -Recurse -Force $script:ExecDst -ErrorAction SilentlyContinue
    }

    It "copies source-only files into dest" {
        Set-Content -Path (Join-Path $script:ExecSrc "copy-me.txt") -Value "copy content" -NoNewline
        $plan = @([PSCustomObject]@{ Action = "Copy"; RelativePath = "copy-me.txt" })
        Invoke-SyncPlan -Plan $plan -SourcePath $script:ExecSrc -DestPath $script:ExecDst

        $destFile = Join-Path $script:ExecDst "copy-me.txt"
        (Test-Path $destFile) | Should -BeTrue
        Get-Content $destFile -Raw | Should -Be "copy content"
    }

    It "creates intermediate directories when copying nested files" {
        Set-Content -Path (Join-Path $script:ExecSrc "sub/nested.txt") -Value "nested" -NoNewline
        $plan = @([PSCustomObject]@{ Action = "Copy"; RelativePath = "sub/nested.txt" })
        Invoke-SyncPlan -Plan $plan -SourcePath $script:ExecSrc -DestPath $script:ExecDst

        (Test-Path (Join-Path $script:ExecDst "sub/nested.txt")) | Should -BeTrue
    }

    It "updates (overwrites) modified files in dest" {
        Set-Content -Path (Join-Path $script:ExecSrc "update-me.txt") -Value "new content"  -NoNewline
        Set-Content -Path (Join-Path $script:ExecDst "update-me.txt") -Value "old content"  -NoNewline
        $plan = @([PSCustomObject]@{ Action = "Update"; RelativePath = "update-me.txt" })
        Invoke-SyncPlan -Plan $plan -SourcePath $script:ExecSrc -DestPath $script:ExecDst

        Get-Content (Join-Path $script:ExecDst "update-me.txt") -Raw | Should -Be "new content"
    }

    It "deletes dest-only files" {
        Set-Content -Path (Join-Path $script:ExecDst "delete-me.txt") -Value "to delete" -NoNewline
        $plan = @([PSCustomObject]@{ Action = "Delete"; RelativePath = "delete-me.txt" })
        Invoke-SyncPlan -Plan $plan -SourcePath $script:ExecSrc -DestPath $script:ExecDst

        (Test-Path (Join-Path $script:ExecDst "delete-me.txt")) | Should -BeFalse
    }

    It "returns a report with ActionsPerformed count" {
        Set-Content -Path (Join-Path $script:ExecSrc "report-test.txt") -Value "r" -NoNewline
        $plan = @([PSCustomObject]@{ Action = "Copy"; RelativePath = "report-test.txt" })
        $report = Invoke-SyncPlan -Plan $plan -SourcePath $script:ExecSrc -DestPath $script:ExecDst

        $report.ActionsPerformed | Should -Be 1
    }
}

# ============================================================
# SECTION 7: End-to-end integration test
# ============================================================

Describe "Sync-Directories end-to-end" {
    BeforeAll {
        $script:E2ESrc = Join-Path ([System.IO.Path]::GetTempPath()) "DirSyncE2ESrc_$(Get-Random)"
        $script:E2EDst = Join-Path ([System.IO.Path]::GetTempPath()) "DirSyncE2EDst_$(Get-Random)"
        New-Item -ItemType Directory -Path $script:E2ESrc | Out-Null
        New-Item -ItemType Directory -Path $script:E2EDst | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:E2ESrc "docs") | Out-Null

        # Source tree
        Set-Content (Join-Path $script:E2ESrc "readme.txt")      -Value "readme"  -NoNewline
        Set-Content (Join-Path $script:E2ESrc "docs/guide.txt")  -Value "guide"   -NoNewline
        Set-Content (Join-Path $script:E2ESrc "config.txt")      -Value "new cfg" -NoNewline

        # Dest tree (partially overlapping)
        Set-Content (Join-Path $script:E2EDst "config.txt")      -Value "old cfg" -NoNewline
        Set-Content (Join-Path $script:E2EDst "obsolete.txt")    -Value "gone"    -NoNewline
    }

    AfterAll {
        Remove-Item -Recurse -Force $script:E2ESrc -ErrorAction SilentlyContinue
        Remove-Item -Recurse -Force $script:E2EDst -ErrorAction SilentlyContinue
    }

    It "dry-run reports correct counts without modifying dest" {
        $report = Sync-Directories -SourcePath $script:E2ESrc -DestPath $script:E2EDst -DryRun
        # readme.txt and docs/guide.txt are source-only -> Copy
        # obsolete.txt is dest-only -> Delete
        # config.txt is modified -> Update
        $report.PlannedActions | Should -Be 4
        # dest should be unchanged
        (Test-Path (Join-Path $script:E2EDst "obsolete.txt")) | Should -BeTrue
        (Test-Path (Join-Path $script:E2EDst "readme.txt"))   | Should -BeFalse
    }

    It "execute mode brings dest in sync with source" {
        $report = Sync-Directories -SourcePath $script:E2ESrc -DestPath $script:E2EDst
        $report.ActionsPerformed | Should -Be 4

        (Test-Path (Join-Path $script:E2EDst "readme.txt"))     | Should -BeTrue
        (Test-Path (Join-Path $script:E2EDst "docs/guide.txt")) | Should -BeTrue
        (Get-Content (Join-Path $script:E2EDst "config.txt") -Raw) | Should -Be "new cfg"
        (Test-Path (Join-Path $script:E2EDst "obsolete.txt"))   | Should -BeFalse
    }
}
