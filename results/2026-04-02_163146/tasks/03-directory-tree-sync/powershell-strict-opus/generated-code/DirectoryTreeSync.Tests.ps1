# DirectoryTreeSync.Tests.ps1
# Pester tests for directory tree sync functionality
# TDD approach: tests written before implementation

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    # Import the module under test
    [string]$modulePath = Join-Path $PSScriptRoot 'DirectoryTreeSync.psm1'
    Import-Module $modulePath -Force
}

# Helper: create a temp directory with a unique name
function New-TestDirectory {
    [CmdletBinding()]
    [OutputType([string])]
    param()
    [string]$path = Join-Path ([System.IO.Path]::GetTempPath()) "DirSyncTest_$([System.Guid]::NewGuid().ToString('N'))"
    New-Item -Path $path -ItemType Directory -Force | Out-Null
    return $path
}

# Helper: create a file with given content inside a base directory
function New-TestFile {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)][string]$BasePath,
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string]$Content
    )
    [string]$fullPath = Join-Path $BasePath $RelativePath
    [string]$parentDir = Split-Path $fullPath -Parent
    if (-not (Test-Path $parentDir)) {
        New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
    }
    Set-Content -Path $fullPath -Value $Content -NoNewline
}

# ============================================================
# TDD Cycle 1: Get-DirectoryHashMap
# Computes SHA-256 hashes for all files in a directory tree
# Returns a hashtable keyed by relative path (forward slashes)
# ============================================================
Describe 'Get-DirectoryHashMap' {
    BeforeEach {
        $script:testRoot = New-TestDirectory
    }

    AfterEach {
        if (Test-Path $script:testRoot) {
            Remove-Item -Path $script:testRoot -Recurse -Force
        }
    }

    It 'Should return an empty hashtable for an empty directory' {
        [hashtable]$result = Get-DirectoryHashMap -Path $script:testRoot
        $result | Should -BeOfType [hashtable]
        $result.Count | Should -Be 0
    }

    It 'Should return SHA-256 hashes for files in a flat directory' {
        New-TestFile -BasePath $script:testRoot -RelativePath 'file1.txt' -Content 'Hello'
        New-TestFile -BasePath $script:testRoot -RelativePath 'file2.txt' -Content 'World'

        [hashtable]$result = Get-DirectoryHashMap -Path $script:testRoot

        $result.Count | Should -Be 2
        $result.ContainsKey('file1.txt') | Should -BeTrue
        $result.ContainsKey('file2.txt') | Should -BeTrue
        # SHA-256 hashes are 64 hex characters
        $result['file1.txt'] | Should -Match '^[A-Fa-f0-9]{64}$'
        $result['file2.txt'] | Should -Match '^[A-Fa-f0-9]{64}$'
    }

    It 'Should use relative paths with forward slashes as keys for nested files' {
        New-TestFile -BasePath $script:testRoot -RelativePath 'root.txt' -Content 'root'
        New-TestFile -BasePath $script:testRoot -RelativePath 'sub/nested.txt' -Content 'nested'

        [hashtable]$result = Get-DirectoryHashMap -Path $script:testRoot

        $result.Count | Should -Be 2
        $result.ContainsKey('root.txt') | Should -BeTrue
        $result.ContainsKey('sub/nested.txt') | Should -BeTrue
    }

    It 'Should handle deeply nested directory structures' {
        New-TestFile -BasePath $script:testRoot -RelativePath 'a/b/c/deep.txt' -Content 'deep'

        [hashtable]$result = Get-DirectoryHashMap -Path $script:testRoot

        $result.Count | Should -Be 1
        $result.ContainsKey('a/b/c/deep.txt') | Should -BeTrue
    }

    It 'Should produce identical hashes for files with identical content' {
        New-TestFile -BasePath $script:testRoot -RelativePath 'a.txt' -Content 'same content'
        New-TestFile -BasePath $script:testRoot -RelativePath 'b.txt' -Content 'same content'

        [hashtable]$result = Get-DirectoryHashMap -Path $script:testRoot

        $result['a.txt'] | Should -Be $result['b.txt']
    }

    It 'Should produce different hashes for files with different content' {
        New-TestFile -BasePath $script:testRoot -RelativePath 'a.txt' -Content 'content A'
        New-TestFile -BasePath $script:testRoot -RelativePath 'b.txt' -Content 'content B'

        [hashtable]$result = Get-DirectoryHashMap -Path $script:testRoot

        $result['a.txt'] | Should -Not -Be $result['b.txt']
    }

    It 'Should throw for a non-existent path' {
        { Get-DirectoryHashMap -Path '/nonexistent/path/xyz_abc_123' } | Should -Throw
    }
}

