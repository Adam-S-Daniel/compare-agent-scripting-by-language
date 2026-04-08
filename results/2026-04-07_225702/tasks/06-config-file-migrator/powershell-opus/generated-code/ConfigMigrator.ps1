# ConfigMigrator.ps1
# Parses INI config files, validates against a JSON schema, and outputs JSON/YAML.
# Handles: sections, comments (;/#), multi-line values (\), type coercion, empty values.

function ConvertTo-TypedValue {
    <#
    .SYNOPSIS
        Coerce a raw INI string value to the appropriate PowerShell type.
        Booleans, integers, floats are detected automatically.
        Quoted strings ("...") are preserved as literal strings without coercion.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value
    )

    # Empty stays empty
    if ($Value -eq '') { return '' }

    # Quoted strings: strip quotes, return as string (no numeric coercion)
    if ($Value -match '^"(.*)"$') { return $Matches[1] }

    # Boolean
    if ($Value -ieq 'true')  { return $true }
    if ($Value -ieq 'false') { return $false }

    # Integer (including negative)
    if ($Value -match '^-?\d+$') {
        return [int]$Value
    }

    # Float / double
    if ($Value -match '^-?\d+\.\d+$') {
        return [double]$Value
    }

    # Default: string
    return $Value
}

function ConvertFrom-Ini {
    <#
    .SYNOPSIS
        Parse an INI file into an ordered hashtable of sections.
        Each section maps to an ordered hashtable of key=value pairs
        with values automatically type-coerced.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "File '$Path' does not exist"
    }

    $lines = Get-Content -Path $Path
    $config = [ordered]@{}
    $currentSection = $null

    # Track multi-line continuation state
    $continuationKey = $null
    $continuationValue = ''

    foreach ($line in $lines) {
        # If we're accumulating a multi-line value
        if ($null -ne $continuationKey) {
            $trimmed = $line.Trim()
            if ($trimmed.EndsWith('\')) {
                # More continuation: append without trailing backslash
                $continuationValue += ' ' + $trimmed.TrimEnd('\').TrimEnd()
            }
            else {
                # Final line of continuation
                $continuationValue += ' ' + $trimmed
                $config[$currentSection][$continuationKey] = ConvertTo-TypedValue $continuationValue
                $continuationKey = $null
                $continuationValue = ''
            }
            continue
        }

        # Strip inline content that is purely a comment line
        $trimmed = $line.Trim()

        # Skip blank lines and comment lines (; or #)
        if ($trimmed -eq '' -or $trimmed.StartsWith(';') -or $trimmed.StartsWith('#')) {
            continue
        }

        # Section header [section_name]
        if ($trimmed -match '^\[(.+)\]$') {
            $currentSection = $Matches[1]
            if (-not $config.Contains($currentSection)) {
                $config[$currentSection] = [ordered]@{}
            }
            continue
        }

        # Key = Value pair
        if ($trimmed -match '^([^=]+?)\s*=\s*(.*)$') {
            $key = $Matches[1].Trim()
            $rawValue = $Matches[2].Trim()

            if ($null -eq $currentSection) {
                # Keys outside a section — put them under a global pseudo-section
                $currentSection = '_global'
                if (-not $config.Contains($currentSection)) {
                    $config[$currentSection] = [ordered]@{}
                }
            }

            # Check for multi-line continuation (trailing backslash)
            if ($rawValue.EndsWith('\')) {
                $continuationKey = $key
                $continuationValue = $rawValue.TrimEnd('\').TrimEnd()
                continue
            }

            $config[$currentSection][$key] = ConvertTo-TypedValue $rawValue
        }
    }

    return $config
}

function Test-IniSchema {
    <#
    .SYNOPSIS
        Validate a parsed INI config against a JSON schema.
        Schema format: { "section": { "key": { "type": "string|integer|boolean|float", "required": true/false } } }
        Returns an object with .Valid (bool) and .Errors (string[]).
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,

        [Parameter(Mandatory)]
        $Schema
    )

    $errors = [System.Collections.Generic.List[string]]::new()

    # Iterate each section defined in the schema
    foreach ($sectionProp in $Schema.PSObject.Properties) {
        $sectionName = $sectionProp.Name
        $sectionDef = $sectionProp.Value

        # Check if section exists in config
        if (-not $Config.Contains($sectionName)) {
            # Collect all required keys to report missing section meaningfully
            $hasRequired = $false
            foreach ($keyProp in $sectionDef.PSObject.Properties) {
                if ($keyProp.Value.required -eq $true) {
                    $hasRequired = $true
                    $errors.Add("Missing required key '$($keyProp.Name)' in section '$sectionName' (section missing)")
                }
            }
            if (-not $hasRequired) {
                # Section is optional if no required keys
                continue
            }
            continue
        }

        $sectionData = $Config[$sectionName]

        # Check each key defined in the schema for this section
        foreach ($keyProp in $sectionDef.PSObject.Properties) {
            $keyName = $keyProp.Name
            $keyDef = $keyProp.Value
            $isRequired = $keyDef.required -eq $true
            $expectedType = $keyDef.type

            if (-not $sectionData.Contains($keyName)) {
                if ($isRequired) {
                    $errors.Add("Missing required key '$keyName' in section '$sectionName'")
                }
                continue
            }

            # Type check
            $actualValue = $sectionData[$keyName]
            $typeOk = switch ($expectedType) {
                'string'  { $actualValue -is [string] }
                'integer' { $actualValue -is [int] -or $actualValue -is [long] }
                'boolean' { $actualValue -is [bool] }
                'float'   { $actualValue -is [double] -or $actualValue -is [float] }
                default   { $true }
            }

            if (-not $typeOk) {
                $errors.Add("Key '$keyName' in section '$sectionName' should be type '$expectedType' but got '$actualValue'")
            }
        }
    }

    return [PSCustomObject]@{
        Valid  = ($errors.Count -eq 0)
        Errors = $errors.ToArray()
    }
}

function ConvertTo-JsonConfig {
    <#
    .SYNOPSIS
        Convert a parsed INI config (ordered hashtable) to a pretty-printed JSON string.
    #>
    param(
        [Parameter(Mandatory)]
$Config
    )

    # Build a nested PSCustomObject so ConvertTo-Json handles types correctly
    $obj = [ordered]@{}
    foreach ($section in $Config.Keys) {
        $sectionObj = [ordered]@{}
        foreach ($key in $Config[$section].Keys) {
            $sectionObj[$key] = $Config[$section][$key]
        }
        $obj[$section] = $sectionObj
    }

    return ($obj | ConvertTo-Json -Depth 10)
}

function ConvertTo-YamlConfig {
    <#
    .SYNOPSIS
        Convert a parsed INI config to a YAML string.
        Hand-rolled serializer to avoid external module dependencies.
        Handles: booleans, integers, floats, strings (with quoting when needed).
    #>
    param(
        [Parameter(Mandatory)]
$Config
    )

    $sb = [System.Text.StringBuilder]::new()

    foreach ($section in $Config.Keys) {
        [void]$sb.AppendLine("${section}:")
        foreach ($key in $Config[$section].Keys) {
            $val = $Config[$section][$key]
            $yamlVal = Format-YamlValue $val
            [void]$sb.AppendLine("  ${key}: $yamlVal")
        }
    }

    return $sb.ToString()
}

function Format-YamlValue {
    <#
    .SYNOPSIS
        Format a single value for YAML output.
        Booleans -> true/false, numbers -> unquoted, strings -> quoted if ambiguous.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        $Value
    )

    if ($Value -is [bool]) {
        if ($Value) { return 'true' } else { return 'false' }
    }

    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [float]) {
        return $Value.ToString()
    }

    # Empty string
    if ($Value -eq '') { return '""' }

    # String values: quote if they contain special YAML chars or could be misread
    $needsQuoting = $Value -match '[:#\[\]{}&*!|>''",@`]' -or
                    $Value -match '^\s' -or $Value -match '\s$' -or
                    $Value -ieq 'true' -or $Value -ieq 'false' -or
                    $Value -match '^\d'

    if ($needsQuoting) {
        # Use double quotes, escape inner double quotes
        $escaped = $Value -replace '"', '\"'
        return "`"$escaped`""
    }

    return $Value
}

function Invoke-ConfigMigrator {
    <#
    .SYNOPSIS
        End-to-end migration: parse INI, optionally validate, write JSON + YAML.
        Returns an object with Config, ValidationResult (if schema provided), JsonPath, YamlPath.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$IniPath,

        [Parameter(Mandatory)]
        [string]$JsonOutPath,

        [Parameter(Mandatory)]
        [string]$YamlOutPath,

        [string]$SchemaPath
    )

    # Parse the INI file
    $config = ConvertFrom-Ini -Path $IniPath

    # Validate against schema if provided
    $validationResult = $null
    if ($SchemaPath) {
        if (-not (Test-Path $SchemaPath)) {
            throw "Schema file '$SchemaPath' does not exist"
        }
        $schema = Get-Content $SchemaPath -Raw | ConvertFrom-Json
        $validationResult = Test-IniSchema -Config $config -Schema $schema
    }

    # Convert and write outputs
    $json = ConvertTo-JsonConfig -Config $config
    $yaml = ConvertTo-YamlConfig -Config $config

    $json | Set-Content -Path $JsonOutPath -Encoding utf8
    $yaml | Set-Content -Path $YamlOutPath -Encoding utf8

    return [PSCustomObject]@{
        Config           = $config
        ValidationResult = $validationResult
        JsonPath         = $JsonOutPath
        YamlPath         = $YamlOutPath
    }
}
