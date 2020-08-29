param (
    $CONFIG
)


$ErrorActionPreference = 'stop'

Write-Log "Installing Chocolatey Package manager"
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

foreach ($package_type in $CONFIG.GetEnumerator()) {
    if ($package_type.Key -eq 'rootdir') {
        continue
    }

    foreach ($item in $package_type.value) {
        Wait-Logging
        Write-Log "- installing '$($item.name)' ($($package_type.Key))"

        # local installers
        if ($package_type.Key -eq 'local') {
            $executable_path = (Resolve-Path (Join-Path $CONFIG.rootdir $item.exe)).Path
            $command = "& `"$executable_path`""

            if ($item.args) {
                $command += " $($item.args)"
            }

            $scripblock = [scriptblock]::Create($command)

            $LASTEXITCODE = 0
            $success_exit_codes = $item.success_exit_codes
        
            if (!$success_exit_codes) {
                $success_exit_codes = 0
            }

            $output = icm $scripblock

            if ($item.interactive) {
                Write-Log -Level WARNING -Message "Starting interactive installer; when done, press any key to continue"
                wait_anykey
            }
            else {
                if ($LASTEXITCODE -notin ([string]$success_exit_codes).split(',')) {
                    throw $output
                }
            }

            continue
        }

        # chocolatey package manager
        if ($package_type.Key -eq 'chocolatey') {

            $command = "& choco install `"$($item.name)`""

            if ($item.args) {
                $command += " --params `"$($item.args)`""
            }

            $command += " -y --force"
            $scripblock = [scriptblock]::Create($command)

            $LASTEXITCODE = 0
            $success_exit_codes = @(0, 1641, 3010)

            icm $scripblock

            if ($LASTEXITCODE -notin $success_exit_codes) {
                throw "Command FAILED: '$command'"
            }

            continue
        }

        # powershell-get package manager
        if ($package_type.Key -eq 'powershellget') {
            if (!(Get-Module $item.name)) {
                if (!(Get-Module $item.name -ListAvailable)) {
                    Install-Module $item.name -Force -Scope $item.scope
                }
                Import-Module $item.name -DisableNameChecking
            }
        }
    }
}
