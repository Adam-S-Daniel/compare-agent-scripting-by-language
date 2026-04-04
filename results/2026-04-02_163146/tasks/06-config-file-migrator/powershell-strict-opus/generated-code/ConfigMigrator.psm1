Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# =============================================================================
# ConfigMigrator Module
# Parses INI files, validates against schemas, outputs JSON and YAML.
# Built using TDD: tests written first, then implementation to pass them.
# =============================================================================

function ConvertTo-TypedValue {
    <#
    .SYNOPSIS
        Coerces a string value to its most appropriate PowerShell type.
    .DESCRIPTION
        Attempts to convert a raw INI string value into a boolean, integer,
        double, or keeps it as a string. Quoted values are unquoted and forced
        to remain strings, preventing "123" from becoming an integer.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value
    )

    # Empty string stays as-is
    if ([string]::IsNullOrEmpty($Value)) {
        return [string]$Value
    }

    # Quoted values: strip quotes and return as string (no coercion)
    if ($Value.StartsWith('"') -and $Value.EndsWith('"') -and $Value.Length -ge 2) {
        return [string]$Value.Substring(1, $Value.Length - 2)
    }

    # Boolean coercion (case-insensitive)
    [string]$lower = $Value.ToLower()
    if ($lower -eq 'true' -or $lower -eq 'yes' -or $lower -eq 'on') {
        return [bool]$true
    }
    if ($lower -eq 'false' -or $lower -eq 'no' -or $lower -eq 'off') {
        return [bool]$false
    }

    # Integer coercion (must be pure digits, optionally with leading minus)
    [int]$intResult = 0
    if ([int]::TryParse($Value, [ref]$intResult)) {
        # Verify it's a clean integer string (no decimals, no extra chars)
        if ($Value -match '^-?\d+$') {
            return [int]$intResult
        }
    }

    # Double/float coercion
    [double]$dblResult = 0.0
    if ($Value -match '^-?\d+\.\d+$') {
        if ([double]::TryParse($Value, [System.Globalization.NumberStyles]::Float,
            [System.Globalization.CultureInfo]::InvariantCulture, [ref]$dblResult)) {
            return [double]$dblResult
        }
    }

    # Default: return as string
    return [string]$Value
}

function ConvertFrom-IniFile {
    <#
    .SYNOPSIS
        Parses an INI file into a nested hashtable structure.
    .DESCRIPTION
        Reads an INI configuration file and returns a hashtable of hashtables.
        Each section becomes a top-level key; keys before any section header
        go under '_global'. Supports semicolon and hash comments, multi-line
        values (continuation lines starting with whitespace), and optional
        type coercion.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter()]
        [switch]$CoerceTypes
    )

    # Validate file exists
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "INI file does not exist: $Path"
    }

    [string[]]$lines = Get-Content -LiteralPath $Path -Encoding UTF8

    # Result: ordered hashtable of section -> ordered hashtable of key -> value
    [hashtable]$result = @{}
    [string]$currentSection = '_global'
    [string]$currentKey = ''
    [string]$currentValue = ''
    [bool]$inMultiLine = $false

    # Helper to save the current key-value pair
# We use a scriptblock instead of a nested function to avoid scope issues
    [scriptblock]$saveCurrentPair = {
        param([hashtable]$res, [string]$sec, [string]$key, [string]$val, [bool]$coerce)
        if ([string]::IsNullOrEmpty($key)) { return }
        if (-not $res.ContainsKey($sec)) {
            $res[$sec] = [ordered]@{}
        }
        [string]$trimmedVal = $val.TrimEnd()
        if ($coerce) {
            $res[$sec][$key] = ConvertTo-TypedValue -Value $trimmedVal
        }
        else {
            $res[$sec][$key] = $trimmedVal
        }
    }

    foreach ($rawLine in $lines) {
        [string]$line = $rawLine

        # Check for continuation lines (multi-line values)
        # A continuation line starts with whitespace and we have a current key
        if ($inMultiLine -and $line.Length -gt 0 -and ($line[0] -eq ' ' -or $line[0] -eq "`t")) {
            # This is a continuation of the previous value
            $currentValue = $currentValue + "`n" + $line.Trim()
            continue
        }

        # If we were in a multi-line value but this line isn't a continuation, save
        if ($inMultiLine) {
            & $saveCurrentPair $result $currentSection $currentKey $currentValue ([bool]$CoerceTypes)
            $currentKey = ''
            $currentValue = ''
            $inMultiLine = $false
        }

        # Skip empty lines
        [string]$trimmed = $line.Trim()
        if ([string]::IsNullOrEmpty($trimmed)) {
            continue
        }

        # Skip comment lines (lines starting with ; or #)
        if ($trimmed[0] -eq ';' -or $trimmed[0] -eq '#') {
            continue
        }

        # Section header: [section_name]
        if ($trimmed -match '^\[(.+)\]$') {
            $currentSection = $Matches[1].Trim()
            if (-not $result.ContainsKey($currentSection)) {
                $result[$currentSection] = [ordered]@{}
            }
            continue
        }

        # Key-value pair: key = value (split only on first '=')
        [int]$eqIdx = $trimmed.IndexOf('=')
        if ($eqIdx -ge 0) {
            $currentKey = $trimmed.Substring(0, $eqIdx).Trim()
            if ($eqIdx -lt $trimmed.Length - 1) {
                $currentValue = $trimmed.Substring($eqIdx + 1).Trim()
            }
            else {
                $currentValue = ''
            }
            $inMultiLine = $true
            continue
        }
    }

    # Save any trailing multi-line value
    if ($inMultiLine -and -not [string]::IsNullOrEmpty($currentKey)) {
        & $saveCurrentPair $result $currentSection $currentKey $currentValue ([bool]$CoerceTypes)
    }

    return $result
}

