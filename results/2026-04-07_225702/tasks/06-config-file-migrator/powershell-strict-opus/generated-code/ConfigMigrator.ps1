Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Configuration file migrator: parses INI, validates against a schema,
    and outputs JSON/YAML.

.DESCRIPTION
    This module provides four main functions:
      - ConvertFrom-Ini   : Parse INI content string into an ordered dictionary
      - Test-IniAgainstSchema : Validate parsed data against a schema definition
      - ConvertTo-JsonConfig  : Serialize parsed data to JSON
      - ConvertTo-YamlConfig  : Serialize parsed data to YAML

    Strict mode is enforced throughout: all parameters are explicitly typed,
    all functions use [CmdletBinding()] and [OutputType()], and no implicit
    type conversions are used.
#>

function ConvertFrom-IniValue {
    <#
    .SYNOPSIS
        Coerce a raw INI string value to its appropriate .NET type.
        Handles integers, doubles, booleans, quoted strings, and plain strings.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$RawValue
    )

    # Empty value stays as empty string
    if ($RawValue -eq '') {
        return [string]''
    }

    # Quoted strings: strip quotes, keep inner text as string (no coercion)
    if (($RawValue.StartsWith('"') -and $RawValue.EndsWith('"')) -or
        ($RawValue.StartsWith("'") -and $RawValue.EndsWith("'"))) {
        return [string]$RawValue.Substring(1, $RawValue.Length - 2)
    }

    # Boolean coercion (case-insensitive)
    if ($RawValue -ieq 'true' -or $RawValue -ieq 'yes') {
        return [bool]$true
    }
    if ($RawValue -ieq 'false' -or $RawValue -ieq 'no') {
        return [bool]$false
    }

    # Integer coercion — matches optional minus sign followed by digits only
    if ($RawValue -match '^\-?[0-9]+$') {
        return [int]::Parse($RawValue)
    }

    # Double coercion — matches decimal numbers
    if ($RawValue -match '^\-?[0-9]+\.[0-9]+$') {
        return [double]::Parse($RawValue, [System.Globalization.CultureInfo]::InvariantCulture)
    }

    # Default: return as string
    return [string]$RawValue
}

function ConvertFrom-Ini {
    <#
    .SYNOPSIS
        Parse INI-format content into a nested ordered dictionary.
        Supports sections, comments (;/#), multi-line values (continuation
        via leading whitespace), and type coercion.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory)]
        [string]$Content
    )

    [System.Collections.Specialized.OrderedDictionary]$result = [ordered]@{}
    [string]$currentSection = ''
    [string]$currentKey = ''
    [System.Collections.Generic.List[string]]$currentLines = [System.Collections.Generic.List[string]]::new()

    # Helper: flush accumulated multi-line value into the current section
    $flushValue = {
        if ($currentKey -ne '' -and $currentSection -ne '') {
            [string]$joined = ($currentLines -join "`n")
            $result[$currentSection][$currentKey] = ConvertFrom-IniValue -RawValue $joined
        }
    }

    [string[]]$lines = $Content -split "`r?`n"

    foreach ($rawLine in $lines) {
        # Skip full-line comments
        [string]$trimmed = $rawLine.TrimStart()
        if ($trimmed.StartsWith(';') -or $trimmed.StartsWith('#')) {
            continue
        }

        # Skip blank lines (but they also terminate multi-line values)
        if ($rawLine.Trim() -eq '') {
            & $flushValue
            $currentKey = ''
            $currentLines.Clear()
            continue
        }

        # Continuation line: starts with whitespace and we have an active key
        if ($rawLine -match '^\s+' -and $currentKey -ne '') {
            $currentLines.Add($rawLine.Trim())
            continue
        }

        # Section header
        if ($trimmed -match '^\[(.+)\]\s*$') {
            & $flushValue
            $currentKey = ''
            $currentLines.Clear()
            $currentSection = $Matches[1].Trim()
            if (-not $result.Contains($currentSection)) {
                $result[$currentSection] = [ordered]@{}
            }
            continue
        }

        # Key=Value line
        if ($trimmed -match '^([^=]+?)=(.*)$') {
            # Flush any pending multi-line value first
            & $flushValue

            [string]$key = $Matches[1].Trim()
            [string]$value = $Matches[2].Trim()

            if ($currentSection -eq '') {
                throw "Key '$key' found outside of any section. All keys must belong to a [section]."
            }

            $currentKey = $key
            $currentLines.Clear()
            $currentLines.Add($value)
            continue
        }
    }

    # Flush the last pending value
    & $flushValue

    return $result
}

