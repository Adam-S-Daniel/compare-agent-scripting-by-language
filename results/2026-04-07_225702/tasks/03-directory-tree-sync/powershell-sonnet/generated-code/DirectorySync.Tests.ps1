# DirectorySync.Tests.ps1
# TDD test suite for Directory Tree Sync functionality
# Using Pester as the testing framework
#
# Approach: Red/Green/Refactor cycle
#  1. Write a failing test
#  2. Write minimum code to pass
#  3. Refactor
#  Repeat for each feature

BeforeAll {
    # Import the module under test
    . "$PSScriptRoot/DirectorySync.ps1"

    # Helper: Create a unique temporary directory for test isolation
    function New-TempTestDir {
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        return $tmp
    }

    # Helper: Remove a temporary directory (best-effort cleanup)
    function Remove-TempTestDir([string]$Path) {
        if (Test-Path $Path) {
            Remove-Item -Recurse -Force $Path
        }
    }
}

# ===========================================================================
# FEATURE 1: Compute SHA-256 hash of a file
# ===========================================================================
Describe "Get-FileSha256" {
    BeforeEach {
        $testDir = New-TempTestDir
    }
    AfterEach {
        Remove-TempTestDir $testDir
    }

    It "returns the SHA-256 hash of a file as a lowercase hex string" {
        $filePath = Join-Path $testDir "test.txt"
        Set-Content -Path $filePath -Value "hello" -NoNewline

        $hash = Get-FileSha256 -Path $filePath

        # Pre-computed SHA-256 of "hello"
        $hash | Should -Be "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
    }

    It "returns different hashes for files with different content" {
        $file1 = Join-Path $testDir "a.txt"
        $file2 = Join-Path $testDir "b.txt"
        Set-Content -Path $file1 -Value "hello" -NoNewline
        Set-Content -Path $file2 -Value "world" -NoNewline

        $hash1 = Get-FileSha256 -Path $file1
        $hash2 = Get-FileSha256 -Path $file2

        $hash1 | Should -Not -Be $hash2
    }

    It "returns the same hash for files with identical content" {
        $file1 = Join-Path $testDir "a.txt"
        $file2 = Join-Path $testDir "b.txt"
        Set-Content -Path $file1 -Value "same content" -NoNewline
        Set-Content -Path $file2 -Value "same content" -NoNewline

        $hash1 = Get-FileSha256 -Path $file1
        $hash2 = Get-FileSha256 -Path $file2

        $hash1 | Should -Be $hash2
    }

    It "throws a meaningful error for a non-existent file" {
        { Get-FileSha256 -Path (Join-Path $testDir "nonexistent.txt") } | Should -Throw
    }
}

# ===========================================================================
# FEATURE 2: Get directory tree as a relative-path -> hash map
# ===========================================================================
Describe "Get-DirectoryTree" {
    BeforeEach {
        $testDir = New-TempTestDir
    }
    AfterEach {
        Remove-TempTestDir $testDir
    }

    It "returns an empty hashtable for an empty directory" {
        $tree = Get-DirectoryTree -Path $testDir
        $tree | Should -BeOfType [hashtable]
        $tree.Count | Should -Be 0
    }

    It "returns a single entry for a directory with one file" {
        Set-Content -Path (Join-Path $testDir "file.txt") -Value "data" -NoNewline

        $tree = Get-DirectoryTree -Path $testDir

        $tree.Count | Should -Be 1
        $tree.Keys | Should -Contain "file.txt"
    }

    It "uses relative paths as keys (not absolute)" {
        $subDir = Join-Path $testDir "subdir"
        New-Item -ItemType Directory -Path $subDir | Out-Null
        Set-Content -Path (Join-Path $subDir "nested.txt") -Value "nested" -NoNewline

        $tree = Get-DirectoryTree -Path $testDir

        # Key should be relative, using forward slash separator for portability
        $tree.Keys | Should -Contain "subdir/nested.txt"
    }

    It "includes all files recursively with correct relative paths" {
        Set-Content -Path (Join-Path $testDir "root.txt") -Value "r" -NoNewline
        $sub = Join-Path $testDir "sub"
        New-Item -ItemType Directory -Path $sub | Out-Null
        Set-Content -Path (Join-Path $sub "child.txt") -Value "c" -NoNewline

        $tree = Get-DirectoryTree -Path $testDir

        $tree.Count | Should -Be 2
        $tree.Keys | Should -Contain "root.txt"
        $tree.Keys | Should -Contain "sub/child.txt"
    }

    It "stores the SHA-256 hash as the value" {
        $filePath = Join-Path $testDir "data.txt"
        Set-Content -Path $filePath -Value "hello" -NoNewline

        $tree = Get-DirectoryTree -Path $testDir

        $tree["data.txt"] | Should -Be "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
    }

    It "throws a meaningful error for a non-existent directory" {
        { Get-DirectoryTree -Path (Join-Path $testDir "missing") } | Should -Throw "*does not exist*"
    }
}

