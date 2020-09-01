param (
    $CONFIG
)


$ErrorActionPreference = 'Stop'

foreach ($config_type in $CONFIG.GetEnumerator()) {

    #extensions
    if ($config_type.Key -eq 'extensions') {
        foreach ($extension in $config_type.value) {
            Write-Log "- installing extension '$extension'"
            code --install-extension $extension --force
        }
    }

    continue
}    
