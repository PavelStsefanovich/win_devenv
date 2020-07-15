# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}

# EnvVars >>
# EnvVars <<

# Functions >>
function prompt {
    $current_location = $pwd.Path
    (Get-Host).UI.RawUI.WindowTitle = (Get-Host).UI.RawUI.WindowTitle -replace '[C-Z]\:\\.*$', $current_location

    $prompt = "@ "
    $pathArray = $current_location.split('\')
    if ($pathArray.length -lt 4) {
        if ($pathArray[1].length -eq 0) {
            $prompt += $current_location + ">"
        }
        else {
            $prompt += $current_location + "\>"
        }
    }
    else {
        $prompt += $pathArray[0] + "\..\" + $pathArray[$pathArray.length - 2] + "\" + $pathArray[$pathArray.length - 1] + "\>"
    }

    $prompt
}
function Invoke-ComputerSleep {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Application]::SetSuspendState("Suspend", $false, $true);
}
function Test-RestartRequired {
    $isRestartRequired = $false

    if (Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -EA Ignore) { $isRestartRequired = $true }
    if (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -EA Ignore) { $isRestartRequired = $true }
    if (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -EA Ignore) { $isRestartRequired = $true }

    try { 
        $util = [wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities"
        $status = $util.DetermineIfRebootPending()
        if (($status -ne $null) -and $status.RebootPending) {
            $isRestartRequired = $true
        }
    }
    catch { }

    return $isRestartRequired
}
function Wait-AnyKey {
    $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
}
# Functions <<

# Modules >>
# $env:PSModulePath = $env:PSModulePath.TrimEnd(';') + ';' + 'E:\Additional_Module_path'
# Import-Module UtilFunctions -Force -DisableNameChecking
# Modules <<

# Assemblies >>
# Assemblies <<

# Title >>
$title = whoami
if (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { $title += "  ADMIN" }
else { $title += "  (no admin)" }
$title += "   $($pwd.path)"
(Get-Host).UI.RawUI.WindowTitle = $title
# Title <<

# Aliases >>
Set-Alias -Name ics -Value Invoke-ComputerSleep
Set-Alias -Name hib -Value Invoke-ComputerSleep
Set-Alias -Name isres -Value Test-RestartRequired
Set-Alias -Name wait -Value Wait-AnyKey
Set-Alias -Name npp -Value "C:\Program Files\Notepad++\notepad++.exe"
# Aliases <<

# Commands >>
$host.PrivateData.ErrorBackgroundColor = $host.UI.RawUI.BackgroundColor
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
$default_locations = @('C:\Windows\system32', $HOME)

if ($pwd.Path -in $default_locations) {
    try {
        cd E:\WORKSHOP -ErrorAction Stop
    }
    catch {
        Write-Warning 'Directory not found: "E:\GoogleDrive\stse.pavell\UsefullScripts"'
    }
}

write-host "`nAliases:`n"
(Get-Alias hib, isres, wait, npp).DisplayName | % { " $_" }


Write-Host "`nCurrent directory: $($pwd.path)`n"
if ($pwd.Path -notin $default_locations) {    
    ls | % { " " + ($_.mode, $_.name -join ("`t")) }
    write-host ""
}
# Commands <<
