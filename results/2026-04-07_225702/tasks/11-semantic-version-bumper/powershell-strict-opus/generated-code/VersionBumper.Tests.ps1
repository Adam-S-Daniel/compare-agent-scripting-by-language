# Import the module under test; strict mode is enforced inside the module itself.
# Pester discovery conflicts with Set-StrictMode at file scope, so we set it in BeforeAll.
BeforeAll {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    . "$PSScriptRoot/VersionBumper.ps1"
}

Describe 'Get-SemanticVersion' {
    It 'parses a plain version string from a VERSION file' {
        $tempFile = Join-Path $TestDrive 'VERSION'
        Set-Content -Path $tempFile -Value '1.2.3'
        $result = Get-SemanticVersion -FilePath $tempFile
        $result.Major | Should -Be 1
        $result.Minor | Should -Be 2
        $result.Patch | Should -Be 3
    }

    It 'parses version from a package.json file' {
        $tempFile = Join-Path $TestDrive 'package.json'
        $json = '{ "name": "my-app", "version": "2.5.10" }'
        Set-Content -Path $tempFile -Value $json
        $result = Get-SemanticVersion -FilePath $tempFile
        $result.Major | Should -Be 2
        $result.Minor | Should -Be 5
        $result.Patch | Should -Be 10
    }

    It 'throws on invalid version string' {
        $tempFile = Join-Path $TestDrive 'VERSION'
        Set-Content -Path $tempFile -Value 'not-a-version'
        { Get-SemanticVersion -FilePath $tempFile } | Should -Throw '*Invalid semantic version*'
    }

    It 'throws when file does not exist' {
        { Get-SemanticVersion -FilePath '/nonexistent/VERSION' } | Should -Throw
    }
}

Describe 'Get-BumpType' {
    It 'returns patch when only fix commits are present' {
        [string]$logFile = Join-Path $PSScriptRoot 'fixtures' 'commits-patch.txt'
        [string[]]$commits = Get-Content -LiteralPath $logFile | Where-Object { $_.Trim() -ne '' }
        [string]$result = Get-BumpType -CommitMessages $commits
        $result | Should -Be 'patch'
    }

    It 'returns minor when feat commits are present (no breaking)' {
        [string]$logFile = Join-Path $PSScriptRoot 'fixtures' 'commits-minor.txt'
        [string[]]$commits = Get-Content -LiteralPath $logFile | Where-Object { $_.Trim() -ne '' }
        [string]$result = Get-BumpType -CommitMessages $commits
        $result | Should -Be 'minor'
    }

    It 'returns major when breaking change marker (!) is present' {
        [string]$logFile = Join-Path $PSScriptRoot 'fixtures' 'commits-major.txt'
        [string[]]$commits = Get-Content -LiteralPath $logFile | Where-Object { $_.Trim() -ne '' }
        [string]$result = Get-BumpType -CommitMessages $commits
        $result | Should -Be 'major'
    }

    It 'returns major when BREAKING CHANGE footer is present' {
        [string]$logFile = Join-Path $PSScriptRoot 'fixtures' 'commits-breaking-footer.txt'
        [string[]]$commits = Get-Content -LiteralPath $logFile | Where-Object { $_.Trim() -ne '' }
        [string]$result = Get-BumpType -CommitMessages $commits
        $result | Should -Be 'major'
    }

    It 'returns none when no conventional commits are found' {
        [string[]]$commits = @('update stuff', 'misc changes')
        [string]$result = Get-BumpType -CommitMessages $commits
        $result | Should -Be 'none'
    }

    It 'returns none for empty commit list' {
        [string[]]$commits = @()
        [string]$result = Get-BumpType -CommitMessages $commits
        $result | Should -Be 'none'
    }
}

