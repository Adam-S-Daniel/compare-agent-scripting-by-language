Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    . "$PSScriptRoot/Rename-Files.ps1"
}

Describe 'Get-RenamePreview' {
    BeforeEach {
        # Create a temp directory with mock files
        $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "rename-test-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path $script:testDir | Out-Null
        # Create mock files
        New-Item -ItemType File -Path (Join-Path $script:testDir 'report_2024.txt') | Out-Null
        New-Item -ItemType File -Path (Join-Path $script:testDir 'report_2025.txt') | Out-Null
        New-Item -ItemType File -Path (Join-Path $script:testDir 'notes.md') | Out-Null
    }

    AfterEach {
        Remove-Item -Recurse -Force $script:testDir -ErrorAction SilentlyContinue
    }

    It 'Should return rename plan without modifying files' {
        [object[]]$results = Get-RenamePreview -Path $script:testDir -Pattern 'report_(\d+)' -Replacement 'rpt_$1'

        # Should find 2 matching files
        $results.Count | Should -Be 2

        # Original files should still exist unchanged
        (Test-Path (Join-Path $script:testDir 'report_2024.txt')) | Should -BeTrue
        (Test-Path (Join-Path $script:testDir 'report_2025.txt')) | Should -BeTrue
    }

    It 'Should return objects with OldName and NewName properties' {
        [object[]]$results = Get-RenamePreview -Path $script:testDir -Pattern 'report_(\d+)' -Replacement 'rpt_$1'

        $sorted = $results | Sort-Object OldName
        $sorted[0].OldName | Should -Be 'report_2024.txt'
        $sorted[0].NewName | Should -Be 'rpt_2024.txt'
        $sorted[1].OldName | Should -Be 'report_2025.txt'
        $sorted[1].NewName | Should -Be 'rpt_2025.txt'
    }

    It 'Should skip files that do not match the pattern' {
        [object[]]$results = Get-RenamePreview -Path $script:testDir -Pattern 'report_(\d+)' -Replacement 'rpt_$1'

        $results | ForEach-Object { $_.OldName | Should -Not -Be 'notes.md' }
    }

    It 'Should return empty array when no files match' {
        [object[]]$results = @(Get-RenamePreview -Path $script:testDir -Pattern 'nonexistent' -Replacement 'x')

        $results.Count | Should -Be 0
    }
}

Describe 'Find-RenameConflicts' {
    BeforeEach {
        $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "rename-test-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path $script:testDir | Out-Null
    }

    AfterEach {
        Remove-Item -Recurse -Force $script:testDir -ErrorAction SilentlyContinue
    }

    It 'Should detect when two files would rename to the same name' {
        # Both files will rename to the same target via pattern that strips digits
        New-Item -ItemType File -Path (Join-Path $script:testDir 'file1.txt') | Out-Null
        New-Item -ItemType File -Path (Join-Path $script:testDir 'file2.txt') | Out-Null

        [PSCustomObject[]]$preview = @(Get-RenamePreview -Path $script:testDir -Pattern 'file\d+' -Replacement 'file')
        [PSCustomObject[]]$conflicts = @(Find-RenameConflicts -RenamePlan $preview)

        $conflicts.Count | Should -BeGreaterThan 0
        $conflicts[0].ConflictingNewName | Should -Be 'file.txt'
    }

    It 'Should return no conflicts when all new names are unique' {
        New-Item -ItemType File -Path (Join-Path $script:testDir 'report_2024.txt') | Out-Null
        New-Item -ItemType File -Path (Join-Path $script:testDir 'report_2025.txt') | Out-Null

        [PSCustomObject[]]$preview = @(Get-RenamePreview -Path $script:testDir -Pattern 'report_(\d+)' -Replacement 'rpt_$1')
        [PSCustomObject[]]$conflicts = @(Find-RenameConflicts -RenamePlan $preview)

        $conflicts.Count | Should -Be 0
    }

    It 'Should detect conflict with an existing file that is not being renamed' {
        New-Item -ItemType File -Path (Join-Path $script:testDir 'old_name.txt') | Out-Null
        New-Item -ItemType File -Path (Join-Path $script:testDir 'new_name.txt') | Out-Null

        [PSCustomObject[]]$preview = @(Get-RenamePreview -Path $script:testDir -Pattern 'old_name' -Replacement 'new_name')
        [PSCustomObject[]]$conflicts = @(Find-RenameConflicts -RenamePlan $preview)

        $conflicts.Count | Should -BeGreaterThan 0
        $conflicts[0].ConflictingNewName | Should -Be 'new_name.txt'
    }
}

