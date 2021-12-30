[cmdletbinding(HelpUri = "")]
param (
    [string]$ConfigFilePath,
    [string]$StartStage,
    [switch]$SkipDependencies
)



##########  FUNCTIONS  ##########################################

#--------------------------------------------------
function IsAdmin {
    return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole] "Administrator")
}

#--------------------------------------------------
function RestartElevated {
    param(
        $arguments,
        [switch]$kill_original,
        [string]$workdir = $PWD.path
    )

    if ($MyInvocation.ScriptName -eq "") { throw 'Script must be saved as a .ps1 file.' }
    if (IsAdmin) { return $null }

    try {
        $script_fullpath = $MyInvocation.ScriptName
        $argline = "-noprofile -nologo -noexit"
        $argline += " -Command cd `"$workdir`"; `"$script_fullpath`""

        if ($arguments) {
            $arguments.GetEnumerator() | % {
                if ($_.Value -is [boolean]) { $argline += " -$($_.key) `$$($_.value)" }
                elseif ($_.Value -is [switch]) { $argline += " -$($_.key)" }
                else { $argline += " -$($_.key) `"$($_.value)`"" }
            }
        }

        $p = Start-Process "$PSHOME\powershell.exe" -Verb Runas -ArgumentList $argline -PassThru -ErrorAction 'stop'
        if ($kill_original) { [System.Diagnostics.Process]::GetCurrentProcess() | Stop-Process -ErrorAction Stop }
        write "Elevated process id: $($p.id)"
        exit
    }
    catch {
        error "Failed to restart script with elevated premissions."
        throw $_
    }
}

#--------------------------------------------------
function ContinueAfterRestart {
    param(
        [string]$scriptpath,
        [hashtable]$arguments,
        [string]$working_directory = $PWD.path,
        [string]$task_name
    )

    $ErrorActionPreference = 'stop'

    try {
        if (!$task_name) {
            $task_name = "runafterrestart", (Split-Path $scriptpath -Leaf) -join ('_')
        }

        Unregister-ScheduledTask -TaskName $task_name -Confirm:$false -ErrorAction SilentlyContinue

        $argstring = "-NoProfile -NoLogo -NoExit -ExecutionPolicy Bypass -Command `"& '$scriptpath'"
        $arguments.GetEnumerator() | % {
            if ( $_.value.GetType() -eq [string] ) {
                if  ($_.value.Length -gt 0 ) { $argstring += " -$($_.key) '$($_.value)'" }
                else { $argstring += " -$($_.key)" }
            }
            else { $argstring += " -$($_.key) $($_.value)" }

        }
        $argstring += '"'

        if ($working_directory) {
            $action = New-ScheduledTaskAction -Execute (gcm powershell).Source -Argument $argstring -WorkingDirectory $working_directory
        }
        else {
            $action = New-ScheduledTaskAction -Execute (gcm powershell).Source -Argument $argstring
        }

        $user = $env:USERDOMAIN, $env:USERNAME -join ('\')
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
        $principal = New-ScheduledTaskPrincipal -UserId $user -RunLevel Highest -LogonType Interactive
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
        $task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings
        Register-ScheduledTask $task_name -InputObject $task | out-null

        return $task_name
    }
    catch {
        Write-Error "ERROR: Failed to register scheduled task."
        throw $_
    }
}




##########  MAIN  ###############################################

#--------------------------------------------------
# INIT
$ErrorActionPreference = 'Stop'
$STOPWATCH = [diagnostics.stopwatch]::StartNew()
$host.PrivateData.ErrorBackgroundColor = $host.UI.RawUI.BackgroundColor
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
$IS_VERBOSE = [bool]($PSCmdlet.MyInvocation.BoundParameters.Verbose)
$MAIN_SCRIPT_FULL_PATH = $PSCommandPath
$MAIN_SCRIPT_DIR = $PSScriptRoot
$MAIN_SCRIPT_BASE_NAME = (gi $PSCommandPath).BaseName
$WORKDIR = $PWD.Path
$ScriptsDir = Join-Path $MAIN_SCRIPT_DIR 'scripts'
$ScheduledTaskName = "runatlogon_$MAIN_SCRIPT_BASE_NAME"


#--------------------------------------------------
# RESTART ELEVATED
RestartElevated -arguments $PSBoundParameters


#--------------------------------------------------
# REMOVE SCHEDULED TASK IF EXISTS
Unregister-ScheduledTask `
    -TaskName $ScheduledTaskName `
    -Confirm:$false `
    -ErrorAction SilentlyContinue


#--------------------------------------------------
# INSTALL PREREQUISITES
if ( !$SkipDependencies ) {
    Write-Host "  Installing dependencies"

    Write-Host "   Nuget package provider" -ForegroundColor DarkGray
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null

    Write-Host "   PackageManagement module" -ForegroundColor DarkGray
    Install-Module -Name PackageManagement -Force -MinimumVersion 1.4.6 -Scope CurrentUser -WarningAction SilentlyContinue

    Write-Host "   PowerShellGet module" -ForegroundColor DarkGray
    Install-Module -Name PowerShellGet -Force -Scope AllUsers -AllowClobber -WarningAction SilentlyContinue

    Write-Host "   UtilityFunctions module" -ForegroundColor DarkGray
    Install-Module -Name UtilityFunctions -Force -Scope CurrentUser -WarningAction SilentlyContinue

    Write-Host "   WinRegistry module" -ForegroundColor DarkGray
    Install-Module -Name WinRegistry -Force -Scope CurrentUser -WarningAction SilentlyContinue

    Write-Host "   PowershellYaml module" -ForegroundColor DarkGray
    Install-Module -Name "powershell-yaml" -Force -Scope CurrentUser -WarningAction SilentlyContinue
}


#--------------------------------------------------
# LOAD MODULES
Write-Host "  Loading modules"

Write-Host "   UtilityFunctions" -ForegroundColor DarkGray
Import-Module -Name UtilityFunctions -Force -Scope Local -DisableNameChecking

Write-Host "   WinRegistry" -ForegroundColor DarkGray
Import-Module -Name WinRegistry -Force -Scope Local -DisableNameChecking

Write-Host "   PowershellYaml" -ForegroundColor DarkGray
Import-Module -Name powershell-yaml -Force -Scope Local -DisableNameChecking


#--------------------------------------------------
# LOAD CONFIG
if ( $ConfigFilePath ) {
    info "Loading config from file `"$ConfigFilePath`""
    $ConfigFilePath = $ConfigFilePath | abspath -verify
    $CONFIG = cat $ConfigFilePath -Raw | ConvertFrom-Yaml -Ordered
}
else {
    $ConfigFilePath = Join-Path $PSScriptRoot "$MAIN_SCRIPT_BASE_NAME`.yml"
    info "Loading config from file `"$ConfigFilePath`""
    $ConfigFilePath = $ConfigFilePath | abspath -verify
    $CONFIG = cat $ConfigFilePath -Raw | ConvertFrom-Yaml -Ordered
    $ConfigFilePath = Join-Path $WORKDIR "progress_$MAIN_SCRIPT_BASE_NAME`.yml"
    $config | ConvertTo-Yaml | Out-File $ConfigFilePath -Force
}


#--------------------------------------------------
# EXECUTE SCRIPTS
foreach ( $stage in $CONFIG.sequence ) {

    # if -StartStage specified, then skip until current stage matches
    if ( $StartStage ) {
        if ( $stage -eq $StartStage ) { $StartStage = $null }
        else { continue }
    }

    # run only if stage config exists
    if ( $CONFIG.$stage ) {
        newline
        info "Stage: $stage"

        # check if system restart is pending
        if ( isrp ) {
            if ( confirm "System restart is pending. Restart now? (setup will continue after restart)" ) {
                info "Restarting"

                $arguments = @{
                    'ConfigFilePath'   = $ConfigFilePath;
                    'StartStage'       = $stage;
                    'SkipDependencies' = ''
                }

                ContinueAfterRestart `
                    -scriptpath $MAIN_SCRIPT_FULL_PATH `
                    -arguments $arguments `
                    -task_name $ScheduledTaskName | `
                Out-Null

                Restart-Computer -Force
            }
        }

        $script_path = Join-Path $ScriptsDir "$stage`.ps1" | abspath -verify
        Write-Verbose "Executing: $script_path"
        & $script_path `
            -ConfigFilePath $ConfigFilePath `
            -MainScriptDir $MAIN_SCRIPT_DIR `
            -UpdateConfigInPlace `
            -Verbose:$IS_VERBOSE

        if ( $LASTEXITCODE -eq 0 ) { info "ok" -success }
        else { warning "stage `"$stage`" completed with errors" -noprefix }
    }
}


#--------------------------------------------------
# ELAPSED TIME
newline
info "SETUP FINISHED in $($STOPWATCH.Elapsed.Minutes) Minutes $($STOPWATCH.Elapsed.Seconds) Seconds."


#--------------------------------------------------
# OPEN PROGRESS CONFIG FILE TO SHOW FAILED/SKIPPED ITEMS
$notepad = "notepad.exe"

if ( Test-Path "C:\Program Files\Notepad++\notepad++.exe" ) {
    $notepad = "C:\Program Files\Notepad++\notepad++.exe"
}

newline
info "Opening current progress file..."
info "(any entries other than under `"sequence`" key indicate failed or skipped steps)" -sub
sleep 2
& $notepad $ConfigFilePath
newline
