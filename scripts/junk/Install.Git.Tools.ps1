[CmdletBinding()]
param (
    $GitEmail = $(throw 'Mandatory parameter not provided: <GitEmail>.')
)



function Install-ChocolateyPackage ($packageName, $arguments) {
    $arguments = $arguments + " -y --force"
    write-host " :: Installing $packageName"
    try {
        $res = (start choco -ArgumentList "install $packageName $arguments" -Wait -PassThru -ErrorAction Stop -RedirectStandardError "$logdirectory\er_$packageName.txt" -RedirectStandardOutput "$logdirectory\out_$packageName.txt").ExitCode
        if ($res -notin 0,1641,3010) {
            "$packageName=failed" >> $logpropsfile
            throw "Installation failed for pacakge: $packageName."
        } else {
            "$packageName=installed" >> $logpropsfile
        }
    } catch {
        $_
    }

    if ($res -in 1641,3010) {
        Write-Warning "Reboot required."
        exit
    }
}

function Start-keyWait {
    Write-Host -NoNewLine 'Press any key to continue...';
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
}



$ErrorActionPreference = 'Stop'
$script:logdirectory = Join-Path $pwd.Path "Log"
$script:logpropsfile = Join-Path $logdirectory "install.results"
ni $logpropsfile -ItemType File -Force

#- install chocolatey if not installed
Write-Host " :: Installing Chocolatey"
Set-ExecutionPolicy Bypass -Scope Process -Force

try {
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    "chocolatey=installed" > $logpropsfile
} catch {
    "chocolatey=failed"
    throw $_
}

Install-ChocolateyPackage "atom"
Install-ChocolateyPackage "notepadplusplus"
Install-ChocolateyPackage "git.install"
Install-ChocolateyPackage "git" "-params `"/GitAndUnixToolsOnPath /WindowsTerminal /NoGuiHereIntegration`""
Install-ChocolateyPackage "openssh" "-params `"/SSHAgentFeature`""
Install-ChocolateyPackage "beyondcompare"

#- generate SSH key pair
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
