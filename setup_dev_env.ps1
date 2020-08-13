[CmdletBinding()]
param (
    [string]$config_file_path,
    [switch]$from_beginning
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
        Format = '[%{timestamp}] [%{filename:25}, ln.%{lineno:-3}] [%{level:7}] %{message}'
        Path   = $log_file_path
    }

    return (Get-LoggingTarget File).Path
}

function stage_manager {
    param (
        [Parameter(ParameterSetName = "init")]
        [switch]$init,

        [Parameter(ParameterSetName = "config")]
        $main_config,

        [Parameter(ParameterSetName = "restart")]
        [switch]$restart,

        [Parameter(Mandatory = $true, ParameterSetName = "restart")]
        [string]$current_stage,

        [Parameter(ParameterSetName = "cleanup")]
        [switch]$cleanup
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

    ## ParameterSetName == "init"
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

    ## ParameterSetName == "restart"
    if ($restart) {
        $stage_config.current_stage = $current_stage
        $stage_config.keys | % { "$_=$($stage_config.$_)" } | escapepath | Out-File $stage_control_filepath -Force ascii | Out-Null
        exit
        #TODO add scheduled task registration
    }    

    ## ParameterSetName == "cleanup"
    if ($cleanup) {
        rm $stage_control_filepath -Force -ErrorAction SilentlyContinue | Out-Null
        return $null
    }

    ## ParameterSetName == "config"
    $stages_to_run = @()

    if ($main_config) {
        $all_stages = $main_config.getenumerator().name
        $current_stage = $stage_config.current_stage

        if (!$current_stage) {
            $current_stage = $all_stages[0]
        }

        for ($i = $all_stages.IndexOf($current_stage) + 1; $i -lt $all_stages.Length; $i++) {
            $stages_to_run += $all_stages[$i]
        }
    }

    return $stages_to_run
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
        $main_config.vars.config_file_path = $config_file_path
        return $main_config
    }
    catch {
        Quit 1 $_
    }
}

function show_report ($report_filepath) {
    Write-Host ("`n" + "_"*35)
    Write-Host "OVERALL REPORT:" -ForegroundColor White
    try {
        foreach ($line in cat $report_filepath) {
            $line_split = $line.split(':')
            $printline = " "*2
            $printline += $line_split[0] + ":"
            $printline += " "*(30 - $printline.Length)
            Write-Host $printline -ForegroundColor White -NoNewline
            if ($line_split[1] -eq 'ok') {
                Write-Host $line_split[1] -ForegroundColor Green
            }
            else {
                Write-Host $line_split[1] -ForegroundColor Red
            }
        }
        Write-Host ("_"*35)
    }
    catch {
        Write-Log -Level ERROR -Message "Failed to read report file '$report_filepath'"
        Write-Log -Level ERROR -Message $_
    }
}



########## MAIN ####################
$ErrorActionPreference = 'stop'
$timestamp = get-date -f 'yyyy-MM-ddTHH-mm-ss'
$script:main_script_basename = (gi $PSCommandPath).BaseName
Import-Module .\scripts\util_functions.psm1 -Force -DisableNameChecking
restart_elevated -script_args $PSBoundParameters
$report_filepath = Join-Path $PSScriptRoot ".$($script:main_script_basename).report"
ni $report_filepath -ItemType File -ErrorAction SilentlyContinue | Out-Null



### Drop current progress and start from beginning
if ($from_beginning) {
    stage_manager -cleanup
}


### Init stage manager
stage_manager -init


### Load modules
load_modules powershell-yaml 


### Load main config
$MAIN_CONFIG = load_main_config -config_file_path:$config_file_path


### Execute scripts
$stages = stage_manager -main_config $MAIN_CONFIG

foreach ($stage in $stages) {
    write-host "Executing script: $($MAIN_CONFIG.$stage.script)" -ForegroundColor Cyan
    try {
        . (Resolve-Path $MAIN_CONFIG.$stage.script).Path -CONFIG $MAIN_CONFIG.$stage.config
        "$stage`:ok" | Out-File $report_filepath -Append ascii
    }
    catch {
        Write-Log -Level ERROR -Message $_
        "$stage`:failed" | Out-File $report_filepath -Append ascii
    }

    if ($MAIN_CONFIG.$stage.restart_required) {
        if (system_restart_pending) {
            if (request_consent "System restart is pending. Do you want to restart now?") {
                Write-Log "Restarting computer"
                stage_manager -restart -current_stage $stage
            }
        }
    }
}


### Report, cleanup, close log and exit
stage_manager -cleanup
Wait-Logging
show_report $report_filepath
rm $report_filepath -Force
if (system_restart_pending) {Write-Log -Level WARNING -Message "System restart is pending. You may want to restart computer for changes to take effect"}
Quit
