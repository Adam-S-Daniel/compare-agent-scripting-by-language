# ConfigMigrator.psm1
# Config File Migrator: INI -> JSON + YAML
#
# Architecture:
#   1. Convert-IniValue       — coerce a raw string to the best PowerShell type
#   2. Format-YamlString      — safely quote a string for YAML
#   3. Format-YamlValue       — format any typed value for YAML
#   4. Read-IniFile           — parse an INI file into a hashtable
#   5. Test-IniSchema         — validate parsed config against a schema
#   6. ConvertTo-JsonConfig   — serialize hashtable to JSON string
#   7. ConvertTo-YamlConfig   — serialize hashtable to YAML string
#   8. Invoke-ConfigMigration — orchestrate the full INI -> JSON + YAML pipeline

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# 1. Convert-IniValue
#    Coerces a raw INI string to the most appropriate PowerShell type.
#    Precedence: bool keywords -> integer -> double -> string
# ---------------------------------------------------------------------------
function Convert-IniValue {
    [CmdletBinding()]
    [OutputType([System.Object])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value
    )

    # Boolean keyword coercion (case-insensitive)
    [string]$lower = $Value.ToLower()
    if ($lower -in @('true', 'yes', 'on')) {
        return [bool]$true
    }
    if ($lower -in @('false', 'no', 'off')) {
        return [bool]$false
    }

    # Integer coercion
    [int]$intResult = 0
    if ([int]::TryParse($Value, [ref]$intResult)) {
        return [int]$intResult
    }

    # Float coercion (invariant culture so '.' is always the decimal separator)
    [double]$dblResult = 0.0
    if ([double]::TryParse(
            $Value,
            [System.Globalization.NumberStyles]::Any,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [ref]$dblResult)) {
        return [double]$dblResult
    }

    # Default: keep as string
    return [string]$Value
}

