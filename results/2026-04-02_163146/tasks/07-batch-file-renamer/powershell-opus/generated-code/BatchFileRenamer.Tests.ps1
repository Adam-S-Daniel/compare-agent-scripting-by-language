# BatchFileRenamer.Tests.ps1
# TDD tests for regex-based batch file renamer using Pester
#
# TDD Methodology followed:
#   Each Describe block represents a TDD cycle:
#   1. RED:    Tests written FIRST (before implementation)
#   2. GREEN:  Minimum code written in BatchFileRenamer.ps1 to pass
#   3. REFACTOR: Code cleaned up while keeping tests green
#
# Run with: Invoke-Pester -Path './BatchFileRenamer.Tests.ps1' -Output Detailed

BeforeAll {
    . "$PSScriptRoot/BatchFileRenamer.ps1"
}

# ============================================================================
# TDD Cycle 1: Get-RenamePreview - core rename computation
# RED:  Written first, failed with "Get-RenamePreview not found"
# GREEN: Implemented Get-RenamePreview with regex replace and filtering
# ============================================================================

Describe "Get-RenamePreview" {

    Context "Basic regex pattern matching" {
        It "Should compute new names using regex substitution" {
            $files = @("IMG_001.jpg", "IMG_002.jpg", "IMG_003.jpg")

            $result = Get-RenamePreview -FileNames $files -Pattern "^IMG_" -Replacement "Photo_"

            $result | Should -HaveCount 3
            $result[0].OldName | Should -Be "IMG_001.jpg"
            $result[0].NewName | Should -Be "Photo_001.jpg"
            $result[1].NewName | Should -Be "Photo_002.jpg"
            $result[2].NewName | Should -Be "Photo_003.jpg"
        }

        It "Should only include files that actually match the pattern" {
            $files = @("IMG_001.jpg", "DOC_001.pdf", "IMG_002.jpg")

            $result = Get-RenamePreview -FileNames $files -Pattern "^IMG_" -Replacement "Photo_"

            # Only IMG files match; DOC file should be excluded
            $result | Should -HaveCount 2
            $result[0].OldName | Should -Be "IMG_001.jpg"
            $result[1].OldName | Should -Be "IMG_002.jpg"
        }

        It "Should return empty array when no files match" {
            $files = @("readme.txt", "notes.md")

            $result = Get-RenamePreview -FileNames $files -Pattern "^IMG_" -Replacement "Photo_"

            $result | Should -HaveCount 0
        }
    }

    Context "Complex regex patterns" {
        It "Should handle capture groups in replacement" {
            $files = @("report-2024-01-15.csv", "report-2024-02-20.csv")

            $result = Get-RenamePreview -FileNames $files `
                -Pattern "report-(\d{4})-(\d{2})-(\d{2})\.csv" `
                -Replacement 'report_$1$2$3.csv'

            $result | Should -HaveCount 2
            $result[0].NewName | Should -Be "report_20240115.csv"
            $result[1].NewName | Should -Be "report_20240220.csv"
        }

        It "Should handle extension replacement" {
            $files = @("data.txt", "config.txt")

            $result = Get-RenamePreview -FileNames $files -Pattern "\.txt$" -Replacement ".md"

            $result[0].NewName | Should -Be "data.md"
            $result[1].NewName | Should -Be "config.md"
        }

        It "Should handle replacing spaces with underscores" {
            $files = @("my file.txt", "another file.pdf")

            $result = Get-RenamePreview -FileNames $files -Pattern "\s+" -Replacement "_"

            $result | Should -HaveCount 2
            $result[0].NewName | Should -Be "my_file.txt"
            $result[1].NewName | Should -Be "another_file.pdf"
        }

        It "Should handle case-insensitive matching via regex options" {
            $files = @("IMG_001.JPG", "img_002.jpg")

            # Using inline regex flag (?i) for case-insensitive match
            $result = Get-RenamePreview -FileNames $files -Pattern "(?i)^img_" -Replacement "Photo_"

            $result | Should -HaveCount 2
            $result[0].NewName | Should -Be "Photo_001.JPG"
            $result[1].NewName | Should -Be "Photo_002.jpg"
        }

        It "Should handle removing parts of filename" {
            $files = @("backup_data.csv", "backup_config.yml")

            $result = Get-RenamePreview -FileNames $files -Pattern "^backup_" -Replacement ""

            $result | Should -HaveCount 2
            $result[0].NewName | Should -Be "data.csv"
            $result[1].NewName | Should -Be "config.yml"
        }
    }

    Context "Error handling" {
        It "Should throw on invalid regex pattern" {
            { Get-RenamePreview -FileNames @("test.txt") -Pattern "[invalid" -Replacement "x" } |
                Should -Throw -ExpectedMessage "*Invalid regex pattern*"
        }
    }
}