function Test-IniSchema {
    <#
    .SYNOPSIS
        Validates a parsed INI config hashtable against a JSON schema.
    .DESCRIPTION
        Checks required keys exist and values match expected types.
        Returns a PSCustomObject with IsValid (bool) and Errors (string[]).
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,

        [Parameter(Mandatory)]
        [string]$SchemaPath
    )

    if (-not (Test-Path -LiteralPath $SchemaPath)) {
        throw "Schema file does not exist: $SchemaPath"
    }

    [string]$schemaJson = Get-Content -LiteralPath $SchemaPath -Raw -Encoding UTF8
    [PSCustomObject]$schema = $schemaJson | ConvertFrom-Json

    [System.Collections.Generic.List[string]]$errors = [System.Collections.Generic.List[string]]::new()

    # Iterate each section defined in the schema
    foreach ($sectionProp in $schema.PSObject.Properties) {
        [string]$sectionName = $sectionProp.Name
        [PSCustomObject]$sectionSchema = $sectionProp.Value

        # Check if the section exists in config
        [bool]$sectionExists = $Config.ContainsKey($sectionName)

        foreach ($keyProp in $sectionSchema.PSObject.Properties) {
            [string]$keyName = $keyProp.Name
            [PSCustomObject]$keySchema = $keyProp.Value

            [string]$expectedType = [string]$keySchema.type
            [bool]$isRequired = [bool]$keySchema.required

            # Check if the key exists
            [bool]$keyExists = $false
            if ($sectionExists) {
                $sectionData = $Config[$sectionName]
                $keyExists = $sectionData.Contains($keyName)
            }

            # Required key check
            if ($isRequired -and -not $keyExists) {
                $errors.Add("[$sectionName].$keyName is required but missing")
                continue
            }

            # If key doesn't exist and isn't required, skip type check
            if (-not $keyExists) {
                continue
            }

            # Type validation
            $value = $Config[$sectionName][$keyName]
            [bool]$typeValid = Test-ValueType -Value $value -ExpectedType $expectedType

            if (-not $typeValid) {
                [string]$actualType = if ($null -eq $value) { 'null' } else { $value.GetType().Name }
                $errors.Add("[$sectionName].$keyName expected type '$expectedType' but got '$actualType'")
            }
        }
    }

    return [PSCustomObject]@{
        IsValid = ($errors.Count -eq 0)
        Errors  = [string[]]$errors.ToArray()
    }
}

function Test-ValueType {
    <#
    .SYNOPSIS
        Checks whether a value matches an expected schema type name.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [object]$Value,

        [Parameter(Mandatory)]
        [string]$ExpectedType
    )

    if ($null -eq $Value) {
        return $false
    }

    switch ($ExpectedType) {
        'string' {
            return ($Value -is [string])
        }
        'integer' {
            return ($Value -is [int] -or $Value -is [long])
        }
        'number' {
            return ($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal])
        }
        'boolean' {
            return ($Value -is [bool])
        }
        default {
            return $true
        }
    }
}

function ConvertTo-JsonConfig {
    <#
    .SYNOPSIS
        Converts a parsed INI hashtable to a JSON string.
    .DESCRIPTION
        Produces a formatted JSON document preserving the section/key structure.
        Optionally writes to a file.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,

        [Parameter()]
        [string]$OutputPath = ''
    )

    # Build an ordered structure for deterministic output
    $ordered = [ordered]@{}
    foreach ($section in ($Config.Keys | Sort-Object)) {
        $sectionData = [ordered]@{}
        foreach ($key in $Config[$section].Keys) {
            $sectionData[$key] = $Config[$section][$key]
        }
        $ordered[$section] = $sectionData
    }

    [string]$json = $ordered | ConvertTo-Json -Depth 10

    if (-not [string]::IsNullOrEmpty($OutputPath)) {
        $json | Set-Content -LiteralPath $OutputPath -Encoding UTF8 -NoNewline
    }

    return $json
}

