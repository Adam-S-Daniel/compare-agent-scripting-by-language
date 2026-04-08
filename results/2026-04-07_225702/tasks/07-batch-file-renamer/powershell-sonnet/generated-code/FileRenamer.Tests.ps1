# FileRenamer.Tests.ps1
# TDD test suite for the batch file renamer using Pester.
# Tests are written BEFORE the implementation to drive design.

BeforeAll {
    # Import the module under test
    . "$PSScriptRoot/FileRenamer.ps1"
}

Describe "Get-RenamePreview" {
    BeforeAll {
        # Create a temporary directory with mock files for each test context
        $script:TestDir = Join-Path ([System.IO.Path]::GetTempPath()) "FileRenamerTests_$(Get-Random)"
        New-Item -ItemType Directory -Path $script:TestDir | Out-Null
    }

    AfterAll {
        Remove-Item -Recurse -Force $script:TestDir -ErrorAction SilentlyContinue
    }

    Context "Basic regex renaming" {
        BeforeEach {
            # Set up mock files
            $script:Files = @("report_2024.txt", "report_2025.txt", "notes.txt") | ForEach-Object {
                $path = Join-Path $script:TestDir $_
                New-Item -ItemType File -Path $path -Force | Out-Null
                $path
            }
        }

        AfterEach {
            Get-ChildItem $script:TestDir | Remove-Item -Force
        }

        It "returns rename pairs for files matching the pattern" {
            $result = Get-RenamePreview -Directory $script:TestDir -Pattern "report_(\d+)" -Replacement "summary_`$1"
            $result | Should -HaveCount 2
        }

        It "maps old name to correct new name" {
            $result = Get-RenamePreview -Directory $script:TestDir -Pattern "report_(\d+)" -Replacement "summary_`$1"
            $item = $result | Where-Object { $_.OldName -eq "report_2024.txt" }
            $item | Should -Not -BeNullOrEmpty
            $item.NewName | Should -Be "summary_2024.txt"
        }

        It "excludes files that do not match the pattern" {
            $result = Get-RenamePreview -Directory $script:TestDir -Pattern "report_(\d+)" -Replacement "summary_`$1"
            $result.OldName | Should -Not -Contain "notes.txt"
        }
    }

    Context "Conflict detection" {
        BeforeEach {
            # Two files that would both rename to the same target
            @("file_a.txt", "file_b.txt") | ForEach-Object {
                New-Item -ItemType File -Path (Join-Path $script:TestDir $_) -Force | Out-Null
            }
        }

        AfterEach {
            Get-ChildItem $script:TestDir | Remove-Item -Force
        }

        It "flags conflicts when two files would get the same new name" {
            # Both match "file_\w" and replacement ignores the letter -> conflict
            $result = Get-RenamePreview -Directory $script:TestDir -Pattern "file_\w" -Replacement "file_x"
            $conflicts = $result | Where-Object { $_.HasConflict }
            $conflicts | Should -HaveCount 2
        }

        It "flags conflict when new name collides with an existing file not being renamed" {
            # Create a file that already has the target name
            New-Item -ItemType File -Path (Join-Path $script:TestDir "target.txt") -Force | Out-Null
            # Rename file_a -> target
            $result = Get-RenamePreview -Directory $script:TestDir -Pattern "file_a" -Replacement "target"
            $item = $result | Where-Object { $_.OldName -eq "file_a.txt" }
            $item.HasConflict | Should -Be $true
        }
    }
}