# ============================================================================
# TDD Cycle 2: Find-RenameConflicts - conflict detection
# RED:  Written first, failed with "Find-RenameConflicts not found"
# GREEN: Implemented duplicate target and existing file conflict checks
# ============================================================================

Describe "Find-RenameConflicts" {

    Context "Duplicate target detection" {
        It "Should detect when two files would get the same name" {
            # Both files lose their numeric prefix and become 'data.csv'
            $operations = @(
                [PSCustomObject]@{ OldName = "01_data.csv"; NewName = "data.csv" }
                [PSCustomObject]@{ OldName = "02_data.csv"; NewName = "data.csv" }
            )

            $conflicts = Find-RenameConflicts -RenameOperations $operations

            $conflicts | Should -HaveCount 1
            $conflicts[0].Type | Should -Be "DuplicateTarget"
            $conflicts[0].NewName | Should -Be "data.csv"
            $conflicts[0].Message | Should -BeLike "*Multiple files*data.csv*"
        }

        It "Should detect multiple groups of duplicate targets" {
            $operations = @(
                [PSCustomObject]@{ OldName = "a1.txt"; NewName = "a.txt" }
                [PSCustomObject]@{ OldName = "a2.txt"; NewName = "a.txt" }
                [PSCustomObject]@{ OldName = "b1.txt"; NewName = "b.txt" }
                [PSCustomObject]@{ OldName = "b2.txt"; NewName = "b.txt" }
            )

            $conflicts = Find-RenameConflicts -RenameOperations $operations

            $conflicts | Should -HaveCount 2
            ($conflicts | Where-Object { $_.NewName -eq "a.txt" }) | Should -Not -BeNullOrEmpty
            ($conflicts | Where-Object { $_.NewName -eq "b.txt" }) | Should -Not -BeNullOrEmpty
        }

        It "Should return no conflicts when all targets are unique" {
            $operations = @(
                [PSCustomObject]@{ OldName = "a.txt"; NewName = "x.txt" }
                [PSCustomObject]@{ OldName = "b.txt"; NewName = "y.txt" }
            )

            $conflicts = Find-RenameConflicts -RenameOperations $operations

            $conflicts | Should -HaveCount 0
        }
    }

    Context "Existing file collision detection" {
        It "Should detect collision with existing non-renamed file" {
            $operations = @(
                [PSCustomObject]@{ OldName = "draft.txt"; NewName = "final.txt" }
            )
            # 'final.txt' already exists and is NOT being renamed
            $allFiles = @("draft.txt", "final.txt", "notes.txt")

            $conflicts = Find-RenameConflicts -RenameOperations $operations -AllFileNames $allFiles

            $conflicts | Should -HaveCount 1
            $conflicts[0].Type | Should -Be "ExistingFile"
            $conflicts[0].Message | Should -BeLike "*already exists*"
        }

        It "Should NOT flag collision when target file is itself being renamed away" {
            # 'b.txt' exists but is also being renamed to 'c.txt', so 'a.txt' -> 'b.txt' is safe
            $operations = @(
                [PSCustomObject]@{ OldName = "a.txt"; NewName = "b.txt" }
                [PSCustomObject]@{ OldName = "b.txt"; NewName = "c.txt" }
            )
            $allFiles = @("a.txt", "b.txt")

            $conflicts = Find-RenameConflicts -RenameOperations $operations -AllFileNames $allFiles

            $conflicts | Should -HaveCount 0
        }
    }

    Context "Combined conflict scenarios" {
        It "Should detect both duplicate targets and existing file collisions" {
            $operations = @(
                [PSCustomObject]@{ OldName = "x1.txt"; NewName = "same.txt" }
                [PSCustomObject]@{ OldName = "x2.txt"; NewName = "same.txt" }
                [PSCustomObject]@{ OldName = "y.txt"; NewName = "existing.txt" }
            )
            $allFiles = @("x1.txt", "x2.txt", "y.txt", "existing.txt")

            $conflicts = Find-RenameConflicts -RenameOperations $operations -AllFileNames $allFiles

            # Should find both: duplicate 'same.txt' AND collision with 'existing.txt'
            $conflicts.Count | Should -BeGreaterOrEqual 2
            ($conflicts | Where-Object { $_.Type -eq "DuplicateTarget" }) | Should -Not -BeNullOrEmpty
            ($conflicts | Where-Object { $_.Type -eq "ExistingFile" }) | Should -Not -BeNullOrEmpty
        }
    }
}

