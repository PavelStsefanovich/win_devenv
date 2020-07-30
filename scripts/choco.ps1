param (
    $CONFIG
)


Write-Log -Level info "Running $(Split-Path $PSCommandPath -leaf)"
$CONFIG
Write-Log -Level info "Finished $(Split-Path $PSCommandPath -leaf)"
exit

Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))