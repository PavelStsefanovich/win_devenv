powershell:
    profiles:
    - name: pwsh
      source: .\conf\ps_profiiles\pwsh\Microsoft.PowerShell_profile.ps1
      destination: '$HOME\Documents\PowerShell'
    - name: powershell
      source: .\conf\ps_profiiles\powershell\Microsoft.PowerShell_profile.ps1
      destination: $HOME\Documents\WindowsPowerShell
    
tools:
    pwsh:
        msi:
            download_url: https://github.com/PowerShell/PowerShell/releases/download/v7.0.2/PowerShell-7.0.2-win-x64.msi
            commandline: msiexec.exe /package PowerShell-7.0.1-win-x64.msi /quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1
        zip:
            download_url: https://github.com/PowerShell/PowerShell/releases/download/v7.0.2/PowerShell-7.0.2-win-x64.zip
            destination_dir: C:\Program Files\PowerShell\zip\7
    


        