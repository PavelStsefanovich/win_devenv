param (
    $CONFIG
)


$ErrorActionPreference = 'stop'

foreach ($item in $CONFIG.sys_utils) {
    Write-Log "- $($item.description)"
    $command = "& `"$($item.exe)`""
    if ($item.args) {
        $command += " $($item.args)"
    }
    $scripblock = [scriptblock]::Create($command)

    $LASTEXITCODE = 0
    $output = icm $scripblock
    if ($LASTEXITCODE -notin ([string]$item.success_exit_codes).split(',')) {
        throw $output
    }
}