Describe 'Update-SemanticVersion' {
    It 'bumps patch version' {
        [hashtable]$ver = @{ Major = 1; Minor = 2; Patch = 3 }
        [hashtable]$result = Update-SemanticVersion -Version $ver -BumpType 'patch'
        $result.Major | Should -Be 1
        $result.Minor | Should -Be 2
        $result.Patch | Should -Be 4
    }

    It 'bumps minor version and resets patch' {
        [hashtable]$ver = @{ Major = 1; Minor = 2; Patch = 3 }
        [hashtable]$result = Update-SemanticVersion -Version $ver -BumpType 'minor'
        $result.Major | Should -Be 1
        $result.Minor | Should -Be 3
        $result.Patch | Should -Be 0
    }

    It 'bumps major version and resets minor and patch' {
        [hashtable]$ver = @{ Major = 1; Minor = 2; Patch = 3 }
        [hashtable]$result = Update-SemanticVersion -Version $ver -BumpType 'major'
        $result.Major | Should -Be 2
        $result.Minor | Should -Be 0
        $result.Patch | Should -Be 0
    }

    It 'throws on invalid bump type' {
        [hashtable]$ver = @{ Major = 1; Minor = 0; Patch = 0 }
        { Update-SemanticVersion -Version $ver -BumpType 'invalid' } | Should -Throw '*Invalid bump type*'
    }

    It 'returns unchanged version for none bump type' {
        [hashtable]$ver = @{ Major = 3; Minor = 1; Patch = 7 }
        [hashtable]$result = Update-SemanticVersion -Version $ver -BumpType 'none'
        $result.Major | Should -Be 3
        $result.Minor | Should -Be 1
        $result.Patch | Should -Be 7
    }
}

Describe 'Set-SemanticVersion' {
    It 'writes version to a plain VERSION file' {
        [string]$tempFile = Join-Path $TestDrive 'VERSION'
        Set-Content -Path $tempFile -Value '0.0.0'
        [hashtable]$ver = @{ Major = 2; Minor = 1; Patch = 0 }
        Set-SemanticVersion -FilePath $tempFile -Version $ver
        [string]$content = (Get-Content -LiteralPath $tempFile -Raw).Trim()
        $content | Should -Be '2.1.0'
    }

    It 'writes version into a package.json preserving other fields' {
        [string]$tempFile = Join-Path $TestDrive 'package.json'
        [string]$json = '{ "name": "my-app", "version": "1.0.0", "description": "test" }'
        Set-Content -Path $tempFile -Value $json
        [hashtable]$ver = @{ Major = 1; Minor = 1; Patch = 0 }
        Set-SemanticVersion -FilePath $tempFile -Version $ver
        [PSCustomObject]$parsed = Get-Content -LiteralPath $tempFile -Raw | ConvertFrom-Json
        $parsed.version | Should -Be '1.1.0'
        $parsed.name | Should -Be 'my-app'
        $parsed.description | Should -Be 'test'
    }
}

Describe 'New-ChangelogEntry' {
    It 'groups commits by type in the changelog' {
        [string[]]$commits = @(
            'feat: add search feature',
            'fix: resolve login bug',
            'feat: add export button'
        )
        [string]$entry = New-ChangelogEntry -Version '2.0.0' -CommitMessages $commits
        $entry | Should -Match '## 2\.0\.0'
        $entry | Should -Match 'Features'
        $entry | Should -Match 'add search feature'
        $entry | Should -Match 'add export button'
        $entry | Should -Match 'Bug Fixes'
        $entry | Should -Match 'resolve login bug'
    }

    It 'includes breaking changes section' {
        [string[]]$commits = @(
            'feat!: remove legacy API',
            'fix: minor typo'
        )
        [string]$entry = New-ChangelogEntry -Version '3.0.0' -CommitMessages $commits
        $entry | Should -Match 'Breaking Changes'
        $entry | Should -Match 'remove legacy API'
    }

    It 'handles commits with no recognized type' {
        [string[]]$commits = @(
            'docs: update README',
            'chore: bump deps'
        )
        [string]$entry = New-ChangelogEntry -Version '1.0.1' -CommitMessages $commits
        $entry | Should -Match '## 1\.0\.1'
        $entry | Should -Match 'Other'
    }

    It 'returns empty string for empty commits' {
        [string[]]$commits = @()
        [string]$entry = New-ChangelogEntry -Version '1.0.0' -CommitMessages $commits
        $entry | Should -BeNullOrEmpty
    }
}

