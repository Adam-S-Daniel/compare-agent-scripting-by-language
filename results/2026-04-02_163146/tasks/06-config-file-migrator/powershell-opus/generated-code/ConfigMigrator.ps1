# ConfigMigrator.ps1
# INI configuration file parser, validator, and converter
# Supports: INI -> JSON and INI -> YAML conversion with schema validation
#
# Approach:
# - ConvertFrom-Ini: Parses INI content into nested ordered dictionaries
#   with automatic type coercion (strings -> int, float, bool, null)
# - Test-IniSchema: Validates parsed config against a JSON schema defining
#   required keys and expected types per section
# - ConvertTo-JsonConfig: Serializes parsed config to formatted JSON
# - ConvertTo-YamlConfig: Serializes parsed config to YAML (custom writer
#   since PowerShell has no built-in YAML support)

# =============================================================================
# Helper: Coerce a raw string value to the appropriate .NET type
# =============================================================================
function Convert-IniValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$RawValue
    )

    # Empty string stays as empty string
    if ($RawValue -eq '') {
        return ''
    }

    # Quoted strings: strip quotes, preserve as string (no further coercion)
    if ($RawValue.Length -ge 2 -and $RawValue[0] -eq '"' -and $RawValue[-1] -eq '"') {
        return $RawValue.Substring(1, $RawValue.Length - 2)
    }

    # Null-like values
    if ($RawValue -eq 'null' -or $RawValue -eq 'none') {
        return $null
    }

    # Boolean values (case-insensitive)
    switch ($RawValue.ToLower()) {
        'true'  { return $true }
        'false' { return $false }
        'yes'   { return $true }
        'no'    { return $false }
        'on'    { return $true }
        'off'   { return $false }
    }

    # Integer values (including negative)
    if ($RawValue -match '^-?\d+$') {
        return [int64]$RawValue
    }

    # Float values (decimal or scientific notation)
    if ($RawValue -match '^-?\d+\.\d+([eE][+-]?\d+)?$' -or $RawValue -match '^-?\d+[eE][+-]?\d+$') {
        return [double]$RawValue
    }

    # Default: return as string
    return $RawValue
}

# =============================================================================
# ConvertFrom-Ini: Parse INI content or file into ordered dictionary
# =============================================================================
function ConvertFrom-Ini {
    [CmdletBinding(DefaultParameterSetName = 'Content')]
    param(
        [Parameter(ParameterSetName = 'Content', Mandatory)]
        [string]$Content,

        [Parameter(ParameterSetName = 'Path', Mandatory)]
        [string]$Path
    )

    # If a file path was given, read its content
    if ($PSCmdlet.ParameterSetName -eq 'Path') {
        if (-not (Test-Path -LiteralPath $Path)) {
            throw "File does not exist: $Path"
        }
        $Content = Get-Content -LiteralPath $Path -Raw
    }

    # Split content into lines
    $lines = $Content -split "`r?`n"

    # Pre-process: join backslash-continued lines
    $processedLines = [System.Collections.Generic.List[string]]::new()
    $i = 0
    while ($i -lt $lines.Count) {
        $line = $lines[$i]
        # If line ends with backslash, join with next line
        while ($line -match '\\$' -and ($i + 1) -lt $lines.Count) {
            # Remove trailing backslash and join with next line (trimmed)
            $line = $line.TrimEnd('\').TrimEnd() + ' ' + $lines[$i + 1].Trim()
            $i++
        }
        $processedLines.Add($line)
        $i++
    }

    # Parse into ordered dictionary of sections
    $result = [ordered]@{}
    $currentSection = $null

    foreach ($line in $processedLines) {
        $trimmed = $line.Trim()

        # Skip empty lines
        if ($trimmed -eq '') { continue }

        # Skip comment lines (semicolon or hash)
        if ($trimmed[0] -eq ';' -or $trimmed[0] -eq '#') { continue }

        # Section header: [section_name]
        if ($trimmed -match '^\[(.+)\]$') {
            $currentSection = $Matches[1].Trim()
            if (-not $result.Contains($currentSection)) {
                $result[$currentSection] = [ordered]@{}
            }
            continue
        }

        # Key-value pair: key = value
        if ($trimmed -match '^([^=]+?)=(.*)$') {
            $key = $Matches[1].Trim()
            $rawValue = $Matches[2].Trim()

            # If no section yet, place in _global
            if ($null -eq $currentSection) {
                $currentSection = '_global'
                if (-not $result.Contains($currentSection)) {
                    $result[$currentSection] = [ordered]@{}
                }
            }

            # Coerce value to appropriate type
            $value = Convert-IniValue -RawValue $rawValue
            $result[$currentSection][$key] = $value
        }
    }

    return $result
}

# =============================================================================
# Test-IniSchema: Validate parsed config against a schema
# Schema format per section:
#   { "required": ["key1", ...], "properties": { "key": { "type": "string|integer|number|boolean" } } }
# =============================================================================
function Test-IniSchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Config,

        [Parameter(Mandatory)]
        $Schema
    )

    if ($null -eq $Schema) {
        throw "Schema cannot be null"
    }

    $errors = [System.Collections.Generic.List[string]]::new()

    # Iterate over each section defined in the schema
    foreach ($sectionName in $Schema.PSObject.Properties.Name) {
        $sectionSchema = $Schema.$sectionName

        # Check if section exists in config
        if (-not $Config.Contains($sectionName)) {
            $errors.Add("Missing required section '$sectionName'")
            continue
        }

        $sectionData = $Config[$sectionName]

        # Check required keys
        if ($sectionSchema.required) {
            foreach ($reqKey in $sectionSchema.required) {
                if (-not $sectionData.Contains($reqKey)) {
                    $errors.Add("Section '$sectionName': missing required key '$reqKey'")
                }
            }
        }

        # Check property types
        if ($sectionSchema.properties) {
            foreach ($propName in $sectionSchema.properties.PSObject.Properties.Name) {
                if (-not $sectionData.Contains($propName)) { continue }

                $expectedType = $sectionSchema.properties.$propName.type
                $actualValue = $sectionData[$propName]

                # Skip null values for type checking
                if ($null -eq $actualValue) { continue }

                $typeMatch = switch ($expectedType) {
                    'string'  { $actualValue -is [string] }
                    'integer' { $actualValue -is [int64] -or $actualValue -is [int32] -or $actualValue -is [int] }
                    'number'  { $actualValue -is [double] -or $actualValue -is [int64] -or $actualValue -is [int32] }
                    'boolean' { $actualValue -is [bool] }
                    default   { $true }
                }

                if (-not $typeMatch) {
                    $actualType = $actualValue.GetType().Name
                    $errors.Add("Section '$sectionName': key '$propName' expected type '$expectedType' but got '$actualType'")
                }
            }
        }
    }

    return [PSCustomObject]@{
        IsValid = ($errors.Count -eq 0)
        Errors  = $errors
    }
}

