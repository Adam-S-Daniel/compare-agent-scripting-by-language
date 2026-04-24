# LicenseChecker.psm1
#
# PowerShell module implementing a dependency license checker. Built iteratively
# via TDD — see tests/LicenseChecker.Tests.ps1 for the driving specifications.
#
# Public surface:
#   Get-ManifestDependencies   Parse package.json or requirements.txt
#   Test-LicenseCompliance     Classify a license against allow/deny lists
#   Invoke-LicenseCheck        End-to-end: parse manifest, look up licenses, classify
#   Get-LicenseSummary         Counts of approved/denied/unknown in a report
#   Format-LicenseReport       Render a report as aligned plain text
#
# The license lookup is injectable so production callers can wire in a real
# registry client while tests mock it with a simple JSON table.

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function Get-ManifestDependencies {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Manifest file not found: $Path"
    }

    $fileName = Split-Path -Leaf $Path

    switch -Regex ($fileName) {
        '^package\.json$'      { return (Read-PackageJson -Path $Path) }
        '^requirements\.txt$'  { return (Read-RequirementsTxt -Path $Path) }
        default {
            throw "Unsupported manifest file: $fileName (supported: package.json, requirements.txt)"
        }
    }
}

function Read-PackageJson {
    param([string]$Path)

    $raw = Get-Content -Raw -LiteralPath $Path
    try {
        $obj = $raw | ConvertFrom-Json
    } catch {
        throw "Failed to parse JSON in $Path`: $($_.Exception.Message)"
    }

    # Collect dependencies and devDependencies into one ordered dictionary so
    # the caller gets a single flat list. Last-write-wins on duplicate names.
    $map = [ordered]@{}
    foreach ($section in @('dependencies','devDependencies')) {
        if (-not $obj.PSObject.Properties[$section]) { continue }
        $bucket = $obj.$section
        if ($null -eq $bucket) { continue }
        foreach ($prop in $bucket.PSObject.Properties) {
            $map[$prop.Name] = [string]$prop.Value
        }
    }

    $result = foreach ($k in $map.Keys) {
        [PSCustomObject]@{ Name = $k; Version = $map[$k] }
    }
    return ,@($result)
}

function Read-RequirementsTxt {
    param([string]$Path)

    $result = New-Object System.Collections.Generic.List[object]
    foreach ($rawLine in Get-Content -LiteralPath $Path) {
        # Strip inline comments first, then whitespace.
        $line = ($rawLine -split '#',2)[0].Trim()
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        if ($line -match '^([A-Za-z0-9][A-Za-z0-9._\-]*)\s*(==|>=|<=|~=|!=|<|>)\s*([^\s;]+)') {
            $result.Add([PSCustomObject]@{ Name = $Matches[1]; Version = $Matches[3] })
        } elseif ($line -match '^([A-Za-z0-9][A-Za-z0-9._\-]*)\s*$') {
            # No version specifier — treat as any version.
            $result.Add([PSCustomObject]@{ Name = $Matches[1]; Version = '*' })
        } else {
            Write-Verbose "Skipping unrecognized line: $rawLine"
        }
    }
    return ,@($result.ToArray())
}

function Test-LicenseCompliance {
    [CmdletBinding()]
    param(
        [AllowNull()][AllowEmptyString()][string]$License,
        [string[]]$AllowList = @(),
        [string[]]$DenyList  = @()
    )

    if ([string]::IsNullOrWhiteSpace($License)) { return 'unknown' }
    # Deny list wins over allow list — a license flagged denied is always denied
    # even if someone accidentally added it to both.
    if ($DenyList  -contains $License) { return 'denied' }
    if ($AllowList -contains $License) { return 'approved' }
    return 'unknown'
}

function Invoke-LicenseCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][string]$ConfigPath,
        # Path to a JSON file mapping package name -> license string. Simulates
        # the output of a real registry client; swap with a live lookup in prod.
        [string]$LicenseDataPath,
        # Optional override: scriptblock that takes a package name and returns
        # a license string (or $null). Wins over $LicenseDataPath if provided.
        [scriptblock]$LicenseLookup
    )

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "License config file not found: $ConfigPath"
    }
    try {
        $config = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json
    } catch {
        throw "Failed to parse license config JSON at $ConfigPath`: $($_.Exception.Message)"
    }

    $allow = @()
    $deny  = @()
    if ($config.PSObject.Properties['allow'] -and $null -ne $config.allow) { $allow = @($config.allow) }
    if ($config.PSObject.Properties['deny']  -and $null -ne $config.deny)  { $deny  = @($config.deny) }

    # Build the license lookup: explicit scriptblock wins, else JSON data file,
    # else an empty table (every package resolves to unknown).
    $lookup = $null
    if ($LicenseLookup) {
        $lookup = $LicenseLookup
    } else {
        $table = @{}
        if ($LicenseDataPath -and (Test-Path -LiteralPath $LicenseDataPath)) {
            try {
                $data = Get-Content -Raw -LiteralPath $LicenseDataPath | ConvertFrom-Json
            } catch {
                throw "Failed to parse license data JSON at $LicenseDataPath`: $($_.Exception.Message)"
            }
            foreach ($prop in $data.PSObject.Properties) {
                $table[$prop.Name] = [string]$prop.Value
            }
        }
        $lookup = { param($n) $table[$n] }.GetNewClosure()
    }

    $deps = Get-ManifestDependencies -Path $ManifestPath

    $report = foreach ($dep in $deps) {
        $license = & $lookup $dep.Name
        $status  = Test-LicenseCompliance -License $license -AllowList $allow -DenyList $deny
        [PSCustomObject]@{
            Name    = $dep.Name
            Version = $dep.Version
            License = $license
            Status  = $status
        }
    }
    return ,@($report)
}

function Get-LicenseSummary {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object[]]$Report)

    $approved = 0; $denied = 0; $unknown = 0
    foreach ($row in $Report) {
        switch ($row.Status) {
            'approved' { $approved++ }
            'denied'   { $denied++ }
            'unknown'  { $unknown++ }
        }
    }
    [PSCustomObject]@{
        Approved = $approved
        Denied   = $denied
        Unknown  = $unknown
        Total    = $Report.Count
    }
}

function Format-LicenseReport {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object[]]$Report)

    $lines = @()
    $lines += 'Dependency License Compliance Report'
    $lines += ('=' * 60)
    $header = '{0,-25} {1,-12} {2,-18} {3}' -f 'Name','Version','License','Status'
    $lines += $header
    $lines += ('-' * 60)
    foreach ($row in $Report) {
        $license = if ([string]::IsNullOrEmpty($row.License)) { '<none>' } else { $row.License }
        $lines += ('{0,-25} {1,-12} {2,-18} {3}' -f $row.Name, $row.Version, $license, $row.Status)
    }
    $summary = Get-LicenseSummary -Report $Report
    $lines += ('-' * 60)
    $lines += "Totals: approved=$($summary.Approved) denied=$($summary.Denied) unknown=$($summary.Unknown) total=$($summary.Total)"
    return ($lines -join [Environment]::NewLine)
}

Export-ModuleMember -Function `
    Get-ManifestDependencies, `
    Test-LicenseCompliance, `
    Invoke-LicenseCheck, `
    Get-LicenseSummary, `
    Format-LicenseReport
