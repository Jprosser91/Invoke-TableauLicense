<#
.SYNOPSIS
    Manages Tableau Desktop and Tableau Prep Builder license activation and deactivation.

.DESCRIPTION
    This script automates the license activation and deactivation process for 
    Tableau Desktop and Tableau Prep Builder on the local machine.

    The script performs the following operations:
    - Detects installed Tableau products in the default installation directory
    - Reads a license key from License.txt located in the script directory
    - Activates or deactivates licenses using Tableau's Custactutil.exe utility
    - Verifies successful activation or deactivation of each product
    - Updates the Windows Registry for application tracking and verification
    - Generates a transcript log for audit and troubleshooting purposes

    Supported Products:
    - Tableau Desktop
    - Tableau Prep Builder

    Transcript Output:
    C:\Windows\Logs\Software\Tableau_LicStatus.log

.PARAMETER Action
    Specifies the licensing action to perform.

    Valid values:
    - Activate   : Activates Tableau Desktop and/or Tableau Prep Builder licenses
                   using the key from License.txt. Skips products that are already
                   activated or not installed. Updates Registry on successful
                   activation.

    - Deactivate : Deactivates (returns) licenses for Tableau Desktop and/or
                   Tableau Prep Builder. Skips products that are not currently
                   activated or not installed. Updates Registry on successful
                   deactivation.

.INPUTS
    License.txt
    A plain text file containing the Tableau license or entitlement key.
    This file must be located in the same directory as the script.
    Only the first line of the file is read and processed.

    Example format:
    XXXXXX-XXXXXX-XXXXXX-XXXXXX

.OUTPUTS
    C:\Windows\Logs\Software\Tableau_LicStatus.log
    Complete transcript of script execution including all status checks,
    activation/deactivation attempts, and verification results.

    <ScriptDirectory>\Tableau_Status.txt
    Temporary output file from Custactutil.exe for Tableau Desktop status checks.
    This file is automatically removed at script completion.

    <ScriptDirectory>\TableauPrep_Status.txt
    Temporary output file from Custactutil.exe for Tableau Prep Builder status checks.
    This file is automatically removed at script completion.

.EXAMPLE
    .\Tableau_License.ps1 -Action Activate

    Activates both Tableau Desktop and Tableau Prep Builder using the license key
    from License.txt. Products that are already activated or not installed are
    skipped. Registry is updated upon successful activation.

.EXAMPLE
    .\Tableau_License.ps1 -Action Deactivate

    Deactivates both Tableau Desktop and Tableau Prep Builder. Products that are
    not currently activated or not installed are skipped. Registry is updated upon
    successful deactivation.

.NOTES
    Author       : Justin Prosser
    Version      : 3.1
    Created      : 4/20/2026
    Last Updated : 4/24/2026

    Requirements:
    - Must be executed with administrative privileges
    - Tableau Desktop and/or Tableau Prep Builder must be installed at:
      C:\Program Files\Tableau\
    - License.txt must exist in the same directory as this script
    - Custactutil.exe must be present in the Tableau installation directory
    - Network connectivity may be required for license validation

    Exit Codes:
    - 0 : Successful completion, or product not installed (no action required)
    - 1 : Failure encountered (missing license file, empty license key, 
          verification failed, or unhandled error)

    Registry Location:
    HKCU:\Software\Tableau\Registration\License

    The script creates or modifies the LicenseStatus registry value to track
    license activation state for application deployment and inventory purposes.

    Process Details:
    - Product paths are auto-detected using wildcard matching
    - License status is verified by parsing Custactutil.exe output
    - Temporary status files are created and removed automatically
    - If Tableau is activated, Tableau Prep Builder is automatically activated
    - If Tableau is deactivated, Tableau Prep Builder is automatically deactivated

.LINK
    Tableau License Activation Documentation:
    https://help.tableau.com/current/desktopdeploy/en-us/desktop_deploy_cli_ref.htm
#>


