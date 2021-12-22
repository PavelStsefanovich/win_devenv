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

foreach ($item in $CONFIG.modules) {
    Wait-Logging
    Write-Log "- installing module `"$($item.name)`""
    Install-Module -Name $item.name -Force -AllowClobber
    Import-Module $item.name -Force -DisableNameChecking
}