# ============================================================
# TDD Cycle 2: Compare-DirectoryTrees
# Compares two directory trees and returns categorized differences
# ============================================================
Describe 'Compare-DirectoryTrees' {
    BeforeEach {
        $script:sourceDir = New-TestDirectory
        $script:targetDir = New-TestDirectory
    }

    AfterEach {
        if (Test-Path $script:sourceDir) { Remove-Item -Path $script:sourceDir -Recurse -Force }
        if (Test-Path $script:targetDir) { Remove-Item -Path $script:targetDir -Recurse -Force }
    }

    It 'Should return no differences for two empty directories' {
        $result = Compare-DirectoryTrees -SourcePath $script:sourceDir -TargetPath $script:targetDir

        $result.SourceOnly.Count | Should -Be 0
        $result.TargetOnly.Count | Should -Be 0
        $result.Modified.Count | Should -Be 0
        $result.Unchanged.Count | Should -Be 0
    }

    It 'Should return no differences for identical directories' {
        New-TestFile -BasePath $script:sourceDir -RelativePath 'file.txt' -Content 'hello'
        New-TestFile -BasePath $script:targetDir -RelativePath 'file.txt' -Content 'hello'

        $result = Compare-DirectoryTrees -SourcePath $script:sourceDir -TargetPath $script:targetDir

        $result.SourceOnly.Count | Should -Be 0
        $result.TargetOnly.Count | Should -Be 0
        $result.Modified.Count | Should -Be 0
        $result.Unchanged.Count | Should -Be 1
        $result.Unchanged[0] | Should -Be 'file.txt'
    }

    It 'Should detect files only in source' {
        New-TestFile -BasePath $script:sourceDir -RelativePath 'only-source.txt' -Content 'source'

        $result = Compare-DirectoryTrees -SourcePath $script:sourceDir -TargetPath $script:targetDir

        $result.SourceOnly.Count | Should -Be 1
        $result.SourceOnly[0] | Should -Be 'only-source.txt'
        $result.TargetOnly.Count | Should -Be 0
        $result.Modified.Count | Should -Be 0
    }

    It 'Should detect files only in target' {
        New-TestFile -BasePath $script:targetDir -RelativePath 'only-target.txt' -Content 'target'

        $result = Compare-DirectoryTrees -SourcePath $script:sourceDir -TargetPath $script:targetDir

        $result.TargetOnly.Count | Should -Be 1
        $result.TargetOnly[0] | Should -Be 'only-target.txt'
        $result.SourceOnly.Count | Should -Be 0
    }

    It 'Should detect modified files (same name, different content)' {
        New-TestFile -BasePath $script:sourceDir -RelativePath 'changed.txt' -Content 'version 1'
        New-TestFile -BasePath $script:targetDir -RelativePath 'changed.txt' -Content 'version 2'

        $result = Compare-DirectoryTrees -SourcePath $script:sourceDir -TargetPath $script:targetDir

        $result.Modified.Count | Should -Be 1
        $result.Modified[0] | Should -Be 'changed.txt'
        $result.Unchanged.Count | Should -Be 0
    }

    It 'Should handle a mix of all difference types' {
        # Unchanged
        New-TestFile -BasePath $script:sourceDir -RelativePath 'same.txt' -Content 'identical'
        New-TestFile -BasePath $script:targetDir -RelativePath 'same.txt' -Content 'identical'
        # Source only
        New-TestFile -BasePath $script:sourceDir -RelativePath 'src-only.txt' -Content 'source'
        # Target only
        New-TestFile -BasePath $script:targetDir -RelativePath 'tgt-only.txt' -Content 'target'
        # Modified
        New-TestFile -BasePath $script:sourceDir -RelativePath 'diff.txt' -Content 'alpha'
        New-TestFile -BasePath $script:targetDir -RelativePath 'diff.txt' -Content 'beta'

        $result = Compare-DirectoryTrees -SourcePath $script:sourceDir -TargetPath $script:targetDir

        $result.Unchanged.Count | Should -Be 1
        $result.SourceOnly.Count | Should -Be 1
        $result.TargetOnly.Count | Should -Be 1
        $result.Modified.Count | Should -Be 1
    }

    It 'Should handle nested files across both trees' {
        New-TestFile -BasePath $script:sourceDir -RelativePath 'dir/a.txt' -Content 'A'
        New-TestFile -BasePath $script:targetDir -RelativePath 'dir/b.txt' -Content 'B'

        $result = Compare-DirectoryTrees -SourcePath $script:sourceDir -TargetPath $script:targetDir

        $result.SourceOnly.Count | Should -Be 1
        $result.SourceOnly[0] | Should -Be 'dir/a.txt'
        $result.TargetOnly.Count | Should -Be 1
        $result.TargetOnly[0] | Should -Be 'dir/b.txt'
    }
}

