# LicenseChecker.psm1
# Module providing license compliance checking for package.json dependencies.
# License lookups go through Get-PackageLicense which tests mock via Pester.

Set-StrictMode -Version Latest

function Get-DependenciesFromManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Manifest file not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    try {
        $manifest = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse manifest as JSON: $($_.Exception.Message)"
    }

    $result = [System.Collections.Generic.List[object]]::new()
    foreach ($section in @('dependencies', 'devDependencies')) {
        if ($manifest.PSObject.Properties.Name -contains $section -and $manifest.$section) {
            foreach ($prop in $manifest.$section.PSObject.Properties) {
                $result.Add([pscustomobject]@{
                    Name    = $prop.Name
                    Version = [string]$prop.Value
                    Scope   = $section
                })
            }
        }
    }
    return ,$result.ToArray()
}

function Get-PackageLicense {
    # Default implementation returns 'UNKNOWN'. Tests mock this to return
    # deterministic values; a production script could swap in a registry call.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Version
    )
    return 'UNKNOWN'
}

function Test-LicenseCompliance {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$License,
        [Parameter(Mandatory)][string[]]$AllowList,
        [Parameter(Mandatory)][string[]]$DenyList
    )

    if ([string]::IsNullOrWhiteSpace($License) -or $License -eq 'UNKNOWN') {
        return 'unknown'
    }
    if ($DenyList -contains $License)  { return 'denied' }
    if ($AllowList -contains $License) { return 'approved' }
    return 'unknown'
}

function Invoke-LicenseCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][string]$ConfigPath
    )

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }

    $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
    $allow = @($config.allow)
    $deny  = @($config.deny)

    $deps = Get-DependenciesFromManifest -Path $ManifestPath

    $entries = foreach ($d in $deps) {
        $license = Get-PackageLicense -Name $d.Name -Version $d.Version
        $status  = Test-LicenseCompliance -License $license -AllowList $allow -DenyList $deny
        [pscustomobject]@{
            name    = $d.Name
            version = $d.Version
            license = $license
            status  = $status
        }
    }

    $entries = @($entries)

    $summary = [pscustomobject]@{
        total    = $entries.Count
        approved = @($entries | Where-Object { $_.status -eq 'approved' }).Count
        denied   = @($entries | Where-Object { $_.status -eq 'denied'   }).Count
        unknown  = @($entries | Where-Object { $_.status -eq 'unknown'  }).Count
    }

    return [pscustomobject]@{
        summary      = $summary
        dependencies = $entries
    }
}

Export-ModuleMember -Function Get-DependenciesFromManifest, Get-PackageLicense,
                              Test-LicenseCompliance, Invoke-LicenseCheck