function ConvertTo-YamlConfig {
    <#
    .SYNOPSIS
        Converts a parsed INI hashtable to a YAML-formatted string.
    .DESCRIPTION
        Produces a simple YAML document. Strings containing special YAML
        characters are double-quoted. Booleans and numbers are unquoted.
        Optionally writes to a file.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,

        [Parameter()]
        [string]$OutputPath = ''
    )

    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

    [bool]$firstSection = $true
    foreach ($section in ($Config.Keys | Sort-Object)) {
        if (-not $firstSection) {
            [void]$sb.AppendLine('')
        }
        $firstSection = $false
        [void]$sb.AppendLine("${section}:")

        foreach ($key in $Config[$section].Keys) {
            $value = $Config[$section][$key]
            [string]$yamlValue = Format-YamlValue -Value $value
            [void]$sb.AppendLine("  ${key}: $yamlValue")
        }
    }

    [string]$yaml = $sb.ToString()

    if (-not [string]::IsNullOrEmpty($OutputPath)) {
        $yaml | Set-Content -LiteralPath $OutputPath -Encoding UTF8 -NoNewline
    }

    return $yaml
}

function Format-YamlValue {
    <#
    .SYNOPSIS
        Formats a single value for YAML output.
    .DESCRIPTION
        Booleans become true/false, numbers are unquoted, strings with
        special characters get double-quoted, plain strings stay unquoted.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return 'null'
    }

    if ($Value -is [bool]) {
        if ([bool]$Value) { return 'true' } else { return 'false' }
    }

    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal]) {
        return $Value.ToString([System.Globalization.CultureInfo]::InvariantCulture)
    }

    # String value - check if quoting is needed
    [string]$strVal = [string]$Value

    if ([string]::IsNullOrEmpty($strVal)) {
        return '""'
    }

    # Multi-line strings use YAML literal block scalar
    if ($strVal.Contains("`n")) {
        [string]$indented = $strVal -replace "`n", "`n    "
        return "|-`n    $indented"
    }

    # Quote strings containing YAML-special characters
    [bool]$needsQuoting = $false
    if ($strVal -match '[:#\[\]{}|>&*!?%@`,]') {
        $needsQuoting = $true
    }
    # Quote if looks like a boolean or number in YAML
    if ($strVal -match '^(true|false|yes|no|on|off|null|~)$') {
        $needsQuoting = $true
    }
    if ($strVal -match '^\d') {
        $needsQuoting = $true
    }

    if ($needsQuoting) {
        # Escape existing double quotes and backslashes for YAML
        [string]$escaped = $strVal -replace '\\', '\\' -replace '"', '\"'
        return """$escaped"""
    }

    return $strVal
}

function Convert-ConfigFile {
    <#
    .SYNOPSIS
        Full pipeline: parse INI, optionally validate, output JSON and YAML.
    .DESCRIPTION
        Orchestrates the full config migration workflow. Parses the INI file
        with type coercion, validates against a schema if provided, and writes
        JSON and YAML output files. Returns a result object with Success and
        Errors properties.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$IniPath,

        [Parameter()]
        [string]$SchemaPath = '',

        [Parameter()]
        [string]$JsonOutputPath = '',

        [Parameter()]
        [string]$YamlOutputPath = ''
    )

    # Parse the INI file with type coercion
    [hashtable]$config = ConvertFrom-IniFile -Path $IniPath -CoerceTypes

    # Validate against schema if provided
    if (-not [string]::IsNullOrEmpty($SchemaPath)) {
        [PSCustomObject]$validation = Test-IniSchema -Config $config -SchemaPath $SchemaPath

        if (-not $validation.IsValid) {
            return [PSCustomObject]@{
                Success = [bool]$false
                Config  = $config
                Errors  = [string[]]$validation.Errors
            }
        }
    }

    # Generate outputs
    if (-not [string]::IsNullOrEmpty($JsonOutputPath)) {
        [void](ConvertTo-JsonConfig -Config $config -OutputPath $JsonOutputPath)
    }

    if (-not [string]::IsNullOrEmpty($YamlOutputPath)) {
        [void](ConvertTo-YamlConfig -Config $config -OutputPath $YamlOutputPath)
    }

    return [PSCustomObject]@{
        Success = [bool]$true
        Config  = $config
        Errors  = [string[]]@()
    }
}

# Export public functions
Export-ModuleMember -Function @(
    'ConvertFrom-IniFile'
    'ConvertTo-TypedValue'
    'Test-IniSchema'
    'ConvertTo-JsonConfig'
    'ConvertTo-YamlConfig'
    'Convert-ConfigFile'
)