# ============================================================
# TDD Cycle 3: New-SyncPlan
# Generates a sync plan from comparison results
# Direction: source -> target (make target match source)
# ============================================================
Describe 'New-SyncPlan' {
    BeforeEach {
        $script:sourceDir = New-TestDirectory
        $script:targetDir = New-TestDirectory
    }

    AfterEach {
        if (Test-Path $script:sourceDir) { Remove-Item -Path $script:sourceDir -Recurse -Force }
        if (Test-Path $script:targetDir) { Remove-Item -Path $script:targetDir -Recurse -Force }
    }

    It 'Should return an empty plan for identical directories' {
        New-TestFile -BasePath $script:sourceDir -RelativePath 'file.txt' -Content 'hello'
        New-TestFile -BasePath $script:targetDir -RelativePath 'file.txt' -Content 'hello'

        [array]$plan = New-SyncPlan -SourcePath $script:sourceDir -TargetPath $script:targetDir

        $plan.Count | Should -Be 0
    }

    It 'Should plan COPY actions for files only in source' {
        New-TestFile -BasePath $script:sourceDir -RelativePath 'new-file.txt' -Content 'new'

        [array]$plan = New-SyncPlan -SourcePath $script:sourceDir -TargetPath $script:targetDir

        $plan.Count | Should -Be 1
        $plan[0].Action | Should -Be 'COPY'
        $plan[0].RelativePath | Should -Be 'new-file.txt'
        $plan[0].SourceFile | Should -Be (Join-Path $script:sourceDir 'new-file.txt')
        $plan[0].TargetFile | Should -Be (Join-Path $script:targetDir 'new-file.txt')
    }

    It 'Should plan DELETE actions for files only in target' {
        New-TestFile -BasePath $script:targetDir -RelativePath 'orphan.txt' -Content 'orphan'

        [array]$plan = New-SyncPlan -SourcePath $script:sourceDir -TargetPath $script:targetDir

        $plan.Count | Should -Be 1
        $plan[0].Action | Should -Be 'DELETE'
        $plan[0].RelativePath | Should -Be 'orphan.txt'
        $plan[0].TargetFile | Should -Be (Join-Path $script:targetDir 'orphan.txt')
    }

    It 'Should plan UPDATE actions for modified files' {
        New-TestFile -BasePath $script:sourceDir -RelativePath 'data.txt' -Content 'v2'
        New-TestFile -BasePath $script:targetDir -RelativePath 'data.txt' -Content 'v1'

        [array]$plan = New-SyncPlan -SourcePath $script:sourceDir -TargetPath $script:targetDir

        $plan.Count | Should -Be 1
        $plan[0].Action | Should -Be 'UPDATE'
        $plan[0].RelativePath | Should -Be 'data.txt'
    }

    It 'Should generate a comprehensive plan for mixed differences' {
        # Same
        New-TestFile -BasePath $script:sourceDir -RelativePath 'keep.txt' -Content 'same'
        New-TestFile -BasePath $script:targetDir -RelativePath 'keep.txt' -Content 'same'
        # Source only -> COPY
        New-TestFile -BasePath $script:sourceDir -RelativePath 'add.txt' -Content 'new'
        # Target only -> DELETE
        New-TestFile -BasePath $script:targetDir -RelativePath 'remove.txt' -Content 'old'
        # Modified -> UPDATE
        New-TestFile -BasePath $script:sourceDir -RelativePath 'change.txt' -Content 'after'
        New-TestFile -BasePath $script:targetDir -RelativePath 'change.txt' -Content 'before'

        [array]$plan = New-SyncPlan -SourcePath $script:sourceDir -TargetPath $script:targetDir

        $plan.Count | Should -Be 3

        [object]$copyAction = $plan | Where-Object { $_.Action -eq 'COPY' }
        [object]$deleteAction = $plan | Where-Object { $_.Action -eq 'DELETE' }
        [object]$updateAction = $plan | Where-Object { $_.Action -eq 'UPDATE' }

        $copyAction | Should -Not -BeNullOrEmpty
        $copyAction.RelativePath | Should -Be 'add.txt'

        $deleteAction | Should -Not -BeNullOrEmpty
        $deleteAction.RelativePath | Should -Be 'remove.txt'

        $updateAction | Should -Not -BeNullOrEmpty
        $updateAction.RelativePath | Should -Be 'change.txt'
    }
}

