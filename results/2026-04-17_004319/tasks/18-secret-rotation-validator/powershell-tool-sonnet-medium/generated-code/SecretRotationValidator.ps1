# SecretRotationValidator.ps1
#
# Validates secrets against rotation policies.
# Functions: Get-SecretStatus, Invoke-SecretRotationValidator, Format-RotationReport

function Get-SecretStatus {
    <#
    .SYNOPSIS
        Determines rotation status (expired / warning / ok) for a single secret.
    .PARAMETER Secret
        Hashtable with keys: Name, LastRotated (yyyy-MM-dd), RotationPolicyDays, RequiredBy.
    .PARAMETER WarningWindowDays
        Number of days before expiry to begin warning. Default 14.
    .PARAMETER ReferenceDate
        Date to treat as "today". Defaults to current date; override for deterministic tests.
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Secret,

        [int]$WarningWindowDays = 14,

        [datetime]$ReferenceDate = (Get-Date)
    )

    if (-not $Secret.ContainsKey('LastRotated') -or -not $Secret.ContainsKey('RotationPolicyDays')) {
        throw "Secret '$($Secret.Name)': missing required fields LastRotated and/or RotationPolicyDays."
    }

    try {
        $lastRotated = [datetime]::Parse($Secret.LastRotated).Date
    }
    catch {
        throw "Secret '$($Secret.Name)': invalid date format '$($Secret.LastRotated)'. Expected yyyy-MM-dd."
    }

    $today       = $ReferenceDate.Date
    $expiryDate  = $lastRotated.AddDays($Secret.RotationPolicyDays)
    # Negative when expired, positive when time remains.
    $daysUntilExpiry = ($expiryDate - $today).Days

    if ($daysUntilExpiry -le 0) {
        return @{
            Status          = "expired"
            ExpiryDate      = $expiryDate
            DaysOverdue     = [math]::Abs($daysUntilExpiry)
            DaysUntilExpiry = $null
        }
    }
    elseif ($daysUntilExpiry -le $WarningWindowDays) {
        return @{
            Status          = "warning"
            ExpiryDate      = $expiryDate
            DaysOverdue     = $null
            DaysUntilExpiry = $daysUntilExpiry
        }
    }
    else {
        return @{
            Status          = "ok"
            ExpiryDate      = $expiryDate
            DaysOverdue     = $null
            DaysUntilExpiry = $daysUntilExpiry
        }
    }
}

function Invoke-SecretRotationValidator {
    <#
    .SYNOPSIS
        Processes all secrets and groups them by urgency: Expired, Warning, Ok.
    .PARAMETER Secrets
        Array of secret hashtables (Name, LastRotated, RotationPolicyDays, RequiredBy).
    .PARAMETER WarningWindowDays
        Warning window in days. Default 14.
    .PARAMETER ReferenceDate
        Reference date for status calculation. Defaults to today.
    #>
    param(
        [Parameter(Mandatory)]
        [array]$Secrets,

        [int]$WarningWindowDays = 14,

        [datetime]$ReferenceDate = (Get-Date)
    )

    $results = @{
        Expired           = [System.Collections.Generic.List[hashtable]]::new()
        Warning           = [System.Collections.Generic.List[hashtable]]::new()
        Ok                = [System.Collections.Generic.List[hashtable]]::new()
        WarningWindowDays = $WarningWindowDays
        ReferenceDate     = $ReferenceDate.Date.ToString("yyyy-MM-dd")
    }

    foreach ($secret in $Secrets) {
        $status = Get-SecretStatus -Secret $secret `
                                   -WarningWindowDays $WarningWindowDays `
                                   -ReferenceDate $ReferenceDate

        $entry = @{
            Name               = $secret.Name
            LastRotated        = $secret.LastRotated
            RotationPolicyDays = $secret.RotationPolicyDays
            RequiredBy         = $secret.RequiredBy
            Status             = $status.Status
            ExpiryDate         = $status.ExpiryDate.ToString("yyyy-MM-dd")
            DaysOverdue        = $status.DaysOverdue
            DaysUntilExpiry    = $status.DaysUntilExpiry
        }

        switch ($status.Status) {
            "expired" { $results.Expired.Add($entry) }
            "warning" { $results.Warning.Add($entry) }
            "ok"      { $results.Ok.Add($entry)      }
        }
    }

    return $results
}

