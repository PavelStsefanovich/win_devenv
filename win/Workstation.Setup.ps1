[CmdletBinding()]
Param (
    [switch]$NoProfileUpdate,
    [switch]$NoExplorerRestart
)

#=== Functions

function Request-Consent ([string]$question) {
    do {
        Write-Host " (?) $question" -ForegroundColor Yellow
        $reply = [string]$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
        if ($reply.tolower() -notin 'y','n') {
            Write-Host "It's a yes/no question."
        }
    }
    while ($reply.tolower() -notin 'y','n')

    switch ($reply) {
        'y' {return $true}
        'n' {return $false}
    }   
}

function Wait-AnyKey {
    $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
}

function Get-InstallRecord ([string]$displayName,[switch]$precise) {
    $uninstallKey = 'HKLM:/SOFTWARE/Microsoft/Windows/CurrentVersion/Uninstall'
    $installedSoftware = gp (ls $uninstallKey).name.Replace('HKEY_LOCAL_MACHINE','HKLM:')
    if ($precise) {
        $installationRecord = $installedSoftware | ?{$_.displayname -eq $displayName}
    } else {
        $installationRecord = $installedSoftware | ?{$_.displayname -like "*$displayName*"}
    }
    
    if ($installedSoftware) {
        return $installationRecord
    } else {
        return $null
    }
}

function Show-Step ([string]$message) {
    Write-Host " :$message" -ForegroundColor Gray -NoNewline
}

function Show-Result ([bool]$result,[string]$message) {
    if ($result) {
        Write-Host "ok" -ForegroundColor Green
    } else {
        Write-Host "failed" -ForegroundColor Red
        Write-Host $message -ForegroundColor Yellow
    }
}

function Get-RegistryValueType ([string]$key,[string]$item) {

    $itemType = ([string](gi $key -ErrorAction Stop).getvaluekind($item)).toUpper()
    if ($itemType -notin 'String','ExpandString','Binary','DWord','MultiString','QWord','Unknown') {
        throw "Unknown registry value type: '$itemType'."
    }    
    return $itemType
}

