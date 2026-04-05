#Requires -Modules Pester
Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# TDD Approach:
# We write failing tests first, then implement the minimum code to pass them.
# Each test group corresponds to a feature area.

BeforeAll {
    # Import the module under test
    $modulePath = Join-Path $PSScriptRoot 'BatchFileRenamer.psm1'
    Import-Module $modulePath -Force
}

# ===========================================================================
# RED TEST 1: Get-RenamePreview - basic regex rename preview
# This is the first failing test. The module doesn't exist yet.
# ===========================================================================
Describe 'Get-RenamePreview' {

    Context 'Basic regex replacement' {
        It 'returns a list of rename operations for matching files' {
            # Arrange: mock files list (no real filesystem needed)
            [string[]]$files = @('report_2023.txt', 'report_2024.txt', 'notes.md')
            [string]$pattern = '^report_(\d{4})\.txt$'
            [string]$replacement = 'summary_$1.txt'

            # Act
            [object[]]$result = Get-RenamePreview -Files $files -Pattern $pattern -Replacement $replacement

            # Assert
            $result | Should -HaveCount 2
            $result[0].OldName | Should -Be 'report_2023.txt'
            $result[0].NewName | Should -Be 'summary_2023.txt'
            $result[1].OldName | Should -Be 'report_2024.txt'
            $result[1].NewName | Should -Be 'summary_2024.txt'
        }

        It 'returns empty array when no files match the pattern' {
            [string[]]$files = @('notes.md', 'readme.txt')
            [string]$pattern = '^invoice_\d+\.pdf$'
            [string]$replacement = 'bill_$0.pdf'

            [object[]]$result = Get-RenamePreview -Files $files -Pattern $pattern -Replacement $replacement

            $result | Should -HaveCount 0
        }

        It 'handles capture groups in replacement' {
            [string[]]$files = @('IMG_001.jpg', 'IMG_002.jpg')
            [string]$pattern = 'IMG_(\d+)\.jpg'
            [string]$replacement = 'photo_$1.jpg'

            [object[]]$result = Get-RenamePreview -Files $files -Pattern $pattern -Replacement $replacement

            $result[0].NewName | Should -Be 'photo_001.jpg'
            $result[1].NewName | Should -Be 'photo_002.jpg'
        }

        It 'skips files where old name equals new name' {
            # If the regex doesn't change the name, skip it
            [string[]]$files = @('photo_001.jpg')
            [string]$pattern = 'photo_(\d+)\.jpg'
            [string]$replacement = 'photo_$1.jpg'

            [object[]]$result = Get-RenamePreview -Files $files -Pattern $pattern -Replacement $replacement

            $result | Should -HaveCount 0
        }
    }

    Context 'Preview result properties' {
        It 'each result has OldName, NewName, and Changed properties' {
            [string[]]$files = @('file_01.txt')
            [string]$pattern = 'file_(\d+)\.txt'
            [string]$replacement = 'document_$1.txt'

            [object[]]$result = Get-RenamePreview -Files $files -Pattern $pattern -Replacement $replacement

            $result[0].PSObject.Properties.Name | Should -Contain 'OldName'
            $result[0].PSObject.Properties.Name | Should -Contain 'NewName'
            $result[0].PSObject.Properties.Name | Should -Contain 'WillChange'
        }
    }
}

# ===========================================================================
# RED TEST 2: Find-RenameConflicts - detect naming conflicts
# ===========================================================================
Describe 'Find-RenameConflicts' {

    It 'detects when two files would rename to the same name' {
        # Two files that would both become 'output.txt'
        [object[]]$operations = @(
            [PSCustomObject]@{ OldName = 'file_a.txt'; NewName = 'output.txt'; WillChange = $true }
            [PSCustomObject]@{ OldName = 'file_b.txt'; NewName = 'output.txt'; WillChange = $true }
            [PSCustomObject]@{ OldName = 'file_c.txt'; NewName = 'unique.txt'; WillChange = $true }
        )

        [object[]]$conflicts = Find-RenameConflicts -Operations $operations

        $conflicts | Should -HaveCount 1
        $conflicts[0].ConflictingName | Should -Be 'output.txt'
        $conflicts[0].SourceFiles | Should -HaveCount 2
        $conflicts[0].SourceFiles | Should -Contain 'file_a.txt'
        $conflicts[0].SourceFiles | Should -Contain 'file_b.txt'
    }

    It 'returns empty array when no conflicts exist' {
        [object[]]$operations = @(
            [PSCustomObject]@{ OldName = 'file_a.txt'; NewName = 'output_a.txt'; WillChange = $true }
            [PSCustomObject]@{ OldName = 'file_b.txt'; NewName = 'output_b.txt'; WillChange = $true }
        )

        [object[]]$conflicts = Find-RenameConflicts -Operations $operations

        $conflicts | Should -HaveCount 0
    }

    It 'detects multiple distinct conflicts' {
        [object[]]$operations = @(
            [PSCustomObject]@{ OldName = 'a1.txt'; NewName = 'same.txt'; WillChange = $true }
            [PSCustomObject]@{ OldName = 'a2.txt'; NewName = 'same.txt'; WillChange = $true }
            [PSCustomObject]@{ OldName = 'b1.txt'; NewName = 'other.txt'; WillChange = $true }
            [PSCustomObject]@{ OldName = 'b2.txt'; NewName = 'other.txt'; WillChange = $true }
        )

        [object[]]$conflicts = Find-RenameConflicts -Operations $operations

        $conflicts | Should -HaveCount 2
    }
}

