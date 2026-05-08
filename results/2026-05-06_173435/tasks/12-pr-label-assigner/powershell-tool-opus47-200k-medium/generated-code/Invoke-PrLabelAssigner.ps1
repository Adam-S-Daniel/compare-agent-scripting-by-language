# Thin CLI wrapper. Pwsh script-level params must live at the top of a file,
# so this exists as a separate entrypoint that dot-sources the library.
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $RulesPath,
    [Parameter(Mandatory)] [string] $FilesPath
)

. "$PSScriptRoot/PrLabelAssigner.ps1"
Invoke-PrLabelAssigner -RulesPath $RulesPath -FilesPath $FilesPath