# ---------------------------------------------------------------------------
# 2. Format-YamlString
#    Returns a YAML-safe representation of a string scalar.
#    Applies double-quoting when the value contains special YAML characters
#    or would be misinterpreted by a YAML parser.
# ---------------------------------------------------------------------------
function Format-YamlString {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value
    )

    # Empty string must be quoted
    if ($Value -eq '') {
        return "''"
    }

    # YAML reserved scalars that must be quoted when used as strings
    [string[]]$yamlKeywords = @(
        'true', 'True', 'TRUE',
        'false', 'False', 'FALSE',
        'yes', 'Yes', 'YES',
        'no', 'No', 'NO',
        'on', 'On', 'ON',
        'off', 'Off', 'OFF',
        'null', 'Null', 'NULL', '~'
    )

    [bool]$needsQuoting = (
        ($Value -in $yamlKeywords) -or
        ($Value -match '[:#\[\]{},&*?|<>=!%@`\\]') -or
        ($Value -match '^\s') -or
        ($Value -match '\s$') -or
        ($Value -match '^\d') -or
        ($Value -match '^-\d') -or
        ($Value[0] -eq '"') -or
        ($Value[0] -eq "'")
    )

    if ($needsQuoting) {
        # Escape backslashes and double-quotes, then wrap in double-quotes
        [string]$escaped = $Value.Replace('\', '\\').Replace('"', '\"')
        return "`"$escaped`""
    }

    return $Value
}

# ---------------------------------------------------------------------------
# 3. Format-YamlValue
#    Dispatches typed values to their YAML scalar representation.
# ---------------------------------------------------------------------------
function Format-YamlValue {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [AllowNull()]
        [System.Object]$Value
    )

    if ($Value -is [bool]) {
        # PowerShell booleans serialize as 'True'/'False'; YAML needs lowercase
        if ([bool]$Value) { return 'true' } else { return 'false' }
    }

    if ($Value -is [int]) {
        return ([int]$Value).ToString([System.Globalization.CultureInfo]::InvariantCulture)
    }

    if ($Value -is [double] -or $Value -is [float]) {
        # 'G' format: shortest round-trip representation; InvariantCulture for '.'
        return ([double]$Value).ToString('G', [System.Globalization.CultureInfo]::InvariantCulture)
    }

    # Everything else is treated as a string
    return Format-YamlString -Value ([string]$Value)
}

# ---------------------------------------------------------------------------
# 4. Read-IniFile
#    Parses an INI file and returns a nested hashtable.
#
#    Supported features:
#      [Section]              — section headers
#      key = value            — key/value with '=' separator
#      key: value             — key/value with ':' separator
#      ; comment / # comment  — full-line comments (skipped)
#      key = val ; comment    — inline comment stripped (space before ; or #)
#      key = line1 \          — backslash continuation (multi-line values)
#            line2
#    Type coercion is applied via Convert-IniValue.
# ---------------------------------------------------------------------------
function Read-IniFile {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path -PathType Leaf)) {
        throw "INI file not found: '$Path'"
    }

    [hashtable]$result        = @{}
    [string]   $currentSection = ''
    [string[]] $lines          = [string[]](Get-Content -Path $Path)
    [int]      $i              = 0

    while ($i -lt $lines.Count) {
        [string]$line = $lines[$i]

        # Skip blank lines
        if ([string]::IsNullOrWhiteSpace($line)) {
            $i++
            continue
        }

        [string]$trimmed = $line.TrimStart()

        # Skip comment lines (must start with ; or # after leading whitespace)
        if ($trimmed.StartsWith(';') -or $trimmed.StartsWith('#')) {
            $i++
            continue
        }

        # Section header: [SectionName]
        if ($trimmed -match '^\[([^\]]+)\]') {
            $currentSection = [string]$Matches[1].Trim()
            if (-not $result.ContainsKey($currentSection)) {
                $result[$currentSection] = [hashtable]@{}
            }
            $i++
            continue
        }

        # Key-value pair: first '=' or ':' separates key from value
        # [^=:]+ stops at the first separator, (.*) captures the rest
        if ($trimmed -match '^([^=:]+)[=:](.*)$') {
            [string]$key   = [string]$Matches[1].Trim()
            [string]$value = [string]$Matches[2].Trim()

            # Multi-line: backslash at end of value continues on next line
            while ($value.EndsWith('\') -and ($i + 1) -lt $lines.Count) {
                $value = [string]$value.Substring(0, $value.Length - 1).TrimEnd()
                $i++
                [string]$continuation = [string]$lines[$i].Trim()
                $value = "$value $continuation"
            }

            # Strip inline comments: must be preceded by at least one space
            [int]$semiIdx = $value.IndexOf(' ;')
            [int]$hashIdx = $value.IndexOf(' #')
            [int]$commentAt = -1

            if ($semiIdx -ge 0 -and $hashIdx -ge 0) {
                $commentAt = [int][Math]::Min($semiIdx, $hashIdx)
            } elseif ($semiIdx -ge 0) {
                $commentAt = $semiIdx
            } elseif ($hashIdx -ge 0) {
                $commentAt = $hashIdx
            }

            if ($commentAt -ge 0) {
                $value = [string]$value.Substring(0, $commentAt).TrimEnd()
            }

            [System.Object]$coerced = Convert-IniValue -Value $value

            if ($currentSection -ne '') {
                [hashtable]$section = [hashtable]$result[$currentSection]
                $section[$key] = $coerced
            } else {
                $result[$key] = $coerced
            }
        }

        $i++
    }

    return $result
}

# ---------------------------------------------------------------------------
# 5. Test-IniSchema
#    Validates a parsed config hashtable against a schema.
#
#    Schema shape:
#      @{
#          SectionName = @{
#              required = @('key1', 'key2')      # mandatory keys
#              types    = @{                      # expected PowerShell type names
#                  key1 = 'string'               # 'string' | 'int' | 'float' | 'bool' | 'number'
#                  key2 = 'int'
#              }
#          }
#      }
#
#    Returns: @{ IsValid = [bool]; Errors = [string[]] }
# ---------------------------------------------------------------------------
function Test-IniSchema {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,

        [Parameter(Mandatory)]
        [hashtable]$Schema
    )

    [System.Collections.Generic.List[string]]$errors =
        [System.Collections.Generic.List[string]]::new()

    foreach ($sectionName in $Schema.Keys) {
        [hashtable]$sectionSchema = [hashtable]$Schema[$sectionName]

        # Check required keys array exists and is non-empty before treating
        # an absent section as an error.
        [bool]$hasRequired = (
            $sectionSchema.ContainsKey('required') -and
            ([array]$sectionSchema['required']).Count -gt 0
        )

        if (-not $Config.ContainsKey($sectionName)) {
            if ($hasRequired) {
                [void]$errors.Add("Section '$sectionName' is missing from config")
            }
            continue
        }

        [hashtable]$configSection = [hashtable]$Config[$sectionName]

        # Required-key checks
        if ($sectionSchema.ContainsKey('required')) {
            [string[]]$requiredKeys = [string[]]$sectionSchema['required']
            foreach ($rk in $requiredKeys) {
                if (-not $configSection.ContainsKey($rk)) {
                    [void]$errors.Add(
                        "Required key '$rk' is missing in section '$sectionName'"
                    )
                }
            }
        }

        # Type checks (only for keys that actually exist in config)
        if ($sectionSchema.ContainsKey('types')) {
            [hashtable]$types = [hashtable]$sectionSchema['types']
            foreach ($typeKey in $types.Keys) {
                if (-not $configSection.ContainsKey($typeKey)) {
                    continue   # absent optional key — not a type violation
                }

                [System.Object]$val = $configSection[$typeKey]
                [string]$expectedType = [string]$types[$typeKey]
                [bool]$ok = $false

                switch ($expectedType.ToLower()) {
                    'string' { $ok = $val -is [string] }
                    'int'    { $ok = $val -is [int] }
                    'float'  { $ok = ($val -is [double]) -or ($val -is [float]) }
                    'bool'   { $ok = $val -is [bool] }
                    'number' { $ok = ($val -is [int]) -or ($val -is [double]) -or ($val -is [float]) }
                    default  {
                        [void]$errors.Add(
                            "Unknown schema type '$expectedType' for key '$typeKey' in section '$sectionName'"
                        )
                        $ok = $true   # don't also add a type-mismatch error
                    }
                }

                if (-not $ok) {
                    [void]$errors.Add(
                        "Key '$typeKey' in section '$sectionName' should be type '$expectedType'" +
                        " but got '$($val.GetType().Name)'"
                    )
                }
            }
        }
    }

    return [hashtable]@{
        IsValid = [bool]($errors.Count -eq 0)
        Errors  = [string[]]$errors.ToArray()
    }
}

# ---------------------------------------------------------------------------
# 6. ConvertTo-JsonConfig
#    Serializes a config hashtable to a pretty-printed JSON string.
# ---------------------------------------------------------------------------
function ConvertTo-JsonConfig {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    return [string]($Config | ConvertTo-Json -Depth 10)
}

# ---------------------------------------------------------------------------
# 7. ConvertTo-YamlConfig
#    Serializes a config hashtable to a YAML string.
#    Keys are sorted alphabetically for deterministic output.
#    Top-level hashtable values are treated as sections (one indentation level).
# ---------------------------------------------------------------------------
function ConvertTo-YamlConfig {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

    foreach ($key in ($Config.Keys | Sort-Object)) {
        [System.Object]$value = $Config[$key]

        if ($value -is [hashtable]) {
            # Section block
            [void]$sb.AppendLine("${key}:")
            foreach ($subKey in (([hashtable]$value).Keys | Sort-Object)) {
                [System.Object]$subValue = ([hashtable]$value)[$subKey]
                [string]$yamlVal = Format-YamlValue -Value $subValue
                [void]$sb.AppendLine("  ${subKey}: ${yamlVal}")
            }
        } else {
            # Global (top-level) key
            [string]$yamlVal = Format-YamlValue -Value $value
            [void]$sb.AppendLine("${key}: ${yamlVal}")
        }
    }

    return [string]$sb.ToString().TrimEnd()
}

# ---------------------------------------------------------------------------
# 8. Invoke-ConfigMigration
#    Full pipeline: read INI -> validate schema -> write JSON + YAML.
#    Throws if validation fails, providing the list of errors.
# ---------------------------------------------------------------------------
function Invoke-ConfigMigration {
    [CmdletBinding()]
    [OutputType([System.Void])]
    param(
        [Parameter(Mandatory)]
        [string]$InputPath,

        [Parameter(Mandatory)]
        [hashtable]$Schema,

        [Parameter(Mandatory)]
        [string]$JsonOutputPath,

        [Parameter(Mandatory)]
        [string]$YamlOutputPath
    )

    # Step 1: parse
    [hashtable]$config = Read-IniFile -Path $InputPath

    # Step 2: validate
    [hashtable]$validation = Test-IniSchema -Config $config -Schema $Schema

    if (-not [bool]$validation['IsValid']) {
        [string[]]$errs = [string[]]$validation['Errors']
        [string]$msg = "Config validation failed for '$InputPath':`n" + ($errs -join "`n")
        throw $msg
    }

    # Step 3: emit JSON
    [string]$json = ConvertTo-JsonConfig -Config $config
    Set-Content -Path $JsonOutputPath -Value $json -Encoding UTF8

    # Step 4: emit YAML
    [string]$yaml = ConvertTo-YamlConfig -Config $config
    Set-Content -Path $YamlOutputPath -Value $yaml -Encoding UTF8

    Write-Verbose "Migration complete: '$InputPath' -> '$JsonOutputPath', '$YamlOutputPath'"
}