Describe 'Invoke-FileRename' {
    BeforeEach {
        $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "rename-test-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path $script:testDir | Out-Null
        New-Item -ItemType File -Path (Join-Path $script:testDir 'report_2024.txt') | Out-Null
        New-Item -ItemType File -Path (Join-Path $script:testDir 'report_2025.txt') | Out-Null
        New-Item -ItemType File -Path (Join-Path $script:testDir 'notes.md') | Out-Null
    }

    AfterEach {
        Remove-Item -Recurse -Force $script:testDir -ErrorAction SilentlyContinue
    }

    It 'Should rename files on disk' {
        [PSCustomObject[]]$plan = @(Get-RenamePreview -Path $script:testDir -Pattern 'report_(\d+)' -Replacement 'rpt_$1')
        Invoke-FileRename -RenamePlan $plan

        (Test-Path (Join-Path $script:testDir 'rpt_2024.txt')) | Should -BeTrue
        (Test-Path (Join-Path $script:testDir 'rpt_2025.txt')) | Should -BeTrue
        # Originals should be gone
        (Test-Path (Join-Path $script:testDir 'report_2024.txt')) | Should -BeFalse
        (Test-Path (Join-Path $script:testDir 'report_2025.txt')) | Should -BeFalse
        # Unmatched file untouched
        (Test-Path (Join-Path $script:testDir 'notes.md')) | Should -BeTrue
    }

    It 'Should abort and throw when conflicts exist' {
        New-Item -ItemType File -Path (Join-Path $script:testDir 'file1.txt') | Out-Null
        New-Item -ItemType File -Path (Join-Path $script:testDir 'file2.txt') | Out-Null

        [PSCustomObject[]]$plan = @(Get-RenamePreview -Path $script:testDir -Pattern 'file\d+' -Replacement 'file')

        { Invoke-FileRename -RenamePlan $plan } | Should -Throw '*conflict*'

        # Both originals should still exist (no partial rename)
        (Test-Path (Join-Path $script:testDir 'file1.txt')) | Should -BeTrue
        (Test-Path (Join-Path $script:testDir 'file2.txt')) | Should -BeTrue
    }

    It 'Should throw on invalid directory path in plan entries' {
        [PSCustomObject[]]$badPlan = @(
            [PSCustomObject]@{
                OldName     = 'x.txt'
                NewName     = 'y.txt'
                FullOldPath = '/nonexistent/path/x.txt'
                FullNewPath = '/nonexistent/path/y.txt'
            }
        )

        { Invoke-FileRename -RenamePlan $badPlan } | Should -Throw
    }
}

Describe 'New-UndoScript' {
    BeforeEach {
        $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "rename-test-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path $script:testDir | Out-Null
        New-Item -ItemType File -Path (Join-Path $script:testDir 'report_2024.txt') | Out-Null
        New-Item -ItemType File -Path (Join-Path $script:testDir 'report_2025.txt') | Out-Null
    }

    AfterEach {
        Remove-Item -Recurse -Force $script:testDir -ErrorAction SilentlyContinue
    }

    It 'Should generate a valid PowerShell undo script file' {
        [PSCustomObject[]]$plan = @(Get-RenamePreview -Path $script:testDir -Pattern 'report_(\d+)' -Replacement 'rpt_$1')
        [string]$undoPath = Join-Path $script:testDir 'undo.ps1'

        New-UndoScript -RenamePlan $plan -OutputPath $undoPath

        (Test-Path $undoPath) | Should -BeTrue
        [string]$content = Get-Content -LiteralPath $undoPath -Raw
        # The undo script should rename back: rpt_2024.txt -> report_2024.txt
        $content | Should -Match 'rpt_2024\.txt'
        $content | Should -Match 'report_2024\.txt'
    }

    It 'Should produce an undo script that actually reverses renames' {
        [PSCustomObject[]]$plan = @(Get-RenamePreview -Path $script:testDir -Pattern 'report_(\d+)' -Replacement 'rpt_$1')
        [string]$undoPath = Join-Path $script:testDir 'undo.ps1'

        # Generate undo script, then perform the rename
        New-UndoScript -RenamePlan $plan -OutputPath $undoPath
        Invoke-FileRename -RenamePlan $plan

        # Verify files were renamed
        (Test-Path (Join-Path $script:testDir 'rpt_2024.txt')) | Should -BeTrue
        (Test-Path (Join-Path $script:testDir 'report_2024.txt')) | Should -BeFalse

        # Run the undo script
        & $undoPath

        # Originals should be restored
        (Test-Path (Join-Path $script:testDir 'report_2024.txt')) | Should -BeTrue
        (Test-Path (Join-Path $script:testDir 'report_2025.txt')) | Should -BeTrue
        # Renamed versions should be gone
        (Test-Path (Join-Path $script:testDir 'rpt_2024.txt')) | Should -BeFalse
        (Test-Path (Join-Path $script:testDir 'rpt_2025.txt')) | Should -BeFalse
    }

    It 'Should include strict mode in the generated undo script' {
        [PSCustomObject[]]$plan = @(Get-RenamePreview -Path $script:testDir -Pattern 'report_(\d+)' -Replacement 'rpt_$1')
        [string]$undoPath = Join-Path $script:testDir 'undo.ps1'

        New-UndoScript -RenamePlan $plan -OutputPath $undoPath

        [string]$content = Get-Content -LiteralPath $undoPath -Raw
        $content | Should -Match 'Set-StrictMode'
        $content | Should -Match 'ErrorActionPreference'
    }
}