# ============================================================
# TDD Cycle 4: Invoke-SyncPlan
# Executes or dry-runs a sync plan
# ============================================================
Describe 'Invoke-SyncPlan' {
    BeforeEach {
        $script:sourceDir = New-TestDirectory
        $script:targetDir = New-TestDirectory
    }

    AfterEach {
        if (Test-Path $script:sourceDir) { Remove-Item -Path $script:sourceDir -Recurse -Force }
        if (Test-Path $script:targetDir) { Remove-Item -Path $script:targetDir -Recurse -Force }
    }

    Context 'Dry-run mode' {
        It 'Should report planned actions without modifying the filesystem' {
            New-TestFile -BasePath $script:sourceDir -RelativePath 'new.txt' -Content 'hello'

            [array]$plan = New-SyncPlan -SourcePath $script:sourceDir -TargetPath $script:targetDir
            [array]$report = Invoke-SyncPlan -Plan $plan -DryRun

            # File should NOT have been copied
            Test-Path (Join-Path $script:targetDir 'new.txt') | Should -BeFalse

            # Report should describe what would happen
            $report.Count | Should -Be 1
            $report[0].Action | Should -Be 'COPY'
            $report[0].RelativePath | Should -Be 'new.txt'
            $report[0].Status | Should -Be 'SKIPPED (dry-run)'
        }

        It 'Should not delete files in dry-run mode' {
            New-TestFile -BasePath $script:targetDir -RelativePath 'victim.txt' -Content 'keep me'

            [array]$plan = New-SyncPlan -SourcePath $script:sourceDir -TargetPath $script:targetDir
            [array]$report = Invoke-SyncPlan -Plan $plan -DryRun

            # File should still exist
            Test-Path (Join-Path $script:targetDir 'victim.txt') | Should -BeTrue

            $report.Count | Should -Be 1
            $report[0].Action | Should -Be 'DELETE'
            $report[0].Status | Should -Be 'SKIPPED (dry-run)'
        }
    }

    Context 'Execute mode' {
        It 'Should copy files that exist only in source' {
            New-TestFile -BasePath $script:sourceDir -RelativePath 'new.txt' -Content 'hello world'

            [array]$plan = New-SyncPlan -SourcePath $script:sourceDir -TargetPath $script:targetDir
            [array]$report = Invoke-SyncPlan -Plan $plan

            # File should now exist in target
            [string]$targetFile = Join-Path $script:targetDir 'new.txt'
            Test-Path $targetFile | Should -BeTrue
            Get-Content -Path $targetFile -Raw | Should -Be 'hello world'

            $report[0].Status | Should -Be 'DONE'
        }

        It 'Should copy files into nested subdirectories, creating them as needed' {
            New-TestFile -BasePath $script:sourceDir -RelativePath 'sub/dir/file.txt' -Content 'nested'

            [array]$plan = New-SyncPlan -SourcePath $script:sourceDir -TargetPath $script:targetDir
            [array]$report = Invoke-SyncPlan -Plan $plan

            [string]$targetFile = Join-Path $script:targetDir 'sub/dir/file.txt'
            Test-Path $targetFile | Should -BeTrue
            Get-Content -Path $targetFile -Raw | Should -Be 'nested'
        }

        It 'Should delete files that exist only in target' {
            New-TestFile -BasePath $script:targetDir -RelativePath 'orphan.txt' -Content 'delete me'

            [array]$plan = New-SyncPlan -SourcePath $script:sourceDir -TargetPath $script:targetDir
            [array]$report = Invoke-SyncPlan -Plan $plan

            Test-Path (Join-Path $script:targetDir 'orphan.txt') | Should -BeFalse
            $report[0].Status | Should -Be 'DONE'
        }

        It 'Should overwrite modified files with source version' {
            New-TestFile -BasePath $script:sourceDir -RelativePath 'data.txt' -Content 'new version'
            New-TestFile -BasePath $script:targetDir -RelativePath 'data.txt' -Content 'old version'

            [array]$plan = New-SyncPlan -SourcePath $script:sourceDir -TargetPath $script:targetDir
            [array]$report = Invoke-SyncPlan -Plan $plan

            [string]$targetFile = Join-Path $script:targetDir 'data.txt'
            Get-Content -Path $targetFile -Raw | Should -Be 'new version'
            $report[0].Status | Should -Be 'DONE'
        }

        It 'Should make target match source after full sync' {
            # Set up a complex scenario
            New-TestFile -BasePath $script:sourceDir -RelativePath 'keep.txt' -Content 'same'
            New-TestFile -BasePath $script:targetDir -RelativePath 'keep.txt' -Content 'same'
            New-TestFile -BasePath $script:sourceDir -RelativePath 'add.txt' -Content 'new file'
            New-TestFile -BasePath $script:targetDir -RelativePath 'remove.txt' -Content 'old file'
            New-TestFile -BasePath $script:sourceDir -RelativePath 'update.txt' -Content 'v2'
            New-TestFile -BasePath $script:targetDir -RelativePath 'update.txt' -Content 'v1'
            New-TestFile -BasePath $script:sourceDir -RelativePath 'sub/deep.txt' -Content 'deep'

            [array]$plan = New-SyncPlan -SourcePath $script:sourceDir -TargetPath $script:targetDir
            Invoke-SyncPlan -Plan $plan | Out-Null

            # Verify: target should now match source
            [hashtable]$sourceHashes = Get-DirectoryHashMap -Path $script:sourceDir
            [hashtable]$targetHashes = Get-DirectoryHashMap -Path $script:targetDir

            $targetHashes.Count | Should -Be $sourceHashes.Count

            foreach ($key in $sourceHashes.Keys) {
                $targetHashes.ContainsKey($key) | Should -BeTrue
                $targetHashes[$key] | Should -Be $sourceHashes[$key]
            }
        }
    }

    Context 'Error handling' {
        It 'Should report errors for invalid source files during COPY' {
            # Create a plan that references a non-existent source file
            [array]$badPlan = @(
                [PSCustomObject]@{
                    Action       = 'COPY'
                    RelativePath = 'ghost.txt'
                    SourceFile   = Join-Path $script:sourceDir 'ghost.txt'
                    TargetFile   = Join-Path $script:targetDir 'ghost.txt'
                }
            )

            [array]$report = Invoke-SyncPlan -Plan $badPlan

            $report[0].Status | Should -BeLike 'ERROR*'
        }

        It 'Should handle an empty plan gracefully' {
            [array]$emptyPlan = @()
            [array]$report = Invoke-SyncPlan -Plan $emptyPlan

            $report.Count | Should -Be 0
        }
    }
}

