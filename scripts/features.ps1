param (
    $CONFIG
)


Write-Log -Level info "Running $(Split-Path $PSCommandPath -leaf)"
#$CONFIG
Write-Log -Level info "Finished $(Split-Path $PSCommandPath -leaf)"
exit