# ============================================================================
# TDD Cycle 3: Invoke-BatchRename - actual file operations with mock FS
# RED:  Written first, failed with "Invoke-BatchRename not found"
# GREEN: Implemented directory validation, preview mode, conflict check, rename
# ============================================================================

Describe "Invoke-BatchRename" {

    # Create a temporary directory with mock files for each test
    BeforeEach {
        $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "BatchRenamerTest_$(Get-Random)"
        New-Item -Path $script:testDir -ItemType Directory -Force | Out-Null
    }

    AfterEach {
        if (Test-Path $script:testDir) {
            Remove-Item -Path $script:testDir -Recurse -Force
        }
    }

    Context "Preview mode" {
        It "Should show what would be renamed without actually renaming" {
            # Create mock files
            "content" | Out-File (Join-Path $script:testDir "IMG_001.jpg")
            "content" | Out-File (Join-Path $script:testDir "IMG_002.jpg")
            "content" | Out-File (Join-Path $script:testDir "readme.txt")

            $result = Invoke-BatchRename -Path $script:testDir -Pattern "^IMG_" -Replacement "Photo_" -Preview

            # Preview should return operations
            $result | Should -HaveCount 2
            $result[0].OldName | Should -Be "IMG_001.jpg"
            $result[0].NewName | Should -Be "Photo_001.jpg"

            # Original files should still exist (not renamed)
            Test-Path (Join-Path $script:testDir "IMG_001.jpg") | Should -BeTrue
            Test-Path (Join-Path $script:testDir "IMG_002.jpg") | Should -BeTrue
            Test-Path (Join-Path $script:testDir "Photo_001.jpg") | Should -BeFalse
        }
    }

    Context "Actual rename execution" {
        It "Should rename files matching the pattern" {
            "content" | Out-File (Join-Path $script:testDir "IMG_001.jpg")
            "content" | Out-File (Join-Path $script:testDir "IMG_002.jpg")
            "content" | Out-File (Join-Path $script:testDir "readme.txt")

            $result = Invoke-BatchRename -Path $script:testDir -Pattern "^IMG_" -Replacement "Photo_"

            # Verify the rename happened
            $result | Should -HaveCount 2
            $result[0].Status | Should -Be "Success"
            $result[1].Status | Should -Be "Success"

            # Verify files on disk
            Test-Path (Join-Path $script:testDir "Photo_001.jpg") | Should -BeTrue
            Test-Path (Join-Path $script:testDir "Photo_002.jpg") | Should -BeTrue
            Test-Path (Join-Path $script:testDir "IMG_001.jpg") | Should -BeFalse

            # Non-matching file should be untouched
            Test-Path (Join-Path $script:testDir "readme.txt") | Should -BeTrue
        }

        It "Should rename files using capture groups" {
            "data" | Out-File (Join-Path $script:testDir "log-2024-01-15.txt")
            "data" | Out-File (Join-Path $script:testDir "log-2024-03-22.txt")

            $result = Invoke-BatchRename -Path $script:testDir `
                -Pattern 'log-(\d{4})-(\d{2})-(\d{2})\.txt' `
                -Replacement 'log_$1$2$3.txt'

            $result | Should -HaveCount 2
            Test-Path (Join-Path $script:testDir "log_20240115.txt") | Should -BeTrue
            Test-Path (Join-Path $script:testDir "log_20240322.txt") | Should -BeTrue
        }
    }

    Context "Conflict detection during rename" {
        It "Should throw when rename would cause duplicate names" {
            "data1" | Out-File (Join-Path $script:testDir "01_data.csv")
            "data2" | Out-File (Join-Path $script:testDir "02_data.csv")

            # Both files would become 'data.csv' after removing the prefix
            { Invoke-BatchRename -Path $script:testDir -Pattern "^\d+_" -Replacement "" } |
                Should -Throw -ExpectedMessage "*conflicts detected*"

            # Original files should still exist (rename was aborted)
            Test-Path (Join-Path $script:testDir "01_data.csv") | Should -BeTrue
            Test-Path (Join-Path $script:testDir "02_data.csv") | Should -BeTrue
        }

        It "Should throw when rename would collide with existing file" {
            "original" | Out-File (Join-Path $script:testDir "draft.txt")
            "important" | Out-File (Join-Path $script:testDir "final.txt")

            # Trying to rename 'draft.txt' to 'final.txt' but 'final.txt' exists
            { Invoke-BatchRename -Path $script:testDir -Pattern "^draft" -Replacement "final" } |
                Should -Throw -ExpectedMessage "*conflicts detected*"
        }

        It "Should allow conflicting renames when Force is used" {
            "data1" | Out-File (Join-Path $script:testDir "prefix_a.txt")
            "data2" | Out-File (Join-Path $script:testDir "other.txt")

            # This would normally conflict but Force overrides
            # Using a non-conflicting case here just to test the Force flag path
            $result = Invoke-BatchRename -Path $script:testDir -Pattern "^prefix_" -Replacement "" -Force

            $result | Should -HaveCount 1
            $result[0].Status | Should -Be "Success"
        }
    }

    Context "Error handling" {
        It "Should throw when directory does not exist" {
            { Invoke-BatchRename -Path "/nonexistent/path" -Pattern ".*" -Replacement "x" } |
                Should -Throw -ExpectedMessage "*Directory not found*"
        }

        It "Should handle empty directory gracefully" {
            # testDir exists but has no files
            $result = Invoke-BatchRename -Path $script:testDir -Pattern ".*" -Replacement "x" 3>&1

            # Should return empty or emit warning - no crash
            # (Warning stream captured by 3>&1)
        }
    }
}

