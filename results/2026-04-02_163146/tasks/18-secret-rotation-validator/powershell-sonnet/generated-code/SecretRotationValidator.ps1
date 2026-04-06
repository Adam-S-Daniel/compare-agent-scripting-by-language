# SecretRotationValidator.ps1
# Secret Rotation Validator — implementation
#
# This module provides functions for:
#   - Classifying secrets by rotation status (Expired / Warning / Ok)
#   - Generating a grouped rotation report
#   - Formatting the report as Markdown or JSON
#   - Loading secret configuration from a JSON file

# ============================================================
# FUNCTION: Get-SecretStatus
#
# Classifies a single secret based on its rotation policy and
# how far past (or close to) its expiry date it currently is.
#
# Parameters:
#   -Secret           hashtable with Name, LastRotated, RotationPolicyDays, RequiredBy
#   -ReferenceDate    the "today" date used for comparison (defaults to [datetime]::Today)
#   -WarningWindowDays number of days before expiry at which to emit a Warning (default: 14)
#
# Returns a hashtable with:
#   Name, Status, ExpiryDate, DaysUntilExpiry, LastRotated, RotationPolicyDays, RequiredBy
# ============================================================
function Get-SecretStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Secret,

        [Parameter()]
        [datetime]$ReferenceDate = [datetime]::Today,

        [Parameter()]
        [int]$WarningWindowDays = 14
    )

    # --- Validate required fields ---
    if (-not $Secret.ContainsKey('Name') -or [string]::IsNullOrWhiteSpace($Secret.Name)) {
        throw "Secret configuration is missing the required 'Name' field."
    }

    if (-not $Secret.ContainsKey('LastRotated') -or [string]::IsNullOrWhiteSpace($Secret['LastRotated'])) {
        throw "Secret '$($Secret.Name)' is missing the required 'LastRotated' field."
    }

    if (-not $Secret.ContainsKey('RotationPolicyDays')) {
        throw "Secret '$($Secret.Name)' is missing the required 'RotationPolicyDays' field."
    }

    # Parse the last-rotated date (supports ISO 8601 strings)
    $lastRotated = $null
    try {
        $lastRotated = [datetime]::Parse($Secret.LastRotated)
    }
    catch {
        throw "Secret '$($Secret.Name)' has an invalid LastRotated date: '$($Secret.LastRotated)'. Expected a parseable date string."
    }

    # Validate rotation policy is positive
    $policyDays = [int]$Secret.RotationPolicyDays
    if ($policyDays -le 0) {
        throw "Secret '$($Secret.Name)' has an invalid RotationPolicyDays value: '$policyDays'. Must be a positive integer."
    }

    # --- Calculate derived values ---
    $expiryDate      = $lastRotated.AddDays($policyDays)
    $daysUntilExpiry = [int]($expiryDate - $ReferenceDate).TotalDays  # negative = already expired

    # --- Classify status ---
    # daysUntilExpiry <= 0  → already expired (or expires today → Expired)
    # 0 < daysUntilExpiry <= WarningWindowDays → expiring soon → Warning
    # daysUntilExpiry > WarningWindowDays      → healthy → Ok
    $status = if ($daysUntilExpiry -le 0) {
        'Expired'
    } elseif ($daysUntilExpiry -le $WarningWindowDays) {
        'Warning'
    } else {
        'Ok'
    }

    return @{
        Name               = $Secret.Name
        Status             = $status
        ExpiryDate         = $expiryDate
        DaysUntilExpiry    = $daysUntilExpiry
        LastRotated        = $lastRotated
        RotationPolicyDays = $policyDays
        RequiredBy         = $Secret['RequiredBy'] ?? @()
    }
}

