function restart-elevated {
    param(
        $arguments,
        [switch]$kill_original,
        [string]$workdir = $PWD.path
    )

    if ($MyInvocation.ScriptName -eq "") { throw 'Script must be saved as a .ps1 file.' }
    if (isadmin) { return $null }

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

function Get-AvailableDrive ([switch]$only_letter) {
    $alphabet = [string[]][char[]]([int][char]'D'..[int][char]'Z')  # no need to iterate A:, B:, C:
    for ($i = 0; $i -lt $alphabet.Length; $i++) {
        if ($alphabet[$i] -notin (Get-PSDrive -PSProvider FileSystem).Name) {
            $available_drive = $alphabet[$i]
            if (!$only_letter) {
                $available_drive += ":"
            }
            break
        }
    }

    if ([string]::IsNullOrEmpty($available_drive)) {
        throw "No drive letters available."
    }

    return $available_drive
}


$ErrorActionPreference = 'stop'
restart-elevated

$drives_map = @{
    'DATA' = 'D:';
    'VMs'  = 'V:'
}

foreach ( $label in $drives_map.Keys ) {
    $Drive = Get-CimInstance -ClassName Win32_Volume -Filter "Label = '$label'"

    if ( $Drive.DriveLetter -ne $drives_map.$label ) {
        
        if (Get-PSDrive | ? { $_.Root -like "$($drives_map.$label)*" }) {
            Write-Warning "Found drive with letter `"$($drives_map.$label)`" that does not match label `"$label`"; changing letter..."
            $available_letter = Get-AvailableDrive
            $moving_drive = Get-CimInstance -ClassName Win32_Volume -Filter "DriveLetter = '$($drives_map.$label)'"
            $moving_drive | Set-CimInstance -Property @{ DriveLetter = $available_letter }
        }
        
        write "Changing drive `"$label`" letter to `"$($drives_map.$label)`""
        $Drive | Set-CimInstance -Property @{ DriveLetter = $drives_map.$label }
    }
}
