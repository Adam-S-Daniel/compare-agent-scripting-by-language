# BatchFileRenamer.Tests.ps1 — Pester 5 tests using red/green TDD methodology
#
# TDD approach documented per section:
#   RED   — test written first, expected to fail (function does not exist yet)
#   GREEN — minimal implementation added to make the test pass
#   REFACTOR — code cleaned up while keeping tests green
#
# Each Describe block corresponds to one TDD cycle.

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    # Import the module under test (re-import on each run)
    Import-Module "$PSScriptRoot/BatchFileRenamer.psm1" -Force
}

# ============================================================================
# Helper: create a temp directory with mock files for testing
# ============================================================================
function New-TestDirectory {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$FileNames
    )

    [string]$dir = Join-Path ([System.IO.Path]::GetTempPath()) "pester_rename_$([guid]::NewGuid())"
    New-Item -ItemType Directory -Path $dir | Out-Null
    foreach ($name in $FileNames) {
        [string]$filePath = Join-Path $dir $name
        # Support subdirectories in the name by creating parent dirs
        [string]$parent = Split-Path $filePath -Parent
        if (-not (Test-Path $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        New-Item -ItemType File -Path $filePath | Out-Null
    }
    return $dir
}

# ============================================================================
# TDD Round 1: Basic regex rename
# RED  — Invoke-BatchRename does not exist → test fails
# GREEN — implement Invoke-BatchRename with -Pattern/-Replacement
# ============================================================================
Describe 'Invoke-BatchRename — basic regex rename' {

    BeforeEach {
        $script:testDir = New-TestDirectory -FileNames @(
            'report_2023.txt',
            'report_2024.txt',
            'notes.txt'
        )
    }

    AfterEach {
        Remove-Item -Recurse -Force $script:testDir -ErrorAction SilentlyContinue
    }

    It 'renames files whose names match the regex pattern' {
        Invoke-BatchRename -Path $script:testDir -Pattern 'report_' -Replacement 'rpt_'

        (Test-Path (Join-Path $script:testDir 'rpt_2023.txt')) | Should -BeTrue
        (Test-Path (Join-Path $script:testDir 'rpt_2024.txt')) | Should -BeTrue
        # Non-matching file is untouched
        (Test-Path (Join-Path $script:testDir 'notes.txt'))    | Should -BeTrue
        # Originals are gone
        (Test-Path (Join-Path $script:testDir 'report_2023.txt')) | Should -BeFalse
        (Test-Path (Join-Path $script:testDir 'report_2024.txt')) | Should -BeFalse
    }

    It 'supports regex capture groups in the replacement string' {
        # Swap two-digit groups: report_2023 → report_23-20
        Invoke-BatchRename -Path $script:testDir -Pattern 'report_(\d{2})(\d{2})' -Replacement 'report_$2-$1'

        (Test-Path (Join-Path $script:testDir 'report_23-20.txt')) | Should -BeTrue
        (Test-Path (Join-Path $script:testDir 'report_24-20.txt')) | Should -BeTrue
    }

    It 'returns RenameResult objects with OldName and NewName' {
        [object[]]$results = Invoke-BatchRename -Path $script:testDir -Pattern 'report_' -Replacement 'rpt_'

        $results.Count | Should -Be 2
        $results | ForEach-Object {
            $_.OldName | Should -Not -BeNullOrEmpty
            $_.NewName | Should -Not -BeNullOrEmpty
            $_.Status  | Should -Be 'Renamed'
        }
    }

    It 'skips files that do not match the pattern and returns nothing for them' {
        [object[]]$results = Invoke-BatchRename -Path $script:testDir -Pattern 'report_' -Replacement 'rpt_'

        # Only 2 files matched, so we should get exactly 2 results
        $results.Count | Should -Be 2
        ($results | Where-Object { $_.OldName -eq 'notes.txt' }) | Should -BeNullOrEmpty
    }

    It 'leaves original files intact when replacement produces the same name' {
        # Pattern matches but replacement is identical
        $results = @(Invoke-BatchRename -Path $script:testDir -Pattern 'notes' -Replacement 'notes')

        # notes.txt still exists
        (Test-Path (Join-Path $script:testDir 'notes.txt')) | Should -BeTrue
        # No rename operations recorded (name unchanged)
        $results.Count | Should -Be 0
    }
}

# ============================================================================
# TDD Round 2: Preview mode (WhatIf / -Preview)
# RED  — -Preview switch does not exist → test fails
# GREEN — add -Preview to Invoke-BatchRename; return results without renaming
# ============================================================================
Describe 'Invoke-BatchRename — preview mode' {

    BeforeEach {
        $script:testDir = New-TestDirectory -FileNames @(
            'photo_001.jpg',
            'photo_002.jpg',
            'readme.md'
        )
    }

    AfterEach {
        Remove-Item -Recurse -Force $script:testDir -ErrorAction SilentlyContinue
    }

    It 'returns planned renames without modifying any files' {
        [object[]]$results = Invoke-BatchRename -Path $script:testDir -Pattern 'photo_' -Replacement 'img_' -Preview

        # Results should show planned renames
        $results.Count | Should -Be 2
        $results[0].Status | Should -Be 'Preview'

        # Original files must still exist (nothing was actually renamed)
        (Test-Path (Join-Path $script:testDir 'photo_001.jpg')) | Should -BeTrue
        (Test-Path (Join-Path $script:testDir 'photo_002.jpg')) | Should -BeTrue
        # New names must NOT exist
        (Test-Path (Join-Path $script:testDir 'img_001.jpg')) | Should -BeFalse
        (Test-Path (Join-Path $script:testDir 'img_002.jpg')) | Should -BeFalse
    }

    It 'shows correct old and new names in preview output' {
        [object[]]$results = Invoke-BatchRename -Path $script:testDir -Pattern '(\d{3})' -Replacement 'NUM$1' -Preview

        $first = $results | Where-Object { $_.OldName -eq 'photo_001.jpg' }
        $first.NewName | Should -Be 'photo_NUM001.jpg'
    }
}

# ============================================================================
# TDD Round 3: Conflict detection
# RED  — no conflict detection → test fails when two files would collide
# GREEN — detect conflicts before renaming and throw / return error results
# ============================================================================
Describe 'Invoke-BatchRename — conflict detection' {

    BeforeEach {
        # Two files that would map to the same name if we strip digits
        $script:testDir = New-TestDirectory -FileNames @(
            'file1.txt',
            'file2.txt',
            'file3.txt'
        )
    }

    AfterEach {
        Remove-Item -Recurse -Force $script:testDir -ErrorAction SilentlyContinue
    }

    It 'detects when multiple files would be renamed to the same target name' {
        # Stripping all digits causes file1.txt, file2.txt, file3.txt → file.txt (collision)
        { Invoke-BatchRename -Path $script:testDir -Pattern '\d' -Replacement '' } |
            Should -Throw '*conflict*'
    }

    It 'does not rename ANY files when a conflict is detected' {
        try {
            Invoke-BatchRename -Path $script:testDir -Pattern '\d' -Replacement ''
        } catch {
            # Expected
        }

        # All original files must still exist
        (Test-Path (Join-Path $script:testDir 'file1.txt')) | Should -BeTrue
        (Test-Path (Join-Path $script:testDir 'file2.txt')) | Should -BeTrue
        (Test-Path (Join-Path $script:testDir 'file3.txt')) | Should -BeTrue
    }

    It 'detects conflict with an already-existing file that is not being renamed' {
        # 'notes.txt' already exists; renaming 'file1.txt' with pattern → 'notes.txt' should conflict
        New-Item -ItemType File -Path (Join-Path $script:testDir 'notes.txt') | Out-Null

        # This pattern replaces 'file1' with 'notes' — collision with existing notes.txt
        { Invoke-BatchRename -Path $script:testDir -Pattern 'file1' -Replacement 'notes' } |
            Should -Throw '*conflict*'
    }

    It 'reports conflicting file names in the error message' {
        try {
            Invoke-BatchRename -Path $script:testDir -Pattern '\d' -Replacement ''
        } catch {
            $_.Exception.Message | Should -Match 'file\.txt'
        }
    }

    It 'detects conflicts in preview mode without throwing' {
        [object[]]$results = Invoke-BatchRename -Path $script:testDir -Pattern '\d' -Replacement '' -Preview

        [object[]]$conflicts = $results | Where-Object { $_.Status -eq 'Conflict' }
        $conflicts.Count | Should -BeGreaterThan 0
    }
}

# ============================================================================
# TDD Round 4: Undo script generation
# RED  — -UndoScriptPath parameter does not exist → test fails
# GREEN — generate a PowerShell script that reverses all renames
# ============================================================================
Describe 'Invoke-BatchRename — undo script generation' {

    BeforeEach {
        $script:testDir = New-TestDirectory -FileNames @(
            'doc_old.txt',
            'doc_ancient.txt'
        )
        $script:undoPath = Join-Path $script:testDir 'undo.ps1'
    }

    AfterEach {
        Remove-Item -Recurse -Force $script:testDir -ErrorAction SilentlyContinue
    }

    It 'generates an undo script at the specified path' {
        Invoke-BatchRename -Path $script:testDir -Pattern 'doc_' -Replacement 'document_' -UndoScriptPath $script:undoPath

        (Test-Path $script:undoPath) | Should -BeTrue
    }

    It 'undo script contains Rename-Item commands to reverse the renames' {
        Invoke-BatchRename -Path $script:testDir -Pattern 'doc_' -Replacement 'document_' -UndoScriptPath $script:undoPath

        [string]$content = Get-Content $script:undoPath -Raw
        # Should contain reverse rename commands
        $content | Should -Match 'Rename-Item'
        $content | Should -Match 'document_old\.txt'
        $content | Should -Match 'doc_old\.txt'
    }

    It 'undo script successfully reverses the renames when executed' {
        Invoke-BatchRename -Path $script:testDir -Pattern 'doc_' -Replacement 'document_' -UndoScriptPath $script:undoPath

        # Verify rename happened
        (Test-Path (Join-Path $script:testDir 'document_old.txt'))     | Should -BeTrue
        (Test-Path (Join-Path $script:testDir 'document_ancient.txt')) | Should -BeTrue

        # Execute the undo script
        & $script:undoPath

        # Verify files are back to original names
        (Test-Path (Join-Path $script:testDir 'doc_old.txt'))     | Should -BeTrue
        (Test-Path (Join-Path $script:testDir 'doc_ancient.txt')) | Should -BeTrue
        # Renamed versions should be gone
        (Test-Path (Join-Path $script:testDir 'document_old.txt'))     | Should -BeFalse
        (Test-Path (Join-Path $script:testDir 'document_ancient.txt')) | Should -BeFalse
    }

    It 'does not generate undo script in preview mode' {
        Invoke-BatchRename -Path $script:testDir -Pattern 'doc_' -Replacement 'document_' -Preview -UndoScriptPath $script:undoPath

        (Test-Path $script:undoPath) | Should -BeFalse
    }
}

# ============================================================================
# TDD Round 5: Error handling / edge cases
# RED  — various edge-case tests that expose missing validation
# GREEN — add parameter validation, directory checks, etc.
# ============================================================================
Describe 'Invoke-BatchRename — error handling' {

    It 'throws when the target directory does not exist' {
        { Invoke-BatchRename -Path '/nonexistent/path/abc123' -Pattern 'x' -Replacement 'y' } |
            Should -Throw '*does not exist*'
    }

    It 'throws when the pattern is an invalid regex' {
        $dir = New-TestDirectory -FileNames @('test.txt')
        try {
            { Invoke-BatchRename -Path $dir -Pattern '[invalid(' -Replacement 'x' } |
                Should -Throw '*invalid*regex*'
        } finally {
            Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
        }
    }

    It 'returns empty array when no files match the pattern' {
        $dir = New-TestDirectory -FileNames @('hello.txt')
        try {
            $results = @(Invoke-BatchRename -Path $dir -Pattern 'zzz_no_match' -Replacement 'x')
            $results.Count | Should -Be 0
        } finally {
            Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
        }
    }

    It 'only renames files, not directories' {
        $dir = New-TestDirectory -FileNames @('file_a.txt')
        # Create a subdirectory whose name matches the pattern
        New-Item -ItemType Directory -Path (Join-Path $dir 'file_b') | Out-Null
        try {
            Invoke-BatchRename -Path $dir -Pattern 'file_' -Replacement 'f_'
            # The directory should NOT have been renamed
            (Test-Path (Join-Path $dir 'file_b')) | Should -BeTrue
            # The file should have been renamed
            (Test-Path (Join-Path $dir 'f_a.txt')) | Should -BeTrue
        } finally {
            Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
        }
    }

    It 'handles empty directory gracefully' {
        $dir = New-TestDirectory -FileNames @()
        try {
            $results = @(Invoke-BatchRename -Path $dir -Pattern 'x' -Replacement 'y')
            $results.Count | Should -Be 0
        } finally {
            Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
        }
    }
}

# ============================================================================
# TDD Round 6: Additional regex features
# ============================================================================
Describe 'Invoke-BatchRename — advanced regex patterns' {

    BeforeEach {
        $script:testDir = New-TestDirectory -FileNames @(
            'IMG_20230101_photo.jpg',
            'IMG_20240215_sunset.jpg',
            'VID_20230505_clip.mp4'
        )
    }

    AfterEach {
        Remove-Item -Recurse -Force $script:testDir -ErrorAction SilentlyContinue
    }

    It 'handles complex regex with multiple capture groups' {
        # Reformat: IMG_YYYYMMDD_desc.ext → desc_YYYY-MM-DD.ext
        # Use [^.]+ to capture the description without the extension
        Invoke-BatchRename -Path $script:testDir `
            -Pattern 'IMG_(\d{4})(\d{2})(\d{2})_([^.]+)' `
            -Replacement '$4_$1-$2-$3'

        (Test-Path (Join-Path $script:testDir 'photo_2023-01-01.jpg')) | Should -BeTrue
        (Test-Path (Join-Path $script:testDir 'sunset_2024-02-15.jpg')) | Should -BeTrue
        # VID file should not match IMG pattern
        (Test-Path (Join-Path $script:testDir 'VID_20230505_clip.mp4')) | Should -BeTrue
    }

    It 'handles case-insensitive matching with (?i) flag' {
        $dir = New-TestDirectory -FileNames @('Report.TXT', 'REPORT.txt', 'notes.md')
        try {
            [object[]]$results = Invoke-BatchRename -Path $dir -Pattern '(?i)report' -Replacement 'doc'
            $results.Count | Should -Be 2
        } finally {
            Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
        }
    }
}