function Format-RotationReport {
    <#
    .SYNOPSIS
        Renders a rotation report as a Markdown table or JSON document.
    .PARAMETER Results
        Output of Invoke-SecretRotationValidator.
    .PARAMETER Format
        "Markdown" (default) or "JSON".
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Results,

        [ValidateSet("Markdown", "JSON")]
        [string]$Format = "Markdown"
    )

    if ($Format -eq "JSON") {
        $doc = [ordered]@{
            generatedAt       = $Results.ReferenceDate
            warningWindowDays = $Results.WarningWindowDays
            summary           = [ordered]@{
                expired = $Results.Expired.Count
                warning = $Results.Warning.Count
                ok      = $Results.Ok.Count
            }
            expired = @($Results.Expired | ForEach-Object {
                [ordered]@{
                    name               = $_.Name
                    lastRotated        = $_.LastRotated
                    expiryDate         = $_.ExpiryDate
                    daysOverdue        = $_.DaysOverdue
                    rotationPolicyDays = $_.RotationPolicyDays
                    requiredBy         = @($_.RequiredBy)
                }
            })
            warning = @($Results.Warning | ForEach-Object {
                [ordered]@{
                    name               = $_.Name
                    lastRotated        = $_.LastRotated
                    expiryDate         = $_.ExpiryDate
                    daysUntilExpiry    = $_.DaysUntilExpiry
                    rotationPolicyDays = $_.RotationPolicyDays
                    requiredBy         = @($_.RequiredBy)
                }
            })
            ok = @($Results.Ok | ForEach-Object {
                [ordered]@{
                    name               = $_.Name
                    lastRotated        = $_.LastRotated
                    expiryDate         = $_.ExpiryDate
                    daysUntilExpiry    = $_.DaysUntilExpiry
                    rotationPolicyDays = $_.RotationPolicyDays
                    requiredBy         = @($_.RequiredBy)
                }
            })
        }
        return $doc | ConvertTo-Json -Depth 5
    }

    # Markdown
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("# Secret Rotation Report")
    $lines.Add("")
    $lines.Add("**Generated:** $($Results.ReferenceDate)")
    $lines.Add("**Warning Window:** $($Results.WarningWindowDays) days")
    $lines.Add("")
    $lines.Add("## Summary")
    $lines.Add("")
    $lines.Add("| Status  | Count |")
    $lines.Add("|---------|-------|")
    $lines.Add("| EXPIRED | $($Results.Expired.Count) |")
    $lines.Add("| WARNING | $($Results.Warning.Count) |")
    $lines.Add("| OK      | $($Results.Ok.Count) |")
    $lines.Add("")

    # Helper closure to emit a table section
    function Write-Section {
        param([string]$Header, [object]$Secrets, [string]$EmptyMsg, [bool]$ShowOverdue)
        $lines.Add($Header)
        $lines.Add("")
        if ($Secrets.Count -eq 0) {
            $lines.Add("_${EmptyMsg}_")
        }
        elseif ($ShowOverdue) {
            $lines.Add("| Secret Name | Last Rotated | Expiry Date | Days Overdue | Required By |")
            $lines.Add("|-------------|-------------|-------------|-------------|-------------|")
            foreach ($s in $Secrets) {
                $rb = ($s.RequiredBy -join ", ")
                $lines.Add("| $($s.Name) | $($s.LastRotated) | $($s.ExpiryDate) | $($s.DaysOverdue) | $rb |")
            }
        }
        else {
            $lines.Add("| Secret Name | Last Rotated | Expiry Date | Days Until Expiry | Required By |")
            $lines.Add("|-------------|-------------|-------------|------------------|-------------|")
            foreach ($s in $Secrets) {
                $rb = ($s.RequiredBy -join ", ")
                $lines.Add("| $($s.Name) | $($s.LastRotated) | $($s.ExpiryDate) | $($s.DaysUntilExpiry) | $rb |")
            }
        }
        $lines.Add("")
    }

    $expiredCount = $Results.Expired.Count
    $warnCount    = $Results.Warning.Count
    $okCount      = $Results.Ok.Count

    Write-Section -Header "## EXPIRED ($expiredCount secret$(if ($expiredCount -ne 1){'s'}) require$(if ($expiredCount -eq 1){'s'}) immediate rotation)" `
                  -Secrets $Results.Expired `
                  -EmptyMsg "No expired secrets." `
                  -ShowOverdue $true

    Write-Section -Header "## WARNING ($warnCount secret$(if ($warnCount -ne 1){'s'}) expiring soon)" `
                  -Secrets $Results.Warning `
                  -EmptyMsg "No secrets expiring soon." `
                  -ShowOverdue $false

    Write-Section -Header "## OK ($okCount secret$(if ($okCount -ne 1){'s'}) healthy)" `
                  -Secrets $Results.Ok `
                  -EmptyMsg "No healthy secrets." `
                  -ShowOverdue $false

    return $lines -join "`n"
}
