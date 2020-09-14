param (
    $CONFIG
)


$ErrorActionPreference = 'stop'

foreach ($util_type in $CONFIG.GetEnumerator()) {
    if ($util_type.Key -eq 'rootdir') {
        continue
    }

    foreach ($item in $util_type.value) {
        Wait-Logging
        Write-Log "- $($item.description) ($($util_type.Key)"

        $command = "& `"$($item.exe)`""

        if ($item.args) {
            $command += " $($item.args)"
        }

        $scriptblock = [scriptblock]::Create($command)

        $LASTEXITCODE = 0
        $success_exit_codes = $item.success_exit_codes

        if (!$success_exit_codes) {
            $success_exit_codes = 0
        }

        $output = icm $scriptblock

        if ($LASTEXITCODE -notin ([string]$success_exit_codes).split(',')) {
            Write-Log -Level WARNING -Message $output
            throw "Command FAILED: '$command' (exit code: $LASTEXITCODE)"
        }
    }
}