# ===========================================================================
# FEATURE 3: Compare two directory trees
# ===========================================================================
Describe "Compare-DirectoryTrees" {
    BeforeEach {
        $sourceDir = New-TempTestDir
        $destDir   = New-TempTestDir
    }
    AfterEach {
        Remove-TempTestDir $sourceDir
        Remove-TempTestDir $destDir
    }

    It "returns a result object with SourceOnly, DestOnly, and Modified lists" {
        $result = Compare-DirectoryTrees -SourcePath $sourceDir -DestPath $destDir

        $result | Should -Not -BeNullOrEmpty
        # Verify all required properties exist on the result object
        $result.PSObject.Properties.Name | Should -Contain "SourceOnly"
        $result.PSObject.Properties.Name | Should -Contain "DestOnly"
        $result.PSObject.Properties.Name | Should -Contain "Modified"
        $result.PSObject.Properties.Name | Should -Contain "Identical"
    }

    It "reports no differences when both trees are empty" {
        $result = Compare-DirectoryTrees -SourcePath $sourceDir -DestPath $destDir

        $result.SourceOnly.Count | Should -Be 0
        $result.DestOnly.Count   | Should -Be 0
        $result.Modified.Count   | Should -Be 0
        $result.Identical.Count  | Should -Be 0
    }

    It "detects files only in source" {
        Set-Content -Path (Join-Path $sourceDir "only-in-source.txt") -Value "src" -NoNewline

        $result = Compare-DirectoryTrees -SourcePath $sourceDir -DestPath $destDir

        $result.SourceOnly | Should -Contain "only-in-source.txt"
        $result.DestOnly.Count  | Should -Be 0
        $result.Modified.Count  | Should -Be 0
    }

    It "detects files only in destination" {
        Set-Content -Path (Join-Path $destDir "only-in-dest.txt") -Value "dst" -NoNewline

        $result = Compare-DirectoryTrees -SourcePath $sourceDir -DestPath $destDir

        $result.DestOnly | Should -Contain "only-in-dest.txt"
        $result.SourceOnly.Count | Should -Be 0
        $result.Modified.Count   | Should -Be 0
    }

    It "detects modified files (same path, different hash)" {
        Set-Content -Path (Join-Path $sourceDir "shared.txt") -Value "version1" -NoNewline
        Set-Content -Path (Join-Path $destDir   "shared.txt") -Value "version2" -NoNewline

        $result = Compare-DirectoryTrees -SourcePath $sourceDir -DestPath $destDir

        $result.Modified | Should -Contain "shared.txt"
        $result.SourceOnly.Count | Should -Be 0
        $result.DestOnly.Count   | Should -Be 0
    }

    It "detects identical files (same path, same hash)" {
        Set-Content -Path (Join-Path $sourceDir "same.txt") -Value "identical" -NoNewline
        Set-Content -Path (Join-Path $destDir   "same.txt") -Value "identical" -NoNewline

        $result = Compare-DirectoryTrees -SourcePath $sourceDir -DestPath $destDir

        $result.Identical | Should -Contain "same.txt"
        $result.Modified.Count   | Should -Be 0
        $result.SourceOnly.Count | Should -Be 0
        $result.DestOnly.Count   | Should -Be 0
    }

    It "handles a complex mixed scenario correctly" {
        # Source only
        Set-Content -Path (Join-Path $sourceDir "new-file.txt") -Value "new" -NoNewline
        # Dest only
        Set-Content -Path (Join-Path $destDir "deleted-file.txt") -Value "del" -NoNewline
        # Modified
        Set-Content -Path (Join-Path $sourceDir "changed.txt") -Value "v1" -NoNewline
        Set-Content -Path (Join-Path $destDir   "changed.txt") -Value "v2" -NoNewline
        # Identical
        Set-Content -Path (Join-Path $sourceDir "same.txt") -Value "abc" -NoNewline
        Set-Content -Path (Join-Path $destDir   "same.txt") -Value "abc" -NoNewline

        $result = Compare-DirectoryTrees -SourcePath $sourceDir -DestPath $destDir

        $result.SourceOnly | Should -Contain "new-file.txt"
        $result.DestOnly   | Should -Contain "deleted-file.txt"
        $result.Modified   | Should -Contain "changed.txt"
        $result.Identical  | Should -Contain "same.txt"
    }
}

