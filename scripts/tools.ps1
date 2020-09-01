param (
    $CONFIG
)


$ErrorActionPreference = 'stop'

# run tools configurations
foreach ($tool_type in $CONFIG.GetEnumerator()) {
    if ($tool_type.Key -eq 'rootdir') {
        continue
    }

    foreach ($tool in $tool_type.value) {
        Wait-Logging
        Write-Log "Configuring '$($tool.name)' ($($tool_type.Key))"

        $tool_config_script = (Resolve-Path (Join-Path $CONFIG.rootdir $tool.script)).Path
        . $tool_config_script -config $tool.config
    }
}