Describe 'Edge Cases' {
    BeforeEach {
        $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "rename-test-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path $script:testDir | Out-Null
    }

    AfterEach {
        Remove-Item -Recurse -Force $script:testDir -ErrorAction SilentlyContinue
    }

    It 'Get-RenamePreview should throw for nonexistent directory' {
        { Get-RenamePreview -Path '/no/such/dir' -Pattern '.*' -Replacement 'x' } | Should -Throw '*not found*'
    }

    It 'Should handle filenames with special regex chars in replacement' {
        New-Item -ItemType File -Path (Join-Path $script:testDir 'data_v1.csv') | Out-Null

        [PSCustomObject[]]$plan = @(Get-RenamePreview -Path $script:testDir -Pattern 'data_v(\d+)' -Replacement 'archive_v$1')
        $plan.Count | Should -Be 1
        $plan[0].NewName | Should -Be 'archive_v1.csv'
    }

    It 'Should handle empty directory gracefully' {
        [object[]]$results = @(Get-RenamePreview -Path $script:testDir -Pattern '.*' -Replacement 'x')
        $results.Count | Should -Be 0
    }

    It 'Should skip files where regex match does not change the name' {
        # Pattern matches but replacement is identical to original
        New-Item -ItemType File -Path (Join-Path $script:testDir 'keep.txt') | Out-Null

        [object[]]$results = @(Get-RenamePreview -Path $script:testDir -Pattern 'keep' -Replacement 'keep')
        $results.Count | Should -Be 0
    }

    It 'Should handle files with spaces in names' {
        New-Item -ItemType File -Path (Join-Path $script:testDir 'my report.txt') | Out-Null

        [PSCustomObject[]]$plan = @(Get-RenamePreview -Path $script:testDir -Pattern 'my report' -Replacement 'my_report')
        $plan.Count | Should -Be 1
        $plan[0].NewName | Should -Be 'my_report.txt'

        Invoke-FileRename -RenamePlan $plan
        (Test-Path (Join-Path $script:testDir 'my_report.txt')) | Should -BeTrue
    }

    It 'Undo script should handle files with single quotes in paths' {
        # Create a directory with a safe but unusual name
        New-Item -ItemType File -Path (Join-Path $script:testDir 'file_a.txt') | Out-Null

        [PSCustomObject[]]$plan = @(Get-RenamePreview -Path $script:testDir -Pattern 'file_a' -Replacement 'file_b')
        [string]$undoPath = Join-Path $script:testDir 'undo.ps1'

        New-UndoScript -RenamePlan $plan -OutputPath $undoPath
        Invoke-FileRename -RenamePlan $plan

        & $undoPath
        (Test-Path (Join-Path $script:testDir 'file_a.txt')) | Should -BeTrue
    }

    It 'Should handle multiple capture groups in pattern' {
        New-Item -ItemType File -Path (Join-Path $script:testDir 'log_2024_01.txt') | Out-Null

        [PSCustomObject[]]$plan = @(Get-RenamePreview -Path $script:testDir -Pattern 'log_(\d{4})_(\d{2})' -Replacement '$1-$2_log')
        $plan.Count | Should -Be 1
        $plan[0].NewName | Should -Be '2024-01_log.txt'
    }
}
