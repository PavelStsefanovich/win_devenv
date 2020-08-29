param (
    $CONFIG
)


$ErrorActionPreference = 'stop'

foreach ($item in $CONFIG.sys_utils) {
    Wait-Logging
    Write-Log "- $($item.description)"
    
    $command = "& `"$($item.exe)`""

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

    if ($LASTEXITCODE -notin ([string]$success_exit_codes).split(',')) {
        throw $output
    }
}
