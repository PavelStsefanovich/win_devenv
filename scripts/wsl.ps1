param (
    $CONFIG
)


$ErrorActionPreference = 'Stop'

Write-Log "- setting default WSL version: '2'"
& wsl --set-default-version $CONFIG.default_version
