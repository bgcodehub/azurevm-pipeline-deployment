# Set download directory to TEMP
$downloadDir = $env:TEMP

# Download the ConfigurationFile.ini from the GitHub raw link
$configurationFileURL = "https://raw.githubusercontent.com/bgcodehub/rnd_pipeline/main/config/ConfigurationFile.ini"
$configurationFileLocation = "$downloadDir\ConfigurationFile.ini"
Invoke-WebRequest -Uri $configurationFileURL -OutFile $configurationFileLocation
Write-Host "Configuration file downloaded successfully."

Write-Host "Starting software installation on VM..." -ForegroundColor Yellow

# Download SQL Server Installer
Write-Host "Downloading SQL Server Installer..."
$sqlInstallerURL = "https://go.microsoft.com/fwlink/?linkid=2215202&clcid=0x409&culture=en-us&country=us"
Invoke-WebRequest -Uri $sqlInstallerURL -OutFile "$downloadDir\sqlinstaller.exe"
Write-Host "SQL Server Installer downloaded successfully."

# Execute SQL Server Installer
Write-Host "Starting SQL Server installation..."
Start-Process -Wait -FilePath "$downloadDir\sqlinstaller.exe" -ArgumentList "/Action=Download /MEDIAPATH=$downloadDir /MEDIATYPE=ISO /Q" | Wait-Process
Write-Host "SQL Server installation files downloaded."

# Mount the ISO file
$MountVolume = Mount-DiskImage -ImagePath "$downloadDir\SQLServer2022-x64-ENU.iso" -PassThru
$driveLetter = ($Mountvolume | Get-Volume).DriveLetter + ":"
Write-Host "SQL Installer files found on: $driveLetter" -ForegroundColor Green

# Set up the path to the setup executable and the ConfigurationFile
$installPath = Join-Path -Path $driveLetter -ChildPath "setup.exe"
$installArguments = "/Configurationfile=$configurationFile /IAcceptSQLServerLicenseTerms"

# Execute the SQL Server installation
Start-Process -FilePath $installPath -ArgumentList $installArguments -Wait -NoNewWindow
Write-Host "SQL Server installation completed."

# Clean up
Dismount-DiskImage -ImagePath "$downloadDir\SQLServer2022-x64-ENU.iso"
Remove-Item -Path "$downloadDir\sqlinstaller.exe"

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