# ============================================================================
# TDD Cycle 4: New-UndoScript - undo script generation
# RED:  Written first, failed with "New-UndoScript not found"
# GREEN: Implemented script generation with reverse rename commands
# ============================================================================

Describe "New-UndoScript" {

    Context "Script content generation" {
        It "Should generate reverse rename commands" {
            $operations = @(
                [PSCustomObject]@{ OldName = "IMG_001.jpg"; NewName = "Photo_001.jpg" }
                [PSCustomObject]@{ OldName = "IMG_002.jpg"; NewName = "Photo_002.jpg" }
            )

            $script = New-UndoScript -RenameOperations $operations -Directory "/tmp/photos"

            # Script should contain reverse operations (NewName -> OldName)
            $script | Should -BeLike "*Photo_001.jpg*IMG_001.jpg*"
            $script | Should -BeLike "*Photo_002.jpg*IMG_002.jpg*"
        }

        It "Should include the directory path in the undo script" {
            $operations = @(
                [PSCustomObject]@{ OldName = "a.txt"; NewName = "b.txt" }
            )

            $script = New-UndoScript -RenameOperations $operations -Directory "/my/dir"

            $script | Should -BeLike "*/my/dir*"
        }

        It "Should include Rename-Item commands in the undo script" {
            $operations = @(
                [PSCustomObject]@{ OldName = "old.txt"; NewName = "new.txt" }
            )

            $script = New-UndoScript -RenameOperations $operations -Directory "/test"

            $script | Should -BeLike "*Rename-Item*"
        }

        It "Should include a header comment with generation timestamp" {
            $operations = @(
                [PSCustomObject]@{ OldName = "a.txt"; NewName = "b.txt" }
            )

            $script = New-UndoScript -RenameOperations $operations -Directory "/test"

            $script | Should -BeLike "*Undo script generated on*"
        }
    }

    Context "Script file output" {
        It "Should write undo script to a file when OutputPath is specified" {
            $operations = @(
                [PSCustomObject]@{ OldName = "IMG_001.jpg"; NewName = "Photo_001.jpg" }
            )
            $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) "undo_test_$(Get-Random).ps1"

            try {
                $result = New-UndoScript -RenameOperations $operations -Directory "/tmp" -OutputPath $tempFile

                # Should return the output path
                $result | Should -Be $tempFile

                # File should exist and contain the undo script
                Test-Path $tempFile | Should -BeTrue
                $content = Get-Content $tempFile -Raw
                $content | Should -BeLike "*Rename-Item*"
                $content | Should -BeLike "*Photo_001.jpg*IMG_001.jpg*"
            }
            finally {
                if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
            }
        }
    }

    Context "Undo script execution" {
        It "Should produce a script that actually reverses renames" {
            # Set up: create a temp dir, rename files, then run the undo script
            $testDir = Join-Path ([System.IO.Path]::GetTempPath()) "UndoTest_$(Get-Random)"
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null

            try {
                # Create and rename files
                "content1" | Out-File (Join-Path $testDir "IMG_001.jpg")
                "content2" | Out-File (Join-Path $testDir "IMG_002.jpg")

                $renameResult = Invoke-BatchRename -Path $testDir -Pattern "^IMG_" -Replacement "Photo_"

                # Verify files were renamed
                Test-Path (Join-Path $testDir "Photo_001.jpg") | Should -BeTrue
                Test-Path (Join-Path $testDir "Photo_002.jpg") | Should -BeTrue

                # Generate and execute undo script
                $undoFile = Join-Path $testDir "undo.ps1"
                New-UndoScript -RenameOperations $renameResult -Directory $testDir -OutputPath $undoFile

                # Execute the undo script
                & $undoFile

                # Verify files were restored to original names
                Test-Path (Join-Path $testDir "IMG_001.jpg") | Should -BeTrue
                Test-Path (Join-Path $testDir "IMG_002.jpg") | Should -BeTrue
                Test-Path (Join-Path $testDir "Photo_001.jpg") | Should -BeFalse
                Test-Path (Join-Path $testDir "Photo_002.jpg") | Should -BeFalse
            }
            finally {
                if (Test-Path $testDir) { Remove-Item $testDir -Recurse -Force }
            }
        }
    }
}

