Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# =============================================================================
# Secret Rotation Validator Module
# =============================================================================
# Identifies expired or expiring secrets based on rotation policies,
# generates rotation reports, and outputs notifications grouped by urgency
# (Expired, Warning, OK) in multiple formats (Markdown table, JSON).
#
# TDD approach: each function was developed test-first:
#   1. Get-SecretStatus         - classifies a single secret's urgency
#   2. Import-SecretConfig      - loads secret configuration from JSON
#   3. Get-RotationReport       - evaluates all secrets, groups by urgency
#   4. ConvertTo-RotationMarkdown - renders report as a markdown table
#   5. ConvertTo-RotationJson     - renders report as JSON
# =============================================================================

function Get-SecretStatus {
    <#
    .SYNOPSIS
        Classifies a secret as Expired, Warning, or OK based on its rotation policy.
    .DESCRIPTION
        Compares the secret's last-rotated date against its rotation policy (in days)
        and a configurable warning window to determine urgency status.
    .PARAMETER LastRotated
        The date when the secret was last rotated.
    .PARAMETER PolicyDays
        The rotation policy period in days.
    .PARAMETER WarningDays
        The number of days before expiry to trigger a warning.
    .PARAMETER ReferenceDate
        The date to evaluate against (defaults to today).
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [datetime]$LastRotated,

        [Parameter(Mandatory)]
        [int]$PolicyDays,

        [Parameter(Mandatory)]
        [int]$WarningDays,

        [Parameter()]
        [datetime]$ReferenceDate = (Get-Date).Date
    )

    # Calculate the expiry date and days remaining
    [datetime]$expiryDate = $LastRotated.AddDays($PolicyDays)
    [int]$daysUntilExpiry = [int][Math]::Floor(($expiryDate - $ReferenceDate).TotalDays)

    # Classify based on days until expiry
    [string]$status = if ($daysUntilExpiry -le 0) {
        'Expired'
    }
    elseif ($daysUntilExpiry -le $WarningDays) {
        'Warning'
    }
    else {
        'OK'
    }

    # Calculate days overdue (positive means overdue)
    [int]$daysOverdue = if ($daysUntilExpiry -le 0) {
        [int][Math]::Abs($daysUntilExpiry)
    }
    else {
        0
    }

    [hashtable]$result = @{
        Status         = [string]$status
        DaysUntilExpiry = [int]$daysUntilExpiry
        DaysOverdue    = [int]$daysOverdue
        ExpiryDate     = [datetime]$expiryDate
    }

    return $result
}

function Import-SecretConfig {
    <#
    .SYNOPSIS
        Loads secret configuration from a JSON file or string.
    .DESCRIPTION
        Parses a JSON configuration containing secret metadata including name,
        last-rotated date, rotation policy in days, and required-by services.
    .PARAMETER Path
        Path to a JSON configuration file.
    .PARAMETER JsonString
        A JSON string containing the configuration.
    #>
    [CmdletBinding(DefaultParameterSetName = 'FromFile')]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'FromFile')]
        [string]$Path,

        [Parameter(Mandatory, ParameterSetName = 'FromString')]
        [string]$JsonString
    )

    # Load raw JSON either from file or string
    [string]$rawJson = if ($PSCmdlet.ParameterSetName -eq 'FromFile') {
        if (-not (Test-Path -Path $Path)) {
            throw "Configuration file not found: $Path"
        }
        Get-Content -Path $Path -Raw
    }
    else {
        $JsonString
    }

    # Parse JSON
    [object]$parsed = $null
    try {
        $parsed = $rawJson | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Invalid JSON configuration: $($_.Exception.Message)"
    }

    # Validate and convert to array of hashtables with explicit types
    [System.Collections.Generic.List[hashtable]]$secrets = [System.Collections.Generic.List[hashtable]]::new()

    # Handle both .secrets wrapper and plain array
    # Use PSObject.Properties to safely check for the 'secrets' key under strict mode
    [bool]$hasSecretsKey = ($parsed -is [PSCustomObject]) -and ($null -ne $parsed.PSObject.Properties['secrets'])
    [object[]]$items = if ($hasSecretsKey) {
        @($parsed.secrets)
    }
    else {
        @($parsed)
    }

    foreach ($item in $items) {
        # Validate required fields — use PSObject.Properties to avoid strict mode error
        # when accessing non-existent properties on PSCustomObject
        [string[]]$requiredFields = @('name', 'lastRotated', 'policyDays', 'requiredBy')
        foreach ($field in $requiredFields) {
            [bool]$hasField = $null -ne $item.PSObject.Properties[$field]
            if (-not $hasField) {
                throw "Missing required field '$field' in secret configuration for entry: $($item | ConvertTo-Json -Compress)"
            }
        }

        # Parse and validate lastRotated date
        [datetime]$lastRotatedDate = [datetime]::MinValue
        [bool]$dateValid = [datetime]::TryParse([string]$item.lastRotated, [ref]$lastRotatedDate)
        if (-not $dateValid) {
            throw "Invalid date format for 'lastRotated' in secret '$($item.name)': $($item.lastRotated)"
        }

        # Build typed hashtable
        [hashtable]$secret = @{
            Name        = [string]$item.name
            LastRotated = [datetime]$lastRotatedDate
            PolicyDays  = [int]$item.policyDays
            RequiredBy  = [string[]]@($item.requiredBy)
        }

        $secrets.Add($secret)
    }

    return [hashtable[]]$secrets.ToArray()
}

