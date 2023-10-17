# Enhanced logging function
function Log-Message {
    param (
        [string]$Message
    )
    Write-Host "$(Get-Date) - $Message" -ForegroundColor Yellow
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
Log-Message "Downloading SQL Server Installer..."
$sqlInstallerURL = "https://go.microsoft.com/fwlink/?linkid=2215202&clcid=0x409&culture=en-us&country=us"
$sqlInstallerPath = "$downloadDir\sqlinstaller.exe"
Invoke-WebRequest -Uri $sqlInstallerURL -OutFile $sqlInstallerPath
Log-Message "SQL Server Installer downloaded successfully."

# Verify installer size
$installerSize = (Get-Item $sqlInstallerPath).length / 1MB
Log-Message "Installer size: $installerSize MB"

# Execute SQL Server Installer
Log-Message "Starting SQL Server installation..."
Start-Process -Wait -FilePath $sqlInstallerPath -ArgumentList "/Action=Download /MEDIAPATH=$downloadDir /MEDIATYPE=ISO /Q" | Wait-Process
Log-Message "SQL Server installation files downloaded."

# Verify the ISO file size
$isoSize = (Get-Item "$downloadDir\SQLServer2022-x64-ENU.iso").length / 1MB
Log-Message "ISO size: $isoSize MB"

# Mount the ISO file
$MountVolume = Mount-DiskImage -ImagePath "$downloadDir\SQLServer2022-x64-ENU.iso" -PassThru
$driveLetter = ($Mountvolume | Get-Volume).DriveLetter + ":"
Log-Message "SQL Installer files found on: $driveLetter"

# Set up the path to the setup executable and the ConfigurationFile
$installPath = Join-Path -Path $driveLetter -ChildPath "setup.exe"
$installArguments = "/Configurationfile=$configurationFileLocation /IAcceptSQLServerLicenseTerms"

# Execute the SQL Server installation
Start-Process -FilePath $installPath -ArgumentList $installArguments -Wait -NoNewWindow
Log-Message "SQL Server installation completed."

# Clean up
Dismount-DiskImage -ImagePath "$downloadDir\SQLServer2022-x64-ENU.iso"
Remove-Item -Path $sqlInstallerPath

# Dynamic Download of Visual Studio 2022 Professional Bootstrapper & Visual Studio Code
Write-Host "Downloading Visual Studio 2022 Professional Bootstrapper and Visual Studio Code..."

$vs2022BootstrapperURL = "https://aka.ms/vs/17/release/vs_professional.exe"
$vsCodeDirectDownloadURL = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64" 

Invoke-WebRequest -Uri $vs2022BootstrapperURL -OutFile "$downloadDir\vs2022-professional-bootstrapper.exe"
Invoke-WebRequest -Uri $vsCodeDirectDownloadURL -OutFile "$downloadDir\vscode-system-installer.exe" 
Write-Host "Download completed for Visual Studio 2022 Professional Bootstrapper and Visual Studio Code."

# Installation of Visual Studio 2022 using Bootstrapper
Write-Host "Starting installation for Visual Studio 2022 using Bootstrapper..."
Start-Process -Wait -FilePath "$downloadDir\vs2022-professional-bootstrapper.exe" -ArgumentList "install --wait --add Microsoft.VisualStudio.Workload.NetWeb --add Microsoft.VisualStudio.Workload.NetCoreTools" | Wait-Process
Write-Host "Visual Studio 2022 installed successfully using Bootstrapper."

# Installation of Visual Studio Code
Write-Host "Starting installation for Visual Studio Code..."
Start-Process -Wait -FilePath "$downloadDir\vscode-system-installer.exe" -ArgumentList "/silent", "/mergetasks=!runcode"
Write-Host "Visual Studio Code installed successfully."

# Clean up the installers after installation
Remove-Item -Path "$downloadDir\vs2022-professional-bootstrapper.exe"
Remove-Item -Path "$downloadDir\vscode-system-installer.exe" 
Write-Host "Cleanup completed."

Write-Host "Restarting the computer..."
Restart-Computer -Force