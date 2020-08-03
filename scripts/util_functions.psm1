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
        Write-Host 'Running as administrator: OK'
        return $null
    }

    try {
        Write-Warning '(!) Running as administrator: NO'
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