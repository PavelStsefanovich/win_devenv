[CmdletBinding()]
param (
    [string]$vscode_config_filepath = $(Join-Path (Split-Path $PSCommandPath) 'vscode.extensions.conf')
)

$ErrorActionPreference = 'Stop'
$install = $true
Write-Host " :: Installing VScode extensions"

$ExtFile = (Resolve-Path $vscode_config_filepath -ErrorAction SilentlyContinue).Path

if ($ExtFile) {
    $vscode_extensions = cat $ExtFile
} else {
    Write-Warning "(!) File not found: '$vscode_config_filepath'"
    $install = $false
}

$env:path = $env:path.TrimEnd(';') + ';' + [System.Environment]::GetEnvironmentVariable('Path','Machine').split(';') | ?{$_ -like '*VS Code*'}
if (!(gcm 'code' -ErrorAction SilentlyContinue)) {
    Write-Warning "(!) vscode not found."
    Write-Warning "Restarting powershell and running this script again might help."
    $install = $false
}

if ($install) {
    foreach ($extension in $vscode_extensions) {
        write-host " - installing: $extension" -ForegroundColor DarkGray
        code --install-extension $extension --force
    }
} else {
    Write-Host " :: Skipped VScode extensions"
}
