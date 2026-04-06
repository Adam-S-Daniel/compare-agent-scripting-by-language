# DependencyLicenseChecker.psm1
# Module that parses dependency manifests, checks licenses against allow/deny
# lists, and generates compliance reports. Designed for testability — license
# lookup is injected as a scriptblock so it can be mocked in tests.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --------------------------------------------------------------------------
# Read-DependencyManifest
# Parses a dependency manifest file and returns an array of dependency objects
# with Name and Version properties. Supports package.json and requirements.txt.
# --------------------------------------------------------------------------
function Read-DependencyManifest {
    [CmdletBinding()]
    [OutputType([PSObject[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    # Validate the file exists
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Manifest file does not exist: $Path"
    }

    [string]$fileName = [System.IO.Path]::GetFileName($Path)
    [string]$extension = [System.IO.Path]::GetExtension($Path).ToLower()

    # Dispatch based on file type
    if ($fileName -eq 'package.json' -or ($extension -eq '.json' -and $fileName -like '*package*')) {
        return [PSObject[]](Read-PackageJson -Path $Path)
    }
    elseif ($fileName -like 'requirements*.txt' -or ($extension -eq '.txt' -and $fileName -like '*requirements*')) {
        return [PSObject[]](Read-RequirementsTxt -Path $Path)
    }
    else {
        throw "Unsupported manifest format: $fileName. Supported: package.json, requirements.txt"
    }
}

# --------------------------------------------------------------------------
# Read-PackageJson (private helper)
# Parses a Node.js package.json and extracts dependencies + devDependencies.
# --------------------------------------------------------------------------
function Read-PackageJson {
    [CmdletBinding()]
    [OutputType([PSObject[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    [string]$content = Get-Content -LiteralPath $Path -Raw

    try {
        [PSObject]$pkg = $content | ConvertFrom-Json
    }
    catch {
        throw "Failed to parse package.json: $($_.Exception.Message)"
    }

    [System.Collections.Generic.List[PSObject]]$deps = [System.Collections.Generic.List[PSObject]]::new()

    # Build a set of property names so we can check existence without
    # triggering strict mode errors on missing properties
    [string[]]$propNames = @($pkg.PSObject.Properties | ForEach-Object { $_.Name })

    # Extract from dependencies
    if ($propNames -contains 'dependencies') {
        [PSObject]$depsObj = $pkg.dependencies
        foreach ($prop in $depsObj.PSObject.Properties) {
            [PSObject]$entry = [PSCustomObject]@{
                Name    = [string]$prop.Name
                Version = [string]$prop.Value
            }
            $deps.Add($entry)
        }
    }

    # Extract from devDependencies
    if ($propNames -contains 'devDependencies') {
        [PSObject]$devDepsObj = $pkg.devDependencies
        foreach ($prop in $devDepsObj.PSObject.Properties) {
            [PSObject]$entry = [PSCustomObject]@{
                Name    = [string]$prop.Name
                Version = [string]$prop.Value
            }
            $deps.Add($entry)
        }
    }

    return [PSObject[]]$deps.ToArray()
}

# --------------------------------------------------------------------------
# Read-RequirementsTxt (private helper)
# Parses a Python requirements.txt. Skips comments, blank lines, and flags
# like -e, -r, --index-url, etc.
# --------------------------------------------------------------------------
function Read-RequirementsTxt {
    [CmdletBinding()]
    [OutputType([PSObject[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    [string[]]$lines = Get-Content -LiteralPath $Path

    [System.Collections.Generic.List[PSObject]]$deps = [System.Collections.Generic.List[PSObject]]::new()

    foreach ($rawLine in $lines) {
        [string]$line = $rawLine.Trim()

        # Skip blank lines, comments, and pip flags (-e, -r, --index-url, etc.)
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line.StartsWith('#')) { continue }
        if ($line.StartsWith('-')) { continue }

        # Parse name and version. Supported operators: ==, >=, <=, ~=, !=, >, <
        # Format: package_name[extras]<operator>version
        # Use regex to split name from version specifier
        [regex]$versionPattern = [regex]::new('^([A-Za-z0-9_.-]+)(?:\[.*?\])?\s*((?:==|>=|<=|~=|!=|>|<).+)?$')
        [System.Text.RegularExpressions.Match]$match = $versionPattern.Match($line)

        if ($match.Success) {
            [string]$name = $match.Groups[1].Value.ToLower()
            [string]$version = if ($match.Groups[2].Success) { $match.Groups[2].Value.Trim() } else { '*' }

            [PSObject]$entry = [PSCustomObject]@{
                Name    = $name
                Version = $version
            }
            $deps.Add($entry)
        }
        # If the line doesn't match the pattern, skip it (could be a URL or other directive)
    }

    return [PSObject[]]$deps.ToArray()
}

# --------------------------------------------------------------------------
# Read-LicenseConfig
# Reads a JSON configuration file containing allowList and denyList arrays.
# Returns an object with AllowList and DenyList string array properties.
# --------------------------------------------------------------------------
function Read-LicenseConfig {
    [CmdletBinding()]
    [OutputType([PSObject])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "License config file does not exist: $Path"
    }

    [string]$content = Get-Content -LiteralPath $Path -Raw

    try {
        [PSObject]$raw = $content | ConvertFrom-Json
    }
    catch {
        throw "Failed to parse license config: $($_.Exception.Message)"
    }

    # Normalize to string arrays — handle both 'allowList'/'denyList' and
    # 'AllowList'/'DenyList' property names from the JSON
    [string[]]$allowList = @()
    if ($null -ne $raw.allowList) {
        $allowList = [string[]]@($raw.allowList)
    }
    elseif ($null -ne $raw.AllowList) {
        $allowList = [string[]]@($raw.AllowList)
    }

    [string[]]$denyList = @()
    if ($null -ne $raw.denyList) {
        $denyList = [string[]]@($raw.denyList)
    }
    elseif ($null -ne $raw.DenyList) {
        $denyList = [string[]]@($raw.DenyList)
    }

    [PSObject]$config = [PSCustomObject]@{
        AllowList = $allowList
        DenyList  = $denyList
    }

    return $config
}

# --------------------------------------------------------------------------
# Get-DependencyLicense
# Looks up the license for a given dependency using an injected scriptblock.
# The scriptblock receives (Name, Version) and should return a license string.
# If the lookup fails or returns null, returns 'UNKNOWN'.
# --------------------------------------------------------------------------
function Get-DependencyLicense {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Version,

        [Parameter(Mandatory)]
        [scriptblock]$LicenseLookup
    )

    try {
        [object]$result = & $LicenseLookup $Name $Version
        if ($null -eq $result -or [string]::IsNullOrWhiteSpace([string]$result)) {
            return [string]'UNKNOWN'
        }
        return [string]$result
    }
    catch {
        # Gracefully handle lookup errors — the dependency license is unknown
        Write-Warning "License lookup failed for '$Name@$Version': $($_.Exception.Message)"
        return [string]'UNKNOWN'
    }
}

# --------------------------------------------------------------------------
# Test-LicenseCompliance
# Checks a license identifier against allow and deny lists.
# Returns 'Approved', 'Denied', or 'Unknown'.
# Deny list takes precedence if a license appears in both lists.
# Matching is case-insensitive.
# --------------------------------------------------------------------------
function Test-LicenseCompliance {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$License,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$AllowList,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$DenyList
    )

    [string]$normalizedLicense = $License.Trim()

    # Deny list takes precedence — check it first
    foreach ($denied in $DenyList) {
        if ([string]::Equals($normalizedLicense, $denied, [System.StringComparison]::OrdinalIgnoreCase)) {
            return [string]'Denied'
        }
    }

    # Check allow list
    foreach ($allowed in $AllowList) {
        if ([string]::Equals($normalizedLicense, $allowed, [System.StringComparison]::OrdinalIgnoreCase)) {
            return [string]'Approved'
        }
    }

    # License is not on either list
    return [string]'Unknown'
}

# --------------------------------------------------------------------------
# New-ComplianceReport
# Orchestrates the full compliance check: parses the manifest, reads config,
# looks up each dependency's license, checks compliance, and returns a
# structured report object.
# --------------------------------------------------------------------------
function New-ComplianceReport {
    [CmdletBinding()]
    [OutputType([PSObject])]
    param(
        [Parameter(Mandatory)]
        [string]$ManifestPath,

        [Parameter(Mandatory)]
        [string]$ConfigPath,

        [Parameter(Mandatory)]
        [scriptblock]$LicenseLookup
    )

    # Parse inputs
    [PSObject[]]$dependencies = Read-DependencyManifest -Path $ManifestPath
    [PSObject]$config = Read-LicenseConfig -Path $ConfigPath

    # Process each dependency
    [System.Collections.Generic.List[PSObject]]$entries = [System.Collections.Generic.List[PSObject]]::new()
    [int]$approvedCount = 0
    [int]$deniedCount = 0
    [int]$unknownCount = 0

    foreach ($dep in $dependencies) {
        [string]$license = Get-DependencyLicense -Name $dep.Name -Version $dep.Version -LicenseLookup $LicenseLookup
        [string]$status = Test-LicenseCompliance -License $license -AllowList $config.AllowList -DenyList $config.DenyList

        [PSObject]$entry = [PSCustomObject]@{
            Name    = [string]$dep.Name
            Version = [string]$dep.Version
            License = [string]$license
            Status  = [string]$status
        }
        $entries.Add($entry)

        # Tally summary counts
        switch ($status) {
            'Approved' { $approvedCount++ }
            'Denied'   { $deniedCount++ }
            'Unknown'  { $unknownCount++ }
        }
    }

    [PSObject]$report = [PSCustomObject]@{
        ManifestPath = [string]$ManifestPath
        Timestamp    = [string](Get-Date -Format 'o')
        Dependencies = [PSObject[]]$entries.ToArray()
        Summary      = [PSCustomObject]@{
            Total    = [int]$entries.Count
            Approved = [int]$approvedCount
            Denied   = [int]$deniedCount
            Unknown  = [int]$unknownCount
        }
    }

    return $report
}

# --------------------------------------------------------------------------
# Export-ComplianceReport
# Serializes a compliance report object to a string in the specified format.
# Supported formats: JSON, Text.
# --------------------------------------------------------------------------
function Export-ComplianceReport {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [PSObject]$Report,

        [Parameter(Mandatory)]
        [ValidateSet('JSON', 'Text')]
        [string]$Format
    )

    switch ($Format) {
        'JSON' {
            return [string]($Report | ConvertTo-Json -Depth 10)
        }
        'Text' {
            [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
            [void]$sb.AppendLine('========================================')
            [void]$sb.AppendLine('  Dependency License Compliance Report')
            [void]$sb.AppendLine('========================================')
            [void]$sb.AppendLine("Manifest: $($Report.ManifestPath)")
            [void]$sb.AppendLine("Generated: $($Report.Timestamp)")
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine('Dependencies:')
            [void]$sb.AppendLine('----------------------------------------')

            foreach ($dep in $Report.Dependencies) {
                [string]$statusMarker = switch ($dep.Status) {
                    'Approved' { '[PASS]' }
                    'Denied'   { '[FAIL]' }
                    'Unknown'  { '[????]' }
                }
                [void]$sb.AppendLine("  $statusMarker $($dep.Name)@$($dep.Version) — $($dep.License) ($($dep.Status))")
            }

            [void]$sb.AppendLine('')
            [void]$sb.AppendLine('Summary:')
            [void]$sb.AppendLine("  Total:    $($Report.Summary.Total)")
            [void]$sb.AppendLine("  Approved: $($Report.Summary.Approved)")
            [void]$sb.AppendLine("  Denied:   $($Report.Summary.Denied)")
            [void]$sb.AppendLine("  Unknown:  $($Report.Summary.Unknown)")
            [void]$sb.AppendLine('========================================')

            return [string]$sb.ToString()
        }
    }
}

# Export public functions
Export-ModuleMember -Function @(
    'Read-DependencyManifest'
    'Read-LicenseConfig'
    'Get-DependencyLicense'
    'Test-LicenseCompliance'
    'New-ComplianceReport'
    'Export-ComplianceReport'
)
