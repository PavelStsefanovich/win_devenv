[cmdletbinding()]
param (
    [string]$ConfigFilePath = $(throw "Required parameter not provided: -ConfigFilePath"),
    [string]$MainScriptDir = $(throw "Required parameter not provided: -MainScriptDir"),
    [switch]$UpdateConfigInPlace
)


$ErrorActionPreference = 'stop'
$excode = 1
$IS_VERBOSE = [bool]($PSCmdlet.MyInvocation.BoundParameters.Verbose)
$stage = (gi $PSCommandPath).BaseName
$ConfigFilePath = $ConfigFilePath | abspath -verify
$MainScriptDir = $MainScriptDir | abspath -verify

# dependencies
if ( !(Get-Module UtilityFunctions) ) { Import-Module -Name powershell-yaml -Force -Scope Local -DisableNameChecking }
if ( !(Get-Module powershell-yaml) ) { Import-Module -Name powershell-yaml -Force -Scope Local -DisableNameChecking }

# install chocolatey
info 'installing "Chocolatey Package Manager"'
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) | Out-Null
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

# load config
$config = cat $ConfigFilePath -Raw | ConvertFrom-Yaml -Ordered
$index = 0

# copy files
while ( $config.$stage[$index] ) {
    $item = $config.$stage[$index]
    info $item.description -sub

    # $success_exit_codes = @(0, 1641, 3010)
    # $LASTEXITCODE = 0

    if ( $item.args ) {
        $output = & choco install $item.name -y --parms "$($item.args)"
    }
    else {
        $output = & choco install $item.name -y
    }

    $failure_index = $output.IndexOf('Failures')

    if ( $failure_index -gt -1 ) {
        error ($output[$failure_index..($output.length -1)] -join "`n")
        $index++
    }
    else {
        $config.$stage.RemoveAt($index)
    }
}

# dump failed config
if ( $config.$stage.Count -eq 0 ) {
    $config.Remove($stage)
    $excode = 0
}

if ( $UpdateConfigInPlace ) {
    $config | ConvertTo-Yaml | Out-File $ConfigFilePath -Force -Encoding utf8
}

exit $excode
