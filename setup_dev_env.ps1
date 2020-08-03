[CmdletBinding()]
param (
    [string]$config_file_path
)



########## FUNCTIONS ####################
function Quit ($exit_code = 0, $exception) {
    if ($exit_code -ne 0) {
        Write-Log -Level ERROR -Message $exception.Exception.Message
        Write-Log -Level DEBUG -Message $exception.InvocationInfo.PositionMessage
    }
    Write-Log '==> END OF LOG <=='
    $log_file_path = (Get-LoggingTarget File).Path
    Wait-Logging
    Remove-Module Logging -Force
    Write-Host "Log path: '$log_file_path'" -ForegroundColor Yellow
    if ($exit_code -ne 0) { notepad $log_file_path }
    exit $exit_code
}

function logger_init ($log_file_path) {
    Write-Host "initializing logger" -ForegroundColor DarkGray
    if (!$log_file_path) {
        $log_file_name = $timestamp, ($main_script_basename + '.log') -join ('_')
        $log_file_path = Join-Path (mkdir (Join-Path $PWD.path '.logs') -Force).FullName $log_file_name
    }
    $log_file_path = $log_file_path | abspath

    if (!(Get-Module Logging)) {
        if (!(Get-Module Logging -ListAvailable)) {
            Install-Module Logging -Force -Scope CurrentUser
        }
        Import-Module Logging -DisableNameChecking
    }

    Add-LoggingTarget -Name Console -Configuration @{
        Level        = 'INFO'
        Format       = ' %{level}: %{message}'
        ColorMapping = @{DEBUG = 'BLUE'; INFO = 'DarkGreen' ; WARNING = 'Yellow'; ERROR = 'Red' }
    }
    Add-LoggingTarget -Name File -Configuration @{
        Level  = 'DEBUG'
        Format = '[%{timestamp}] [%{filename:15}, ln.%{lineno:-3}] [%{level:7}] %{message}'
        Path   = $log_file_path
    }

    return (Get-LoggingTarget File).Path
}

function stage_manager {
    param (
        [Parameter(ParameterSetName = "init")]
        [switch]$init,

        [Parameter(ParameterSetName = "config")]
        $config,

        [Parameter(ParameterSetName = "config")]
        [string]$config_file_path
    )

    try {
        $stage_control_filepath = Join-Path $PSScriptRoot ".$($script:main_script_basename).stage"
        if (Test-Path $stage_control_filepath) {
            $stage_config = cat $stage_control_filepath -Raw | ConvertFrom-StringData
        }
    }
    catch {
        Write-Error "Failed to load .stage file"
        throw $_
    }

    $stages = @()

    if ($init) {
        try {
            if ($stage_config) {
                $log_file_path = $stage_config.log_file_path
                logger_init $log_file_path | Out-Null
                Write-Log '== CONTINUING LOG =='
            }
            else {
                $log_file_path = logger_init
                "log_file_path=$log_file_path" | escapepath | Out-File $stage_control_filepath -Force ascii | Out-Null
                Write-Log '<== BEGINNING OF LOG ==>'
            }

            return $null
        }
        catch {
            Write-Error "Failed to initiate logger"
            throw $_
        }
    }



    if ($config) {
        # foreach ($s) {}
    }
    #(ps)
    # if ($stage -ne 'vars') {

    # }
    #return $stages
}

function load_modules ([string[]]$modules) {
    foreach ($module_name in $modules) {
        try {
            Write-Log "Installing module: $module_name"
            if (!(Get-Module $module_name)) {
                if (!(Get-Module $module_name -ListAvailable)) {
                    Install-Module $module_name -Force -Scope CurrentUser
                }
                Import-Module $module_name -DisableNameChecking
            }
        }
        catch {
            Quit 1 $_
        }
    }
}

function load_main_config ($config_file_path) {
    if (!$config_file_path) {
        $config_file_path = Join-Path $PSScriptRoot "$main_script_basename`.yml"
    }
    $config_file_path = $config_file_path | abspath

    try {
        Write-Log "Loading configuration from '$config_file_path'"
        $main_config = cat $config_file_path -Raw | ConvertFrom-Yaml -Ordered
        return $main_config
    }
    catch {
        Quit 1 $_
    }
}



########## MAIN ####################
$ErrorActionPreference = 'stop'
$timestamp = get-date -f 'yyyy-MM-ddTHH-mm-ss'
$script:main_script_basename = (gi $PSCommandPath).BaseName
Import-Module .\scripts\util_functions.psm1 -Force -DisableNameChecking
restart_elevated -script_args $PSBoundParameters


### Init stage manager
stage_manager -init


### Load modules
load_modules powershell-yaml


### Load main config
$MAIN_CONFIG = load_main_config -config_file_path:$config_file_path


### Execute scripts
$stages = stage_manager -config $MAIN_CONFIG -config_file_path $config_file_path

try {
    foreach ($stage in $stages) {
        . (Resolve-Path $MAIN_CONFIG.$stage.script).Path -CONFIG $MAIN_CONFIG.$stage.config
    }
}
catch {
    Quit 1 $_
}


### Remove logger and exit
Quit
