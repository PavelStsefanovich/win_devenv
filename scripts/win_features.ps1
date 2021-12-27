# [cmdletbinding()]
param (
    [string]$ConfigFilePath = $(throw "Required parameter not provided: -ConfigFilePath"),
    [switch]$UpdateConfigInPlace
)


$ErrorActionPreference = 'stop'
$excode = 1
# $IS_VERBOSE = [bool]($PSCmdlet.MyInvocation.BoundParameters.Verbose)
$stage = (gi $PSCommandPath).BaseName
$ConfigFilePath = $ConfigFilePath | abspath -verify

# dependencies
if ( !(Get-Module UtilityFunctions) ) { Import-Module -Name powershell-yaml -Force -Scope Local -DisableNameChecking }
if ( !(Get-Module powershell-yaml) ) { Import-Module -Name powershell-yaml -Force -Scope Local -DisableNameChecking }

# load config
$config = cat $ConfigFilePath -Raw | ConvertFrom-Yaml -Ordered
$index = 0

# Enable features
while ( $config.$stage[$index] ) {
    $item = $config.$stage[$index]
    info " enabling feature `"$($item.name)`"" -sub
    $command = "Enable-WindowsOptionalFeature -FeatureName $($item.name) -online -norestart"
    if ( $item.all ) { $command += " -all" }
    $command += " | Out-Null"

    try {
        $scriptblock = [scriptblock]::Create($command)
        icm $scriptblock

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