# ===========================================================================
# FEATURE 4: Generate sync plan
# ===========================================================================
Describe "Get-SyncPlan" {
    BeforeEach {
        $sourceDir = New-TempTestDir
        $destDir   = New-TempTestDir
    }
    AfterEach {
        Remove-TempTestDir $sourceDir
        Remove-TempTestDir $destDir
    }

    It "produces a plan with Copy actions for source-only files" {
        Set-Content -Path (Join-Path $sourceDir "new.txt") -Value "new" -NoNewline

        $comparison = Compare-DirectoryTrees -SourcePath $sourceDir -DestPath $destDir
        $plan = Get-SyncPlan -Comparison $comparison -SourcePath $sourceDir -DestPath $destDir

        $copyAction = $plan | Where-Object { $_.Action -eq "Copy" -and $_.RelativePath -eq "new.txt" }
        $copyAction | Should -Not -BeNullOrEmpty
    }

    It "produces a plan with Overwrite actions for modified files" {
        Set-Content -Path (Join-Path $sourceDir "mod.txt") -Value "src" -NoNewline
        Set-Content -Path (Join-Path $destDir   "mod.txt") -Value "dst" -NoNewline

        $comparison = Compare-DirectoryTrees -SourcePath $sourceDir -DestPath $destDir
        $plan = Get-SyncPlan -Comparison $comparison -SourcePath $sourceDir -DestPath $destDir

        $overwriteAction = $plan | Where-Object { $_.Action -eq "Overwrite" -and $_.RelativePath -eq "mod.txt" }
        $overwriteAction | Should -Not -BeNullOrEmpty
    }

    It "produces a plan with Delete actions for dest-only files" {
        Set-Content -Path (Join-Path $destDir "orphan.txt") -Value "orphan" -NoNewline

        $comparison = Compare-DirectoryTrees -SourcePath $sourceDir -DestPath $destDir
        $plan = Get-SyncPlan -Comparison $comparison -SourcePath $sourceDir -DestPath $destDir

        $deleteAction = $plan | Where-Object { $_.Action -eq "Delete" -and $_.RelativePath -eq "orphan.txt" }
        $deleteAction | Should -Not -BeNullOrEmpty
    }

    It "does not include actions for identical files" {
        Set-Content -Path (Join-Path $sourceDir "same.txt") -Value "same" -NoNewline
        Set-Content -Path (Join-Path $destDir   "same.txt") -Value "same" -NoNewline

        $comparison = Compare-DirectoryTrees -SourcePath $sourceDir -DestPath $destDir
        $plan = Get-SyncPlan -Comparison $comparison -SourcePath $sourceDir -DestPath $destDir

        $sameAction = $plan | Where-Object { $_.RelativePath -eq "same.txt" }
        $sameAction | Should -BeNullOrEmpty
    }

    It "each plan entry has SourcePath, DestPath, Action, and RelativePath" {
        Set-Content -Path (Join-Path $sourceDir "f.txt") -Value "x" -NoNewline

        $comparison = Compare-DirectoryTrees -SourcePath $sourceDir -DestPath $destDir
        $plan = Get-SyncPlan -Comparison $comparison -SourcePath $sourceDir -DestPath $destDir

        $entry = $plan[0]
        $entry.PSObject.Properties.Name | Should -Contain "Action"
        $entry.PSObject.Properties.Name | Should -Contain "RelativePath"
        $entry.PSObject.Properties.Name | Should -Contain "SourcePath"
        $entry.PSObject.Properties.Name | Should -Contain "DestPath"
    }
}

