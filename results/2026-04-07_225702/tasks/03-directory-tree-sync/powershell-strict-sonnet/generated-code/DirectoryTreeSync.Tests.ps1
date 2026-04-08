#Requires -Version 7.0
# TDD test suite for DirectoryTreeSync module.
# Helper functions are defined in the top-level BeforeAll so they are in scope
# for all nested Describe/BeforeAll/AfterAll/It blocks (Pester 5 scoping rule).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    $moduleFile = Join-Path $PSScriptRoot 'DirectoryTreeSync.psm1'
    if (Test-Path $moduleFile) {
        Import-Module $moduleFile -Force
    }

    # ── Shared test helpers ────────────────────────────────────────────────────
    function New-TestTree {
        [CmdletBinding()]
        [OutputType([string])]
        param([string]$Tag = 'Test')
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) `
                         "DirSync-$Tag-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
        [void](New-Item -ItemType Directory -Path $tmp -Force)
        return $tmp
    }

    function Remove-TestTree {
        [CmdletBinding()]
        [OutputType([void])]
        param([string]$Path)
        if (Test-Path $Path) { Remove-Item -Recurse -Force -Path $Path }
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# RED #1 — Get-DirectoryIndex
# ═══════════════════════════════════════════════════════════════════════════════
Describe 'Get-DirectoryIndex' {
    BeforeAll {
        $testRoot = New-TestTree -Tag 'GDI'

        # Structure:
        #   file1.txt
        #   sub/file2.txt
        #   sub/nested/file3.txt
        New-Item -ItemType File -Path (Join-Path $testRoot 'file1.txt') `
                 -Value 'hello' -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $testRoot 'sub') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $testRoot 'sub' 'file2.txt') `
                 -Value 'world' -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $testRoot 'sub' 'nested') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $testRoot 'sub' 'nested' 'file3.txt') `
                 -Value 'deep' -Force | Out-Null
    }

    AfterAll { Remove-TestTree -Path $testRoot }

    It 'returns a hashtable' {
        $index = Get-DirectoryIndex -Path $testRoot
        $index | Should -BeOfType [hashtable]
    }

    It 'finds all files recursively' {
        $index = Get-DirectoryIndex -Path $testRoot
        $index.Keys | Should -HaveCount 3
    }

    It 'uses forward-slash-normalised relative paths as keys' {
        $index = Get-DirectoryIndex -Path $testRoot
        $index.Keys | Should -Contain 'file1.txt'
        $index.Keys | Should -Contain 'sub/file2.txt'
        $index.Keys | Should -Contain 'sub/nested/file3.txt'
    }

    It 'stores a 64-char hex SHA-256 hash for each file' {
        $index = Get-DirectoryIndex -Path $testRoot
        $index['file1.txt'] | Should -Match '^[0-9a-f]{64}$'
    }

    It 'throws when the directory does not exist' {
        { Get-DirectoryIndex -Path '/no/such/directory' } | Should -Throw
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# RED #2 — Compare-DirectoryTrees
# ═══════════════════════════════════════════════════════════════════════════════
Describe 'Compare-DirectoryTrees' {
    BeforeAll {
        $srcRoot = New-TestTree -Tag 'CmpSrc'
        $dstRoot = New-TestTree -Tag 'CmpDst'

        # Source:  same.txt | changed.txt(v1) | src-only.txt
        # Dest:    same.txt | changed.txt(v2) | dst-only.txt
        New-Item -ItemType File -Path (Join-Path $srcRoot 'same.txt')     -Value 'same'     -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $srcRoot 'changed.txt')  -Value 'version1' -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $srcRoot 'src-only.txt') -Value 'src'      -Force | Out-Null

        New-Item -ItemType File -Path (Join-Path $dstRoot 'same.txt')     -Value 'same'     -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $dstRoot 'changed.txt')  -Value 'version2' -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $dstRoot 'dst-only.txt') -Value 'dst'      -Force | Out-Null
    }

    AfterAll {
        Remove-TestTree -Path $srcRoot
        Remove-TestTree -Path $dstRoot
    }

    It 'returns an object with Modified, SourceOnly, DestinationOnly, Identical properties' {
        $result = Compare-DirectoryTrees -SourcePath $srcRoot -DestinationPath $dstRoot
        $result | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties.Name | Should -Contain 'Modified'
        $result.PSObject.Properties.Name | Should -Contain 'SourceOnly'
        $result.PSObject.Properties.Name | Should -Contain 'DestinationOnly'
        $result.PSObject.Properties.Name | Should -Contain 'Identical'
    }

    It 'detects files that differ by content hash' {
        $result = Compare-DirectoryTrees -SourcePath $srcRoot -DestinationPath $dstRoot
        $result.Modified | Should -Contain 'changed.txt'
    }

    It 'detects identical files' {
        $result = Compare-DirectoryTrees -SourcePath $srcRoot -DestinationPath $dstRoot
        $result.Identical | Should -Contain 'same.txt'
    }

    It 'detects files only in source' {
        $result = Compare-DirectoryTrees -SourcePath $srcRoot -DestinationPath $dstRoot
        $result.SourceOnly | Should -Contain 'src-only.txt'
    }

    It 'detects files only in destination' {
        $result = Compare-DirectoryTrees -SourcePath $srcRoot -DestinationPath $dstRoot
        $result.DestinationOnly | Should -Contain 'dst-only.txt'
    }

    It 'includes SourcePath and DestinationPath in result' {
        $result = Compare-DirectoryTrees -SourcePath $srcRoot -DestinationPath $dstRoot
        $result.SourcePath      | Should -Be $srcRoot
        $result.DestinationPath | Should -Be $dstRoot
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# RED #3 — New-SyncPlan
# ═══════════════════════════════════════════════════════════════════════════════
Describe 'New-SyncPlan' {
    BeforeAll {
        $srcRoot = New-TestTree -Tag 'PlanSrc'
        $dstRoot = New-TestTree -Tag 'PlanDst'

        New-Item -ItemType File -Path (Join-Path $srcRoot 'same.txt')     -Value 'same' -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $srcRoot 'changed.txt')  -Value 'v1'   -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $srcRoot 'new.txt')      -Value 'new'  -Force | Out-Null

        New-Item -ItemType File -Path (Join-Path $dstRoot 'same.txt')     -Value 'same' -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $dstRoot 'changed.txt')  -Value 'v2'   -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $dstRoot 'obsolete.txt') -Value 'old'  -Force | Out-Null

        $script:comparison = Compare-DirectoryTrees -SourcePath $srcRoot -DestinationPath $dstRoot
    }

    AfterAll {
        Remove-TestTree -Path $srcRoot
        Remove-TestTree -Path $dstRoot
    }

    It 'returns a SyncPlan with Actions, SourcePath, DestinationPath' {
        $plan = New-SyncPlan -Comparison $script:comparison
        $plan | Should -Not -BeNullOrEmpty
        $plan.PSObject.Properties.Name | Should -Contain 'Actions'
        $plan.PSObject.Properties.Name | Should -Contain 'SourcePath'
        $plan.PSObject.Properties.Name | Should -Contain 'DestinationPath'
    }

    It 'includes a Copy action for source-only files' {
        $plan = New-SyncPlan -Comparison $script:comparison
        $copyAction = $plan.Actions | Where-Object { $_.Action -eq 'Copy' -and $_.RelativePath -eq 'new.txt' }
        $copyAction | Should -Not -BeNullOrEmpty
    }

    It 'includes an Overwrite action for modified files' {
        $plan = New-SyncPlan -Comparison $script:comparison
        $overwrite = $plan.Actions | Where-Object { $_.Action -eq 'Overwrite' -and $_.RelativePath -eq 'changed.txt' }
        $overwrite | Should -Not -BeNullOrEmpty
    }

    It 'includes a Delete action for destination-only files' {
        $plan = New-SyncPlan -Comparison $script:comparison
        $delete = $plan.Actions | Where-Object { $_.Action -eq 'Delete' -and $_.RelativePath -eq 'obsolete.txt' }
        $delete | Should -Not -BeNullOrEmpty
    }

    It 'does not include actions for identical files' {
        $plan = New-SyncPlan -Comparison $script:comparison
        $sameActions = $plan.Actions | Where-Object { $_.RelativePath -eq 'same.txt' }
        $sameActions | Should -BeNullOrEmpty
    }

    It 'each action has SourcePath and DestinationPath properties' {
        $plan = New-SyncPlan -Comparison $script:comparison
        foreach ($action in $plan.Actions) {
            $action.PSObject.Properties.Name | Should -Contain 'SourcePath'
            $action.PSObject.Properties.Name | Should -Contain 'DestinationPath'
        }
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# RED #4 — Invoke-SyncPlan (dry-run)
# ═══════════════════════════════════════════════════════════════════════════════
Describe 'Invoke-SyncPlan dry-run' {
    BeforeAll {
        $srcRoot = New-TestTree -Tag 'DryRunSrc'
        $dstRoot = New-TestTree -Tag 'DryRunDst'

        New-Item -ItemType File -Path (Join-Path $srcRoot 'new.txt')     -Value 'new'  -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $srcRoot 'changed.txt') -Value 'v1'   -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $dstRoot 'changed.txt') -Value 'v2'   -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $dstRoot 'old.txt')     -Value 'gone' -Force | Out-Null

        $comparison   = Compare-DirectoryTrees -SourcePath $srcRoot -DestinationPath $dstRoot
        $script:plan  = New-SyncPlan -Comparison $comparison
        $script:report = Invoke-SyncPlan -Plan $script:plan -DryRun
    }

    AfterAll {
        Remove-TestTree -Path $srcRoot
        Remove-TestTree -Path $dstRoot
    }

    It 'returns a report with ActionsPlanned, ActionsExecuted, WasDryRun' {
        $script:report | Should -Not -BeNullOrEmpty
        $script:report.PSObject.Properties.Name | Should -Contain 'ActionsPlanned'
        $script:report.PSObject.Properties.Name | Should -Contain 'ActionsExecuted'
        $script:report.PSObject.Properties.Name | Should -Contain 'WasDryRun'
    }

    It 'sets WasDryRun to true' {
        $script:report.WasDryRun | Should -BeTrue
    }

    It 'does not copy files to destination' {
        Test-Path (Join-Path $dstRoot 'new.txt') | Should -BeFalse
    }

    It 'does not delete destination-only files' {
        Test-Path (Join-Path $dstRoot 'old.txt') | Should -BeTrue
    }

    It 'reports ActionsExecuted as 0 and ActionsPlanned as plan count' {
        $script:report.ActionsPlanned  | Should -Be $script:plan.Actions.Count
        $script:report.ActionsExecuted | Should -Be 0
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# RED #5 — Invoke-SyncPlan (execute)
# ═══════════════════════════════════════════════════════════════════════════════
Describe 'Invoke-SyncPlan execute' {
    # Fresh trees per test so operations don't bleed between tests
    BeforeEach {
        $script:srcRoot = New-TestTree -Tag 'ExecSrc'
        $script:dstRoot = New-TestTree -Tag 'ExecDst'
    }

    AfterEach {
        Remove-TestTree -Path $script:srcRoot
        Remove-TestTree -Path $script:dstRoot
    }

    It 'copies source-only files to destination' {
        New-Item -ItemType File -Path (Join-Path $script:srcRoot 'copy-me.txt') -Value 'fresh' -Force | Out-Null

        $comparison = Compare-DirectoryTrees -SourcePath $script:srcRoot -DestinationPath $script:dstRoot
        $plan = New-SyncPlan -Comparison $comparison
        [void](Invoke-SyncPlan -Plan $plan)

        Test-Path (Join-Path $script:dstRoot 'copy-me.txt') | Should -BeTrue
        Get-Content (Join-Path $script:dstRoot 'copy-me.txt') | Should -Be 'fresh'
    }

    It 'overwrites modified files in destination' {
        New-Item -ItemType File -Path (Join-Path $script:srcRoot 'update.txt') -Value 'new-content' -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $script:dstRoot 'update.txt') -Value 'old-content' -Force | Out-Null

        $comparison = Compare-DirectoryTrees -SourcePath $script:srcRoot -DestinationPath $script:dstRoot
        $plan = New-SyncPlan -Comparison $comparison
        [void](Invoke-SyncPlan -Plan $plan)

        Get-Content (Join-Path $script:dstRoot 'update.txt') | Should -Be 'new-content'
    }

    It 'deletes destination-only files' {
        New-Item -ItemType File -Path (Join-Path $script:dstRoot 'remove-me.txt') -Value 'stale' -Force | Out-Null

        $comparison = Compare-DirectoryTrees -SourcePath $script:srcRoot -DestinationPath $script:dstRoot
        $plan = New-SyncPlan -Comparison $comparison
        [void](Invoke-SyncPlan -Plan $plan)

        Test-Path (Join-Path $script:dstRoot 'remove-me.txt') | Should -BeFalse
    }

    It 'preserves identical files' {
        New-Item -ItemType File -Path (Join-Path $script:srcRoot 'keep.txt') -Value 'same' -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $script:dstRoot 'keep.txt') -Value 'same' -Force | Out-Null

        $comparison = Compare-DirectoryTrees -SourcePath $script:srcRoot -DestinationPath $script:dstRoot
        $plan = New-SyncPlan -Comparison $comparison
        [void](Invoke-SyncPlan -Plan $plan)

        Get-Content (Join-Path $script:dstRoot 'keep.txt') | Should -Be 'same'
    }

    It 'creates intermediate subdirectories when copying' {
        New-Item -ItemType Directory -Path (Join-Path $script:srcRoot 'a' 'b') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $script:srcRoot 'a' 'b' 'deep.txt') -Value 'deep' -Force | Out-Null

        $comparison = Compare-DirectoryTrees -SourcePath $script:srcRoot -DestinationPath $script:dstRoot
        $plan = New-SyncPlan -Comparison $comparison
        [void](Invoke-SyncPlan -Plan $plan)

        Test-Path (Join-Path $script:dstRoot 'a' 'b' 'deep.txt') | Should -BeTrue
    }

    It 'returns a report with WasDryRun=false and ActionsExecuted matching plan' {
        New-Item -ItemType File -Path (Join-Path $script:srcRoot 'x.txt') -Value 'x' -Force | Out-Null

        $comparison = Compare-DirectoryTrees -SourcePath $script:srcRoot -DestinationPath $script:dstRoot
        $plan = New-SyncPlan -Comparison $comparison
        $report = Invoke-SyncPlan -Plan $plan

        $report.WasDryRun       | Should -BeFalse
        $report.ActionsExecuted | Should -Be $plan.Actions.Count
        $report.ActionsPlanned  | Should -Be $plan.Actions.Count
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# RED #6 — Edge cases
# ═══════════════════════════════════════════════════════════════════════════════
Describe 'Edge cases' {
    It 'two identical trees produce zero actions' {
        $srcRoot = New-TestTree -Tag 'EdgeSrc'
        $dstRoot = New-TestTree -Tag 'EdgeDst'
        try {
            New-Item -ItemType File -Path (Join-Path $srcRoot 'a.txt') -Value 'data' -Force | Out-Null
            New-Item -ItemType File -Path (Join-Path $dstRoot 'a.txt') -Value 'data' -Force | Out-Null

            $comparison = Compare-DirectoryTrees -SourcePath $srcRoot -DestinationPath $dstRoot
            $plan = New-SyncPlan -Comparison $comparison
            $plan.Actions | Should -HaveCount 0
        }
        finally {
            Remove-TestTree -Path $srcRoot
            Remove-TestTree -Path $dstRoot
        }
    }

    It 'two empty trees produce zero actions' {
        $srcRoot = New-TestTree -Tag 'EmptySrc'
        $dstRoot = New-TestTree -Tag 'EmptyDst'
        try {
            $comparison = Compare-DirectoryTrees -SourcePath $srcRoot -DestinationPath $dstRoot
            $plan = New-SyncPlan -Comparison $comparison
            $plan.Actions | Should -HaveCount 0
        }
        finally {
            Remove-TestTree -Path $srcRoot
            Remove-TestTree -Path $dstRoot
        }
    }

    It 'detects changes in deeply nested files' {
        $srcRoot = New-TestTree -Tag 'DeepSrc'
        $dstRoot = New-TestTree -Tag 'DeepDst'
        try {
            New-Item -ItemType Directory -Path (Join-Path $srcRoot 'x' 'y' 'z') -Force | Out-Null
            New-Item -ItemType File -Path (Join-Path $srcRoot 'x' 'y' 'z' 'deep.txt') -Value 'deep'      -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $dstRoot 'x' 'y' 'z') -Force | Out-Null
            New-Item -ItemType File -Path (Join-Path $dstRoot 'x' 'y' 'z' 'deep.txt') -Value 'different' -Force | Out-Null

            $comparison = Compare-DirectoryTrees -SourcePath $srcRoot -DestinationPath $dstRoot
            $comparison.Modified | Should -Contain 'x/y/z/deep.txt'
        }
        finally {
            Remove-TestTree -Path $srcRoot
            Remove-TestTree -Path $dstRoot
        }
    }
}