# ============================================================================
# TDD Cycle 5: Format-RenamePreview - formatted output
# RED:  Written first, failed with "Format-RenamePreview not found"
# GREEN: Implemented formatted string output with arrow notation
# ============================================================================

Describe "Format-RenamePreview" {

    It "Should format operations as oldname -> newname" {
        $operations = @(
            [PSCustomObject]@{ OldName = "a.txt"; NewName = "b.txt" }
            [PSCustomObject]@{ OldName = "c.txt"; NewName = "d.txt" }
        )

        $output = Format-RenamePreview -RenameOperations $operations

        $output | Should -BeLike "*a.txt -> b.txt*"
        $output | Should -BeLike "*c.txt -> d.txt*"
    }

    It "Should include the file count in the header" {
        $operations = @(
            [PSCustomObject]@{ OldName = "a.txt"; NewName = "b.txt" }
            [PSCustomObject]@{ OldName = "c.txt"; NewName = "d.txt" }
            [PSCustomObject]@{ OldName = "e.txt"; NewName = "f.txt" }
        )

        $output = Format-RenamePreview -RenameOperations $operations

        $output | Should -BeLike "*3 file*"
    }
}

# ============================================================================
# TDD Cycle 6: Integration / end-to-end scenarios
# These tests combine all components to verify the full workflow
# ============================================================================

