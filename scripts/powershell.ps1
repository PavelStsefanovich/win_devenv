param (
    $CONFIG
)


$ErrorActionPreference = 'stop'

foreach ($item in $CONFIG.profiles) {
    Wait-Logging
    Write-Log "- updating profile for '$($item.name)'"
    $source_filepath = (Resolve-Path (Join-Path $CONFIG.rootdir $item.source)).Path
    $destination_filepath = $item.destingation.Replace('$HOME',$HOME)
    cp $source_filepath $destination_filepath -Force
}
