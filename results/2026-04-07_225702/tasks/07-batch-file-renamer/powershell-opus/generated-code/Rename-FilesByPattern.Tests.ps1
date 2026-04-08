BeforeAll {
    . "$PSScriptRoot/Rename-FilesByPattern.ps1"
}

Describe "Rename-FilesByPattern" {

    # Create a temp directory with mock files for each test
    BeforeEach {
        $script:TestDir = Join-Path ([System.IO.Path]::GetTempPath()) "renamer-tests-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:TestDir | Out-Null
    }

    AfterEach {
        if (Test-Path $script:TestDir) {
            Remove-Item -Recurse -Force $script:TestDir
        }
    }

    Context "Preview mode" {

        It "Should show proposed renames without changing files" {
            # Arrange: create mock files
            "content" | Set-Content (Join-Path $script:TestDir "report_2024.txt")
            "content" | Set-Content (Join-Path $script:TestDir "report_2025.txt")
            "content" | Set-Content (Join-Path $script:TestDir "notes.txt")

            # Act: preview rename replacing 'report' with 'summary'
            $results = Rename-FilesByPattern -Path $script:TestDir `
                -Pattern 'report' -Replacement 'summary' -Preview

            # Assert: results describe what would change
            $results | Should -HaveCount 2
            $results[0].OldName | Should -Be "report_2024.txt"
            $results[0].NewName | Should -Be "summary_2024.txt"
            $results[1].OldName | Should -Be "report_2025.txt"
            $results[1].NewName | Should -Be "summary_2025.txt"

            # Files should NOT have been renamed
            (Test-Path (Join-Path $script:TestDir "report_2024.txt")) | Should -BeTrue
            (Test-Path (Join-Path $script:TestDir "summary_2024.txt")) | Should -BeFalse
        }
    }

    Context "Actual rename execution" {

        It "Should rename matching files on disk" {
            # Arrange
            "data" | Set-Content (Join-Path $script:TestDir "IMG_001.jpg")
            "data" | Set-Content (Join-Path $script:TestDir "IMG_002.jpg")

            # Act
            $results = Rename-FilesByPattern -Path $script:TestDir `
                -Pattern '^IMG_' -Replacement 'Photo_'

            # Assert: files were actually renamed
            $results | Should -HaveCount 2
            (Test-Path (Join-Path $script:TestDir "Photo_001.jpg")) | Should -BeTrue
            (Test-Path (Join-Path $script:TestDir "Photo_002.jpg")) | Should -BeTrue
            (Test-Path (Join-Path $script:TestDir "IMG_001.jpg")) | Should -BeFalse
        }

        It "Should support regex capture groups in replacement" {
            # Arrange: files with date-like names
            "data" | Set-Content (Join-Path $script:TestDir "2024-01-15_report.txt")
            "data" | Set-Content (Join-Path $script:TestDir "2024-02-20_report.txt")

            # Act: rearrange date parts using capture groups
            $results = Rename-FilesByPattern -Path $script:TestDir `
                -Pattern '(\d{4})-(\d{2})-(\d{2})_(.+)' -Replacement '$4_$1$2$3'

            # Assert
            (Test-Path (Join-Path $script:TestDir "report.txt_20240115")) | Should -BeTrue
            (Test-Path (Join-Path $script:TestDir "report.txt_20240220")) | Should -BeTrue
        }

        It "Should skip files that do not match the pattern" {
            # Arrange
            "data" | Set-Content (Join-Path $script:TestDir "match_me.txt")
            "data" | Set-Content (Join-Path $script:TestDir "leave_me.log")

            # Act
            $results = Rename-FilesByPattern -Path $script:TestDir `
                -Pattern '\.txt$' -Replacement '.md'

            # Assert: only the .txt file changed
            $results | Should -HaveCount 1
            (Test-Path (Join-Path $script:TestDir "match_me.md")) | Should -BeTrue
            (Test-Path (Join-Path $script:TestDir "leave_me.log")) | Should -BeTrue
        }
    }

    Context "Conflict detection" {

        It "Should throw when two files would get the same new name" {
            # Arrange: two files whose distinguishing part gets stripped
            "data" | Set-Content (Join-Path $script:TestDir "file_a_backup.txt")
            "data" | Set-Content (Join-Path $script:TestDir "file_b_backup.txt")

            # Act/Assert: replacing 'file_[ab]' with 'file' makes both 'file_backup.txt'
            { Rename-FilesByPattern -Path $script:TestDir `
                -Pattern 'file_[ab]' -Replacement 'file' } |
                Should -Throw "*Conflict*"
        }

        It "Should throw when rename would overwrite an existing non-matched file" {
            # Arrange: 'old.txt' will be renamed to 'existing.txt' which already exists
            "data" | Set-Content (Join-Path $script:TestDir "old.txt")
            "other" | Set-Content (Join-Path $script:TestDir "existing.txt")

            # Act/Assert
            { Rename-FilesByPattern -Path $script:TestDir `
                -Pattern '^old' -Replacement 'existing' } |
                Should -Throw "*Conflict*"
        }

        It "Should NOT throw when no conflicts exist" {
            "data" | Set-Content (Join-Path $script:TestDir "alpha.txt")
            "data" | Set-Content (Join-Path $script:TestDir "beta.txt")

            # These rename to unique names, no conflict
            { Rename-FilesByPattern -Path $script:TestDir `
                -Pattern '(alpha|beta)' -Replacement 'renamed_$1' } |
                Should -Not -Throw
        }
    }

    Context "Undo script generation" {

        It "Should generate an undo script that reverses renames" {
            # Arrange
            "data" | Set-Content (Join-Path $script:TestDir "old_a.txt")
            "data" | Set-Content (Join-Path $script:TestDir "old_b.txt")
            $undoPath = Join-Path $script:TestDir "undo.ps1"

            # Act: rename and generate undo script
            Rename-FilesByPattern -Path $script:TestDir `
                -Pattern '^old_' -Replacement 'new_' -UndoScriptPath $undoPath

            # Assert: undo script was created
            (Test-Path $undoPath) | Should -BeTrue

            # Files should now be renamed
            (Test-Path (Join-Path $script:TestDir "new_a.txt")) | Should -BeTrue
            (Test-Path (Join-Path $script:TestDir "new_b.txt")) | Should -BeTrue

            # Run the undo script to reverse the renames
            & $undoPath

            # Assert: original names are restored
            (Test-Path (Join-Path $script:TestDir "old_a.txt")) | Should -BeTrue
            (Test-Path (Join-Path $script:TestDir "old_b.txt")) | Should -BeTrue
            (Test-Path (Join-Path $script:TestDir "new_a.txt")) | Should -BeFalse
            (Test-Path (Join-Path $script:TestDir "new_b.txt")) | Should -BeFalse
        }

        It "Should include a comment header in the undo script" {
            "data" | Set-Content (Join-Path $script:TestDir "x.txt")
            $undoPath = Join-Path $script:TestDir "undo.ps1"

            Rename-FilesByPattern -Path $script:TestDir `
                -Pattern 'x' -Replacement 'y' -UndoScriptPath $undoPath

            $content = Get-Content $undoPath -Raw
            $content | Should -Match '# Undo script'
        }
    }

    Context "Error handling" {

        It "Should throw when directory does not exist" {
            { Rename-FilesByPattern -Path "/nonexistent/path" `
                -Pattern 'x' -Replacement 'y' } |
                Should -Throw "*Directory not found*"
        }

        It "Should return empty results when no files match the pattern" {
            "data" | Set-Content (Join-Path $script:TestDir "hello.txt")

            $results = Rename-FilesByPattern -Path $script:TestDir `
                -Pattern 'zzz_no_match' -Replacement 'new'

            $results | Should -HaveCount 0
        }
    }

    Context "Preview mode does not check conflicts" {

        It "Should still return results in preview even with conflicts" {
            # Preview mode is informational — it shows what would happen,
            # letting the user spot conflicts themselves before committing.
            "data" | Set-Content (Join-Path $script:TestDir "file_a.txt")
            "data" | Set-Content (Join-Path $script:TestDir "file_b.txt")

            $results = Rename-FilesByPattern -Path $script:TestDir `
                -Pattern 'file_[ab]' -Replacement 'file' -Preview

            # Both proposed renames are returned so the user can see the conflict
            $results | Should -HaveCount 2
            $results[0].NewName | Should -Be "file.txt"
            $results[1].NewName | Should -Be "file.txt"
        }
    }

    Context "Large mock file system" {

        It "Should handle bulk renames across many files" {
            # Arrange: create 20 mock log files
            1..20 | ForEach-Object {
                $name = "app_{0:D3}.log" -f $_
                "log data $_" | Set-Content (Join-Path $script:TestDir $name)
            }

            # Act: rename prefix from 'app_' to 'service_'
            $results = Rename-FilesByPattern -Path $script:TestDir `
                -Pattern '^app_' -Replacement 'service_'

            # Assert
            $results | Should -HaveCount 20
            1..20 | ForEach-Object {
                $expected = "service_{0:D3}.log" -f $_
                (Test-Path (Join-Path $script:TestDir $expected)) | Should -BeTrue
            }
        }
    }

    Context "Undo with capture groups" {

        It "Should correctly undo renames that used capture groups" {
            # Arrange
            "data" | Set-Content (Join-Path $script:TestDir "photo_vacation_01.jpg")
            "data" | Set-Content (Join-Path $script:TestDir "photo_birthday_02.jpg")
            $undoPath = Join-Path $script:TestDir "undo.ps1"

            # Act: rename using capture groups
            Rename-FilesByPattern -Path $script:TestDir `
                -Pattern 'photo_(\w+)_(\d+)\.jpg' `
                -Replacement '$1-$2.jpg' `
                -UndoScriptPath $undoPath

            # Verify renames happened
            (Test-Path (Join-Path $script:TestDir "birthday-02.jpg")) | Should -BeTrue
            (Test-Path (Join-Path $script:TestDir "vacation-01.jpg")) | Should -BeTrue

            # Undo
            & $undoPath

            # Verify originals are restored
            (Test-Path (Join-Path $script:TestDir "photo_vacation_01.jpg")) | Should -BeTrue
            (Test-Path (Join-Path $script:TestDir "photo_birthday_02.jpg")) | Should -BeTrue
        }
    }
}
