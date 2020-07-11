[CmdletBinding()]
param (
    [string]$psprofile_config_filepath = $(Join-Path (Split-Path $PSCommandPath) 'psprofile.conf')
)

function Request-Consent ([string]$question) {
    do {
        Write-Host " (?) $question" -ForegroundColor Yellow
        $reply = [string]$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
        if ($reply.tolower() -notin 'y', 'n') {
            Write-Host "It's a yes/no question."
        }
    }
    while ($reply.tolower() -notin 'y', 'n')

    switch ($reply) {
        'y' { return $true }
        'n' { return $false }
    }   
}

function Add-Section ($profile_content, $section, $section_name) {
    $boudaries = ($profile_content | Select-String $section_name).LineNumber
    $new_content = @()
    # add everything before
    $profile_content[0..($boudaries[1]-2)] | %{$new_content += $_}

    # add new section
    $section | %{$new_content += $_}

    # add everything after
    $profile_content[($boudaries[1]-1)..($profile_content.length-1)] | %{$new_content += $_}

    return $new_content
}

#- initialization
Write-Host " :: Setting up Powershell Profile"
$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path $PSCommandPath
$UpdateProfile = $true
$CONF = cat $psprofile_config_filepath -Raw | ConvertFrom-StringData
$CONF.psprofile_template = (Resolve-Path (Join-Path $scriptDir $CONF.psprofile_template)).Path
$CONF.modules_directory = (Resolve-Path (Join-Path $scriptDir '../Modules') -ErrorAction SilentlyContinue).Path
$CONF.start_location = (Resolve-Path (Join-Path $scriptDir $CONF.start_location) -ErrorAction SilentlyContinue).Path
# modules_exclude=PythonDevTools

#- backup psprofile
if (!(Test-Path (Split-Path $PROFILE))) {
    ni (Split-Path $PROFILE) -ItemType Directory -ErrorAction SilentlyContinue | Out-Null    # ensure that default profile directory exists
}
if ($CONF.psprofile_template) {
    if (Test-Path $PROFILE) {
        if (!(Request-Consent "Powershell profile exists. Append configuration?")) {
            $UpdateProfile = $false
        }
    }
} else {
    Write-Warning "(!) File not found: '$($CONF.psprofile_template)'"
    $UpdateProfile = $false
}

#- update psprofile
if ($UpdateProfile) {
    $profile_content = cat $CONF.psprofile_template

    #- modules
    if ($CONF.modules_include) {
        $mod_include = $CONF.modules_include.split(',')
    } else {
        $mod_include = (ls $CONF.modules_directory).Name
    }
    if ($CONF.modules_exclude) {
        $mod_exclude = $CONF.modules_exclude.split(',')
    }

    $CONF.modules = $mod_include | ?{$_ -notin $mod_exclude}

    if ($CONF.modules) {
        $section_modules = @()
        $section_modules += "`$env:PSModulePath = `$env:PSModulePath.TrimEnd(';') + ';' + '$($CONF.modules_directory)'"

        foreach ($module in $CONF.modules) {
            $section_modules += "Import-Module $module -Force -DisableNameChecking"
        }
    }

    $profile_content = Add-Section $profile_content $section_modules 'Modules'

    #- commands
    if ($CONF.start_location) {
        $section_commands = "cd $($CONF.start_location)"
    }

    $profile_content = Add-Section $profile_content $section_commands 'Commands'

    #- save updated profile

    $profile_content | Out-File $PROFILE -Append
}
else {
    Write-Host " :: Skipped Powershell Profile"
}
