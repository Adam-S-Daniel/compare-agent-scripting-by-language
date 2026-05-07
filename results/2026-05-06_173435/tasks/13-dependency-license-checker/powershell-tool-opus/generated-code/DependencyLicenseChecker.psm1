# Dependency License Checker — parses manifests, checks licenses against allow/deny lists

function Get-LicenseLookupTable {
    return @{
        'express'       = 'MIT'
        'lodash'        = 'MIT'
        'react'         = 'MIT'
        'axios'         = 'MIT'
        'moment'        = 'MIT'
        'chalk'         = 'MIT'
        'debug'         = 'MIT'
        'uuid'          = 'MIT'
        'webpack'       = 'MIT'
        'typescript'    = 'Apache-2.0'
        'angular'       = 'MIT'
        'vue'           = 'MIT'
        'jquery'        = 'MIT'
        'underscore'    = 'MIT'
        'request'       = 'Apache-2.0'
        'async'         = 'MIT'
        'bluebird'      = 'MIT'
        'commander'     = 'MIT'
        'minimist'      = 'MIT'
        'glob'          = 'ISC'
        'rimraf'        = 'ISC'
        'semver'        = 'ISC'
        'yargs'         = 'MIT'
        'mkdirp'        = 'MIT'
        'body-parser'   = 'MIT'
        'cors'          = 'MIT'
        'dotenv'        = 'BSD-2-Clause'
        'helmet'        = 'MIT'
        'jsonwebtoken'  = 'MIT'
        'bcrypt'        = 'MIT'
        'mongoose'      = 'MIT'
        'sequelize'     = 'MIT'
        'pg'            = 'MIT'
        'redis'         = 'MIT'
        'socket.io'     = 'MIT'
        'winston'       = 'MIT'
        'morgan'        = 'MIT'
        'passport'      = 'MIT'
        'multer'        = 'MIT'
        'nodemailer'    = 'MIT'
        'sharp'         = 'Apache-2.0'
        'puppeteer'     = 'Apache-2.0'
        'jest'          = 'MIT'
        'mocha'         = 'MIT'
        'chai'          = 'MIT'
        'sinon'         = 'BSD-3-Clause'
        'eslint'        = 'MIT'
        'prettier'      = 'MIT'
        'flask'         = 'BSD-3-Clause'
        'django'        = 'BSD-3-Clause'
        'requests'      = 'Apache-2.0'
        'numpy'         = 'BSD-3-Clause'
        'pandas'        = 'BSD-3-Clause'
        'scipy'         = 'BSD-3-Clause'
        'matplotlib'    = 'PSF'
        'pillow'        = 'HPND'
        'sqlalchemy'    = 'MIT'
        'celery'        = 'BSD-3-Clause'
        'pytest'        = 'MIT'
        'boto3'         = 'Apache-2.0'
        'gunicorn'      = 'MIT'
        'uvicorn'       = 'BSD-3-Clause'
        'fastapi'       = 'MIT'
        'pydantic'      = 'MIT'
        'gpl-lib'       = 'GPL-3.0'
        'agpl-pkg'      = 'AGPL-3.0'
        'lgpl-tool'     = 'LGPL-2.1'
        'unknown-pkg'   = $null
    }
}

function Get-MockLicense {
    param(
        [Parameter(Mandatory)][string]$PackageName,
        [hashtable]$LookupTable = $null
    )
    if (-not $LookupTable) {
        $LookupTable = Get-LicenseLookupTable
    }
    $key = $PackageName.ToLower().Trim()
    if ($LookupTable.ContainsKey($key)) {
        return $LookupTable[$key]
    }
    return $null
}

function Read-PackageJson {
    param(
        [Parameter(Mandatory)][string]$Path
    )
    if (-not (Test-Path $Path)) {
        throw "Manifest not found: $Path"
    }
    $content = Get-Content -Path $Path -Raw -ErrorAction Stop
    $json = $content | ConvertFrom-Json -ErrorAction Stop

    $deps = @()
    if ($json.PSObject.Properties['dependencies']) {
        $json.dependencies.PSObject.Properties | ForEach-Object {
            $deps += @{ Name = $_.Name; Version = $_.Value }
        }
    }
    if ($json.PSObject.Properties['devDependencies']) {
        $json.devDependencies.PSObject.Properties | ForEach-Object {
            $deps += @{ Name = $_.Name; Version = $_.Value }
        }
    }
    return $deps
}

function Read-RequirementsTxt {
    param(
        [Parameter(Mandatory)][string]$Path
    )
    if (-not (Test-Path $Path)) {
        throw "Manifest not found: $Path"
    }
    $lines = Get-Content -Path $Path -ErrorAction Stop
    $deps = @()
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
            continue
        }
        # Handle ==, >=, <=, ~=, !=, > , <
        if ($trimmed -match '^([A-Za-z0-9_.\-]+)\s*([><=!~]+)\s*(.+)$') {
            $deps += @{ Name = $Matches[1]; Version = "$($Matches[2])$($Matches[3].Trim())" }
        } else {
            $deps += @{ Name = $trimmed; Version = '*' }
        }
    }
    return $deps
}

