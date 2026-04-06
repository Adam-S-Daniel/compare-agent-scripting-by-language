# Rename-Files.Tests.ps1
# TDD tests for the Batch File Renamer
# RED phase: Write failing tests first, then implement minimum code to pass

# Import the module under test
$ScriptPath = Join-Path $PSScriptRoot "Rename-Files.ps1"
. $ScriptPath

Describe "Get-RenamePreview" {
    # Tests for preview mode - should return rename operations without touching the file system

    BeforeEach {
        # Create a clean test directory using Pester's TestDrive
        $TestDir = Join-Path $TestDrive "rename-test"
        New-Item -ItemType Directory -Path $TestDir -Force | Out-Null

        # Create mock files
        New-Item -ItemType File -Path (Join-Path $TestDir "photo_001.jpg") -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $TestDir "photo_002.jpg") -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $TestDir "photo_003.jpg") -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $TestDir "document.txt") -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $TestDir "readme.md") -Force | Out-Null
    }

    It "returns rename operations for files matching the regex pattern" {
        # RED: This test should fail until Get-RenamePreview is implemented
        $result = Get-RenamePreview -Directory $TestDir -Pattern "photo_(\d+)\.jpg" -Replacement "image_`$1.jpg"

        $result | Should -HaveCount 3
        $result[0].OldName | Should -Be "photo_001.jpg"
        $result[0].NewName | Should -Be "image_001.jpg"
    }

    It "returns empty array when no files match the pattern" {
        $result = Get-RenamePreview -Directory $TestDir -Pattern "nonexistent_(\d+)\.txt" -Replacement "new_`$1.txt"

        $result | Should -HaveCount 0
    }

    It "does not rename files - only returns preview data" {
        Get-RenamePreview -Directory $TestDir -Pattern "photo_(\d+)\.jpg" -Replacement "image_`$1.jpg" | Out-Null

        # Original files should still exist
        Test-Path (Join-Path $TestDir "photo_001.jpg") | Should -BeTrue
        # New files should NOT exist
        Test-Path (Join-Path $TestDir "image_001.jpg") | Should -BeFalse
    }

    It "correctly applies regex replacement with capture groups" {
        $result = Get-RenamePreview -Directory $TestDir -Pattern "photo_(\d+)\.jpg" -Replacement "vacation_2024_`$1.jpg"

        $result[0].NewName | Should -Be "vacation_2024_001.jpg"
    }

    It "includes full source and destination paths in results" {
        $result = Get-RenamePreview -Directory $TestDir -Pattern "photo_(\d+)\.jpg" -Replacement "image_`$1.jpg"

        $result[0].OldPath | Should -Be (Join-Path $TestDir "photo_001.jpg")
        $result[0].NewPath | Should -Be (Join-Path $TestDir "image_001.jpg")
    }

    It "handles case-insensitive matching when specified" {
        New-Item -ItemType File -Path (Join-Path $TestDir "PHOTO_004.JPG") -Force | Out-Null

        $result = Get-RenamePreview -Directory $TestDir -Pattern "photo_(\d+)\.jpg" -Replacement "image_`$1.jpg" -CaseInsensitive

        $result | Should -HaveCount 4
    }
}

Describe "Test-RenameConflicts" {
    # Tests for conflict detection - prevents two files getting the same name

    It "detects conflicts when two source files map to the same target name" {
        # Both "001_photo.jpg" and "photo_001.jpg" might map to same target
        $renameOps = @(
            [PSCustomObject]@{ OldName = "file_a.txt"; NewName = "output.txt"; OldPath = "C:\test\file_a.txt"; NewPath = "C:\test\output.txt" },
            [PSCustomObject]@{ OldName = "file_b.txt"; NewName = "output.txt"; OldPath = "C:\test\file_b.txt"; NewPath = "C:\test\output.txt" }
        )

        $conflicts = Test-RenameConflicts -RenameOperations $renameOps

        $conflicts | Should -HaveCount 1
        $conflicts[0].ConflictingFiles | Should -Contain "file_a.txt"
        $conflicts[0].ConflictingFiles | Should -Contain "file_b.txt"
        $conflicts[0].TargetName | Should -Be "output.txt"
    }

    It "detects conflicts when target name matches an existing file not being renamed" {
        $TestDir = Join-Path $TestDrive "conflict-test"
        New-Item -ItemType Directory -Path $TestDir -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $TestDir "existing.txt") -Force | Out-Null

        $renameOps = @(
            [PSCustomObject]@{
                OldName = "source.txt"
                NewName = "existing.txt"
                OldPath = (Join-Path $TestDir "source.txt")
                NewPath = (Join-Path $TestDir "existing.txt")
            }
        )

        $conflicts = Test-RenameConflicts -RenameOperations $renameOps -Directory $TestDir

        $conflicts | Should -HaveCount 1
        $conflicts[0].ConflictType | Should -Be "ExistingFile"
    }

    It "returns empty array when there are no conflicts" {
        $renameOps = @(
            [PSCustomObject]@{ OldName = "file_a.txt"; NewName = "output_a.txt"; OldPath = "C:\test\file_a.txt"; NewPath = "C:\test\output_a.txt" },
            [PSCustomObject]@{ OldName = "file_b.txt"; NewName = "output_b.txt"; OldPath = "C:\test\file_b.txt"; NewPath = "C:\test\output_b.txt" }
        )

        $conflicts = Test-RenameConflicts -RenameOperations $renameOps

        $conflicts | Should -HaveCount 0
    }

    It "ignores conflict when a file is renaming to its own current name" {
        # A rename that results in same name (no-op) should not be reported as conflict
        $TestDir = Join-Path $TestDrive "self-conflict-test"
        New-Item -ItemType Directory -Path $TestDir -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $TestDir "photo.jpg") -Force | Out-Null

        $renameOps = @(
            [PSCustomObject]@{
                OldName = "photo.jpg"
                NewName = "photo.jpg"
                OldPath = (Join-Path $TestDir "photo.jpg")
                NewPath = (Join-Path $TestDir "photo.jpg")
            }
        )

        $conflicts = Test-RenameConflicts -RenameOperations $renameOps -Directory $TestDir

        $conflicts | Should -HaveCount 0
    }
}