function Test-IniAgainstSchema {
    <#
    .SYNOPSIS
        Validate parsed INI data against a schema that defines required keys
        and their expected types per section.
    .DESCRIPTION
        Schema format: ordered dictionary where each top-level key is a section name,
        and each value is a dictionary of key definitions with 'type' and 'required' fields.
        Supported types: 'string', 'int', 'double', 'bool'.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.Specialized.OrderedDictionary]$Data,

        [Parameter(Mandatory)]
        [System.Collections.Specialized.OrderedDictionary]$Schema
    )

    [System.Collections.Generic.List[string]]$errors = [System.Collections.Generic.List[string]]::new()

    foreach ($sectionName in $Schema.Keys) {
        if (-not $Data.Contains($sectionName)) {
            $errors.Add("Missing required section '$sectionName'")
            continue
        }

        [System.Collections.Specialized.OrderedDictionary]$sectionSchema = [System.Collections.Specialized.OrderedDictionary]$Schema[$sectionName]
        [System.Collections.Specialized.OrderedDictionary]$sectionData = [System.Collections.Specialized.OrderedDictionary]$Data[$sectionName]

        foreach ($keyName in $sectionSchema.Keys) {
            [hashtable]$keyDef = [hashtable]$sectionSchema[$keyName]
            [bool]$isRequired = [bool]$keyDef['required']
            [string]$expectedType = [string]$keyDef['type']

            if (-not $sectionData.Contains($keyName)) {
                if ($isRequired) {
                    $errors.Add("Missing required key '$keyName' in section '$sectionName'")
                }
                continue
            }

            $value = $sectionData[$keyName]

            # Type checking
            [bool]$typeOk = $false
            switch ($expectedType) {
                'string' { $typeOk = $value -is [string] }
                'int'    { $typeOk = $value -is [int] -or $value -is [long] }
                'double' { $typeOk = $value -is [double] -or $value -is [float] }
                'bool'   { $typeOk = $value -is [bool] }
                default  { $typeOk = $true }  # Unknown types pass
            }

            if (-not $typeOk) {
                [string]$actualType = $value.GetType().Name
                $errors.Add("Key '$keyName' in section '$sectionName' expected type '$expectedType' but got '$actualType'")
            }
        }
    }

    return @{
        Valid  = ($errors.Count -eq 0)
        Errors = [string[]]@($errors)
    }
}

function ConvertTo-JsonConfig {
    <#
    .SYNOPSIS
        Convert parsed INI data (ordered dictionary) to a formatted JSON string.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.Specialized.OrderedDictionary]$Data
    )

    # Build a PSCustomObject tree so ConvertTo-Json handles it cleanly
    [hashtable]$obj = @{}
    foreach ($section in $Data.Keys) {
        [hashtable]$sectionObj = @{}
        foreach ($key in $Data[$section].Keys) {
            $sectionObj[$key] = $Data[$section][$key]
        }
        $obj[$section] = [PSCustomObject]$sectionObj
    }
    [PSCustomObject]$root = [PSCustomObject]$obj

    return ($root | ConvertTo-Json -Depth 10)
}

function Format-YamlValue {
    <#
    .SYNOPSIS
        Format a single value for YAML output, handling quoting for strings
        that might be ambiguous.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return 'null'
    }

    if ($Value -is [bool]) {
        if ([bool]$Value) { return 'true' } else { return 'false' }
    }

    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [float]) {
        return $Value.ToString([System.Globalization.CultureInfo]::InvariantCulture)
    }

    # String value — quote if it contains special YAML characters or is empty
    [string]$strVal = [string]$Value
    if ($strVal -eq '' -or
        $strVal -match '[:#\[\]\{\},&\*\?\|>!%@`]' -or
        $strVal -match '^\s' -or $strVal -match '\s$' -or
        $strVal -match '`n') {
        # Use double quotes and escape internal quotes
        [string]$escaped = $strVal.Replace('\', '\\').Replace('"', '\"')
        return "`"$escaped`""
    }

    return $strVal
}

function ConvertTo-YamlConfig {
    <#
    .SYNOPSIS
        Convert parsed INI data (ordered dictionary) to a YAML string.
        Produces a clean, human-readable YAML format.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.Specialized.OrderedDictionary]$Data
    )

    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

    [int]$sectionIndex = 0
    foreach ($section in $Data.Keys) {
        if ($sectionIndex -gt 0) {
            [void]$sb.AppendLine('')
        }
        [void]$sb.AppendLine("${section}:")

        foreach ($key in $Data[$section].Keys) {
            $value = $Data[$section][$key]
            [string]$formatted = Format-YamlValue -Value $value
            [void]$sb.AppendLine("  ${key}: $formatted")
        }
        $sectionIndex++
    }

    return $sb.ToString().TrimEnd()
}
