function isadmin {
    return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole] "Administrator")
}

function restart_elevated {
     
    param(
        $script_args,
        [switch]$kill_original,
        [string]$current_dir = $PWD.path
    )

    if ($MyInvocation.ScriptName -eq "") {
        throw 'Script must be saved as a .ps1 file.'
    }

    if (isadmin) {
        Write-Host 'running as administrator: OK' -ForegroundColor DarkGray
        return $null
    }

    try {
        Write-Warning '(!) running as administrator: NO'
        Write-Host 'Restarting with elevated permissions'
        sleep 3

        $script_fullpath = $MyInvocation.ScriptName

        $argline = "-noprofile -nologo -noexit"
        $argline += " -Command cd `"$current_dir`"; `"$script_fullpath`""

        $script_args.GetEnumerator() | % {
            
            if ($_.Value -is [boolean]) {
                $argline += " -$($_.key) `$$($_.value)"
            }

            elseif ($_.Value -is [switch]) {
                $argline += " -$($_.key)"
            }

            else {
                $argline += " -$($_.key) `"$($_.value)`""
            }
        }

        $p = Start-Process "$PSHOME\powershell.exe" -Verb Runas -ArgumentList $argline -PassThru -ErrorAction 'stop'

        if ($kill_original) {
            [System.Diagnostics.Process]::GetCurrentProcess() | Stop-Process -ErrorAction Stop
        }

        Write-Host "Elevated process id: $($p.id)"
        exit
    }
    catch {
        Write-Error "ERROR: Failed to restart script with elevated premissions."
        throw $_
    }
}

function abspath ($parent = $pwd.Path) {
    ## convert to absolute path
    process {        
        if ([System.IO.Path]::IsPathRooted($_)) { $_ }
        else { Join-Path $parent $_ }
    }
}

function escapepath () {
    ## escape backslashes
    process {        
        $_.replace('\','\\')
    }
}

function system_restart_pending {
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

function request_consent ([string]$question) {
    do {
        Write-Host "`n (?) $question" -ForegroundColor Yellow
        $reply = [string]$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
        if ($reply.tolower() -notin 'y', 'n') {
            Write-Host "It's a yes/no question."
        }
    }
    while ($reply.tolower() -notin 'y', 'n')

    switch ($reply) {
        'y' { return $true }
        'n' { return $false }
    }   
}