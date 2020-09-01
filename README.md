# DevEnv

DevEnv is a suite of scripts (Powershell) that automate configuration of various aspects of development environment on Windows.

---
### Currently included:
- **setup_dev_env.ps1** (main script)
- **util_functions.psm1** (support procedures)
- **packages.ps1** (handles installation from various sources)
- **powershell.ps1** (configures powershel profiles)
- **registry.ps1** (applies registry tweaks)
- **tools.ps1** (a wrapper that calls app-specific scripts that applies tools configurations)
- **utils** (executes system utilities with parameters)
- **vscode** (app-specific script that configures vs code)
- **winfeatures** (enables windows optional features)

---
### Configuration file
**setup_dev_env.yml** (main configuration file)

Main config file holds configuration for all the scripts in the suite in YAML format.

Configuration is devided into sections that correspond to each script. These sections are referred to as **'stages'** during the execution and are logically separated.

The stages are executed in the order they appear in the main config file. Each stage result is reported individually. In case of error during stage execution, main script marks it as failure and proceeds with the next stage.

Some stages may require system restart in order for their changes to come into effect. In such cases a user has a choice to restart immediately and automatically continue after restart (recommended), or skip restart and proceed with the next stage.

Stages configurations follow uniform format:

    <?yaml
    stage_name:
        restart_required: indicates if stage needs system restart to complete configuration
        script:  path to the script that handles this specific stage execution, relative to main script
        config:  custom stage configuration that can be consumed by the stage script
    ?>

To add a new stage, append stage config to the main configuration file and place corresponding script into the /scripts directory. If needed, place additional files or binaries into /files or /binaries directories respectively and update stage config with relative paths.

---
### Logging
Log file is created on initial execution of the main script and maintained throughout all stages, even after system restart, until the last stage has finished executing.
Log file is placed into the ./logs directory inside current directory (may be different from the main script location)

In case of failures in any of the stages, the main script will automatically open log in the notepad after completion. If all stages finished successfully, the log will not open, but it's full path will be displayed instead.

The main script will also display the overal report that summarizes results for each stage.
