# Pester unit tests for the semantic version bumper.
# Written TDD-style: each Describe block represents one red-green-refactor cycle.
#
# Test organization matches the public surface of the SemanticVersionBumper module:
#   Get-CurrentVersion      -> parses version from VERSION file or package.json
#   Get-BumpType            -> classifies conventional commits as major/minor/patch
#   Get-NextVersion         -> applies a bump type to a semantic version string
#   Set-VersionInFile       -> persists the new version back to disk
#   New-ChangelogEntry      -> formats a Keep-a-Changelog style section
#   Invoke-VersionBump      -> orchestrates the full pipeline end-to-end

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..' 'src' 'SemanticVersionBumper.psm1'
    Import-Module $script:ModulePath -Force
}

Describe 'Get-CurrentVersion' {
    BeforeEach {
        $script:TempDir = Join-Path ([IO.Path]::GetTempPath()) ("svb-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path $script:TempDir | Out-Null
    }
    AfterEach {
        if (Test-Path $script:TempDir) { Remove-Item -Recurse -Force $script:TempDir }
    }

    It 'reads a bare version from a VERSION file' {
        $file = Join-Path $script:TempDir 'VERSION'
        Set-Content -Path $file -Value '1.2.3' -NoNewline
        (Get-CurrentVersion -Path $file) | Should -Be '1.2.3'
    }

    It 'trims whitespace and a leading v prefix' {
        $file = Join-Path $script:TempDir 'VERSION'
        Set-Content -Path $file -Value "  v2.0.1`n"
        (Get-CurrentVersion -Path $file) | Should -Be '2.0.1'
    }

    It 'reads the version field from package.json' {
        $file = Join-Path $script:TempDir 'package.json'
        '{ "name": "demo", "version": "0.9.4" }' | Set-Content -Path $file
        (Get-CurrentVersion -Path $file) | Should -Be '0.9.4'
    }

    It 'throws a clear error when the file does not exist' {
        { Get-CurrentVersion -Path (Join-Path $script:TempDir 'missing') } |
            Should -Throw -ExpectedMessage '*not found*'
    }

    It 'throws when package.json lacks a version field' {
        $file = Join-Path $script:TempDir 'package.json'
        '{ "name": "demo" }' | Set-Content -Path $file
        { Get-CurrentVersion -Path $file } | Should -Throw -ExpectedMessage '*version*'
    }

    It 'throws when the content is not a valid semantic version' {
        $file = Join-Path $script:TempDir 'VERSION'
        'banana' | Set-Content -Path $file
        { Get-CurrentVersion -Path $file } | Should -Throw -ExpectedMessage '*semantic version*'
    }
}

Describe 'Get-BumpType' {
    It 'returns patch for a single fix commit' {
        Get-BumpType -Commits @('fix: correct off-by-one in pagination') | Should -Be 'patch'
    }

    It 'returns minor for a feat commit' {
        Get-BumpType -Commits @('feat: add dark mode') | Should -Be 'minor'
    }

    It 'returns minor when any commit is feat, even if a fix also appears' {
        $commits = @('fix: typo in readme', 'feat(api): add /health endpoint')
        Get-BumpType -Commits $commits | Should -Be 'minor'
    }

    It 'returns major for a commit marked with ! after the type' {
        Get-BumpType -Commits @('feat!: drop Node 14 support') | Should -Be 'major'
    }

    It 'returns major for a commit with a BREAKING CHANGE footer' {
        $commit = "refactor: rename client factory`n`nBREAKING CHANGE: the old name is removed."
        Get-BumpType -Commits @($commit) | Should -Be 'major'
    }

    It 'returns major even when lower-severity commits are present' {
        $commits = @('fix: log line', 'feat!: new auth flow', 'chore: bump deps')
        Get-BumpType -Commits $commits | Should -Be 'major'
    }

    It 'returns $null when no commit indicates a user-visible change' {
        Get-BumpType -Commits @('chore: tidy imports', 'docs: fix typo') | Should -BeNullOrEmpty
    }

    It 'returns $null for an empty commit list' {
        Get-BumpType -Commits @() | Should -BeNullOrEmpty
    }

    It 'is case-insensitive on commit type prefix' {
        Get-BumpType -Commits @('FEAT: uppercase feat') | Should -Be 'minor'
    }
}

Describe 'Get-NextVersion' {
    It 'bumps the patch component' {
        Get-NextVersion -Current '1.2.3' -BumpType 'patch' | Should -Be '1.2.4'
    }

    It 'bumps the minor component and resets patch' {
        Get-NextVersion -Current '1.2.3' -BumpType 'minor' | Should -Be '1.3.0'
    }

    It 'bumps the major component and resets minor+patch' {
        Get-NextVersion -Current '1.2.3' -BumpType 'major' | Should -Be '2.0.0'
    }

    It 'handles 0.x releases correctly' {
        Get-NextVersion -Current '0.0.9' -BumpType 'patch' | Should -Be '0.0.10'
    }

    It 'rejects unknown bump types' {
        { Get-NextVersion -Current '1.0.0' -BumpType 'giant' } |
            Should -Throw -ExpectedMessage '*bump type*'
    }

    It 'rejects malformed input versions' {
        { Get-NextVersion -Current 'not-a-version' -BumpType 'patch' } |
            Should -Throw -ExpectedMessage '*semantic version*'
    }
}

Describe 'Set-VersionInFile' {
    BeforeEach {
        $script:TempDir = Join-Path ([IO.Path]::GetTempPath()) ("svb-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path $script:TempDir | Out-Null
    }
    AfterEach {
        if (Test-Path $script:TempDir) { Remove-Item -Recurse -Force $script:TempDir }
    }

    It 'updates a plain VERSION file' {
        $file = Join-Path $script:TempDir 'VERSION'
        '1.0.0' | Set-Content -Path $file
        Set-VersionInFile -Path $file -Version '1.1.0'
        (Get-Content -Path $file -Raw).Trim() | Should -Be '1.1.0'
    }

    It 'updates the version in package.json without destroying other fields' {
        $file = Join-Path $script:TempDir 'package.json'
        '{ "name": "demo", "version": "1.0.0", "private": true }' | Set-Content -Path $file
        Set-VersionInFile -Path $file -Version '1.1.0'
        $parsed = Get-Content -Path $file -Raw | ConvertFrom-Json
        $parsed.version | Should -Be '1.1.0'
        $parsed.name | Should -Be 'demo'
        $parsed.private | Should -BeTrue
    }
}

Describe 'New-ChangelogEntry' {
    It 'groups commits by type under a version heading' {
        $entry = New-ChangelogEntry -Version '1.2.0' -Date '2026-04-19' -Commits @(
            'feat: add dark mode',
            'fix: crash on empty input',
            'chore: bump deps'
        )
        $entry | Should -Match '## \[1\.2\.0\] - 2026-04-19'
        $entry | Should -Match '### Added'
        $entry | Should -Match '- add dark mode'
        $entry | Should -Match '### Fixed'
        $entry | Should -Match '- crash on empty input'
    }

    It 'lists breaking changes under their own heading' {
        $entry = New-ChangelogEntry -Version '2.0.0' -Date '2026-04-19' -Commits @(
            'feat!: remove legacy API'
        )
        $entry | Should -Match '### BREAKING CHANGES'
        $entry | Should -Match '- remove legacy API'
    }
}

Describe 'Invoke-VersionBump (integration)' {
    BeforeEach {
        $script:TempDir = Join-Path ([IO.Path]::GetTempPath()) ("svb-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path $script:TempDir | Out-Null
    }
    AfterEach {
        if (Test-Path $script:TempDir) { Remove-Item -Recurse -Force $script:TempDir }
    }

    It 'bumps a patch version and writes a changelog entry' {
        $versionFile = Join-Path $script:TempDir 'VERSION'
        $commitsFile = Join-Path $script:TempDir 'commits.txt'
        $changelogFile = Join-Path $script:TempDir 'CHANGELOG.md'
        '1.0.0' | Set-Content -Path $versionFile
        'fix: correct null-pointer in parser' | Set-Content -Path $commitsFile

        $result = Invoke-VersionBump -VersionFile $versionFile -CommitsFile $commitsFile -ChangelogFile $changelogFile -Date '2026-04-19'

        $result.NewVersion | Should -Be '1.0.1'
        (Get-Content $versionFile -Raw).Trim() | Should -Be '1.0.1'
        (Get-Content $changelogFile -Raw) | Should -Match '\[1\.0\.1\]'
        (Get-Content $changelogFile -Raw) | Should -Match 'correct null-pointer in parser'
    }

    It 'bumps a minor version for a feat commit' {
        $versionFile = Join-Path $script:TempDir 'package.json'
        $commitsFile = Join-Path $script:TempDir 'commits.txt'
        $changelogFile = Join-Path $script:TempDir 'CHANGELOG.md'
        '{ "name": "demo", "version": "1.1.0" }' | Set-Content -Path $versionFile
        @('feat: add OAuth login', 'chore: bump deps') | Set-Content -Path $commitsFile

        $result = Invoke-VersionBump -VersionFile $versionFile -CommitsFile $commitsFile -ChangelogFile $changelogFile -Date '2026-04-19'

        $result.NewVersion | Should -Be '1.2.0'
        ((Get-Content $versionFile -Raw) | ConvertFrom-Json).version | Should -Be '1.2.0'
    }

    It 'bumps a major version for a breaking commit' {
        $versionFile = Join-Path $script:TempDir 'VERSION'
        $commitsFile = Join-Path $script:TempDir 'commits.txt'
        $changelogFile = Join-Path $script:TempDir 'CHANGELOG.md'
        '1.5.2' | Set-Content -Path $versionFile
        "feat!: redesign public API`n`nBREAKING CHANGE: method names have changed." |
            Set-Content -Path $commitsFile

        $result = Invoke-VersionBump -VersionFile $versionFile -CommitsFile $commitsFile -ChangelogFile $changelogFile -Date '2026-04-19'

        $result.NewVersion | Should -Be '2.0.0'
    }

    It 'preserves any prior changelog content when prepending' {
        $versionFile = Join-Path $script:TempDir 'VERSION'
        $commitsFile = Join-Path $script:TempDir 'commits.txt'
        $changelogFile = Join-Path $script:TempDir 'CHANGELOG.md'
        '1.0.0' | Set-Content -Path $versionFile
        'fix: a new fix' | Set-Content -Path $commitsFile
        "# Changelog`n`n## [1.0.0] - 2026-01-01`n- initial release" | Set-Content -Path $changelogFile

        Invoke-VersionBump -VersionFile $versionFile -CommitsFile $commitsFile -ChangelogFile $changelogFile -Date '2026-04-19' | Out-Null

        $content = Get-Content $changelogFile -Raw
        $content | Should -Match '\[1\.0\.1\]'
        $content | Should -Match '\[1\.0\.0\]'
        # the new entry must appear before the old one
        $idxNew = $content.IndexOf('[1.0.1]')
        $idxOld = $content.IndexOf('[1.0.0]')
        $idxNew | Should -BeLessThan $idxOld
    }

    It 'exits with a meaningful error if no bump is warranted' {
        $versionFile = Join-Path $script:TempDir 'VERSION'
        $commitsFile = Join-Path $script:TempDir 'commits.txt'
        $changelogFile = Join-Path $script:TempDir 'CHANGELOG.md'
        '1.0.0' | Set-Content -Path $versionFile
        'chore: whitespace' | Set-Content -Path $commitsFile

        { Invoke-VersionBump -VersionFile $versionFile -CommitsFile $commitsFile -ChangelogFile $changelogFile -Date '2026-04-19' } |
            Should -Throw -ExpectedMessage '*no version bump*'
    }
}
