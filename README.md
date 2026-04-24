# Tableau License Manager

A PowerShell script to automate the activation and deactivation of Tableau Desktop and Tableau Prep Builder licenses on Windows machines.

## Overview

This script simplifies license management by automating the activation and deactivation process. It reads a license key from a file, applies it to installed Tableau products, and verifies the operation succeeded.

Ideal for IT administrators managing Tableau deployments across multiple machines using SCCM or other deployment tools.

## Features

* **Automatic product detection** - Finds Tableau Desktop and Tableau Prep Builder if installed
* **License verification** - Confirms activation/deactivation was successful before proceeding
* **Registry tracking** - Updates Windows Registry for application inventory and SCCM compatibility
* **Comprehensive logging** - Full transcript of all actions for audit and troubleshooting
* **Error handling** - Clear error messages and exit codes for automation workflows
* **SCCM compatible** - Properly handles SYSTEM context execution

## Requirements

* Windows PowerShell 5.0 or later
* Administrator privileges
* Tableau Desktop and/or Tableau Prep Builder installed at `C:\Program Files\Tableau\`
* `License.txt` file in the script directory containing a valid Tableau license key

## Installation

1. Download `Invoke_TableauLicense.ps1` to your desired location
2. Create a `License.txt` file in the same directory with your Tableau license key:
   `XXXXXX-XXXXXX-XXXXXX-XXXXXX`
3. Right-click PowerShell and select "Run as Administrator"

## Usage

### Activate Licenses

```CMD
Invoke_TableauLicense.ps1 -Action Activate
```

Activates Tableau Desktop and/or Tableau Prep Builder using the license key from License.txt. Products already licensed or not installed are skipped.

### Deactivate Licenses

```CMD
Invoke_TableauLicense.ps1 -Action Deactivate
```

Deactivates Tableau Desktop and/or Tableau Prep Builder and returns licenses to Tableau's pool. Products not currently licensed or not installed are skipped.

## Exit Codes

| Code | Meaning                         |
| ---- | ------------------------------- |
| 0    | Success (or no action required) |
| 1    | Failure (check transcript log)  |

## Logs

All script activity is logged to:

```
C:\Windows\Logs\Software\Tableau_LicStatus.log
```

Temporary license status files are created during execution and automatically removed:

```
<ScriptDirectory>\Tableau_Status.txt
```

```
<ScriptDirectory>\TableauPrep_Status.txt
```

## Configuration

### Registry Location (HKLM)

```
HKLM:\Software\Tableau\Registration\License
```

The script creates and updates the LicenseStatus registry value for application tracking.

## SCCM Deployment

For SCCM deployments, use one of these command lines:

**Activation:**

```CMD
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Invoke_TableauLicense.ps1" -Action Activate
```

**Deactivation:**

```CMD
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Invoke_TableauLicense.ps1" -Action Deactivate
```

## Troubleshooting

| Issue                                         | Solution                                                         |
| --------------------------------------------- | ---------------------------------------------------------------- |
| License.txt not found                         | Create License.txt in the script directory with your license key |
| License.txt is empty                          | Add your Tableau license key to the file                         |
| Custactutil.exe not found                     | Ensure Tableau is installed in C:\\Program Files\\Tableau\\      |
| Access denied                                 | Run PowerShell as Administrator                                  |
| Activation/Deactivation could not be verified | Check the transcript log for details                             |

## Notes

* Tableau Prep Builder activation/deactivation is automatic when Tableau Desktop is activated/deactivated
* The script operates on the current machine only
* No changes are made if products are already in the desired state
* All operations are logged with timestamps for compliance and audit purposes

## Author

Justin Prosser

## License

This script is provided as-is for use in managing Tableau licenses within your organization.

## Related Resources

* [Activate Tableau Desktop and Tableau Prep Builder](https://help.tableau.com/current/desktopdeploy/en-us/desktop_deploy_automate.htm#:~:text=Activate%20Tableau%20Desktop%20and%20Tableau%20Prep%20Builder)

## Acknowledgements

*This project was built with some assistance from Claude by Anthropic.* (Mostly error checking/ logic testing)
