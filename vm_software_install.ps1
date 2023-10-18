param (
    [string]$vsEdition = "Professional"
)

# Enhanced logging function
function Log-Message {
    param (
        [string]$Message
    )
    $timestampedMessage = "$(Get-Date) - $Message"
    Write-Host $timestampedMessage -ForegroundColor Yellow
    Write-Output $timestampedMessage
}

# Set download directory to TEMP
$downloadDir = $env:TEMP

# Download the ConfigurationFile.ini from the GitHub raw link
$configurationFileURL = "https://raw.githubusercontent.com/bgcodehub/rnd_pipeline/main/config/ConfigurationFile.ini"
$configurationFileLocation = "$downloadDir\ConfigurationFile.ini"
Invoke-WebRequest -Uri $configurationFileURL -OutFile $configurationFileLocation
Log-Message "Configuration file downloaded successfully."

Log-Message "Starting software installation on VM..."

if ($vsEdition -ne "None") {
    # Download SQL Server Installer
    Log-Message "Starting download of SQL Server Installer..."
    $sqlInstallerURL = "https://go.microsoft.com/fwlink/?linkid=2215202&clcid=0x409&culture=en-us&country=us"
    $sqlInstallerPath = "$downloadDir\sqlinstaller.exe"
    Invoke-WebRequest -Uri $sqlInstallerURL -OutFile $sqlInstallerPath
    Log-Message "SQL Server Installer successfully downloaded."

    # Verify installer size
    $installerSize = (Get-Item $sqlInstallerPath).length / 1MB
    Log-Message "Verified SQL Installer size: $installerSize MB"

    # Execute SQL Server Installer
    Log-Message "Initiating SQL Server installation process..."
    Start-Process -Wait -FilePath $sqlInstallerPath -ArgumentList "/Action=Download /MEDIAPATH=$downloadDir /MEDIATYPE=ISO /Q" | Wait-Process
    Log-Message "SQL Server installation files successfully downloaded."

    # Verify the ISO file size
    $isoSize = (Get-Item "$downloadDir\SQLServer2022-x64-ENU.iso").length / 1MB
    Log-Message "Verified ISO file size: $isoSize MB"

    # Mount the ISO file
    $MountVolume = Mount-DiskImage -ImagePath "$downloadDir\SQLServer2022-x64-ENU.iso" -PassThru
    $driveLetter = ($Mountvolume | Get-Volume).DriveLetter + ":"
    Log-Message "SQL Installer files are available on: $driveLetter"

    # Set up the path to the setup executable and the ConfigurationFile
    $installPath = Join-Path -Path $driveLetter -ChildPath "setup.exe"
    $installArguments = "/Configurationfile=$configurationFileLocation /IAcceptSQLServerLicenseTerms /Q"

    # Execute the SQL Server installation
    Log-Message "Beginning SQL Server installation using configuration file..."
    Start-Process -FilePath $installPath -ArgumentList $installArguments -Wait -NoNewWindow
    Log-Message "SQL Server installation has been completed."

    # Clean up
    Log-Message "Cleaning up SQL Server installation artifacts..."
    Dismount-DiskImage -ImagePath "$downloadDir\SQLServer2022-x64-ENU.iso"
    Remove-Item -Path $sqlInstallerPath
    Log-Message "Cleanup for SQL Server completed."
}

# Dynamic Download and Installation of Visual Studio based on user selection
switch ($vsEdition) {
    "Professional" {
        Log-Message "Downloading Visual Studio 2022 Professional Bootstrapper..."
        $vs2022BootstrapperURL = "https://aka.ms/vs/17/release/vs_professional.exe"
        Invoke-WebRequest -Uri $vs2022BootstrapperURL -OutFile "$downloadDir\vs2022-professional-bootstrapper.exe"
        Log-Message "Visual Studio 2022 Professional Bootstrapper downloaded."

        # Installation of Visual Studio 2022 Professional
        Log-Message "Starting the installation of Visual Studio 2022 Professional..."
        Start-Process -Wait -FilePath "$downloadDir\vs2022-professional-bootstrapper.exe" -ArgumentList "install --wait --add Microsoft.VisualStudio.Workload.NetWeb --add Microsoft.VisualStudio.Workload.NetCoreTools --quiet --norestart" | Wait-Process
        Log-Message "Visual Studio 2022 Professional installation is complete."

        # Clean up the installer after installation
        Remove-Item -Path "$downloadDir\vs2022-professional-bootstrapper.exe"
        Log-Message "Visual Studio 2022 Professional Bootstrapper installer removed."
    }
    "Enterprise" {
        Log-Message "Downloading Visual Studio 2022 Enterprise Bootstrapper..."
        $vs2022BootstrapperURL = "https://aka.ms/vs/17/release/vs_enterprise.exe"
        Invoke-WebRequest -Uri $vs2022BootstrapperURL -OutFile "$downloadDir\vs2022-enterprise-bootstrapper.exe"
        Log-Message "Visual Studio 2022 Enterprise Bootstrapper downloaded."

        # Installation of Visual Studio 2022 Enterprise
        Log-Message "Starting the installation of Visual Studio 2022 Enterprise..."
        Start-Process -Wait -FilePath "$downloadDir\vs2022-enterprise-bootstrapper.exe" -ArgumentList "install --wait --add Microsoft.VisualStudio.Workload.NetWeb --add Microsoft.VisualStudio.Workload.NetCoreTools --quiet --norestart" | Wait-Process
        Log-Message "Visual Studio 2022 Enterprise installation is complete."

        # Clean up the installer after installation
        Remove-Item -Path "$downloadDir\vs2022-enterprise-bootstrapper.exe"
        Log-Message "Visual Studio 2022 Enterprise Bootstrapper installer removed."
    }
    "None" {
        Log-Message "Skipping Visual Studio installation as per user's choice."
    }
}

Log-Message "Preparing to restart the computer..."
Restart-Computer -Force