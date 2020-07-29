[CmdletBinding()]
param (
    [string]$vscode_config_filepath = $(Join-Path (Split-Path $PSCommandPath) 'vscode.extensions.conf')
)

$ErrorActionPreference = 'Stop'

code --list-extensions | Out-File $vscode_config_filepath ascii -Force