Describe "Invoke-BatchRename" {
    BeforeAll {
        $script:TestDir = Join-Path ([System.IO.Path]::GetTempPath()) "FileRenamerInvokeTests_$(Get-Random)"
        New-Item -ItemType Directory -Path $script:TestDir | Out-Null
    }

    AfterAll {
        Remove-Item -Recurse -Force $script:TestDir -ErrorAction SilentlyContinue
    }

    BeforeEach {
        Get-ChildItem $script:TestDir | Remove-Item -Force
        @("photo_001.jpg", "photo_002.jpg", "readme.txt") | ForEach-Object {
            New-Item -ItemType File -Path (Join-Path $script:TestDir $_) -Force | Out-Null
        }
    }

    It "actually renames files on disk when not in preview mode" {
        Invoke-BatchRename -Directory $script:TestDir -Pattern "photo_(\d+)" -Replacement "image_`$1"
        (Test-Path (Join-Path $script:TestDir "image_001.jpg")) | Should -Be $true
        (Test-Path (Join-Path $script:TestDir "image_002.jpg")) | Should -Be $true
        (Test-Path (Join-Path $script:TestDir "photo_001.jpg")) | Should -Be $false
    }

    It "does NOT rename files when -WhatIf is specified" {
        Invoke-BatchRename -Directory $script:TestDir -Pattern "photo_(\d+)" -Replacement "image_`$1" -WhatIf
        (Test-Path (Join-Path $script:TestDir "photo_001.jpg")) | Should -Be $true
        (Test-Path (Join-Path $script:TestDir "image_001.jpg")) | Should -Be $false
    }

    It "does not rename files that would cause conflicts" {
        # Both would map to same.jpg -> neither should be renamed
        Get-ChildItem $script:TestDir | Remove-Item -Force
        @("alpha.jpg", "beta.jpg") | ForEach-Object {
            New-Item -ItemType File -Path (Join-Path $script:TestDir $_) -Force | Out-Null
        }
        Invoke-BatchRename -Directory $script:TestDir -Pattern "\w+\.jpg" -Replacement "same.jpg"
        (Test-Path (Join-Path $script:TestDir "alpha.jpg")) | Should -Be $true
        (Test-Path (Join-Path $script:TestDir "beta.jpg")) | Should -Be $true
    }

    It "returns a result object for each processed file" {
        $results = Invoke-BatchRename -Directory $script:TestDir -Pattern "photo_(\d+)" -Replacement "image_`$1"
        $results | Should -HaveCount 2
        $results[0].Success | Should -Be $true
    }
}

Describe "New-UndoScript" {
    BeforeAll {
        $script:TestDir = Join-Path ([System.IO.Path]::GetTempPath()) "FileRenamerUndoTests_$(Get-Random)"
        New-Item -ItemType Directory -Path $script:TestDir | Out-Null
    }

    AfterAll {
        Remove-Item -Recurse -Force $script:TestDir -ErrorAction SilentlyContinue
    }

    It "generates a PowerShell undo script that reverses the renames" {
        $renamePairs = @(
            [PSCustomObject]@{ OldName = "photo_001.jpg"; NewName = "image_001.jpg"; HasConflict = $false }
            [PSCustomObject]@{ OldName = "photo_002.jpg"; NewName = "image_002.jpg"; HasConflict = $false }
        )
        $undoPath = Join-Path $script:TestDir "undo.ps1"
        New-UndoScript -RenamePairs $renamePairs -Directory $script:TestDir -OutputPath $undoPath

        $undoPath | Should -Exist
        $content = Get-Content $undoPath -Raw
        # Undo should rename new->old
        $content | Should -Match "image_001\.jpg"
        $content | Should -Match "photo_001\.jpg"
        $content | Should -Match "image_002\.jpg"
        $content | Should -Match "photo_002\.jpg"
    }

    It "executing the undo script reverses actual renames" {
        # Create files, rename them, generate undo, execute undo, verify originals are back
        $dir = Join-Path $script:TestDir "live_test"
        New-Item -ItemType Directory -Path $dir | Out-Null

        @("doc_1.txt", "doc_2.txt") | ForEach-Object {
            New-Item -ItemType File -Path (Join-Path $dir $_) -Force | Out-Null
        }

        $results = Invoke-BatchRename -Directory $dir -Pattern "doc_(\d+)" -Replacement "file_`$1" -GenerateUndo -UndoPath (Join-Path $dir "undo.ps1")

        # Files should be renamed now
        (Test-Path (Join-Path $dir "file_1.txt")) | Should -Be $true

        # Execute the undo script
        & (Join-Path $dir "undo.ps1")

        # Files should be back to original names
        (Test-Path (Join-Path $dir "doc_1.txt")) | Should -Be $true
        (Test-Path (Join-Path $dir "file_1.txt")) | Should -Be $false

        Remove-Item -Recurse -Force $dir
    }
}