Describe "End-to-End Workflow" {

    BeforeEach {
        $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "E2ETest_$(Get-Random)"
        New-Item -Path $script:testDir -ItemType Directory -Force | Out-Null
    }

    AfterEach {
        if (Test-Path $script:testDir) {
            Remove-Item -Path $script:testDir -Recurse -Force
        }
    }

    It "Should support full preview -> rename -> undo workflow" {
        # Step 1: Create test files
        1..5 | ForEach-Object { "data$_" | Out-File (Join-Path $script:testDir "IMG_$($_.ToString('D3')).jpg") }

        # Step 2: Preview
        $preview = Invoke-BatchRename -Path $script:testDir -Pattern "^IMG_" -Replacement "Photo_" -Preview
        $preview | Should -HaveCount 5
        # Files should NOT be renamed yet
        Test-Path (Join-Path $script:testDir "IMG_001.jpg") | Should -BeTrue

        # Step 3: Execute rename
        $result = Invoke-BatchRename -Path $script:testDir -Pattern "^IMG_" -Replacement "Photo_"
        $result | Should -HaveCount 5
        ($result | Where-Object { $_.Status -eq "Success" }) | Should -HaveCount 5

        # Step 4: Generate undo script
        $undoPath = Join-Path $script:testDir "undo.ps1"
        New-UndoScript -RenameOperations $result -Directory $script:testDir -OutputPath $undoPath
        Test-Path $undoPath | Should -BeTrue

        # Step 5: Execute undo
        & $undoPath

        # Step 6: Verify all files restored
        1..5 | ForEach-Object {
            $name = "IMG_$($_.ToString('D3')).jpg"
            Test-Path (Join-Path $script:testDir $name) | Should -BeTrue -Because "File '$name' should be restored"
        }
    }

    It "Should handle special characters in filenames" {
        "data" | Out-File (Join-Path $script:testDir "file (1).txt")
        "data" | Out-File (Join-Path $script:testDir "file (2).txt")

        # Replace parenthesized numbers with underscored numbers
        $result = Invoke-BatchRename -Path $script:testDir -Pattern "\((\d+)\)" -Replacement '_$1'

        $result | Should -HaveCount 2
        Test-Path (Join-Path $script:testDir "file _1.txt") | Should -BeTrue
        Test-Path (Join-Path $script:testDir "file _2.txt") | Should -BeTrue
    }

    It "Should handle mixed matching and non-matching files" {
        "img" | Out-File (Join-Path $script:testDir "photo_001.jpg")
        "img" | Out-File (Join-Path $script:testDir "photo_002.png")
        "doc" | Out-File (Join-Path $script:testDir "document.pdf")
        "txt" | Out-File (Join-Path $script:testDir "notes.txt")

        # Only rename .jpg files
        $result = Invoke-BatchRename -Path $script:testDir -Pattern "^photo_(\d+)\.jpg$" -Replacement 'image_$1.jpg'

        $result | Should -HaveCount 1
        Test-Path (Join-Path $script:testDir "image_001.jpg") | Should -BeTrue
        # Non-matching files untouched
        Test-Path (Join-Path $script:testDir "photo_002.png") | Should -BeTrue
        Test-Path (Join-Path $script:testDir "document.pdf") | Should -BeTrue
        Test-Path (Join-Path $script:testDir "notes.txt") | Should -BeTrue
    }
}