# ===========================================================================
# RED TEST 3: Invoke-BatchRename - perform actual renames on filesystem
# ===========================================================================
Describe 'Invoke-BatchRename' {

    BeforeEach {
        # Create a temporary directory with mock files
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "BatchRenameTest_$(New-Guid)"
        New-Item -Path $script:tempDir -ItemType Directory | Out-Null
        'content1' | Set-Content -Path (Join-Path $script:tempDir 'report_2023.txt')
        'content2' | Set-Content -Path (Join-Path $script:tempDir 'report_2024.txt')
        'content3' | Set-Content -Path (Join-Path $script:tempDir 'notes.md')
    }

    AfterEach {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'renames files matching the pattern in the directory' {
        [string]$pattern = '^report_(\d{4})\.txt$'
        [string]$replacement = 'summary_$1.txt'

        Invoke-BatchRename -Directory $script:tempDir -Pattern $pattern -Replacement $replacement

        Test-Path (Join-Path $script:tempDir 'summary_2023.txt') | Should -Be $true
        Test-Path (Join-Path $script:tempDir 'summary_2024.txt') | Should -Be $true
        Test-Path (Join-Path $script:tempDir 'report_2023.txt') | Should -Be $false
        Test-Path (Join-Path $script:tempDir 'report_2024.txt') | Should -Be $false
        # Non-matching file should remain untouched
        Test-Path (Join-Path $script:tempDir 'notes.md') | Should -Be $true
    }

    It 'does not rename files when WhatIf is specified' {
        [string]$pattern = '^report_(\d{4})\.txt$'
        [string]$replacement = 'summary_$1.txt'

        Invoke-BatchRename -Directory $script:tempDir -Pattern $pattern -Replacement $replacement -WhatIf

        # Files should be unchanged
        Test-Path (Join-Path $script:tempDir 'report_2023.txt') | Should -Be $true
        Test-Path (Join-Path $script:tempDir 'report_2024.txt') | Should -Be $true
        Test-Path (Join-Path $script:tempDir 'summary_2023.txt') | Should -Be $false
    }

    It 'throws when conflicts are detected and Force is not specified' {
        # Create a scenario where two files would conflict
        'x' | Set-Content -Path (Join-Path $script:tempDir 'doc_v1.txt')
        'y' | Set-Content -Path (Join-Path $script:tempDir 'doc_v2.txt')

        # Pattern that would rename both to same name (strip version)
        [string]$pattern = '^doc_v\d+\.txt$'
        [string]$replacement = 'document.txt'

        { Invoke-BatchRename -Directory $script:tempDir -Pattern $pattern -Replacement $replacement } |
            Should -Throw -ExceptionType ([System.InvalidOperationException])
    }

    It 'returns rename operation results' {
        [string]$pattern = '^report_(\d{4})\.txt$'
        [string]$replacement = 'summary_$1.txt'

        [object[]]$results = Invoke-BatchRename -Directory $script:tempDir -Pattern $pattern -Replacement $replacement

        $results | Should -HaveCount 2
        $results | ForEach-Object {
            $_.PSObject.Properties.Name | Should -Contain 'OldName'
            $_.PSObject.Properties.Name | Should -Contain 'NewName'
            $_.PSObject.Properties.Name | Should -Contain 'Success'
        }
    }
}

# ===========================================================================
# RED TEST 4: New-UndoScript - generate an undo script
# ===========================================================================
Describe 'New-UndoScript' {

    It 'generates a PowerShell undo script from rename operations' {
        [object[]]$operations = @(
            [PSCustomObject]@{ OldName = 'report_2023.txt'; NewName = 'summary_2023.txt'; WillChange = $true }
            [PSCustomObject]@{ OldName = 'report_2024.txt'; NewName = 'summary_2024.txt'; WillChange = $true }
        )
        [string]$directory = '/tmp/testdir'

        [string]$script = New-UndoScript -Operations $operations -Directory $directory

        # Script should rename new->old (reverse the operations)
        $script | Should -Match 'summary_2023\.txt'
        $script | Should -Match 'report_2023\.txt'
        $script | Should -Match 'summary_2024\.txt'
        $script | Should -Match 'report_2024\.txt'
        # Should include the directory context
        $script | Should -Match [regex]::Escape($directory)
    }

    It 'includes strict mode header in generated script' {
        [object[]]$operations = @(
            [PSCustomObject]@{ OldName = 'old.txt'; NewName = 'new.txt'; WillChange = $true }
        )
        [string]$directory = '/tmp/testdir'

        [string]$script = New-UndoScript -Operations $operations -Directory $directory

        $script | Should -Match 'Set-StrictMode'
        $script | Should -Match 'ErrorActionPreference'
    }

    It 'generates empty script body when no operations are provided' {
        [object[]]$operations = @()
        [string]$directory = '/tmp/testdir'

        [string]$script = New-UndoScript -Operations $operations -Directory $directory

        # Should still be a valid script but with no rename commands
        $script | Should -Not -BeNullOrEmpty
        $script | Should -Match 'Set-StrictMode'
    }

    It 'saves undo script to file when OutputPath is specified' {
        [object[]]$operations = @(
            [PSCustomObject]@{ OldName = 'old.txt'; NewName = 'new.txt'; WillChange = $true }
        )
        [string]$directory = '/tmp/testdir'
        [string]$outputPath = Join-Path ([System.IO.Path]::GetTempPath()) "undo_$(New-Guid).ps1"

        try {
            New-UndoScript -Operations $operations -Directory $directory -OutputPath $outputPath

            Test-Path $outputPath | Should -Be $true
            [string]$content = Get-Content $outputPath -Raw
            $content | Should -Match 'Set-StrictMode'
        }
        finally {
            Remove-Item $outputPath -ErrorAction SilentlyContinue
        }
    }
}

# ===========================================================================
# RED TEST 5: Integration - full workflow with real temp directory
# ===========================================================================
Describe 'Full workflow integration' {

    BeforeEach {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "BatchRenameInteg_$(New-Guid)"
        New-Item -Path $script:tempDir -ItemType Directory | Out-Null
        # Create a set of test files
        @('invoice_001.pdf', 'invoice_002.pdf', 'invoice_003.pdf', 'readme.txt') | ForEach-Object {
            "content of $_" | Set-Content -Path (Join-Path $script:tempDir $_)
        }
    }

    AfterEach {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'preview shows correct renames without touching files' {
        [string[]]$files = Get-ChildItem -Path $script:tempDir -File | Select-Object -ExpandProperty Name
        [string]$pattern = '^invoice_(\d+)\.pdf$'
        [string]$replacement = 'bill_$1.pdf'

        [object[]]$preview = Get-RenamePreview -Files $files -Pattern $pattern -Replacement $replacement

        $preview | Should -HaveCount 3
        # Files on disk should be unchanged
        Test-Path (Join-Path $script:tempDir 'invoice_001.pdf') | Should -Be $true
        Test-Path (Join-Path $script:tempDir 'bill_001.pdf') | Should -Be $false
    }

    It 'rename + undo script restores original names' {
        [string]$pattern = '^invoice_(\d+)\.pdf$'
        [string]$replacement = 'bill_$1.pdf'
        [string]$undoPath = Join-Path $script:tempDir 'undo_rename.ps1'

        # Perform rename and get operations
        [object[]]$ops = Invoke-BatchRename -Directory $script:tempDir -Pattern $pattern -Replacement $replacement

        # Files should now have new names
        Test-Path (Join-Path $script:tempDir 'bill_001.pdf') | Should -Be $true
        Test-Path (Join-Path $script:tempDir 'invoice_001.pdf') | Should -Be $false

        # Generate and run undo script
        New-UndoScript -Operations $ops -Directory $script:tempDir -OutputPath $undoPath
        & $undoPath

        # Files should be restored
        Test-Path (Join-Path $script:tempDir 'invoice_001.pdf') | Should -Be $true
        Test-Path (Join-Path $script:tempDir 'bill_001.pdf') | Should -Be $false
    }
}