Describe 'Invoke-VersionBump' {
    It 'performs a full minor bump on a VERSION file' {
        # Setup: VERSION file + commit log with a feat
        [string]$versionFile = Join-Path $TestDrive 'VERSION'
        Set-Content -Path $versionFile -Value '1.0.0'
        [string]$commitLog = Join-Path $TestDrive 'commits.txt'
        Set-Content -Path $commitLog -Value @(
            'feat: add user search',
            'fix: handle null email'
        )

        [hashtable]$result = Invoke-VersionBump -VersionFilePath $versionFile -CommitLogPath $commitLog
        $result.OldVersion | Should -Be '1.0.0'
        $result.NewVersion | Should -Be '1.1.0'
        $result.BumpType   | Should -Be 'minor'
        $result.Changelog  | Should -Match 'add user search'

        # Verify file was updated
        [string]$fileContent = (Get-Content -LiteralPath $versionFile -Raw).Trim()
        $fileContent | Should -Be '1.1.0'
    }

    It 'performs a major bump when breaking change is present' {
        [string]$versionFile = Join-Path $TestDrive 'VERSION'
        Set-Content -Path $versionFile -Value '2.3.1'
        [string]$commitLog = Join-Path $TestDrive 'commits.txt'
        Set-Content -Path $commitLog -Value @(
            'feat!: overhaul API response format',
            'fix: typo in error message'
        )

        [hashtable]$result = Invoke-VersionBump -VersionFilePath $versionFile -CommitLogPath $commitLog
        $result.NewVersion | Should -Be '3.0.0'
        $result.BumpType   | Should -Be 'major'
    }

    It 'performs a patch bump for fix-only commits' {
        [string]$versionFile = Join-Path $TestDrive 'VERSION'
        Set-Content -Path $versionFile -Value '0.5.3'
        [string]$commitLog = Join-Path $TestDrive 'commits.txt'
        Set-Content -Path $commitLog -Value @(
            'fix: correct timezone handling'
        )

        [hashtable]$result = Invoke-VersionBump -VersionFilePath $versionFile -CommitLogPath $commitLog
        $result.NewVersion | Should -Be '0.5.4'
        $result.BumpType   | Should -Be 'patch'
    }

    It 'works with package.json' {
        [string]$pkgFile = Join-Path $TestDrive 'package.json'
        [string]$json = '{ "name": "test-pkg", "version": "3.2.0" }'
        Set-Content -Path $pkgFile -Value $json
        [string]$commitLog = Join-Path $TestDrive 'commits.txt'
        Set-Content -Path $commitLog -Value @(
            'feat: add dark mode'
        )

        [hashtable]$result = Invoke-VersionBump -VersionFilePath $pkgFile -CommitLogPath $commitLog
        $result.NewVersion | Should -Be '3.3.0'

        # Verify package.json was updated correctly
        [PSCustomObject]$parsed = Get-Content -LiteralPath $pkgFile -Raw | ConvertFrom-Json
        $parsed.version | Should -Be '3.3.0'
        $parsed.name | Should -Be 'test-pkg'
    }

    It 'returns none when no conventional commits are found' {
        [string]$versionFile = Join-Path $TestDrive 'VERSION'
        Set-Content -Path $versionFile -Value '1.0.0'
        [string]$commitLog = Join-Path $TestDrive 'commits.txt'
        Set-Content -Path $commitLog -Value @(
            'updated stuff',
            'misc changes'
        )

        [hashtable]$result = Invoke-VersionBump -VersionFilePath $versionFile -CommitLogPath $commitLog
        $result.BumpType   | Should -Be 'none'
        $result.NewVersion | Should -Be '1.0.0'
        $result.OldVersion | Should -Be '1.0.0'
    }
}
