[CmdletBinding()]
param (
    [string]$GitEmail,
    [switch]$GenerateSshKey
)

#=== Functions

function IsRestartRequired {
    $isRestartRequired = $false

    if (Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -EA Ignore) { $isRestartRequired = $true }
    if (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -EA Ignore) { $isRestartRequired = $true }
    if (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -EA Ignore) { $isRestartRequired = $true }

    try { 
        $util = [wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities"
        $status = $util.DetermineIfRebootPending()
        if(($status -ne $null) -and $status.RebootPending){
            $isRestartRequired = $true
        }
    }catch{}

    return $isRestartRequired
}

function Install-ChocolateyPackage ($packageName, $arguments, [int]$timeout) {
    
    if (!$timeout) {$timeout = 30}
    $arguments = $arguments + " -y"
    $installedPackages = choco list --localonly -r

    if ($packageName -in ($installedPackages | %{$_.split('|')[0]})) {
        Write-Host " :: Skipped $packageName (already installed)"
    } else {    
        write-host " :: Installing $packageName"
        try {
            $proc = start choco -ArgumentList "install $packageName $arguments" -NoNewWindow -PassThru -ErrorAction Stop -ErrorVariable err_choco

        } catch {
            Write-Warning " (!) Installation failed for pacakge: $packageName."
        }

        try {
            $proc | Wait-Process -Timeout $timeout -ErrorAction Stop
        } catch {
            $proc | Stop-Process -Force
            Write-Warning " (!) Timeout exeeded for pacakge: $packageName."
        }

        if (IsRestartRequired) {
            Write-Warning "Reboot required."
            Write-Warning "Restart computer and run this script again."
            exit
        }
    }
}

function Start-keyWait {
    Write-Host -NoNewLine 'Press any key to continue...';
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
}


#=== Initialization ===

$ErrorActionPreference = 'Stop'
$scriptName = $MyInvocation.MyCommand.Name

#- install chocolatey if not installed
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    try {
        Write-Host " :: Installing Chocolatey"
        Set-ExecutionPolicy Bypass -Scope Process -Force
        iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    } catch {
        Write-Host " (!) Installation of Chocolatey FAILED:" -ForegroundColor Red
        throw $_
    }
}

Install-ChocolateyPackage "notepadplusplus"
Install-ChocolateyPackage "vscode"
Install-ChocolateyPackage "beyondcompare"
Install-ChocolateyPackage "git.install"
Install-ChocolateyPackage "git" "-params `"/GitAndUnixToolsOnPath /WindowsTerminal /NoGuiHereIntegration`""
Install-ChocolateyPackage "openssh" "-params `"/SSHAgentFeature`""

#- vscode extensions
$vsextensions_scriptpath = (Resolve-Path .\DevEnv\Install.Vscode.Extensions.ps1 -ErrorAction SilentlyContinue).Path
if ($vsextensions_scriptpath) {
    & $vsextensions_scriptpath
} else {
    Write-Warning "(!) File not found: '$vsextensions_scriptpath'"
}

#- powershell profile
$psprofile_scriptpath = (Resolve-Path .\DevEnv\Setup.PSProfile.ps1 -ErrorAction SilentlyContinue).Path
if ($psprofile_scriptpath) {
    & $psprofile_scriptpath
}
else {
    Write-Warning "(!) File not found: '$psprofile_scriptpath'"
}

#- generate SSH key pair
if ($GenerateSshKey) {
    if ($GitEmail) {
        do {
            Write-Host " :: Generating SSH key pair"
            $keygenshPath = Join-Path $pwd.Path "keygen.sh"
            "ssh-keygen -t rsa -b 4096 -C `"$GitEmail`"" | Out-File $keygenshPath -Encoding ascii -Force
            try {
                start 'C:\Program Files\Git\bin\bash.exe' -ArgumentList "$keygenshPath" -Wait -PassThru -ErrorAction Stop -NoNewWindow | Out-Null
            } catch {
                throw $_
            }
            if (Test-Path "C:\Users\Pavel\.ssh\id_rsa.pub") {
                Write-Warning "Please copy public key and add to GitHub account"
                sleep 2
                notepad++ "C:\Users\Pavel\.ssh\id_rsa.pub"
                Start-KeyWait
                ssh-add.exe
                ssh -T git@github.com
            } else {
                Write-Warning "Only default rsa key pair filepaths are supported: '~\.ssh\id_rsa(.pub)'."
            }
        } while (!(Test-Path "C:\Users\Pavel\.ssh\id_rsa.pub"))
    } else {
        Write-Warning " (!) 'GitEmail' not specified, SSH key generation skipped."
    }
}

Write-Host " DONE: $scriptName`n"