function Get-RotationReport {
    <#
    .SYNOPSIS
        Generates a rotation report for all secrets, grouped by urgency.
    .DESCRIPTION
        Evaluates each secret against its rotation policy and the warning window,
        then groups results into Expired, Warning, and OK categories.
    .PARAMETER Secrets
        Array of secret configuration hashtables.
    .PARAMETER WarningDays
        Number of days before expiry to trigger a warning (default: 14).
    .PARAMETER ReferenceDate
        The date to evaluate against (defaults to today).
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable[]]$Secrets,

        [Parameter()]
        [int]$WarningDays = 14,

        [Parameter()]
        [datetime]$ReferenceDate = (Get-Date).Date
    )

    # Initialize result collections
    [System.Collections.Generic.List[hashtable]]$expired = [System.Collections.Generic.List[hashtable]]::new()
    [System.Collections.Generic.List[hashtable]]$warning = [System.Collections.Generic.List[hashtable]]::new()
    [System.Collections.Generic.List[hashtable]]$ok = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($secret in $Secrets) {
        # Get the status for this secret
        [hashtable]$statusResult = Get-SecretStatus `
            -LastRotated ([datetime]$secret.LastRotated) `
            -PolicyDays ([int]$secret.PolicyDays) `
            -WarningDays $WarningDays `
            -ReferenceDate $ReferenceDate

        # Build the report entry
        [hashtable]$entry = @{
            Name           = [string]$secret.Name
            LastRotated    = [datetime]$secret.LastRotated
            PolicyDays     = [int]$secret.PolicyDays
            RequiredBy     = [string[]]$secret.RequiredBy
            Status         = [string]$statusResult.Status
            DaysUntilExpiry = [int]$statusResult.DaysUntilExpiry
            DaysOverdue    = [int]$statusResult.DaysOverdue
            ExpiryDate     = [datetime]$statusResult.ExpiryDate
        }

        # Group by urgency
        switch ($statusResult.Status) {
            'Expired' { $expired.Add($entry) }
            'Warning' { $warning.Add($entry) }
            'OK'      { $ok.Add($entry) }
        }
    }

    # Build summary
    [hashtable]$report = @{
        GeneratedAt  = [datetime]$ReferenceDate
        WarningDays  = [int]$WarningDays
        TotalSecrets = [int]$Secrets.Count
        Summary      = @{
            Expired = [int]$expired.Count
            Warning = [int]$warning.Count
            OK      = [int]$ok.Count
        }
        Expired      = [hashtable[]]$expired.ToArray()
        Warning      = [hashtable[]]$warning.ToArray()
        OK           = [hashtable[]]$ok.ToArray()
    }

    return $report
}

