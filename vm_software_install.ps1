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

# Dynamic Download of Visual Studio 2022 Professional Bootstrapper & Visual Studio Code
Log-Message "Downloading Visual Studio 2022 Professional Bootstrapper and Visual Studio Code..."
$vs2022BootstrapperURL = "https://aka.ms/vs/17/release/vs_professional.exe"
$vsCodeDirectDownloadURL = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64" 

Invoke-WebRequest -Uri $vs2022BootstrapperURL -OutFile "$downloadDir\vs2022-professional-bootstrapper.exe"
Log-Message "Visual Studio 2022 Professional Bootstrapper downloaded."

Invoke-WebRequest -Uri $vsCodeDirectDownloadURL -OutFile "$downloadDir\vscode-system-installer.exe" 
Log-Message "Visual Studio Code downloaded."

# Installation of Visual Studio 2022 using Bootstrapper
Log-Message "Starting the installation of Visual Studio 2022..."
Start-Process -Wait -FilePath "$downloadDir\vs2022-professional-bootstrapper.exe" -ArgumentList "install --wait --add Microsoft.VisualStudio.Workload.NetWeb --add Microsoft.VisualStudio.Workload.NetCoreTools --quiet --norestart" | Wait-Process
Log-Message "Visual Studio 2022 installation is complete."

# Installation of Visual Studio Code
Log-Message "Initiating the installation of Visual Studio Code..."
Start-Process -Wait -FilePath "$downloadDir\vscode-system-installer.exe" -ArgumentList "/silent", "/mergetasks=!runcode"
Log-Message "Visual Studio Code installation is complete."

# Clean up the installers after installation
Log-Message "Starting cleanup process..."
Remove-Item -Path "$downloadDir\vs2022-professional-bootstrapper.exe"
Log-Message "Visual Studio 2022 Bootstrapper installer removed."

Remove-Item -Path "$downloadDir\vscode-system-installer.exe" 
Log-Message "Visual Studio Code installer removed."

Log-Message "Cleanup process completed."

Log-Message "Preparing to restart the computer..."
Restart-Computer -Force