# ============================================================
# Integration test: end-to-end scenario
# ============================================================
Describe 'End-to-end sync scenario' {
    BeforeEach {
        $script:sourceDir = New-TestDirectory
        $script:targetDir = New-TestDirectory
    }

    AfterEach {
        if (Test-Path $script:sourceDir) { Remove-Item -Path $script:sourceDir -Recurse -Force }
        if (Test-Path $script:targetDir) { Remove-Item -Path $script:targetDir -Recurse -Force }
    }

    It 'Should sync a complex directory structure from source to target' {
        # Build source tree
        New-TestFile -BasePath $script:sourceDir -RelativePath 'readme.md' -Content '# Project'
        New-TestFile -BasePath $script:sourceDir -RelativePath 'src/main.ps1' -Content 'Write-Host "Hello"'
        New-TestFile -BasePath $script:sourceDir -RelativePath 'src/lib/utils.ps1' -Content 'function Get-Thing { }'
        New-TestFile -BasePath $script:sourceDir -RelativePath 'docs/guide.txt' -Content 'User Guide'

        # Build target tree with some overlap
        New-TestFile -BasePath $script:targetDir -RelativePath 'readme.md' -Content '# Old Project'
        New-TestFile -BasePath $script:targetDir -RelativePath 'src/main.ps1' -Content 'Write-Host "Hello"'
        New-TestFile -BasePath $script:targetDir -RelativePath 'old-stuff/legacy.txt' -Content 'legacy code'

        # Step 1: Compare
        $comparison = Compare-DirectoryTrees -SourcePath $script:sourceDir -TargetPath $script:targetDir

        $comparison.Modified | Should -Contain 'readme.md'
        $comparison.Unchanged | Should -Contain 'src/main.ps1'
        $comparison.SourceOnly | Should -Contain 'src/lib/utils.ps1'
        $comparison.SourceOnly | Should -Contain 'docs/guide.txt'
        $comparison.TargetOnly | Should -Contain 'old-stuff/legacy.txt'

        # Step 2: Generate sync plan
        [array]$plan = New-SyncPlan -SourcePath $script:sourceDir -TargetPath $script:targetDir
        $plan.Count | Should -Be 4  # 1 update + 2 copy + 1 delete

        # Step 3: Dry run — nothing changes
        Invoke-SyncPlan -Plan $plan -DryRun | Out-Null

        # Verify nothing changed
        Test-Path (Join-Path $script:targetDir 'old-stuff/legacy.txt') | Should -BeTrue
        Test-Path (Join-Path $script:targetDir 'docs/guide.txt') | Should -BeFalse

        # Step 4: Execute
        Invoke-SyncPlan -Plan $plan | Out-Null

        # Step 5: Verify target matches source
        [hashtable]$sourceHashes = Get-DirectoryHashMap -Path $script:sourceDir
        [hashtable]$targetHashes = Get-DirectoryHashMap -Path $script:targetDir

        $targetHashes.Count | Should -Be $sourceHashes.Count

        foreach ($key in $sourceHashes.Keys) {
            $targetHashes.ContainsKey($key) | Should -BeTrue
            $targetHashes[$key] | Should -Be $sourceHashes[$key]
        }

        # Verify orphaned target file is gone
        Test-Path (Join-Path $script:targetDir 'old-stuff/legacy.txt') | Should -BeFalse
    }
}
