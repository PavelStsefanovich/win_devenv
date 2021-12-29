[cmdletbinding()]
param (
    [string]$ConfigFilePath = $(throw "Required parameter not provided: -ConfigFilePath"),
    [string]$MainScriptDir,
    [switch]$UpdateConfigInPlace
)


$ErrorActionPreference = 'stop'
$excode = 1
$IS_VERBOSE = [bool]($PSCmdlet.MyInvocation.BoundParameters.Verbose)
$stage = (gi $PSCommandPath).BaseName
$ConfigFilePath = $ConfigFilePath | abspath -verify

# dependencies
if ( !(Get-Module UtilityFunctions) ) { Import-Module -Name powershell-yaml -Force -Scope Local -DisableNameChecking }
if ( !(Get-Module powershell-yaml) ) { Import-Module -Name powershell-yaml -Force -Scope Local -DisableNameChecking }

# load config
$config = cat $ConfigFilePath -Raw | ConvertFrom-Yaml -Ordered
$index = 0

# run utilities
while ( $config.$stage[$index] ) {
    $item = $config.$stage[$index]
    info $item.description -sub
    
    $success_exit_codes = $item.success_exit_codes
    if ( !$success_exit_codes ) { $success_exit_codes = @(0) }
    
    if ( $IS_VERBOSE ) { Write-Verbose "EXECUTING: $($item.exe) $($item.args)" }
    try { $process = run-process $item.exe $item.args -no_console_output }
    catch {
        if ( $_.exception -like '*Failed to validate parameter <executable>*' ) {
            $process = @{
                'errcode' = -1;
                'stderr'  = "Failed to resolve executable `"$($item.exe)`""
            }
        }
    }

    #TODO replace 'errcode' with 'exitcode' after UtilFunctions update 
    if ( $process.errcode -in $success_exit_codes ) {
        $config.$stage.RemoveAt($index)
    }
    else {
        if ( $process.stderr ) { error $process.stderr }
        else { error $process.stdout }
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