# =============================================================================
# ConvertTo-JsonConfig: Convert parsed config to formatted JSON string
# =============================================================================
function ConvertTo-JsonConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Config
    )

    # Build a PSCustomObject tree for proper JSON serialization
    $obj = [ordered]@{}
    foreach ($section in $Config.Keys) {
        $sectionObj = [ordered]@{}
        foreach ($key in $Config[$section].Keys) {
            $sectionObj[$key] = $Config[$section][$key]
        }
        $obj[$section] = [PSCustomObject]$sectionObj
    }

    return [PSCustomObject]$obj | ConvertTo-Json -Depth 10
}

# =============================================================================
# Helper: Format a value for YAML output
# =============================================================================
function Format-YamlValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        $Value
    )

    # Null -> yaml null
    if ($null -eq $Value) {
        return 'null'
    }

    # Boolean -> lowercase true/false
    if ($Value -is [bool]) {
        return $Value.ToString().ToLower()
    }

    # Numbers -> as-is
    if ($Value -is [int64] -or $Value -is [int32] -or $Value -is [double]) {
        return $Value.ToString()
    }

    # Empty string -> quoted
    if ($Value -eq '') {
        return "''"
    }

    # Strings that need quoting: contain special YAML characters
    $needsQuoting = $false
    if ($Value -match '[:#\[\]{}&*!|>''"%@`]' -or
        $Value -match '^\s' -or $Value -match '\s$' -or
        $Value -match '^(true|false|yes|no|on|off|null|none)$') {
        $needsQuoting = $true
    }

    if ($needsQuoting) {
        # Use single quotes, escaping any internal single quotes
        $escaped = $Value -replace "'", "''"
        return "'$escaped'"
    }

    return $Value
}

# =============================================================================
# ConvertTo-YamlConfig: Convert parsed config to YAML string
# =============================================================================
function ConvertTo-YamlConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Config
    )

    $sb = [System.Text.StringBuilder]::new()

    $sectionIndex = 0
    foreach ($section in $Config.Keys) {
        # Blank line between sections (but not before first)
        if ($sectionIndex -gt 0) {
            [void]$sb.AppendLine()
        }

        [void]$sb.AppendLine("${section}:")

        foreach ($key in $Config[$section].Keys) {
            $yamlValue = Format-YamlValue -Value $Config[$section][$key]
            [void]$sb.AppendLine("  ${key}: $yamlValue")
        }

        $sectionIndex++
    }

    return $sb.ToString()
}
