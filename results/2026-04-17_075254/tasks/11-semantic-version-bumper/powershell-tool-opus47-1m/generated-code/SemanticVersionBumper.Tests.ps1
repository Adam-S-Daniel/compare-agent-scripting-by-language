# Pester tests for SemanticVersionBumper module.
# Run with: Invoke-Pester -Path ./SemanticVersionBumper.Tests.ps1

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot 'SemanticVersionBumper.psm1'
    Import-Module $script:ModulePath -Force
}

Describe 'Get-BumpType' {
    It 'returns "none" for empty commit list' {
        Get-BumpType -Commits @() | Should -Be 'none'
    }

    It 'returns "patch" for fix commits' {
        Get-BumpType -Commits @('fix: correct typo', 'fix(api): null guard') | Should -Be 'patch'
    }

    It 'returns "minor" for feat commits' {
        Get-BumpType -Commits @('fix: typo', 'feat: add login') | Should -Be 'minor'
    }

    It 'returns "major" for breaking change commits with !' {
        Get-BumpType -Commits @('feat!: rewrite API', 'fix: small') | Should -Be 'major'
    }

    It 'returns "major" for BREAKING CHANGE footer' {
        $msg = "feat: new thing`n`nBREAKING CHANGE: removes old API"
        Get-BumpType -Commits @($msg) | Should -Be 'major'
    }

    It 'ignores non-conventional commits' {
        Get-BumpType -Commits @('random change', 'wip stuff') | Should -Be 'none'
    }

    It 'major beats minor and patch' {
        Get-BumpType -Commits @('fix: a', 'feat: b', 'feat!: c') | Should -Be 'major'
    }
}

Describe 'Step-SemanticVersion' {
    It 'bumps patch correctly' {
        Step-SemanticVersion -Version '1.2.3' -BumpType 'patch' | Should -Be '1.2.4'
    }

    It 'bumps minor and resets patch' {
        Step-SemanticVersion -Version '1.2.3' -BumpType 'minor' | Should -Be '1.3.0'
    }

    It 'bumps major and resets minor/patch' {
        Step-SemanticVersion -Version '1.2.3' -BumpType 'major' | Should -Be '2.0.0'
    }

    It 'returns same version for none' {
        Step-SemanticVersion -Version '1.2.3' -BumpType 'none' | Should -Be '1.2.3'
    }

    It 'throws on invalid version' {
        { Step-SemanticVersion -Version 'not-a-version' -BumpType 'patch' } | Should -Throw '*Invalid semantic version*'
    }

    It 'throws on invalid bump type' {
        { Step-SemanticVersion -Version '1.0.0' -BumpType 'huge' } | Should -Throw
    }
}

Describe 'Get-VersionFromFile' {
    It 'reads version from package.json' {
        $tmp = New-TemporaryFile
        try {
            '{ "name": "x", "version": "4.5.6" }' | Set-Content $tmp.FullName
            $newName = [System.IO.Path]::ChangeExtension($tmp.FullName, '.json')
            Move-Item $tmp.FullName $newName
            Get-VersionFromFile -Path $newName | Should -Be '4.5.6'
            Remove-Item $newName
        } catch {
            if (Test-Path $tmp.FullName) { Remove-Item $tmp.FullName }
            throw
        }
    }

    It 'reads version from a plain VERSION text file' {
        $tmp = New-TemporaryFile
        '7.8.9' | Set-Content $tmp.FullName
        Get-VersionFromFile -Path $tmp.FullName | Should -Be '7.8.9'
        Remove-Item $tmp.FullName
    }

    It 'throws if file is missing' {
        { Get-VersionFromFile -Path '/nope/missing.json' } | Should -Throw '*not found*'
    }
}

Describe 'Set-VersionInFile' {
    It 'updates version in package.json preserving JSON structure' {
        $tmp = [System.IO.Path]::ChangeExtension((New-TemporaryFile).FullName, '.json')
        '{ "name": "x", "version": "1.0.0", "scripts": { "test": "echo" } }' | Set-Content $tmp
        Set-VersionInFile -Path $tmp -NewVersion '2.0.0'
        Get-VersionFromFile -Path $tmp | Should -Be '2.0.0'
        # ensure other fields preserved
        (Get-Content $tmp -Raw) | Should -Match 'scripts'
        Remove-Item $tmp
    }

    It 'updates plain VERSION file' {
        $tmp = (New-TemporaryFile).FullName
        '1.0.0' | Set-Content $tmp
        Set-VersionInFile -Path $tmp -NewVersion '1.1.0'
        Get-VersionFromFile -Path $tmp | Should -Be '1.1.0'
        Remove-Item $tmp
    }
}

Describe 'New-ChangelogEntry' {
    It 'groups commits by type with header' {
        $entry = New-ChangelogEntry -Version '1.2.0' -Date '2026-04-17' -Commits @(
            'feat: add login',
            'fix: null guard',
            'feat(ui): new button'
        )
        $entry | Should -Match '## \[1\.2\.0\] - 2026-04-17'
        $entry | Should -Match '### Features'
        $entry | Should -Match 'add login'
        $entry | Should -Match '### Bug Fixes'
        $entry | Should -Match 'null guard'
    }

    It 'includes BREAKING CHANGES section' {
        $entry = New-ChangelogEntry -Version '2.0.0' -Date '2026-04-17' -Commits @('feat!: rewrite')
        $entry | Should -Match '### BREAKING CHANGES'
    }
}

Describe 'Invoke-VersionBump (integration)' {
    BeforeEach {
        $script:tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:tmpDir | Out-Null
        $script:pkg = Join-Path $script:tmpDir 'package.json'
        '{ "name": "demo", "version": "1.1.0" }' | Set-Content $script:pkg
        $script:log = Join-Path $script:tmpDir 'commits.txt'
        @('feat: add A', 'fix: small bug') -join "`n" | Set-Content $script:log
        $script:changelog = Join-Path $script:tmpDir 'CHANGELOG.md'
    }
    AfterEach {
        Remove-Item -Recurse -Force $script:tmpDir
    }

    It 'bumps minor when feat present, writes file and changelog' {
        $result = Invoke-VersionBump -VersionFile $script:pkg -CommitsFile $script:log -ChangelogFile $script:changelog -Date '2026-04-17'
        $result.NewVersion | Should -Be '1.2.0'
        $result.PreviousVersion | Should -Be '1.1.0'
        $result.BumpType | Should -Be 'minor'
        Get-VersionFromFile -Path $script:pkg | Should -Be '1.2.0'
        Test-Path $script:changelog | Should -Be $true
        (Get-Content $script:changelog -Raw) | Should -Match '1\.2\.0'
    }

    It 'no bump when no conventional commits' {
        'random update' | Set-Content $script:log
        $result = Invoke-VersionBump -VersionFile $script:pkg -CommitsFile $script:log -ChangelogFile $script:changelog -Date '2026-04-17'
        $result.NewVersion | Should -Be '1.1.0'
        $result.BumpType | Should -Be 'none'
    }
}