function Read-DependencyManifest {
    param(
        [Parameter(Mandatory)][string]$Path
    )
    $filename = [System.IO.Path]::GetFileName($Path)
    $ext = [System.IO.Path]::GetExtension($Path).ToLower()
    if ($filename -eq 'requirements.txt') {
        return Read-RequirementsTxt -Path $Path
    } elseif ($ext -eq '.json') {
        return Read-PackageJson -Path $Path
    } else {
        throw "Unsupported manifest format: $filename"
    }
}

function Read-LicenseConfig {
    param(
        [Parameter(Mandatory)][string]$Path
    )
    if (-not (Test-Path $Path)) {
        throw "Config file not found: $Path"
    }
    $content = Get-Content -Path $Path -Raw -ErrorAction Stop
    $json = $content | ConvertFrom-Json -ErrorAction Stop

    $config = @{
        AllowList = @()
        DenyList  = @()
    }
    if ($json.PSObject.Properties['allowList']) {
        $config.AllowList = @($json.allowList)
    }
    if ($json.PSObject.Properties['denyList']) {
        $config.DenyList = @($json.denyList)
    }
    return $config
}

function Get-LicenseStatus {
    param(
        [Parameter(Mandatory)][string]$License,
        [Parameter(Mandatory)][hashtable]$Config
    )
    $upper = $License.ToUpper()
    foreach ($denied in $Config.DenyList) {
        if ($denied.ToUpper() -eq $upper) { return 'denied' }
    }
    foreach ($allowed in $Config.AllowList) {
        if ($allowed.ToUpper() -eq $upper) { return 'approved' }
    }
    return 'unknown'
}

function New-ComplianceReport {
    param(
        [Parameter(Mandatory)][array]$Dependencies,
        [Parameter(Mandatory)][hashtable]$Config,
        [hashtable]$LookupTable = $null
    )
    $results = @()
    foreach ($dep in $Dependencies) {
        $license = Get-MockLicense -PackageName $dep.Name -LookupTable $LookupTable
        if ($null -eq $license -or $license -eq '') {
            $status = 'unknown'
            $licenseDisplay = 'UNKNOWN'
        } else {
            $status = Get-LicenseStatus -License $license -Config $Config
            $licenseDisplay = $license
        }
        $results += [PSCustomObject]@{
            Name    = $dep.Name
            Version = $dep.Version
            License = $licenseDisplay
            Status  = $status
        }
    }
    return $results
}

function Format-ComplianceReport {
    param(
        [Parameter(Mandatory)][array]$Report
    )
    $output = @()
    $output += "=" * 70
    $output += "DEPENDENCY LICENSE COMPLIANCE REPORT"
    $output += "=" * 70
    $output += ""

    $approved = @($Report | Where-Object { $_.Status -eq 'approved' })
    $denied   = @($Report | Where-Object { $_.Status -eq 'denied' })
    $unknown  = @($Report | Where-Object { $_.Status -eq 'unknown' })

    $output += "Summary: $($Report.Count) dependencies checked"
    $output += "  Approved: $($approved.Count)"
    $output += "  Denied:   $($denied.Count)"
    $output += "  Unknown:  $($unknown.Count)"
    $output += ""

    if ($denied.Count -gt 0) {
        $output += "-" * 70
        $output += "DENIED DEPENDENCIES"
        $output += "-" * 70
        foreach ($d in $denied) {
            $output += "  [DENIED]   $($d.Name)@$($d.Version) - License: $($d.License)"
        }
        $output += ""
    }

    if ($unknown.Count -gt 0) {
        $output += "-" * 70
        $output += "UNKNOWN DEPENDENCIES"
        $output += "-" * 70
        foreach ($u in $unknown) {
            $output += "  [UNKNOWN]  $($u.Name)@$($u.Version) - License: $($u.License)"
        }
        $output += ""
    }

    if ($approved.Count -gt 0) {
        $output += "-" * 70
        $output += "APPROVED DEPENDENCIES"
        $output += "-" * 70
        foreach ($a in $approved) {
            $output += "  [APPROVED] $($a.Name)@$($a.Version) - License: $($a.License)"
        }
        $output += ""
    }

    $output += "=" * 70
    if ($denied.Count -gt 0) {
        $output += "RESULT: FAIL - $($denied.Count) denied license(s) found"
    } else {
        $output += "RESULT: PASS - No denied licenses found"
    }
    $output += "=" * 70

    return $output -join "`n"
}

function Invoke-LicenseCheck {
    param(
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][string]$ConfigPath,
        [hashtable]$LookupTable = $null
    )
    $deps = Read-DependencyManifest -Path $ManifestPath
    if ($deps.Count -eq 0) {
        Write-Host "No dependencies found in $ManifestPath"
        return @()
    }
    $config = Read-LicenseConfig -Path $ConfigPath
    $report = New-ComplianceReport -Dependencies $deps -Config $config -LookupTable $LookupTable
    $formatted = Format-ComplianceReport -Report $report
    Write-Host $formatted
    return $report
}

Export-ModuleMember -Function *