# ============================================================
# FUNCTION: Invoke-SecretRotationReport
#
# Processes a list of secret configurations and produces a
# structured report grouped by urgency: Expired, Warning, Ok.
#
# Parameters:
#   -Secrets          array of secret hashtables
#   -ReferenceDate    the "today" date (defaults to [datetime]::Today)
#   -WarningWindowDays number of days before expiry considered a warning (default: 14)
#
# Returns a hashtable:
#   Expired, Warning, Ok — each an array of status results
#   Summary              — counts and metadata
#   GeneratedAt          — timestamp
# ============================================================
function Invoke-SecretRotationReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Secrets,

        [Parameter()]
        [datetime]$ReferenceDate = [datetime]::Today,

        [Parameter()]
        [int]$WarningWindowDays = 14
    )

    $expired = @()
    $warning = @()
    $ok      = @()

    foreach ($secret in $Secrets) {
        $statusResult = Get-SecretStatus -Secret $secret -ReferenceDate $ReferenceDate -WarningWindowDays $WarningWindowDays

        switch ($statusResult.Status) {
            'Expired' { $expired += $statusResult }
            'Warning' { $warning += $statusResult }
            'Ok'      { $ok      += $statusResult }
        }
    }

    return @{
        Expired     = $expired
        Warning     = $warning
        Ok          = $ok
        GeneratedAt = $ReferenceDate.ToString('o')   # ISO 8601
        Summary     = @{
            TotalSecrets   = $Secrets.Count
            ExpiredCount   = $expired.Count
            WarningCount   = $warning.Count
            OkCount        = $ok.Count
            WarningWindowDays = $WarningWindowDays
        }
    }
}

# ============================================================
# FUNCTION: Format-RotationReport
#
# Renders a rotation report (from Invoke-SecretRotationReport)
# into the requested output format.
#
# Supported formats: 'JSON', 'Markdown'
#
# Returns a string.
# ============================================================
function Format-RotationReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Report,

        [Parameter(Mandatory)]
        [ValidateSet('JSON', 'Markdown')]
        [string]$Format
    )

    switch ($Format) {
        'JSON' {
            return _Format-Json -Report $Report
        }
        'Markdown' {
            return _Format-Markdown -Report $Report
        }
        default {
            # ValidateSet will catch this, but keep a guard for programmatic misuse
            throw "Unsupported output format '$Format'. Valid options: JSON, Markdown."
        }
    }
}

# ============================================================
# PRIVATE HELPER: _Format-Json
# Serialises the report to pretty-printed JSON.
# ============================================================
function _Format-Json {
    param([hashtable]$Report)

    # Convert hashtables → ordered dicts so that ConvertTo-Json preserves keys
    $serialisable = @{
        GeneratedAt = $Report.GeneratedAt
        Summary     = $Report.Summary
        Expired     = @($Report.Expired | ForEach-Object { _Secret-ToSerializable $_ })
        Warning     = @($Report.Warning | ForEach-Object { _Secret-ToSerializable $_ })
        Ok          = @($Report.Ok      | ForEach-Object { _Secret-ToSerializable $_ })
    }

    return $serialisable | ConvertTo-Json -Depth 5
}

# ============================================================
# PRIVATE HELPER: _Secret-ToSerializable
# Converts a secret status hashtable into a form suitable for JSON.
# ============================================================
function _Secret-ToSerializable {
    param($Status)

    return [ordered]@{
        Name               = $Status.Name
        Status             = $Status.Status
        ExpiryDate         = $Status.ExpiryDate.ToString('yyyy-MM-dd')
        DaysUntilExpiry    = $Status.DaysUntilExpiry
        LastRotated        = $Status.LastRotated.ToString('yyyy-MM-dd')
        RotationPolicyDays = $Status.RotationPolicyDays
        RequiredBy         = $Status.RequiredBy
    }
}