param (
    [Parameter(Mandatory=$True)]
    [ValidateSet("Activate","Deactivate")]
    [String]$Action
)

Start-Transcript -Path "C:\Windows\Logs\Software\Tableau_LicStatus.log" -Force

Try {
    ## Set the script execution policy for this process
    Try {
        Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop'
    } Catch {
        Write-Output "Warning: Could not set execution policy for this process: $_"
    }


    # Detect Tableau and TableauPrep path
    Write-Output "Setting Tableau filepath variables"
    $Tableau = Get-ChildItem -Path "$env:programfiles\Tableau" -Filter "Tableau.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
    $TableauPrep = Get-ChildItem -Path "$env:programfiles\Tableau" -Filter "Tableau Prep Builder.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
    
    # Run a file check to see if license.txt is in the script's root directory, then pull data from it into $License
    if (!(Test-Path "$PSScriptRoot\License.txt")) {
        Write-Output "License.txt not found in script directory"
        Exit 1
    }
    $License = (Get-Content -path "$PSScriptRoot\License.txt" | Select-Object -First 1).Trim()

    # Validate $license after reading
    if ([string]::IsNullOrEmpty($License)) {
        Write-Output "License.txt is empty or contains no valid key"
        Exit 1
    }
    
    <## Debugging - disabled
    Write-Output @"
    Variables set to the following:
    Tableau: $Tableau
    TableauPrep: $TableauPrep
    #License: $License moved to function Get-TableauLicenseStatus for better comparison
    "@
    #>

    ##*===============================================
    ##* FUNCTIONS
    ##*===============================================
    Function Get-TableauLicenseStatus {
        # Take input from the script and check the specific product's status
        param (
            [Parameter(Mandatory=$True)]
            [ValidateSet("Tableau","Tableau Prep")]
            [String]$Product
        )

        # Switch beween products depending on $Product input
        switch ($Product) {
            "Tableau" {$ProgramName = "$env:programfiles\Tableau\Tableau *.*\bin"}
            "Tableau Prep" {$ProgramName = "$env:programfiles\Tableau\Tableau Prep Builder *.*\Resources"}
        }
        
        Try {
            # Run Custactutil (Tableau Licensing Utility) and store output into *status.txt file 
            $ExecutablePath = Get-ChildItem -Path "$ProgramName" -Filter "Custactutil.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName

            if ([string]::IsNullOrEmpty($ExecutablePath)) {
                Write-Host "Custactutil.exe not found"
                return $False
            }

            # Set $Product to product-specific output files to avoid cross-contamination
            switch ($Product) {
                "Tableau"      { $StatusFile = "$PSScriptRoot\Tableau_Status.txt" }
                "Tableau Prep" { $StatusFile = "$PSScriptRoot\TableauPrep_Status.txt" }
            }
            Write-Host "Checking $Product's license status"
            & $ExecutablePath -view 2>&1 | Tee-Object -FilePath "$StatusFile" | Out-Null
            $LicStatus = Select-String -path "$StatusFile" -Pattern "$License" -SimpleMatch 
            
            <## Debugging - disabled
            Write-Host @"
            Get-TableauLicenseStatus Function Variables set to:
            Product: $Product
            ExecutablePath: $ExecutablePath
            License: $License
            LicStatus: $LicStatus
            "@
            #>
            
            # Check output for active license
            if ($LicStatus) {
                Write-Host "$Product License Status: Active"
                return $True
            }
            else {
                Write-Host "$Product License Status: Not Active"
                return $False
            }
        } Catch {
            Write-Host "Failed to get license status: $_"
            return $False
        }
    }

    # Configure Registry key for SCCM Application verifcation
    Function Set-Registry{
        param (
        [Parameter(Mandatory=$True)]
        [ValidateSet("Active","Inactive")]
        [String]$State
        )

        
        Try {
            # Check to see if $Registry exists, then create it if not (doesn't exist by default, is needed for dectection)
            $Registry ="HKLM:\Software\Tableau\Registration\License"
            if (!(Test-Path -Path "$Registry")){
                Write-Host "Registry path doesn't exist. Creating $Registry"
                New-Item -Path $Registry -Force | Out-Null
                Write-Host "$Registry created."
            }

            <## Debugging - disabled
            Write-Host @" 
            Set-Regisrty Function Variables set to:
            State: $State
            Registry: $Registry
            "@
            #>


            # Check Output for active license
            if ($State -ieq "Active") {
                Write-Host "Setting Registration status in the Registry"
                New-ItemProperty -Path $Registry -Name "LicenseStatus" -Value "Active" -PropertyType String -Force
                Write-Host "Registration status successfully set"

            }
            else {
                # Verify path is correct for proper removal, use $ValueData as a var
                $ValueData = Get-ItemPropertyValue -Path "$Registry" -Name "LicenseStatus" -ErrorAction SilentlyContinue
                
                # Checking if $ValueData is null or not equal to "Active"
                if ($null -eq $ValueData -or $ValueData -ine "Active") {
                Write-Host "Registry key not found or active"
                 return $False
                }
                else {
                    Write-Host "Found $Registry\LicenseStatus, it is set to $ValueData. Proceeding to removal"
                    Write-Host "Removing Registration status from the Registry"
                    Remove-ItemProperty -Path "$Registry" -name "LicenseStatus"
                    Write-Host "Registration status successfully removed"
                }
            }
        } Catch {
            Write-Host "Failed to get registry status: $_"
            return $False
        }
    }

    ##*===============================================
    ##* MAIN SCRIPT
    ##*===============================================


    ##*==================*##
    ##*--- ACTIVATION ---*##
    ##*==================*##
    if ($Action -ieq "Activate"){

        # Initializing key variables early to avoid errors
        [string]$State = ""
        [bool]$RegistrationDue = $False

        # Check to see if Tableau is on the system 
        if (!(test-path -path "$env:programfiles\Tableau")){
            Write-Output  "Tableau isn't currently installed on this system"
            Exit 0
        }
        
        # --- Tableau ---
        if (Test-Path -Path $Tableau){
            Write-Output "Tableau is currently installed here: $Tableau."
            $IsLicensed = Get-TableauLicenseStatus -product "Tableau"

            # Checking Lic status
            if ($IsLicensed.Equals($True)){
                Write-Output "Tableau is already activated, skipping activation"
                $RegistrationDue = $False
            }
        
            # Activating Tableau
            else {
                Write-Output "Tableau is not activated, proceeding with activation"
                Write-Output "Activating Tableau"
                Start-Process -FilePath $Tableau -ArgumentList "-activate $license" -wait #-nonewwindow
                    
                # Verify activation was successful
                Write-Output "Verifying Tableau activation"
                $ActivationCheck = Get-TableauLicenseStatus -product "Tableau"
                if ($ActivationCheck.Equals($True)){
                    Write-Output "Tableau activation verified successfully"
                    $RegistrationDue = $True
                    $State = "Active"
                }
                else {
                    Write-Output "Tableau activation could not be verified, please check manually"
                    $RegistrationDue = $False
                    Exit 1
                }
            }
        }
        
        # --- Tableau Prep ---
        if (Test-Path -Path $TableauPrep){
            Write-Output "Tableau Prep is currently installed here: $TableauPrep."
            $IsLicensed = Get-TableauLicenseStatus -product "Tableau Prep"


            # Checking Lic status
            if ($IsLicensed.Equals($True)){
                Write-Output "Tableau Prep is already activated, skipping activation"
            }
            <# Once Tableau is activated, TableauPrep is automatically activated.
            #Activating Tableau prep
            else {
                Write-Output "Tableau Prep is not activated, proceeding with activation"
                Write-Output "Activating Tableau Prep"
                Start-Process -FilePath $TableauPrep -ArgumentList "-activate $license" -wait #-nonewwindow 
                
                # Verify activation was successful
                Write-Output "Verifying Tableau Prep activation"
                $ActivationCheck = Get-TableauLicenseStatus -product "Tableau Prep"
                if ($ActivationCheck.Equals($True)){
                    Write-Output "Tableau Prep activation verified successfully"
                }
                else {
                    Write-Output "Tableau prep activation could not be verified, please check manually"
                    Exit 1
                }
            }#>
        }

        # --- Registration ---
        Write-Output "Proceeding with registration"

        # Check if $RegistrationDue equals true before setting the registry with $State
        if ($RegistrationDue.Equals($True)){
            Set-Registry -State "$State"
        }
        else {
            Write-Output "Registration not required."
        }
    }

    ##*====================*##
    ##*--- DEACTIVATION ---*##
    ##*====================*##
    elseif ($Action -ieq "Deactivate"){

        # Initializing key variables early to avoid errors
        [string]$State = ""
        [bool]$RegistrationDue = $False

        # --- Tableau ---
        if (Test-Path -Path $Tableau){
            Write-Output "Tableau is currently installed here: $Tableau."
            $IsLicensed = Get-TableauLicenseStatus -product "Tableau" 
            
            # Checking Lic Status
            if (!($IsLicensed.Equals($True))){
                Write-Output "Tableau is not currently activated, skipping deactivation"
                $RegistrationDue = $False
            }

            # Deactivating Tableau
            else {
                Write-Output "Tableau is activated, proceeding with deactivation"
                Write-Output "Deactivating Tableau"
                Start-Process -FilePath $Tableau -ArgumentList "-return $license" -wait #-nonewwindow

                # Verify Deactivation was successful
                Write-Output "Verifying Tableau deactivation"
                $DeactivationCheck = Get-TableauLicenseStatus -product "Tableau"
                if ($DeactivationCheck.Equals($False)){
                    Write-Output "Tableau deactivation verified successfully"
                    $RegistrationDue = $True
                    $State = "Inactive"
                }
                else {
                    Write-Output "Tableau deactivation could not be verified, please check manually"
                    $RegistrationDue = $False
                    Exit 1
                }
            }
        }

        # --- Tableau Prep ---
        if (Test-Path -Path $TableauPrep){
            Write-Output "Tableau Prep is currently installed here: $TableauPrep."
            $IsLicensed = Get-TableauLicenseStatus -product "Tableau Prep"

            # Checking Lic status
            if (!($IsLicensed.Equals($True))){
                Write-Output "Tableau Prep is not currently activated, skipping deactivation"
            }
            <# Once Tableau is deactivated, TableauPrep is automatically deactivated.
            # Deactivating Tableau Prep
            else {
                Write-Output "Tableau prep is activated, proceeding with deactivation"
                Write-Output "Deactivating Tableau"
                Start-Process -FilePath $TableauPrep -ArgumentList "-return $license" -wait #-nonewwindow 

                # Verify Deactivation was successful
                Write-Output "Verifying Tableau Prep deactivation"
                $DeactivationCheck = Get-TableauLicenseStatus -product "Tableau Prep"
                if ($DeactivationCheck.Equals($False)){
                    Write-Output "Tableau Prep deactivation verified successfully"
                }
                else {
                    Write-Output "Tableau prep deactivation could not be verified, please check manually"
                    Exit 1
                }
            }#>       
        }

        # --- Deregistration ---
        Write-Output "Proceeding with deregistration"

        # Check if $RegistrationDue equals True before setting the registry with $State
        if ($RegistrationDue.Equals($True)){
            Set-Registry -State "$State"
        }
        else {
            Write-Output "Deregistration not required."
        }
    } 
} Catch {
        Write-Output "An error occurred: $_"
}

Finally {
# Removes Status Files from $PSScriptRoot for cleanliness. 
# Comment out when troubleshooting

# Handy block for commenting out
Write-Output "Removing status files"
Remove-Item -Path "$PSScriptRoot\*_Status.txt" -ErrorAction SilentlyContinue
#>

Write-Output "All jobs Complete"
Stop-Transcript
}