# ===========================================================================
# FEATURE 5: Dry-run mode (report only, no file changes)
# ===========================================================================
Describe "Invoke-SyncDryRun" {
    BeforeEach {
        $sourceDir = New-TempTestDir
        $destDir   = New-TempTestDir
    }
    AfterEach {
        Remove-TempTestDir $sourceDir
        Remove-TempTestDir $destDir
    }

    It "returns a report object describing what would happen" {
        Set-Content -Path (Join-Path $sourceDir "new.txt") -Value "n" -NoNewline
        Set-Content -Path (Join-Path $destDir   "old.txt") -Value "o" -NoNewline

        $report = Invoke-SyncDryRun -SourcePath $sourceDir -DestPath $destDir

        $report | Should -Not -BeNullOrEmpty
        $report.Plan | Should -Not -BeNullOrEmpty
        $report.Summary | Should -Not -BeNullOrEmpty
    }

    It "does NOT modify the destination directory" {
        Set-Content -Path (Join-Path $sourceDir "new.txt") -Value "n" -NoNewline
        Set-Content -Path (Join-Path $destDir   "keep.txt") -Value "k" -NoNewline

        Invoke-SyncDryRun -SourcePath $sourceDir -DestPath $destDir | Out-Null

        # Destination should be unchanged
        Test-Path (Join-Path $destDir "new.txt")  | Should -Be $false
        Test-Path (Join-Path $destDir "keep.txt") | Should -Be $true
    }

    It "summary contains counts of Copy, Overwrite, Delete, and Identical" {
        Set-Content -Path (Join-Path $sourceDir "copy.txt")      -Value "c" -NoNewline
        Set-Content -Path (Join-Path $sourceDir "overwrite.txt") -Value "v1" -NoNewline
        Set-Content -Path (Join-Path $destDir   "overwrite.txt") -Value "v2" -NoNewline
        Set-Content -Path (Join-Path $destDir   "delete.txt")    -Value "d" -NoNewline
        Set-Content -Path (Join-Path $sourceDir "same.txt")      -Value "s" -NoNewline
        Set-Content -Path (Join-Path $destDir   "same.txt")      -Value "s" -NoNewline

        $report = Invoke-SyncDryRun -SourcePath $sourceDir -DestPath $destDir

        $report.Summary.CopyCount      | Should -Be 1
        $report.Summary.OverwriteCount | Should -Be 1
        $report.Summary.DeleteCount    | Should -Be 1
        $report.Summary.IdenticalCount | Should -Be 1
    }
}