function Set-RegistryData {
    [CmdletBinding()]
    param (
        [parameter()]
        [string]$key = $(throw "Mandatory argument not provided: <key>."),

        [parameter()]
        [string]$item = $(throw "Mandatory argument not provided: <item>."),

        [parameter()]
        [ValidateSet('String','ExpandString','Binary','DWord','MultiString','QWord','Unknown',$null)]
        [string]$itemType = $null,

        [parameter()]
        $value = $null
    )

    $ErrorActionPreference = 'Stop'

    if ($key.StartsWith('Computer\')) {
        $key = $key.Substring(9)
    }

    if ($key.StartsWith('HKEY_CURRENT_USER\')) {
        $key = "HKCU:" + $key.Substring(17)
    }

    if ($key.StartsWith('HKEY_LOCAL_MACHINE\')) {
        $key = "HKLM:" + $key.Substring(18)
    }

    if (!$itemType) {
        $itemType = Get-RegistryValueType $key -item $item
    }
    
    #- create missing directories in $key
    $path = $key
    $paths = @()
    while (!(Test-Path $path)) {
        $paths += $path
        $path = $path | Split-Path
    }
    $paths[($paths.Length -1)..0] | %{New-Item $_ | Out-Null}

    #- create registry value with data
    New-ItemProperty $key -Name $item -PropertyType $itemType -Value $value -Force | Out-Null
}


#=== Initialization ===

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
$scriptName = $MyInvocation.MyCommand.Name
$workspace = $PWD.Path


#=== DisplayLink driver

if (!(Get-InstallRecord 'DisplayLink Graphics Driver')) {
    if (Request-Consent "Install DisplayLink driver?") {
        Show-Step "Installing DisplayLink driver..."
        try {
            $installerDirectory = (Resolve-Path '..\..\..\Binaries\Drivers\').Path
            $installerPath = (ls $installerDirectory\DisplayLink*exe).FullName
            if ($installerPath) {
                if ($installerPath -is [array]) {
                    throw "More than one installer found in path : '$installerDirectory'"
                } else {
                    start $installerPath -Wait | Out-Null
                    Show-Result $true
                }
            } else {
                throw ("DisplayLink installer not found in path: '$installerDirectory'")
            }

            Write-Host "Press any key to proceed when external monitors are connected" -ForegroundColor Yellow
            Wait-AnyKey

        } catch {
            Show-Result $false $_
        }
    }
} else {
    Show-Step "DisplayLink driver installed "
    Show-Result $true
}

#=== Registry tweaks

#- Bulk tweaks
$registryTweaks = @()
$registryTweaks += @{'name' = 'taskbar_buttons';`
    'stepDescription' = 'Setting taskbar buttons: show on all screens...';`
    'regKey' = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced';`
    'regItem' = 'MMTaskbarMode';`
    'regItemType' = 'DWORD';`
    'regValue' = 0}
$registryTweaks += @{'name' = 'cortana_icon';`
    'stepDescription' = 'Removing Cortana icon...';`
    'regKey' = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search';`
    'regItem' = 'SearchboxTaskbarMode';`
    'regItemType' = 'DWORD';`
    'regValue' = 0}
$registryTweaks += @{'name' = 'people_icon';`
    'stepDescription' = 'Removing People icon...';`
    'regKey' = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People';`
    'regItem' = 'PeopleBand';`
    'regItemType' = 'DWORD';`
    'regValue' = 0}
$registryTweaks += @{'name' = 'task_view_icon';`
    'stepDescription' = 'Removing task view icon...';`
    'regKey' = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';`
    'regItem' = 'ShowTaskViewButton';`
    'regItemType' = 'DWORD';`
    'regValue' = 0}
$registryTweaks += @{'name' = 'show_file_extensions';`
    'stepDescription' = 'Setting file extensions: show...';`
    'regKey' = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';`
    'regItem' = 'HideFileExt';`
    'regItemType' = 'DWORD';`
    'regValue' = 0}
$registryTweaks += @{'name' = 'color_prevalence';`
    'stepDescription' = 'Setting color prevalence: start, taskbar and action center...';`
    'regKey' = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize';`
    'regItem' = 'ColorPrevalence';`
    'regItemType' = 'DWORD';`
    'regValue' = 1}
$registryTweaks += @{'name' = 'caption_height';`
    'stepDescription' = 'Setting caption height: -285...';`
    'regKey' = 'HKCU:\Control Panel\Desktop\WindowMetrics';`
    'regItem' = 'CaptionHeight';`
    'regItemType' = 'STRING';`
    'regValue' = '-285'}
$registryTweaks += @{'name' = 'caption_width';`
    'stepDescription' = 'Setting caption height: -285...';`
    'regKey' = 'HKCU:\Control Panel\Desktop\WindowMetrics';`
    'regItem' = 'CaptionWidth';`
    'regItemType' = 'STRING';`
    'regValue' = '-285'}
$registryTweaks += @{'name' = 'scroll_height';`
    'stepDescription' = 'Setting scroll height: -150...';`
    'regKey' = 'HKCU:\Control Panel\Desktop\WindowMetrics';`
    'regItem' = 'ScrollHeight';`
    'regItemType' = 'STRING';`
    'regValue' = '-150'}
$registryTweaks += @{'name' = 'scroll_width';`
    'stepDescription' = 'Setting scroll width: -150...';`
    'regKey' = 'HKCU:\Control Panel\Desktop\WindowMetrics';`
    'regItem' = 'ScrollWidth';`
    'regItemType' = 'STRING';`
    'regValue' = '-150'}
$registryTweaks += @{'name' = 'border_width';`
    'stepDescription' = 'Setting border width: 0...';`
    'regKey' = 'HKCU:\Control Panel\Desktop\WindowMetrics';`
    'regItem' = 'PaddedBorderWidth';`
    'regItemType' = 'STRING';`
    'regValue' = '0'}
$registryTweaks += @{'name' = 'advertising_id';`
    'stepDescription' = 'Disabling advertising id...';`
    'regKey' = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo';`
    'regItem' = 'Enabled';`
    'regItemType' = 'DWORD';`
    'regValue' = '0'}
$registryTweaks += @{'name' = 'language_list';`
    'stepDescription' = 'Disabling access to language list...';`
    'regKey' = 'HKCU:\Control Panel\International\User Profile';`
    'regItem' = 'HttpAcceptLanguageOptOut';`
    'regItemType' = 'DWORD';`
    'regValue' = '1'}
$registryTweaks += @{'name' = 'feedback_notifications';`
    'stepDescription' = 'Disabling feedback notifications...';`
    'regKey' = 'HKLM:\Software\Policies\Microsoft\Windows\DataCollection';`
    'regItem' = 'DoNotShowFeedbackNotifications';`
    'regItemType' = 'DWORD';`
    'regValue' = '1'}
$registryTweaks += @{'name' = 'explorer_default_location';`
    'stepDescription' = 'Setting explorer default location: this pc...';`
    'regKey' = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';`
    'regItem' = 'LaunchTo';`
    'regItemType' = 'DWORD';`
    'regValue' = 1}
$registryTweaks += @{'name' = 'explorer_recent_files';`
    'stepDescription' = 'Setting explorer recent files: hide...';`
    'regKey' = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer';`
    'regItem' = 'ShowRecent';`
    'regItemType' = 'DWORD';`
    'regValue' = 0}
$registryTweaks += @{'name' = 'explorer_frequent_folders';`
    'stepDescription' = 'Setting explorer frequetn folders: hide...';`
    'regKey' = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer';`
    'regItem' = 'ShowFrequent';`
    'regItemType' = 'DWORD';`
    'regValue' = 0}

foreach ($tweak in $registryTweaks) {
    Show-Step $tweak.stepDescription
    try {
        Set-RegistryData $tweak.regKey -item $tweak.regItem -itemType $tweak.regItemType -value $tweak.regValue
        Show-Result $true
    } catch {
        Show-Result $false $_
    }
}

#- Custom tweaks

#-- taskbar position
Show-Step "Setting taskbar position: left..."
$regkeys = @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\MMStuckRects3'
)
try {
    foreach ($key in $regkeys) {
        $properties = (gi $key).property
        foreach ($prop in $properties) {
            $data = (gp $key).$prop
            $data[12] = 0
            Set-ItemProperty $key -Name $prop -Value $data -Force
        }
    }
    Show-Result $true
} catch {
    Show-Result $false $_
}

#=== Power settings

Show-Step "Setting 'Close lid action' when on AC power: do nothing..."
try {
    start cmd -ArgumentList "/C powercfg -setacvalueindex SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 5ca83367-6e45-459f-a27b-476b1d01c936 0" -NoNewWindow -Wait
    Show-Result $true
} catch {
    Show-Result $false $_
}


#=== Reload explorer

if (!$NoExplorerRestart) {
    Show-Step "Restarting Windows explorer..."
    gps explorer | Stop-Process
    do {sleep 1}
    while (!(gps explorer -ErrorAction SilentlyContinue))
    Show-Result $true
}

Write-Host "Done" -ForegroundColor Green
Write-Host "Some changes will come into effect after next logon." -ForegroundColor Yellow


#=== END ===
