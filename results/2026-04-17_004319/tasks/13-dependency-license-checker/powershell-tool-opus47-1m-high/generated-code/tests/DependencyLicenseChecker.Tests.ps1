# Pester tests for the Dependency License Checker module.
# Written red-first per the TDD requirement: each Describe block was added
# before its implementation, then minimum code was added to make it pass.

BeforeAll {
    # Import the module under test. A single module keeps the API surface
    # discoverable and gives us a clean Mock target.
    $script:ModulePath = Join-Path $PSScriptRoot '..' 'src' 'DependencyLicenseChecker.psm1'
    Import-Module $script:ModulePath -Force

    $script:FixturesDir = Join-Path $PSScriptRoot '..' 'fixtures'
}

Describe 'Get-ManifestDependencies' {
    It 'parses a package.json file and returns dependency records' {
        $manifest = Join-Path $script:FixturesDir 'package.json'
        $deps = Get-ManifestDependencies -Path $manifest

        $deps | Should -HaveCount 5
        ($deps | Where-Object Name -eq 'express').Version | Should -Be '4.18.2'
        ($deps | Where-Object Name -eq 'jest').Version    | Should -Be '29.7.0'
    }

    It 'tags devDependencies with Scope=dev and runtime deps with Scope=prod' {
        $manifest = Join-Path $script:FixturesDir 'package.json'
        $deps = Get-ManifestDependencies -Path $manifest

        ($deps | Where-Object Name -eq 'express').Scope | Should -Be 'prod'
        ($deps | Where-Object Name -eq 'jest').Scope    | Should -Be 'dev'
    }

    It 'throws a clear error when the manifest file does not exist' {
        { Get-ManifestDependencies -Path '/tmp/does-not-exist.json' } |
            Should -Throw -ExpectedMessage '*not found*'
    }

    It 'throws a clear error on malformed JSON' {
        $bad = New-TemporaryFile
        Set-Content -Path $bad -Value '{ not json'
        try {
            { Get-ManifestDependencies -Path $bad } |
                Should -Throw -ExpectedMessage '*parse*'
        } finally {
            Remove-Item $bad -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Get-DependencyLicense (mockable lookup)' {
    It 'returns the license reported by the lookup provider' {
        # The real implementation calls an injected ScriptBlock provider.
        # Here we pass a fake provider so the test is hermetic.
        $provider = { param($name) if ($name -eq 'express') { 'MIT' } else { $null } }
        Get-DependencyLicense -Name 'express' -Provider $provider | Should -Be 'MIT'
    }

    It 'returns $null when the provider does not know the package' {
        $provider = { param($name) $null }
        Get-DependencyLicense -Name 'unknown-pkg' -Provider $provider | Should -BeNullOrEmpty
    }
}

Describe 'Test-LicenseCompliance' {
    BeforeAll {
        $script:Policy = @{
            allow = @('MIT', 'Apache-2.0', 'ISC')
            deny  = @('GPL-3.0', 'AGPL-3.0')
        }
    }

    It 'marks a license on the allow-list as approved' {
        Test-LicenseCompliance -License 'MIT' -Policy $script:Policy | Should -Be 'approved'
    }

    It 'marks a license on the deny-list as denied' {
        Test-LicenseCompliance -License 'GPL-3.0' -Policy $script:Policy | Should -Be 'denied'
    }

    It 'marks a license not on either list as unknown' {
        Test-LicenseCompliance -License 'WTFPL' -Policy $script:Policy | Should -Be 'unknown'
    }

    It 'marks a $null license as unknown' {
        Test-LicenseCompliance -License $null -Policy $script:Policy | Should -Be 'unknown'
    }

    It 'gives deny precedence when a license appears on both lists (defense-in-depth)' {
        $policy = @{ allow = @('MIT'); deny = @('MIT') }
        Test-LicenseCompliance -License 'MIT' -Policy $policy | Should -Be 'denied'
    }
}

Describe 'New-ComplianceReport' {
    BeforeAll {
        $script:Policy = Get-Content (Join-Path $script:FixturesDir 'license-policy.json') -Raw |
            ConvertFrom-Json -AsHashtable

        # Static fake license database injected as a provider. No network calls.
        # NB: `.GetNewClosure()` captures *local* variables — using a plain $db
        # here (not $script:DB) is what lets the closure see the data once the
        # scriptblock is invoked from inside the module's session state.
        $db = Get-Content (Join-Path $script:FixturesDir 'license-database.json') -Raw |
            ConvertFrom-Json -AsHashtable

        $script:Provider = {
            param($name)
            if ($db.ContainsKey($name)) { $db[$name] } else { $null }
        }.GetNewClosure()
    }

    It 'produces one report row per dependency with the expected status' {
        $manifest = Join-Path $script:FixturesDir 'package.json'
        $report = New-ComplianceReport -ManifestPath $manifest -Policy $script:Policy -Provider $script:Provider

        $report.Entries | Should -HaveCount 5
        ($report.Entries | Where-Object Name -eq 'express').Status    | Should -Be 'approved'
        ($report.Entries | Where-Object Name -eq 'gpl-lib').Status    | Should -Be 'denied'
        ($report.Entries | Where-Object Name -eq 'mystery-pkg').Status | Should -Be 'unknown'
    }

    It 'captures the license string on each entry' {
        $manifest = Join-Path $script:FixturesDir 'package.json'
        $report = New-ComplianceReport -ManifestPath $manifest -Policy $script:Policy -Provider $script:Provider

        ($report.Entries | Where-Object Name -eq 'express').License | Should -Be 'MIT'
        ($report.Entries | Where-Object Name -eq 'gpl-lib').License | Should -Be 'GPL-3.0'
        ($report.Entries | Where-Object Name -eq 'mystery-pkg').License | Should -BeNullOrEmpty
    }

    It 'computes aggregate counts in the Summary' {
        $manifest = Join-Path $script:FixturesDir 'package.json'
        $report = New-ComplianceReport -ManifestPath $manifest -Policy $script:Policy -Provider $script:Provider

        $report.Summary.Approved | Should -Be 3
        $report.Summary.Denied   | Should -Be 1
        $report.Summary.Unknown  | Should -Be 1
        $report.Summary.Total    | Should -Be 5
    }

    It 'exposes a HasViolations flag that is true when any entry is denied' {
        $manifest = Join-Path $script:FixturesDir 'package.json'
        $report = New-ComplianceReport -ManifestPath $manifest -Policy $script:Policy -Provider $script:Provider

        $report.HasViolations | Should -BeTrue
    }

    It 'HasViolations is false for a fully-compliant manifest' {
        $tmpManifest = New-TemporaryFile
        $manifestContent = @{
            name = 'clean'; version = '1.0.0'
            dependencies = @{ express = '1.0.0'; lodash = '1.0.0' }
        } | ConvertTo-Json -Depth 5
        Set-Content -Path $tmpManifest -Value $manifestContent

        try {
            $report = New-ComplianceReport -ManifestPath $tmpManifest -Policy $script:Policy -Provider $script:Provider
            $report.HasViolations | Should -BeFalse
            $report.Summary.Denied | Should -Be 0
        } finally {
            Remove-Item $tmpManifest -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Format-ComplianceReport' {
    It 'renders a report as a readable text block with status tags' {
        $report = [pscustomobject]@{
            Entries = @(
                [pscustomobject]@{ Name = 'express';     Version = '4.18.2'; License = 'MIT';     Status = 'approved'; Scope = 'prod' }
                [pscustomobject]@{ Name = 'gpl-lib';     Version = '1.0.0';  License = 'GPL-3.0'; Status = 'denied';   Scope = 'prod' }
                [pscustomobject]@{ Name = 'mystery-pkg'; Version = '0.1.0';  License = $null;     Status = 'unknown';  Scope = 'dev'  }
            )
            Summary = [pscustomobject]@{ Approved = 1; Denied = 1; Unknown = 1; Total = 3 }
            HasViolations = $true
        }

        $text = Format-ComplianceReport -Report $report
        $text | Should -Match 'express'
        $text | Should -Match 'MIT'
        $text | Should -Match 'approved'
        $text | Should -Match 'gpl-lib.*denied'
        $text | Should -Match 'mystery-pkg.*unknown'
        $text | Should -Match 'Approved:\s*1'
        $text | Should -Match 'Denied:\s*1'
        $text | Should -Match 'Unknown:\s*1'
    }
}

Describe 'Invoke-DependencyLicenseCheck (integration)' {
    It 'returns exit code 0 when no violations are found' {
        $manifestContent = @{
            name = 'clean'; version = '1.0.0'
            dependencies = @{ express = '1.0.0' }
        } | ConvertTo-Json -Depth 5
        $tmp = New-TemporaryFile
        Set-Content -Path $tmp -Value $manifestContent

        try {
            $exit = Invoke-DependencyLicenseCheck `
                -ManifestPath $tmp `
                -PolicyPath (Join-Path $script:FixturesDir 'license-policy.json') `
                -LicenseDatabasePath (Join-Path $script:FixturesDir 'license-database.json')
            $exit | Should -Be 0
        } finally { Remove-Item $tmp -ErrorAction SilentlyContinue }
    }

    It 'returns exit code 1 when a denied license is present' {
        $exit = Invoke-DependencyLicenseCheck `
            -ManifestPath (Join-Path $script:FixturesDir 'package.json') `
            -PolicyPath (Join-Path $script:FixturesDir 'license-policy.json') `
            -LicenseDatabasePath (Join-Path $script:FixturesDir 'license-database.json')

        $exit | Should -Be 1
    }

    It 'writes a report to the path given by -OutputPath' {
        $out = Join-Path ([System.IO.Path]::GetTempPath()) ("report-{0}.txt" -f ([guid]::NewGuid()))
        try {
            $null = Invoke-DependencyLicenseCheck `
                -ManifestPath (Join-Path $script:FixturesDir 'package.json') `
                -PolicyPath (Join-Path $script:FixturesDir 'license-policy.json') `
                -LicenseDatabasePath (Join-Path $script:FixturesDir 'license-database.json') `
                -OutputPath $out

            Test-Path $out | Should -BeTrue
            $content = Get-Content $out -Raw
            $content | Should -Match 'gpl-lib'
            $content | Should -Match 'denied'
        } finally {
            Remove-Item $out -ErrorAction SilentlyContinue
        }
    }
}