function ConvertTo-RotationMarkdown {
    <#
    .SYNOPSIS
        Converts a rotation report to markdown table format.
    .DESCRIPTION
        Renders the rotation report as markdown with sections for each urgency
        level, including a summary header and detailed tables.
    .PARAMETER Report
        The rotation report hashtable from Get-RotationReport.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Report
    )

    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

    # Header
    [void]$sb.AppendLine('# Secret Rotation Report')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("**Generated:** $($Report.GeneratedAt.ToString('yyyy-MM-dd'))")
    [void]$sb.AppendLine("**Warning Window:** $($Report.WarningDays) days")
    [void]$sb.AppendLine("**Total Secrets:** $($Report.TotalSecrets)")
    [void]$sb.AppendLine('')

    # Summary
    [void]$sb.AppendLine('## Summary')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("| Status | Count |")
    [void]$sb.AppendLine("| --- | --- |")
    [void]$sb.AppendLine("| Expired | $($Report.Summary.Expired) |")
    [void]$sb.AppendLine("| Warning | $($Report.Summary.Warning) |")
    [void]$sb.AppendLine("| OK | $($Report.Summary.OK) |")
    [void]$sb.AppendLine('')

    # Helper to render a section of secrets
    [scriptblock]$renderSection = {
        param([string]$Title, [hashtable[]]$Entries)
        if ($Entries.Count -eq 0) { return }

        [void]$sb.AppendLine("## $Title")
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('| Name | Last Rotated | Policy (days) | Expiry Date | Days Until Expiry | Required By |')
        [void]$sb.AppendLine('| --- | --- | --- | --- | --- | --- |')

        foreach ($entry in $Entries) {
            [string]$requiredByStr = ($entry.RequiredBy -join ', ')
            [string]$lastRotatedStr = $entry.LastRotated.ToString('yyyy-MM-dd')
            [string]$expiryDateStr = $entry.ExpiryDate.ToString('yyyy-MM-dd')
            [string]$daysStr = if ($entry.Status -eq 'Expired') {
                "$($entry.DaysOverdue) overdue"
            }
            else {
                [string]$entry.DaysUntilExpiry
            }

            [void]$sb.AppendLine("| $($entry.Name) | $lastRotatedStr | $($entry.PolicyDays) | $expiryDateStr | $daysStr | $requiredByStr |")
        }
        [void]$sb.AppendLine('')
    }

    # Render each section (expired first for urgency)
    & $renderSection 'Expired Secrets' ([hashtable[]]$Report.Expired)
    & $renderSection 'Warning Secrets' ([hashtable[]]$Report.Warning)
    & $renderSection 'OK Secrets' ([hashtable[]]$Report.OK)

    return $sb.ToString().TrimEnd()
}

function ConvertTo-RotationJson {
    <#
    .SYNOPSIS
        Converts a rotation report to JSON format.
    .DESCRIPTION
        Serializes the rotation report as a JSON string with proper structure
        for machine consumption.
    .PARAMETER Report
        The rotation report hashtable from Get-RotationReport.
    .PARAMETER Depth
        The depth for JSON serialization (default: 5).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Report,

        [Parameter()]
        [int]$Depth = 5
    )

    # Build a structured object for clean JSON output
    [hashtable]$jsonObj = @{
        generatedAt  = [string]$Report.GeneratedAt.ToString('yyyy-MM-dd')
        warningDays  = [int]$Report.WarningDays
        totalSecrets = [int]$Report.TotalSecrets
        summary      = @{
            expired = [int]$Report.Summary.Expired
            warning = [int]$Report.Summary.Warning
            ok      = [int]$Report.Summary.OK
        }
        expired      = [object[]]@(ConvertTo-JsonEntries -Entries ([hashtable[]]$Report.Expired))
        warning      = [object[]]@(ConvertTo-JsonEntries -Entries ([hashtable[]]$Report.Warning))
        ok           = [object[]]@(ConvertTo-JsonEntries -Entries ([hashtable[]]$Report.OK))
    }

    [string]$json = $jsonObj | ConvertTo-Json -Depth $Depth
    return $json
}

function ConvertTo-JsonEntries {
    <#
    .SYNOPSIS
        Helper function to convert report entries to JSON-friendly format.
    .DESCRIPTION
        Transforms hashtable entries into ordered hashtables with string dates
        suitable for JSON serialization.
    .PARAMETER Entries
        Array of report entry hashtables.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [hashtable[]]$Entries
    )

    [System.Collections.Generic.List[object]]$results = [System.Collections.Generic.List[object]]::new()

    foreach ($entry in $Entries) {
        [System.Collections.Specialized.OrderedDictionary]$obj = [ordered]@{
            name           = [string]$entry.Name
            lastRotated    = [string]$entry.LastRotated.ToString('yyyy-MM-dd')
            policyDays     = [int]$entry.PolicyDays
            expiryDate     = [string]$entry.ExpiryDate.ToString('yyyy-MM-dd')
            status         = [string]$entry.Status
            daysUntilExpiry = [int]$entry.DaysUntilExpiry
            daysOverdue    = [int]$entry.DaysOverdue
            requiredBy     = [string[]]$entry.RequiredBy
        }
        $results.Add($obj)
    }

    return [object[]]$results.ToArray()
}

# Export public functions
Export-ModuleMember -Function @(
    'Get-SecretStatus'
    'Import-SecretConfig'
    'Get-RotationReport'
    'ConvertTo-RotationMarkdown'
    'ConvertTo-RotationJson'
)
