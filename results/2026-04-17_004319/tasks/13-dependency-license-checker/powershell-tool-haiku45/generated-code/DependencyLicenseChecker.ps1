param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,

    [Parameter(Mandatory = $false)]
    [hashtable]$AllowedLicenses = @{},

    [Parameter(Mandatory = $false)]
    [hashtable]$DeniedLicenses = @{},

    [Parameter(Mandatory = $false)]
    [scriptblock]$LicenseLookup = $null
)

function Parse-PackageJson {
    param([string]$Path)

    $content = Get-Content -Path $Path -Raw | ConvertFrom-Json
    $dependencies = @()

    if ($content.dependencies) {
        foreach ($depName in $content.dependencies.PSObject.Properties.Name) {
            $dependencies += [PSCustomObject]@{
                Name    = $depName
                Version = $content.dependencies.$depName
            }
        }
    }

    return $dependencies
}

function Parse-RequirementsTxt {
    param([string]$Path)

    $lines = Get-Content -Path $Path
    $dependencies = @()

    foreach ($line in $lines) {
        $line = $line.Trim()
        # Skip empty lines and comments
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) {
            continue
        }

        # Parse version specifiers like ==, >=, <=, ~=, >, <
        if ($line -match '^([a-zA-Z0-9\-_\.]+)\s*([><=~!]+)\s*(.*)$') {
            $name = $matches[1]
            $version = $matches[3]
        } else {
            $name = $line
            $version = ""
        }

        $dependencies += [PSCustomObject]@{
            Name    = $name
            Version = $version
        }
    }

    return $dependencies
}

# Determine file type and parse accordingly
if ($ManifestPath -match '\.json$') {
    $dependencies = Parse-PackageJson -Path $ManifestPath
} elseif ($ManifestPath -match '\.txt$') {
    $dependencies = Parse-RequirementsTxt -Path $ManifestPath
} else {
    Write-Error "Unsupported manifest file type: $ManifestPath"
    exit 1
}

# If license lookup is provided, generate compliance report
if ($null -ne $LicenseLookup) {
    $report = foreach ($dep in $dependencies) {
        $license = & $LicenseLookup $dep.Name

        $status = "unknown"
        if ($null -ne $license) {
            if ($DeniedLicenses.ContainsKey($license)) {
                $status = "denied"
            } elseif ($AllowedLicenses.ContainsKey($license)) {
                $status = "approved"
            }
        }

        [PSCustomObject]@{
            Name    = $dep.Name
            Version = $dep.Version
            License = $license
            Status  = $status
        }
    }
    Write-Output $report
} else {
    Write-Output $dependencies
}