Describe "New-UndoScript" {
    # Tests for undo script generation

    BeforeEach {
        $TestDir = Join-Path $TestDrive "undo-test"
        New-Item -ItemType Directory -Path $TestDir -Force | Out-Null
    }

    It "generates a PowerShell undo script that reverses renames" {
        $renameOps = @(
            [PSCustomObject]@{ OldName = "photo_001.jpg"; NewName = "image_001.jpg"; OldPath = "C:\test\photo_001.jpg"; NewPath = "C:\test\image_001.jpg" },
            [PSCustomObject]@{ OldName = "photo_002.jpg"; NewName = "image_002.jpg"; OldPath = "C:\test\photo_002.jpg"; NewPath = "C:\test\image_002.jpg" }
        )

        $undoPath = Join-Path $TestDir "undo.ps1"
        New-UndoScript -RenameOperations $renameOps -OutputPath $undoPath

        Test-Path $undoPath | Should -BeTrue
        $content = Get-Content $undoPath -Raw
        # Undo script should rename NEW names back to OLD names
        $content | Should -Match "image_001\.jpg"
        $content | Should -Match "photo_001\.jpg"
        $content | Should -Match "Rename-Item"
    }

    It "undo script reverses operations in reverse order" {
        $renameOps = @(
            [PSCustomObject]@{ OldName = "a.txt"; NewName = "b.txt"; OldPath = "C:\test\a.txt"; NewPath = "C:\test\b.txt" },
            [PSCustomObject]@{ OldName = "b.txt"; NewName = "c.txt"; OldPath = "C:\test\b.txt"; NewPath = "C:\test\c.txt" }
        )

        $undoPath = Join-Path $TestDir "undo_order.ps1"
        New-UndoScript -RenameOperations $renameOps -OutputPath $undoPath

        $lines = Get-Content $undoPath | Where-Object { $_ -match "Rename-Item" }
        # c.txt -> b.txt should come BEFORE b.txt -> a.txt (reverse order)
        $firstRenameLine = $lines | Select-Object -First 1
        $firstRenameLine | Should -Match "c\.txt"
    }
}

Describe "Invoke-FileRename" {
    # Integration tests for the main rename function

    BeforeEach {
        $TestDir = Join-Path $TestDrive "invoke-test"
        New-Item -ItemType Directory -Path $TestDir -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $TestDir "report_2023.pdf") -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $TestDir "report_2024.pdf") -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $TestDir "notes.txt") -Force | Out-Null
    }

    It "renames files matching the pattern when not in preview mode" {
        Invoke-FileRename -Directory $TestDir -Pattern "report_(\d{4})\.pdf" -Replacement "annual_report_`$1.pdf" -Preview:$false

        Test-Path (Join-Path $TestDir "annual_report_2023.pdf") | Should -BeTrue
        Test-Path (Join-Path $TestDir "annual_report_2024.pdf") | Should -BeTrue
        # Original files should be gone
        Test-Path (Join-Path $TestDir "report_2023.pdf") | Should -BeFalse
    }

    It "does NOT rename files when in preview mode" {
        Invoke-FileRename -Directory $TestDir -Pattern "report_(\d{4})\.pdf" -Replacement "annual_report_`$1.pdf" -Preview:$true

        # Original files should still exist
        Test-Path (Join-Path $TestDir "report_2023.pdf") | Should -BeTrue
        # New files should NOT exist
        Test-Path (Join-Path $TestDir "annual_report_2023.pdf") | Should -BeFalse
    }

    It "returns rename operation objects with old and new names" {
        $result = Invoke-FileRename -Directory $TestDir -Pattern "report_(\d{4})\.pdf" -Replacement "annual_report_`$1.pdf" -Preview:$true

        $result | Should -HaveCount 2
        $result[0].OldName | Should -Match "^report_"
        $result[0].NewName | Should -Match "^annual_report_"
    }

    It "throws an error when conflicts are detected and StopOnConflict is set" {
        # Create a scenario where two files would rename to the same name
        New-Item -ItemType File -Path (Join-Path $TestDir "IMG001.jpg") -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $TestDir "IMG002.jpg") -Force | Out-Null

        # Pattern that maps both to same name (by removing digits)
        { Invoke-FileRename -Directory $TestDir -Pattern "IMG\d+\.jpg" -Replacement "image.jpg" -Preview:$false -StopOnConflict } | Should -Throw

    }

    It "generates an undo script when UndoScriptPath is specified" {
        $undoPath = Join-Path $TestDir "undo.ps1"

        Invoke-FileRename -Directory $TestDir -Pattern "report_(\d{4})\.pdf" -Replacement "annual_report_`$1.pdf" -Preview:$false -UndoScriptPath $undoPath

        Test-Path $undoPath | Should -BeTrue
    }

    It "does not modify files not matching the pattern" {
        Invoke-FileRename -Directory $TestDir -Pattern "report_(\d{4})\.pdf" -Replacement "annual_report_`$1.pdf" -Preview:$false

        # notes.txt should remain unchanged
        Test-Path (Join-Path $TestDir "notes.txt") | Should -BeTrue
    }
}
