# win_devenv

***win_devenv*** *is a suite of PowerShell scripts that automate configuration of various aspects of development environment on Windows.*

---
### Currently included:
- **setup.ps1** (main script)
- **chocolatey.ps1** (wrapper for Chocolatey Package Manager)
- **copy.ps1** (handles copying of files and directories)
- **packages.ps1** (handles deployements from stand-alone installers)
- **registry.ps1** (applies registry tweaks)
- **sysconfig** (executes system utilities or dev tools with parameters)
- **win_features** (enables windows optional features)

---
### Configuration file
- **setup.yml** (main configuration file)

Main config file holds configuration for all the scripts in the suite in YAML format.

Configuration is devided into sections. These sections are referred to as **'stages'** during the execution and are logically separated.

The stages are executed in the order they appear under the "sequence" key in the main config file. If any steps included into a stage fail, each failure reason will be displayed and a warning will be issued in the end of stage execution. Setup script will then proceed with the next stage.

Some steps may trigger "pending restart" system state, this usually happens when restart is needed for the changes to come into effect. Setup script checks if restart is pending in the beginning of each stage. If detected, a user will be prompted to restart immediately and automatically continue on the next logon, or postpone restart and proceed.

**Note:** Stages names are defined by the top-level keys in the main config file (except for the "sequence" key) and each stage must have a corresponding script with matching name in the /scripts directory.

---
### Progress Configuration file
- **progress_setup.yml** (dynamically updated progress configuration file)

Progress config file is created when setup script starts, and holds a copy of the main configuration.

During execution of the setup script, configurations for successully completed steps are removed from the progress file, so that at any given time progress file only contains not yet executed or failed steps. The progress file can be used later to re-run setup script for only those steps using -ConfigFilePath parameter (for example, if a few steps failed due to a minor obstacle, a user can remove that obstacle and re-run the setup script to only execute failed steps).

Progress config file is also utilized when setup automatically resumes after restart.

Progress config file can also be used as a log or status file: after setup script has finished, any configuration entries left indicate failed steps (except for the "sequence" block).

---
### Input Parameters
Main configuration script takes the following input parameters (all parameters are optional):

| Name | Type | Description |
| ------ | ------ | ------ |
| ConfigFilePath | string | Path to the config file to use (YAML) if other than default |
| StartStage | string | Indicate the stage name under the "sequence" key. Setup script will execute sequence starting with the specified stage to the end of the list |
| SkipDependencies | switch | Use to skip dependency modules installations on subsequent runs of the setup script |
