param (
    $CONFIG
)


$ErrorActionPreference = 'stop'

foreach ($item in $CONFIG.enable) {
    Wait-Logging
    Write-Log "- enabling winfeature '$($item.name)'"    
    $command = "Enable-WindowsOptionalFeature -FeatureName $($item.name) -norestart"
    $options = $item.options.split(',')
    $options | %{ $command += " -$_" }
    $command += " | out-null"
    $scriptblock = [scriptblock]::Create($command)
    icm $scriptblock
}
