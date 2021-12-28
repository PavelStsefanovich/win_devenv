[cmdletbinding()]
param (
    [string]$ConfigFilePath = $(throw "Required parameter not provided: -ConfigFilePath"),
    [string]$MainScriptDir = $(throw "Required parameter not provided: -MainScriptDir"),
    [switch]$UpdateConfigInPlace
)


$ErrorActionPreference = 'stop'
$excode = 1
$stage = (gi $PSCommandPath).BaseName
$ConfigFilePath = $ConfigFilePath | abspath -verify
$MainScriptDir = $MainScriptDir | abspath -verify

# dependencies
if ( !(Get-Module UtilityFunctions) ) { Import-Module -Name powershell-yaml -Force -Scope Local -DisableNameChecking }
if ( !(Get-Module powershell-yaml) ) { Import-Module -Name powershell-yaml -Force -Scope Local -DisableNameChecking }
if ( !(Get-Module WinRegistry) ) { Import-Module -Name WinRegistry -Force -Scope Local -DisableNameChecking }

# load config
$config = cat $ConfigFilePath -Raw | ConvertFrom-Yaml -Ordered
$index = 0

# copy files
while ( $config.$stage[$index] ) {
    $item = $config.$stage[$index]
    info $item.description -sub

    try {
        Set-RegKeyPropertyValue `
            -RegPath $item.key `
            -Property $item.property `
            -Value $item.value `
            -ValueType $item.type `
            -Force

        # remove from config, if succeded
        $config.$stage.RemoveAt($index)
    }
    catch {
        error "$($_.exception)"
        $index++
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
