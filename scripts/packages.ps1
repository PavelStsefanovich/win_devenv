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

# load config
$config = cat $ConfigFilePath -Raw | ConvertFrom-Yaml -Ordered
$index = 0

# deploy packages
while ( $config.$stage[$index] ) {
    $item = $config.$stage[$index]
    info $item.description -sub
    $failure = $null

    $installer_filepath = $item.installer | abspath -parent $MainScriptDir

    if ( ! (Test-Path $installer_filepath) ) {
        # download installer
        if ( $item.url ) {
            try {
                [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
                $wc = New-Object System.Net.WebClient
                $wc.DownloadFile($item.url, $installer_filepath)
            }
            catch {
                $failure = "Donwload failed: " + $_.exception.InnerException.InnerException.Message
            }
        }
        # fail if not found
        else {
            $failure = "Cannot find path `"$installer_filepath`""
        }
    }

    # run installer
    if ( ! $failure ) {
        $success_exit_codes = $item.success_exit_codes
        if ( ! $success_exit_codes ) { $success_exit_codes = @(0) }

        # type: msi
        if ( $item.type -eq 'msi' ) {
            $arguments = "/i `"$installer_filepath`""
            if ( ! $item.interactive ) { $arguments += " /qn" }
            if ( $item.args ) { $arguments += " $($item.args)" }
            $installer_filepath = "msiexec"
        }
        # type: exe
        else {
            $arguments = $item.args
        }

        if ( $item.interactive ) {
            warning " Interactive Install: follow prompts of the external installer" -noprefix
        }

        # execute
        if ( $IS_VERBOSE ) { Write-Verbose "EXECUTING: `"$installer_filepath`" $arguments" }
        $process = start $installer_filepath `
            -ArgumentList $arguments `
            -Wait `
            -PassThru

        if ( $process.ExitCode -notin $success_exit_codes ) {
            $executable = Split-Path $installer_filepath -Leaf
            $failure = "`"$executable`" failed with exit code `"$($process.ExitCode)`""
        }
    }

    if ( $failure ) {
        error $failure
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