# ============================================================
# PRIVATE HELPER: _Format-Markdown
# Renders the report as a Markdown document with tables.
# ============================================================
function _Format-Markdown {
    param([hashtable]$Report)

    $sb = [System.Text.StringBuilder]::new()

    [void]$sb.AppendLine('# Secret Rotation Report')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("Generated: $($Report.GeneratedAt)")
    [void]$sb.AppendLine('')

    # ---- Summary section ----
    [void]$sb.AppendLine('## Summary')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("| Metric | Value |")
    [void]$sb.AppendLine("|--------|-------|")
    [void]$sb.AppendLine("| Total secrets | $($Report.Summary.TotalSecrets) |")
    [void]$sb.AppendLine("| Expired | $($Report.Summary.ExpiredCount) |")
    [void]$sb.AppendLine("| Warning (within $($Report.Summary.WarningWindowDays) days) | $($Report.Summary.WarningCount) |")
    [void]$sb.AppendLine("| Ok | $($Report.Summary.OkCount) |")
    [void]$sb.AppendLine('')

    # ---- Expired section ----
    [void]$sb.AppendLine('## Expired')
    [void]$sb.AppendLine('')
    if ($Report.Expired.Count -gt 0) {
        [void]$sb.AppendLine('| Secret Name | Expired (days) | Expiry Date | Required By |')
        [void]$sb.AppendLine('|-------------|---------------|-------------|-------------|')
        foreach ($s in $Report.Expired) {
            $daysOverdue = [Math]::Abs($s.DaysUntilExpiry)
            $requiredBy  = ($s.RequiredBy -join ', ')
            [void]$sb.AppendLine("| $($s.Name) | $daysOverdue | $($s.ExpiryDate.ToString('yyyy-MM-dd')) | $requiredBy |")
        }
    } else {
        [void]$sb.AppendLine('_No expired secrets._')
    }
    [void]$sb.AppendLine('')

    # ---- Warning section ----
    [void]$sb.AppendLine('## Warning')
    [void]$sb.AppendLine('')
    if ($Report.Warning.Count -gt 0) {
        [void]$sb.AppendLine('| Secret Name | Days Until Expiry | Expiry Date | Required By |')
        [void]$sb.AppendLine('|-------------|------------------|-------------|-------------|')
        foreach ($s in $Report.Warning) {
            $requiredBy = ($s.RequiredBy -join ', ')
            [void]$sb.AppendLine("| $($s.Name) | $($s.DaysUntilExpiry) | $($s.ExpiryDate.ToString('yyyy-MM-dd')) | $requiredBy |")
        }
    } else {
        [void]$sb.AppendLine('_No secrets in the warning window._')
    }
    [void]$sb.AppendLine('')

    # ---- Ok section ----
    [void]$sb.AppendLine('## Ok')
    [void]$sb.AppendLine('')
    if ($Report.Ok.Count -gt 0) {
        [void]$sb.AppendLine('| Secret Name | Days Until Expiry | Expiry Date | Required By |')
        [void]$sb.AppendLine('|-------------|------------------|-------------|-------------|')
        foreach ($s in $Report.Ok) {
            $requiredBy = ($s.RequiredBy -join ', ')
            [void]$sb.AppendLine("| $($s.Name) | $($s.DaysUntilExpiry) | $($s.ExpiryDate.ToString('yyyy-MM-dd')) | $requiredBy |")
        }
    } else {
        [void]$sb.AppendLine('_No healthy secrets._')
    }

    return $sb.ToString()
}

# ============================================================
# FUNCTION: Import-SecretConfig
#
# Loads a secret configuration from a JSON file.
# Expected JSON schema:
#   {
#     "warningWindowDays": 14,
#     "secrets": [
#       { "name": "...", "lastRotated": "YYYY-MM-DD",
#         "rotationPolicyDays": 90, "requiredBy": ["svc-a"] }
#     ]
#   }
#
# Returns a hashtable with:
#   Secrets           — array of normalised secret hashtables
#   WarningWindowDays — integer
# ============================================================
function Import-SecretConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    # Validate the file exists
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Configuration file not found: '$Path'."
    }

    # Read and parse the JSON
    $raw = Get-Content -LiteralPath $Path -Raw
    $parsed = $null
    try {
        $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Failed to parse configuration file '$Path' as JSON. Error: $($_.Exception.Message)"
    }

    # Normalise the JSON objects into hashtables that Get-SecretStatus can consume
    $secrets = @($parsed.secrets | ForEach-Object {
        @{
            Name               = $_.name
            LastRotated        = $_.lastRotated
            RotationPolicyDays = [int]$_.rotationPolicyDays
            RequiredBy         = @($_.requiredBy)
        }
    })

    $warningWindow = if ($null -ne $parsed.warningWindowDays) { [int]$parsed.warningWindowDays } else { 14 }

    return @{
        Secrets           = $secrets
        WarningWindowDays = $warningWindow
    }
}