# ===========================================================================
# FEATURE 6: Execute mode (perform the actual sync)
# ===========================================================================
Describe "Invoke-SyncExecute" {
    BeforeEach {
        $sourceDir = New-TempTestDir
        $destDir   = New-TempTestDir
    }
    AfterEach {
        Remove-TempTestDir $sourceDir
        Remove-TempTestDir $destDir
    }

    It "copies source-only files to destination" {
        Set-Content -Path (Join-Path $sourceDir "new.txt") -Value "hello" -NoNewline

        Invoke-SyncExecute -SourcePath $sourceDir -DestPath $destDir | Out-Null

        Test-Path (Join-Path $destDir "new.txt") | Should -Be $true
        Get-Content (Join-Path $destDir "new.txt") -Raw | Should -Be "hello"
    }

    It "overwrites modified files in destination with source version" {
        Set-Content -Path (Join-Path $sourceDir "mod.txt") -Value "new-version" -NoNewline
        Set-Content -Path (Join-Path $destDir   "mod.txt") -Value "old-version" -NoNewline

        Invoke-SyncExecute -SourcePath $sourceDir -DestPath $destDir | Out-Null

        Get-Content (Join-Path $destDir "mod.txt") -Raw | Should -Be "new-version"
    }

    It "deletes dest-only files from destination" {
        Set-Content -Path (Join-Path $destDir "orphan.txt") -Value "gone" -NoNewline

        Invoke-SyncExecute -SourcePath $sourceDir -DestPath $destDir | Out-Null

        Test-Path (Join-Path $destDir "orphan.txt") | Should -Be $false
    }

    It "preserves identical files unchanged" {
        Set-Content -Path (Join-Path $sourceDir "same.txt") -Value "unchanged" -NoNewline
        Set-Content -Path (Join-Path $destDir   "same.txt") -Value "unchanged" -NoNewline

        Invoke-SyncExecute -SourcePath $sourceDir -DestPath $destDir | Out-Null

        Get-Content (Join-Path $destDir "same.txt") -Raw | Should -Be "unchanged"
    }

    It "creates subdirectories in destination when copying nested files" {
        $subDir = Join-Path $sourceDir "subdir"
        New-Item -ItemType Directory -Path $subDir | Out-Null
        Set-Content -Path (Join-Path $subDir "nested.txt") -Value "nested" -NoNewline

        Invoke-SyncExecute -SourcePath $sourceDir -DestPath $destDir | Out-Null

        Test-Path (Join-Path $destDir "subdir/nested.txt") | Should -Be $true
    }

    It "returns a result object with actions taken" {
        Set-Content -Path (Join-Path $sourceDir "f.txt") -Value "x" -NoNewline

        $result = Invoke-SyncExecute -SourcePath $sourceDir -DestPath $destDir

        $result | Should -Not -BeNullOrEmpty
        $result.ActionsPerformed | Should -Not -BeNullOrEmpty
    }

    It "full sync scenario: copy, overwrite, delete, and keep identical" {
        # Source has: new.txt, shared.txt (modified), same.txt
        Set-Content -Path (Join-Path $sourceDir "new.txt")    -Value "new"    -NoNewline
        Set-Content -Path (Join-Path $sourceDir "shared.txt") -Value "src"    -NoNewline
        Set-Content -Path (Join-Path $sourceDir "same.txt")   -Value "same"   -NoNewline
        # Dest has: shared.txt (old version), orphan.txt, same.txt
        Set-Content -Path (Join-Path $destDir   "shared.txt") -Value "dst"    -NoNewline
        Set-Content -Path (Join-Path $destDir   "orphan.txt") -Value "orphan" -NoNewline
        Set-Content -Path (Join-Path $destDir   "same.txt")   -Value "same"   -NoNewline

        Invoke-SyncExecute -SourcePath $sourceDir -DestPath $destDir | Out-Null

        # After sync, dest should mirror source
        Test-Path (Join-Path $destDir "new.txt")    | Should -Be $true
        Get-Content (Join-Path $destDir "shared.txt") -Raw | Should -Be "src"
        Test-Path (Join-Path $destDir "orphan.txt") | Should -Be $false
        Get-Content (Join-Path $destDir "same.txt") -Raw  | Should -Be "same"
    }
}
