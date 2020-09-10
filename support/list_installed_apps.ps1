param (
    [string]$outfile
)

$uninstallKeys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall')

$registryAlias = @{
    'HKEY_LOCAL_MACHINE' = 'HKLM:'
    'HKEY_CURRENT_USER' = 'HKCU:'
}

[string[]]$installedSoftware = @()

foreach ($key in $uninstallKeys){
    $apps_records = (ls $key).name | % { $_.replace($_.split('\')[0], $registryAlias.($_.split('\')[0])) | gp }

    $apps_records | %{
        $app_name = $_.DisplayName

        if ($app_name) {
            if ($app_name -notin $installedSoftware) {
                $installedSoftware += $app_name
            }
        }
    }
}

$installedSoftware = $installedSoftware	| sort

if ($outfile) {
    $installedSoftware | out-file $outfile -force -encoding ascii
} else {
    $installedSoftware
}
