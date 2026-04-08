# FileRenamer.Tests.ps1
# TDD tests for the Batch File Renamer module using Pester 5.x
# Red/Green approach: write failing test, implement minimum code, refactor, repeat

# Import the module under test — fails gracefully if not yet created
$modulePath = Join-Path $PSScriptRoot 'FileRenamer.psm1'
if (Test-Path $modulePath) {
    Import-Module $modulePath -Force
}

BeforeAll {
    # Helper: create a mock file system in a temp directory
    function New-MockFileSystem {
        [CmdletBinding()]
        [OutputType([string])]
        param(
            [string[]]$FileNames
        )
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("MockFS_" + [System.Guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $tempDir
        foreach ($name in $FileNames) {
            $null = New-Item -ItemType File -Path (Join-Path $tempDir $name)
        }
        return $tempDir
    }
}

Describe 'Get-RenamePreview' {
    BeforeAll {
        # Create a mock directory with sample files
        $script:mockDir = New-MockFileSystem -FileNames @(
            'photo_001.jpg',
            'photo_002.jpg',
            'photo_003.jpg',
            'document.txt',
            'notes.txt'
        )
    }

    AfterAll {
        if (Test-Path $script:mockDir) {
            Remove-Item -Path $script:mockDir -Recurse -Force
        }
    }

    It 'returns a list of rename operations for matching files' {
        # RED: This test should fail until Get-RenamePreview is implemented
        $result = Get-RenamePreview -Directory $script:mockDir -Pattern 'photo_(\d+)\.jpg' -Replacement 'image_$1.jpg'
        $result | Should -HaveCount 3
    }

    It 'returns objects with OldName and NewName properties' {
        $result = Get-RenamePreview -Directory $script:mockDir -Pattern 'photo_(\d+)\.jpg' -Replacement 'image_$1.jpg'
        $result[0].OldName | Should -Not -BeNullOrEmpty
        $result[0].NewName | Should -Not -BeNullOrEmpty
    }

    It 'correctly maps old names to new names using regex replacement' {
        $result = Get-RenamePreview -Directory $script:mockDir -Pattern 'photo_(\d+)\.jpg' -Replacement 'image_$1.jpg'
        $sortedResult = $result | Sort-Object OldName
        $sortedResult[0].OldName | Should -Be 'photo_001.jpg'
        $sortedResult[0].NewName | Should -Be 'image_001.jpg'
        $sortedResult[1].OldName | Should -Be 'photo_002.jpg'
        $sortedResult[1].NewName | Should -Be 'image_002.jpg'
    }

    It 'does not include non-matching files in the result' {
        $result = Get-RenamePreview -Directory $script:mockDir -Pattern 'photo_(\d+)\.jpg' -Replacement 'image_$1.jpg'
        $oldNames = $result | Select-Object -ExpandProperty OldName
        $oldNames | Should -Not -Contain 'document.txt'
        $oldNames | Should -Not -Contain 'notes.txt'
    }

    It 'returns full paths in OldPath and NewPath properties' {
        $result = Get-RenamePreview -Directory $script:mockDir -Pattern 'photo_(\d+)\.jpg' -Replacement 'image_$1.jpg'
        $result[0].OldPath | Should -Not -BeNullOrEmpty
        $result[0].NewPath | Should -Not -BeNullOrEmpty
        $result[0].OldPath | Should -BeLike '*photo_*'
        $result[0].NewPath | Should -BeLike '*image_*'
    }

    It 'throws when directory does not exist' {
        { Get-RenamePreview -Directory '/does/not/exist/anywhere' -Pattern 'foo' -Replacement 'bar' } | Should -Throw
    }
}

Describe 'Invoke-FileRename' {
    BeforeEach {
        $script:mockDir = New-MockFileSystem -FileNames @(
            'report_2023.txt',
            'report_2024.txt',
            'readme.md'
        )
    }

    AfterEach {
        if (Test-Path $script:mockDir) {
            Remove-Item -Path $script:mockDir -Recurse -Force
        }
    }

    It 'renames files matching the pattern' {
        Invoke-FileRename -Directory $script:mockDir -Pattern 'report_(\d{4})\.txt' -Replacement 'archive_$1.txt'
        Test-Path (Join-Path $script:mockDir 'archive_2023.txt') | Should -BeTrue
        Test-Path (Join-Path $script:mockDir 'archive_2024.txt') | Should -BeTrue
    }

    It 'does not rename non-matching files' {
        Invoke-FileRename -Directory $script:mockDir -Pattern 'report_(\d{4})\.txt' -Replacement 'archive_$1.txt'
        Test-Path (Join-Path $script:mockDir 'readme.md') | Should -BeTrue
    }

    It 'removes original files after rename' {
        Invoke-FileRename -Directory $script:mockDir -Pattern 'report_(\d{4})\.txt' -Replacement 'archive_$1.txt'
        Test-Path (Join-Path $script:mockDir 'report_2023.txt') | Should -BeFalse
        Test-Path (Join-Path $script:mockDir 'report_2024.txt') | Should -BeFalse
    }

    It 'returns rename operation results' {
        $result = Invoke-FileRename -Directory $script:mockDir -Pattern 'report_(\d{4})\.txt' -Replacement 'archive_$1.txt'
        $result | Should -HaveCount 2
        $result[0].Success | Should -BeTrue
    }

    It 'throws when directory does not exist' {
        { Invoke-FileRename -Directory '/does/not/exist' -Pattern 'foo' -Replacement 'bar' } | Should -Throw
    }
}

Describe 'Get-ConflictDetection' {
    BeforeAll {
        $script:mockDir = New-MockFileSystem -FileNames @(
            'file_a.txt',
            'file_b.txt',
            'file_c.txt'
        )
    }

    AfterAll {
        if (Test-Path $script:mockDir) {
            Remove-Item -Path $script:mockDir -Recurse -Force
        }
    }

    It 'detects no conflicts when all new names are unique' {
        $result = Get-ConflictDetection -Directory $script:mockDir -Pattern 'file_(\w)\.txt' -Replacement 'doc_$1.txt'
        $result.HasConflicts | Should -BeFalse
        $result.Conflicts | Should -HaveCount 0
    }

    It 'detects conflicts when pattern maps multiple files to the same name' {
        # All file_*.txt files would become 'same_name.txt'
        $result = Get-ConflictDetection -Directory $script:mockDir -Pattern 'file_\w\.txt' -Replacement 'same_name.txt'
        $result.HasConflicts | Should -BeTrue
        $result.Conflicts.Count | Should -BeGreaterThan 0
    }

    It 'returns conflict details including the conflicting new name' {
        $result = Get-ConflictDetection -Directory $script:mockDir -Pattern 'file_\w\.txt' -Replacement 'same_name.txt'
        $result.Conflicts[0].NewName | Should -Be 'same_name.txt'
        $result.Conflicts[0].SourceFiles.Count | Should -BeGreaterThan 1
    }

    It 'detects conflict when new name matches an existing non-renamed file' {
        # file_a.txt would be renamed to file_b.txt, which already exists
        $result = Get-ConflictDetection -Directory $script:mockDir -Pattern 'file_a\.txt' -Replacement 'file_b.txt'
        $result.HasConflicts | Should -BeTrue
    }
}

Describe 'New-UndoScript' {
    BeforeEach {
        $script:mockDir = New-MockFileSystem -FileNames @(
            'img_001.png',
            'img_002.png'
        )
        $script:undoScriptPath = Join-Path $script:mockDir 'undo_rename.ps1'
    }

    AfterEach {
        if (Test-Path $script:mockDir) {
            Remove-Item -Path $script:mockDir -Recurse -Force
        }
    }

    It 'generates an undo script file' {
        $preview = Get-RenamePreview -Directory $script:mockDir -Pattern 'img_(\d+)\.png' -Replacement 'photo_$1.png'
        New-UndoScript -RenameOperations $preview -OutputPath $script:undoScriptPath
        Test-Path $script:undoScriptPath | Should -BeTrue
    }

    It 'undo script contains rename commands to reverse the operations' {
        $preview = Get-RenamePreview -Directory $script:mockDir -Pattern 'img_(\d+)\.png' -Replacement 'photo_$1.png'
        New-UndoScript -RenameOperations $preview -OutputPath $script:undoScriptPath
        $content = Get-Content $script:undoScriptPath -Raw
        # Undo script should rename from NewPath back to OldPath
        $content | Should -Match 'photo_001\.png'
        $content | Should -Match 'img_001\.png'
    }

    It 'generated undo script is valid PowerShell' {
        $preview = Get-RenamePreview -Directory $script:mockDir -Pattern 'img_(\d+)\.png' -Replacement 'photo_$1.png'
        New-UndoScript -RenameOperations $preview -OutputPath $script:undoScriptPath
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($script:undoScriptPath, [ref]$null, [ref]$errors)
        $errors | Should -HaveCount 0
    }

    It 'undo script actually reverses the renames when executed' {
        # First perform the rename
        Invoke-FileRename -Directory $script:mockDir -Pattern 'img_(\d+)\.png' -Replacement 'photo_$1.png'
        # Build preview manually (original files are gone now, so we supply operations directly)
        [array]$ops = @(
            [PSCustomObject]@{
                OldName = 'img_001.png'
                NewName = 'photo_001.png'
                OldPath = Join-Path $script:mockDir 'img_001.png'
                NewPath = Join-Path $script:mockDir 'photo_001.png'
            },
            [PSCustomObject]@{
                OldName = 'img_002.png'
                NewName = 'photo_002.png'
                OldPath = Join-Path $script:mockDir 'img_002.png'
                NewPath = Join-Path $script:mockDir 'photo_002.png'
            }
        )
        New-UndoScript -RenameOperations $ops -OutputPath $script:undoScriptPath
        # Run the undo script
        & pwsh -NonInteractive -File $script:undoScriptPath
        # Verify original names are restored
        Test-Path (Join-Path $script:mockDir 'img_001.png') | Should -BeTrue
        Test-Path (Join-Path $script:mockDir 'img_002.png') | Should -BeTrue
        Test-Path (Join-Path $script:mockDir 'photo_001.png') | Should -BeFalse
        Test-Path (Join-Path $script:mockDir 'photo_002.png') | Should -BeFalse
    }

    It 'throws when RenameOperations is empty' {
        [array]$emptyOps = @()
        { New-UndoScript -RenameOperations $emptyOps -OutputPath $script:undoScriptPath } | Should -Throw
    }
}

Describe 'Full Integration: Preview, Conflict Check, Rename, and Undo' {
    BeforeEach {
        $script:mockDir = New-MockFileSystem -FileNames @(
            'sales_jan.csv',
            'sales_feb.csv',
            'sales_mar.csv',
            'readme.txt'
        )
    }

    AfterEach {
        if (Test-Path $script:mockDir) {
            Remove-Item -Path $script:mockDir -Recurse -Force
        }
    }

    It 'complete workflow: preview, no-conflict, rename, undo restores original state' {
        # Step 1: Preview
        $preview = Get-RenamePreview -Directory $script:mockDir -Pattern 'sales_(\w+)\.csv' -Replacement 'report_$1.csv'
        $preview | Should -HaveCount 3

        # Step 2: Conflict check
        $conflicts = Get-ConflictDetection -Directory $script:mockDir -Pattern 'sales_(\w+)\.csv' -Replacement 'report_$1.csv'
        $conflicts.HasConflicts | Should -BeFalse

        # Step 3: Generate undo script before rename
        $undoPath = Join-Path $script:mockDir 'undo.ps1'
        New-UndoScript -RenameOperations $preview -OutputPath $undoPath

        # Step 4: Perform rename
        Invoke-FileRename -Directory $script:mockDir -Pattern 'sales_(\w+)\.csv' -Replacement 'report_$1.csv'
        Test-Path (Join-Path $script:mockDir 'report_jan.csv') | Should -BeTrue
        Test-Path (Join-Path $script:mockDir 'sales_jan.csv') | Should -BeFalse

        # Step 5: Run undo script
        & pwsh -NonInteractive -File $undoPath
        Test-Path (Join-Path $script:mockDir 'sales_jan.csv') | Should -BeTrue
        Test-Path (Join-Path $script:mockDir 'report_jan.csv') | Should -BeFalse
    }

    It 'blocks rename when conflicts are detected' {
        # Pattern maps all CSV files to same name — Invoke-FileRename should throw
        { Invoke-FileRename -Directory $script:mockDir -Pattern 'sales_\w+\.csv' -Replacement 'data.csv' } | Should -Throw
    }
}
