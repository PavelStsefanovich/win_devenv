param (
    $CONFIG
)


$ErrorActionPreference = 'stop'

foreach ($item in $CONFIG.enable) {
    Write-Log "- enabling winfeature '$($item.name)'"    
    $command = "Enable-WindowsOptionalFeature -FeatureName $($item.name) -norestart"
    $options = $item.options.split(',')
    $options | %{ $command += " -$_" }
    $command += " | out-null"
    $scripblock = [scriptblock]::Create($command)
    icm $scripblock
}
