param (
    $CONFIG
)


function Get-RegistryValue {
    [CmdletBinding()]
    param (
        [parameter()]
        [string]$key = $(throw "Mandatory argument not provided: <key>."),

        [parameter()]
        [string]$item = '*'
    )

    $ErrorActionPreference = 'Stop'
    $regValues = (gi $key).property | ? { $_ -like $item }
    return $regValues
}
function Get-RegistryValueData {
    [CmdletBinding()]
    param (
        [parameter()]
        [string]$key = $(throw "Mandatory argument not provided: <key>."),

        [parameter()]
        [string]$item = $(throw "Mandatory argument not provided: <item>.")
    )

    $ErrorActionPreference = 'Stop'
    $keyValue = Get-ItemProperty $key | Select-Object -ExpandProperty $item
    return $keyValue
}
function Get-RegistryValueDataType ([string]$key, [string]$item) {
    $ErrorActionPreference = 'Stop'

    $itemType = ([string](gi $key -ErrorAction Stop).getvaluekind($item)).toUpper()
    if ($itemType -notin 'STRING', 'EXPANDSTRING', 'BINARY', 'DWORD', 'MULTISTRING', 'QWORD') {
        return $null
    }
    return $itemType
}
function Set-RegistryValueData {
    [CmdletBinding()]
    param (
        [parameter()]
        [string]$key = $(throw "Mandatory argument not provided: <key>."),

        [parameter()]
        [string]$item = $(throw "Mandatory argument not provided: <item>."),

        [parameter()]
        [ValidateSet('STRING', 'EXPANDSTRING', 'BINARY', 'DWORD', 'MULTISTRING', 'QWORD', $null)]
        [string]$itemType = $null,

        [parameter()]
        $value = $null
    )

    $ErrorActionPreference = 'Stop'

    if ($key.StartsWith('Computer\')) {
        $key = $key.Substring(9)
    }

    if ($key.StartsWith('HKEY_CURRENT_USER\')) {
        $key = "HKCU:" + $key.Substring(17)
    }

    if ($key.StartsWith('HKEY_LOCAL_MACHINE\')) {
        $key = "HKLM:" + $key.Substring(18)
    }

    if (!$itemType) {
        $itemType = Get-RegistryValueDataType $key -item $item
    }

    if (!$itemType) {
        $itemType = 'STRING'
    }

    #- create missing directories in $key
    $path = $key
    $paths = @()
    while (!(Test-Path $path)) {
        $paths += $path
        $path = $path | Split-Path
    }
    $paths[($paths.Length - 1)..0] | % { New-Item $_ | Out-Null }

    #- create registry value with data
    New-ItemProperty $key -Name $item -PropertyType $itemType -Value $value -Force | Out-Null
}


$ErrorActionPreference = 'stop'

foreach ($section in $CONFIG.GetEnumerator()) {
    if ($section.Key -eq 'rootdir') {
        continue
    }

    foreach ($item in $section.value) {
        Wait-Logging
        Write-Log "- $($item.description) ($($section.Key))"

        $reg_properties_to_update = [array](Get-RegistryValue $item.reg_key $item.reg_property)
        if (!$reg_properties_to_update) {
            $reg_properties_to_update = [array]$item.reg_property
        }

        foreach ($reg_property in $reg_properties_to_update) {
            if ($item.reg_property_type -eq 'BINARY') {
                try {
                    $current_value = Get-RegistryValueData $item.reg_key $reg_property
                    $new_value = $current_value
                }
                catch {}

                if (!$new_value) {
                    $new_value = @()
                    0..500 | % { $new_value += 0 }
                }

                foreach ($binvalue in $item.reg_property_value.split(',')) {
                    $index = $binvalue.split(':')[0].trim('[]')
                    $index_value = $binvalue.split(':')[1]
                    $new_value[$index] = [int]$index_value
                }
            }
            else {
                $new_value = $item.reg_property_value
            }

            Set-RegistryValue -key $item.reg_key `
                            -item $reg_property `
                            -itemType $item.reg_property_type `
                            -value $new_value
        }
    }
}
